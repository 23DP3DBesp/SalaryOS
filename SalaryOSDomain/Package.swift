// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryOSDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalaryOSDomain", targets: ["SalaryOSDomain"]),
        .library(name: "SalaryOSPersistence", targets: ["SalaryOSPersistence"])
    ],
    targets: [
        .target(name: "SalaryOSDomain"),
        .target(name: "SalaryOSPersistence", dependencies: ["SalaryOSDomain"]),
        .testTarget(name: "SalaryOSDomainTests", dependencies: ["SalaryOSDomain"]),
        .testTarget(name: "SalaryOSPersistenceTests", dependencies: ["SalaryOSDomain", "SalaryOSPersistence"])
    ]
)
