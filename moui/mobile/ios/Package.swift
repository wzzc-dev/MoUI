// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MoUIMobileShell",
  platforms: [.iOS(.v15)],
  products: [
    .library(name: "MoUIMobileShell", targets: ["MoUIMobileShell"])
  ],
  targets: [
    .target(
      name: "MoUIMobileRuntimeBridge",
      path: "bridge",
      publicHeadersPath: "include",
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("UIKit"),
      ]
    ),
    .target(
      name: "MoUIMobileShell",
      dependencies: ["MoUIMobileRuntimeBridge"],
      path: "Sources/MoUIMobileShell",
      linkerSettings: [
        .linkedFramework("Metal"),
        .linkedFramework("QuartzCore"),
        .linkedFramework("SwiftUI"),
        .linkedFramework("UIKit"),
      ]
    ),
  ],
  cxxLanguageStandard: .cxx17
)
