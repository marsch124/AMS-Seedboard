import Foundation
import SeedboardCore

extension Sample {
    /// A made-up "Who does what" board: four names, nine messages (one of them to itself), a note and
    /// a section. `-board Loan` opens it (no other sample board has that word in its name);
    /// `-pick <word>` chooses a name or a message by its words.
    static func loanSteps(now: Date = Date()) -> Board {
        var board = Board.sequence(title: "Loan steps", created: now.addingTimeInterval(-86_400 * 2))
        board.colour = "teal"
        let anna = board.addWho("Anna")
        let bank = board.addWho("Bank")
        let builder = board.addWho("Builder")
        let council = board.addWho("Council")
        board.addMessage("Ask for loan", from: anna, to: bank)
        board.addMessage("Check the papers", from: bank, to: bank)
        board.addBand("Bank closed on Sundays")
        board.addMessage("Yes, up to 2 million", from: bank, to: anna, answer: true)
        let order = board.addMessage("Order the build", from: anna, to: builder)
        board.addMessage("Ask for permit", from: builder, to: council)
        board.addMessage("Permit granted", from: council, to: builder, answer: true)
        board.addMessage("Start in May", from: builder, to: anna, answer: true)
        board.addSection("If the loan is refused")
        board.addMessage("Ask again with a guarantor", from: anna, to: bank)
        board.addMessage("New offer", from: bank, to: anna, answer: true)
        if let order, let i = board.index(of: order) { board.items[i].todo = true }
        board.changed = now.addingTimeInterval(-7_200)
        return board
    }
}
