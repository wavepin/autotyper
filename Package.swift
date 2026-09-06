// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Autotyper",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Autotyper", targets: ["Autotyper"])],
    targets: [
        .target(name: "AutotyperCore"),
        .executableTarget(name: "Autotyper", dependencies: ["AutotyperCore"]),
        .executableTarget(name: "AutotyperChecks", dependencies: ["AutotyperCore"], path: "Tests/AutotyperCoreTests")
    ],
    swiftLanguageModes: [.v6]
)
