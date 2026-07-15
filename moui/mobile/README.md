# MoUI Mobile Packaging

MoUI mobile packaging support is published inside the `wzzc-dev/moui` package
so an application project can build Android/iOS/HarmonyOS shells without
depending on the MoUI repository checkout.

The reusable pieces live here:

- `scripts/mobile/prepare-native-build.mjs`: generates MoonBit native C,
  resolves Skia provider flags, and writes platform build inputs.
- `scripts/mobile/build-android-apk.sh`: drives an app Gradle project.
- `scripts/mobile/build-ios-app.sh`: drives an app Xcode project.
- `scripts/mobile/build-harmonyos-hap.sh`: drives an app Stage
  Ability/XComponent/Hvigor project.
- `mobile/include/moui_mobile_runtime_v1.h`: stable, versioned C ABI and
  consumer-side function-table compatibility helper.
- `mobile/runtime/moui_mobile_runtime_v1.cpp`: MoonBit ownership adapter behind
  the stable ABI; platform shells do not exchange MoonBit object types.
- `mobile/android/`: canonical Kotlin/AndroidX managed shell, shared Gradle
  glue, registered JNI adapter, CMake module, and framework-staged project
  template.
- `mobile/legacy/android/`: Release N Java/name-mangled-JNI compatibility
  fixture; selected only with `--legacy-java-shell`.
- `mobile/ios/`: canonical SwiftUI managed shell, `CAMetalLayer` host view,
  UIKit service adapters, plugin registry, ABI v1 Objective-C++ bridge, Swift
  package, and framework-staged Xcode template.
- `mobile/ios/legacy/`: Release N UIKit/Objective-C++ compatibility fixture;
  selected only with `--legacy-uikit-shell`.
- `mobile/harmonyos/`: canonical ArkTS Stage Ability/XComponent managed shell,
  generated plugin registry, fixed-ABI NAPI bridge, and CMake module.
- `mobile/test-probe/`: repository-only plugin used by shell contract and
  matching-device evidence jobs; it is never part of a production shell.
- `mobile/android/cmake/MoUIMobileAndroid.cmake`: shared JNI/CMake native
  source list.
- `mobile/harmonyos/cmake/MoUIMobileHarmonyOS.cmake`: shared NAPI/CMake native
  source list.
- `mobile/android/template/`: canonical Android staging and eject source.
- `mobile/ios/template/`: canonical iOS staging and eject source.
- `mobile/harmonyos/template/`: canonical HarmonyOS staging and eject source.
- `mobile/template.mobile.json`: strict schema v2 app metadata without native
  symbol maps or app-owned project paths.

Application developers own shared app code, thin MoonBit mobile entrypoints,
`mobile.json`, and resource overlays. A managed build stages the canonical
native project from the resolved `wzzc-dev/moui` package into `artifacts/`; the
application repository does not carry an Activity, Xcode project, Stage
Ability, JNI/NAPI bridge, or CMake copy. `moui mobile eject` is the explicit
versioned path for applications that need to own and modify those files.

`mobile/build-contracts.json` and `mobile/legacy/fixtures` exist only for the
Release N schema v1 compatibility matrix. Managed and ejected schema v2 builds
derive fixed ABI contracts and do not store app-specific symbol maps.

Android:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-android-apk.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json"
```

The Android default is `MoUIActivity : ComponentActivity` with a bottom
`MoUISurfaceView` and a top `FrameLayout` for native PlatformViews. The build
uses Gradle 9.6.1, AGP 9.2.1 with built-in Kotlin 2.2.10, JVM 17,
`compileSdk 36`, `targetSdk 35`, minSdk 23, NDK 28.2.13676358, and CMake
3.22.1. AndroidX Activity 1.13.0 requires compileSdk 36 even though the product
target remains 35.

The managed JNI layer obtains `moui_mobile_get_runtime_api_v1()` during
`JNI_OnLoad`, rejects an incompatible table with
`moui_mobile_runtime_api_v1_is_compatible()`, and dispatches lifecycle,
renderer, frame, input, and host-service calls only through that table. Surface
detach preserves the application session; terminal application destruction is
a separate ABI operation and is not tied to Android Activity recreation. The
Release N legacy Java shell intentionally retains its direct app-specific
exports and is available only through `--legacy-java-shell`.

iOS Simulator:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-ios-app.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json"
```

The iOS default is a SwiftUI `App` whose `UIViewRepresentable` hosts a
`CAMetalLayer` view and a pass-through PlatformView overlay. Swift owns scene
lifecycle, `CADisplayLink`, touch/scroll, IME, pasteboard, accessibility,
PlatformView, and Host Service adapters. Objective-C++ only negotiates and
dispatches the stable Mobile Runtime ABI v1 function table and copies/releases
length-driven data.

iOS requires Xcode 15.4 or newer, Swift language mode 5, and iOS 15 or newer.
ABI v1 is single-scene: managed plists disable concurrent scenes and the Swift
shell rejects a second scene. Surface detach preserves the application session;
terminal application destruction is a separate ABI operation. The Release N
UIKit fixture is available only through `--legacy-uikit-shell`.

Managed mobile plugins are source/resource manifests. iOS plugin entry types
can register PlatformView factories and named Host Service handlers through
shell API v1. Plugins that require build scripts, package managers, binary
frameworks, or prebuilt native libraries must use an app-owned ejected shell
and keep `mobile/include/moui_mobile_runtime_v1.h` as the compatibility boundary.

Schema v2 uses stable permission capability ids. A plugin permission must also
appear in `mobile.permissions`; managed staging maps the grant to the platform
declaration below and rejects unknown ids with an eject diagnostic.

| Capability | Android | iOS | HarmonyOS |
|---|---|---|---|
| `camera` | `android.permission.CAMERA` | `NSCameraUsageDescription` | `ohos.permission.CAMERA` |
| `microphone` | `android.permission.RECORD_AUDIO` | `NSMicrophoneUsageDescription` | `ohos.permission.MICROPHONE` |
| `location` | coarse + fine location | when-in-use usage description | approximate + precise location |
| `photos` | legacy/read-media image permissions | photo-library usage description | `ohos.permission.READ_IMAGEVIDEO` |
| `notifications` | `POST_NOTIFICATIONS` | runtime authorization; no plist key | runtime notification manager; no manifest grant |
| `clipboard` | no manifest grant | no plist key | canonical `READ_PASTEBOARD` declaration |

Versioned ejected shells own any additional platform-specific permission and
purpose declarations.

HarmonyOS:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-harmonyos-hap.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --fallback-skia
```

The HarmonyOS default is the package-owned `MoUIRoot`: ArkTS owns
`displaySync`, IME, pasteboard, accessibility, PlatformView overlays, and Host
Service plugins, while native XComponent callbacks are the only source of
surface, resize, pointer, scroll, and detach events. The floor is API 20; the
target and model remain API 21 / 6.0.1.

For any platform, an ejected build must pass both the native project path and
the corresponding `--ejected-shell` flag. The builder validates
`.moui-shell.json` shell API/runtime ABI compatibility but does not overwrite
or update the ejected project. Legacy flags accept only the schema v1 fixtures,
emit `mobile-deprecation.json`, and are removed in Release N+1.

Fallback Skia builds (`--fallback-skia`) are packaging evidence only. A passed
Android/iOS/HarmonyOS runtime claim still requires a non-fallback build plus
matching emulator/simulator or device smoke evidence.
