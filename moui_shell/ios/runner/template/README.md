# MoUI iOS Template

This directory is the package-owned canonical Xcode metadata for MoUI's iOS
shell.
The published `moui_shell/ios` Swift package owns the SwiftUI `App`,
`UIViewRepresentable`, `CAMetalLayer` surface, frame pacing, host adapters, and
plugin registry. The narrow Objective-C++ module only negotiates Shell Runtime
ABI v1, dispatches its function table, and copies/releases boundary data.

Requirements:

- Xcode 15.4 or newer
- Swift language mode 5
- iOS 15 or newer

Do not copy or customize it for a managed application. Keep application
identity and deployment policy in schema v1 `shell.json`; `moui build ios`
stages this template into the artifact directory and generates the
Swift configuration:

```sh
moui build ios my_app \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app-config "$PWD/shell.json"
```

The project intentionally has no location-dependent local Swift package
reference. Its native build phase compiles the canonical package from the
explicit `--moui-root`. Repository-only fixtures may keep a local package
reference for source navigation.

The app's `shell.json` must use `ios.runnerMode = "managed"`. Schema v1 uses
fixed Embedding API v1 symbols and never reads an app-specific native
export map. Shell Runtime ABI v1 is single-scene: keep
`UIApplicationSupportsMultipleScenes` false. The Swift shell also rejects a
second concurrent scene instead of sharing one runtime session unsafely.

Managed extensions are source-based `moui.plugin.json` plugins. iOS plugins can
register PlatformView factories and named Host Service channels through shell
API v1; their declared Swift/Objective-C++ sources and resources are compiled
into the app. Plugins cannot bring build scripts, static libraries, frameworks,
or package managers into the managed shell. An app needing those capabilities
must run `moui shell eject ios --output <dir>` and own the versioned native
project while continuing to use the stable Shell Runtime ABI.

Keep `UILaunchScreen` in `Info.plist`. It opts the shell into modern full-screen
geometry; removing it may cause legacy `320x480` compatibility scaling on
current simulators and devices.
