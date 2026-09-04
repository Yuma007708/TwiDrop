// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TwiDropKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "TwiDropKit", targets: ["TwiDropKit"])
    ],
    targets: [
        // Foundation のみに依存するので、iOS 実機・シミュレータに加えて
        // Linux 上の CI でもそのままテストできる。
        .target(name: "TwiDropKit"),
        .testTarget(name: "TwiDropKitTests", dependencies: ["TwiDropKit"]),
    ]
)
