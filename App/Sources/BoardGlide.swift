import SwiftUI
import QuartzCore
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 1: the board glides instead of jumping. Every move of the view the owner did not make with his own
// fingers — a zoom step, "Show the whole board", bringing a new idea into sight, the iPhone's zoom for typing —
// is stepped by the session itself, frame by frame (the rule and the times: `Glide` in the Core). The drawing is
// one Canvas, which SwiftUI cannot animate; stepping the view keeps drawing, frame, bar and typing field together.
// A finger, a scroll or a key ends a glide at once, where it is. No glide when a board opens, none with
// "Reduce Motion", none on a timeline (it places its days itself).

/// The screen's own frame clock, running only while something is in motion.
@MainActor
final class FrameClock: NSObject {
    private var link: CADisplayLink?
    private var timer: Timer?
    private var onFrame: (() -> Void)?

    var running: Bool { link != nil || timer != nil }

    func start(_ frame: @escaping () -> Void) {
        onFrame = frame
        guard !running else { return }
        #if os(macOS)
        if let screen = NSScreen.main {
            let made = screen.displayLink(target: self, selector: #selector(tick))
            made.add(to: .main, forMode: .common)
            link = made
            return
        }
        #else
        let made = CADisplayLink(target: self, selector: #selector(tick))
        made.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        made.add(to: .main, forMode: .common)
        link = made
        #endif
        if link == nil {
            // No screen to ask (a Mac with its lid shut): a plain timer does.
            let made = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.onFrame?() }
            }
            RunLoop.main.add(made, forMode: .common)
            timer = made
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
        timer?.invalidate()
        timer = nil
        onFrame = nil
    }

    @objc private func tick() { onFrame?() }
}

extension BoardSession {
    /// Whether the view may glide right now.
    private var glides: Bool { BoardMotion.on && !board.isTimeline && viewSize.width > 10 }

    /// Makes `move` (which puts the view where it shall stand) a glide of `seconds` from where the view shows now.
    /// A glide that is still running counts as arrived for the move (three quick zoom steps are three full steps),
    /// but the eye goes on from where the board shows. A move inside a move is just a move.
    func glide(_ seconds: Double, _ move: () -> Void) {
        if motion.inMove { move(); return }
        let shown = (offset: place.offset, scale: place.scale)
        let running = motion.glide
        if let running {
            stand(at: running.plan.toOffset, scale: running.plan.toScale)
            motion.glide = nil
        }
        motion.inMove = true
        move()
        motion.inMove = false
        guard seconds > 0, glides else { return }
        let plan = Glide(fromOffset: shown.offset, fromScale: shown.scale, toOffset: place.offset, toScale: place.scale, seconds: seconds)
        guard !plan.isStill else { return }
        stand(at: shown.offset, scale: shown.scale)
        if let running, running.plan.toOffset == plan.toOffset, running.plan.toScale == plan.toScale {
            // The move changed nothing: the glide goes on as it was.
            motion.glide = running
        } else {
            motion.now = CACurrentMediaTime()
            motion.glide = (plan, motion.now)
        }
        startMotionClock()
    }

    /// A finger, a scroll or a key landed: the glide ends at once, where it is.
    func stopGlide() {
        guard !motion.inMove else { return }
        motion.glide = nil
    }

    /// The view is placed from outside (its room changed): a running glide is at its end first.
    func settleGlide() {
        #if DEBUG
        motionTryOnce()
        #endif
        guard !motion.inMove, let running = motion.glide else { return }
        motion.glide = nil
        stand(at: running.plan.toOffset, scale: running.plan.toScale)
    }

    /// The room changed while a glide runs (the keyboard coming up during the iPhone's zoom for typing): the glide
    /// goes on to the new end. With no glide running the view is placed at once, as before.
    func retarget(_ move: () -> Void) {
        glide(motion.glide?.plan.seconds ?? 0, move)
    }

    /// One zoom step (the Smaller and Bigger buttons, ⌘+ and ⌘−, Actual Size): the middle stays put.
    func zoomStep(by factor: CGFloat) {
        glide(Glide.zoomStep) { zoom(to: scale * factor) }
    }

    /// Life size (⌘0).
    func zoomStep(to size: CGFloat) {
        glide(Glide.zoomStep) { zoom(to: size) }
    }

    /// iPhone: the view goes to life size round the words being typed, and back afterwards — as a glide.
    func typing(in id: UUID?) {
        guard Finger.phone else { return }
        glide(Glide.intoSight) { typingJump(in: id) }
    }

    // MARK: The clock

    func startMotionClock() {
        guard !motion.clock.running else { return }
        let clock = motion.clock
        clock.start { [weak self, weak clock] in
            if let self { self.motionFrame() } else { clock?.stop() }
        }
    }

    /// One frame: the view goes one step along its glide, and things on their way are drawn again.
    private func motionFrame() {
        motion.now = CACurrentMediaTime()
        if let running = motion.glide {
            let part = motion.part(since: running.began, of: running.plan.seconds)
            if part >= 1 {
                motion.glide = nil
                stand(at: running.plan.toOffset, scale: running.plan.toScale)
            } else {
                let step = running.plan.view(at: part)
                stand(at: step.offset, scale: step.scale)
            }
        }
        if motion.animating {
            // What has arrived is let go; one more drawing shows it at rest.
            motion.prune()
            objectWillChange.send()
        }
        if motion.glide == nil, !motion.animating { motion.clock.stop() }
    }
}
