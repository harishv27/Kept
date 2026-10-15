import SwiftUI

/// Colours and the few shared building blocks. Everything is semantic, so dark mode needs no special cases.
enum Theme {
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let line = Color(.separator).opacity(0.5)
    static let side: CGFloat = 20
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.5))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

extension Date {
    /// "Wednesday, 14 October".
    var longDay: String { formatted(.dateTime.weekday(.wide).day().month(.wide)) }
}
