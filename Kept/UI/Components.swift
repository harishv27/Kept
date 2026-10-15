import SwiftUI

/// A habit's icon in a tinted rounded square.
struct HabitIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The check on the right of a habit row.
struct CheckButton: View {
    let done: Bool
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(done ? color : Color.secondary.opacity(0.35), lineWidth: 2)
                    .background(Circle().fill(done ? color : .clear))
                if done {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 30, height: 30)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(done ? "Done" : "Not done")
        .accessibilityAddTraits(.isToggle)
    }
}
