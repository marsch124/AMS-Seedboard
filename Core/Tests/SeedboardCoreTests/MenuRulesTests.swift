import XCTest
@testable import SeedboardCore

/// Pick 25: the menu bar and the keys.
final class MenuRulesTests: XCTestCase {
    func testTheInsertMenuListsTheSevenToolsEachWithItsOwnLetter() {
        XCTAssertEqual(MenuRules.tools.map(\.name), ["Mind map", "Box", "Diamond", "Arrow", "Sticky note", "Text", "Frame"])
        XCTAssertEqual(String(MenuRules.tools.map(\.letter)), "mbdantf")
        XCTAssertEqual(MenuRules.moreShapes.map(\.kind), [.round, .oval])
        let letters = (MenuRules.tools + MenuRules.moreShapes).map(\.letter)
        XCTAssertEqual(Set(letters).count, letters.count)
        // Only the arrow tool makes no thing of its own.
        XCTAssertEqual(MenuRules.tools.filter { $0.kind == nil }.map(\.name), ["Arrow"])
    }

    func testALetterIsAToolOnlyWhenItCannotBeMeantAsAWord() {
        XCTAssertTrue(MenuRules.lettersAreTools(surfaceHasKeys: true, typing: false, chosen: 0, arrowChosen: false, readOnly: false))
        // Words are being typed, a text field has the keys, one thing is chosen (a letter types in it),
        // an arrow is chosen, or the board cannot be changed: the letter is not a tool.
        XCTAssertFalse(MenuRules.lettersAreTools(surfaceHasKeys: true, typing: true, chosen: 1, arrowChosen: false, readOnly: false))
        XCTAssertFalse(MenuRules.lettersAreTools(surfaceHasKeys: false, typing: false, chosen: 0, arrowChosen: false, readOnly: false))
        XCTAssertFalse(MenuRules.lettersAreTools(surfaceHasKeys: true, typing: false, chosen: 1, arrowChosen: false, readOnly: false))
        XCTAssertFalse(MenuRules.lettersAreTools(surfaceHasKeys: true, typing: false, chosen: 0, arrowChosen: true, readOnly: false))
        XCTAssertFalse(MenuRules.lettersAreTools(surfaceHasKeys: true, typing: false, chosen: 0, arrowChosen: false, readOnly: true))
    }

    func testAShortPressOfSpaceTypesAndAPressWithADragOnlySlides() {
        XCTAssertTrue(MenuRules.spaceStartsTyping(slid: false, held: 0.12, chosen: 1, typing: false))
        XCTAssertFalse(MenuRules.spaceStartsTyping(slid: true, held: 0.12, chosen: 1, typing: false))
        XCTAssertFalse(MenuRules.spaceStartsTyping(slid: false, held: 0.8, chosen: 1, typing: false))
        XCTAssertFalse(MenuRules.spaceStartsTyping(slid: false, held: 0.12, chosen: 0, typing: false))
        XCTAssertFalse(MenuRules.spaceStartsTyping(slid: false, held: 0.12, chosen: 2, typing: false))
        XCTAssertFalse(MenuRules.spaceStartsTyping(slid: false, held: 0.12, chosen: 1, typing: true))
    }
}
