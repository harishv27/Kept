// swift-tools-version: 5.9
import PackageDescription

// Pure logic shared by the app and the widget: day keys, schedules, streaks and stats.
// No UI and no SwiftData here, so `swift test` runs it on the Mac in seconds.
let package = Package(
    name: "KeptCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KeptCore", targets: ["KeptCore"])],
    targets: [
        .target(name: "KeptCore"),
        .testTarget(name: "KeptCoreTests", dependencies: ["KeptCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
