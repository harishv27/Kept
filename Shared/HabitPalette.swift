import SwiftUI

/// The colours a habit can have. Chosen to read on both light and dark backgrounds.
enum HabitPalette {
    static let colors: [Color] = [
        Color(red: 0.20, green: 0.62, blue: 0.55), // teal
        Color(red: 0.93, green: 0.42, blue: 0.30), // coral
        Color(red: 0.30, green: 0.52, blue: 0.90), // blue
        Color(red: 0.56, green: 0.44, blue: 0.85), // violet
        Color(red: 0.86, green: 0.34, blue: 0.56), // pink
        Color(red: 0.86, green: 0.67, blue: 0.14), // amber
        Color(red: 0.36, green: 0.68, blue: 0.30), // green
        Color(red: 0.45, green: 0.50, blue: 0.58), // slate
    ]

    static func color(_ index: Int) -> Color { colors[((index % colors.count) + colors.count) % colors.count] }

    static let symbols = [
        "figure.run", "book.fill", "drop.fill", "bed.double.fill", "dumbbell.fill", "leaf.fill",
        "brain.head.profile", "pencil.and.outline", "fork.knife", "pills.fill", "guitars.fill", "paintbrush.fill",
        "figure.mind.and.body", "sun.max.fill", "moon.stars.fill", "heart.fill", "phone.down.fill", "cup.and.saucer.fill",
        "bicycle", "pawprint.fill", "music.note", "laptopcomputer", "checkmark", "star.fill",
    ]
}
