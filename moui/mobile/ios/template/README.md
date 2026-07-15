# MoUI iOS Template

This directory is the package-owned canonical Xcode metadata for MoUI's iOS
shell.
The published `moui/mobile/ios` Swift package owns the SwiftUI `App`,
`UIViewRepresentable`, `CAMetalLayer` surface, frame pacing, host adapters, and
plugin registry. The narrow Objective-C++ module only negotiates Mobile Runtime
ABI v1, dispatches its function table, and copies/releases boundary data.

Requirements:

- Xcode 15.4 or newer
- Swift language mode 5
- iOS 15 or newer

Do not copy or customize it for a managed application. Keep application
identity and deployment policy in schema v2 `mobile.json`; the published build
script stages this template into the artifact directory and generates the
Swift configuration:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-ios-app.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json"
```

The project intentionally has no location-dependent local Swift package
reference. Its native build phase compiles the canonical package from the
explicit `--moui-root`. Repository-only fixtures may keep a local package
reference for source navigation.

The app's `mobile.json` must use `ios.shellMode = "managed"`. Schema v2 uses
fixed Mobile Runtime ABI v1 symbols and never reads an app-specific native
export map. Mobile Runtime ABI v1 is single-scene: keep
`UIApplicationSupportsMultipleScenes` false. The Swift shell also rejects a
second concurrent scene instead of sharing one runtime session unsafely.

Managed extensions are source-based `moui.plugin.json` plugins. iOS plugins can
register PlatformView factories and named Host Service channels through shell
API v1; their declared Swift/Objective-C++ sources and resources are compiled
into the app. Plugins cannot bring build scripts, static libraries, frameworks,
or package managers into the managed shell. An app needing those capabilities
must run `moui mobile eject ios --output <dir>` and own the versioned native
project while continuing to use the stable Mobile Runtime ABI.

`--legacy-uikit-shell` selects the frozen Release N UIKit/Objective-C++ fixture
for compatibility auditing only. It is not the managed shell and is not an
eject mechanism.

Keep `UILaunchScreen` in `Info.plist`. It opts the shell into modern full-screen
geometry; removing it may cause legacy `320x480` compatibility scaling on
current simulators and devices.
