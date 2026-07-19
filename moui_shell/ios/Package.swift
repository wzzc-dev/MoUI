// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MoUIShellShell",
  platforms: [.iOS(.v15)],
  products: [
    .library(name: "MoUIShellShell", targets: ["MoUIShellShell"])
  ],
  targets: [
    .target(
      name: "MoUIShellRuntimeBridge",
      path: "embedder/bridge",
      publicHeadersPath: "include",
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("UIKit"),
      ]
    ),
    .target(
      name: "MoUIShellShell",
      dependencies: ["MoUIShellRuntimeBridge"],
      path: "embedder/Sources/MoUIMobileShell",
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
