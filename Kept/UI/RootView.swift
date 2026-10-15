import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checkmark.circle") }
            HabitsView()
                .tabItem { Label("Habits", systemImage: "list.bullet") }
        }
    }
}
