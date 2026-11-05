// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryOSDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalaryOSDomain", targets: ["SalaryOSDomain"]),
        .library(name: "SalaryOSPersistence", targets: ["SalaryOSPersistence"]),
        .library(name: "SalaryOSApplication", targets: ["SalaryOSApplication"]),
        .library(name: "SalaryOSTax", targets: ["SalaryOSTax"])
    ],
    targets: [
        .target(name: "SalaryOSDomain"),
        .target(name: "SalaryOSPersistence", dependencies: ["SalaryOSDomain"]),
        .target(name: "SalaryOSApplication", dependencies: ["SalaryOSDomain"]),
        .target(name: "SalaryOSTax", dependencies: ["SalaryOSDomain"]),
        .testTarget(name: "SalaryOSDomainTests", dependencies: ["SalaryOSDomain"]),
        .testTarget(name: "SalaryOSPersistenceTests", dependencies: ["SalaryOSDomain", "SalaryOSPersistence"]),
        .testTarget(name: "SalaryOSApplicationTests", dependencies: ["SalaryOSDomain", "SalaryOSPersistence", "SalaryOSApplication"]),
        .testTarget(name: "SalaryOSTaxTests", dependencies: ["SalaryOSTax", "SalaryOSDomain"])
    ]
)
