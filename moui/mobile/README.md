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
- `mobile/android/mobile-app.gradle`: shared Android Gradle glue.
- `mobile/android/cmake/MoUIMobileAndroid.cmake`: shared JNI/CMake native
  source list.
- `mobile/harmonyos/cmake/MoUIMobileHarmonyOS.cmake`: shared NAPI/CMake native
  source list.
- `mobile/android/template/`: copyable minimal Android project.
- `mobile/ios/template/`: copyable minimal iOS Xcode project.
- `mobile/harmonyos/template/`: copyable minimal HarmonyOS project.
- `mobile/template.mobile.json`: copyable app metadata and native export
  contract skeleton.

Application developers own their app `mobile.json`, Android Gradle project,
iOS Xcode project, HarmonyOS Stage Ability project, and MoonBit platform
entrypoint packages. The MoUI package owns only the reusable shell/build
templates. The repository example contracts in `mobile/build-contracts.json`
are compatibility defaults for MoUI's own Counter and Component Gallery
examples; external apps should put their native contract in their own
`mobile.json`.

Android:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-android-apk.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --android-project "$PWD/android_app"
```

iOS Simulator:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-ios-app.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --xcode-project "$PWD/ios_app/MoUIMobileApp.xcodeproj" \
  --scheme MoUIMobileApp \
  --product-name MoUIMobileApp
```

HarmonyOS:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-harmonyos-hap.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --harmonyos-project "$PWD/harmonyos_app" \
  --fallback-skia
```

Fallback Skia builds (`--fallback-skia`) are packaging evidence only. A passed
Android/iOS/HarmonyOS runtime claim still requires a non-fallback build plus
matching emulator/simulator or device smoke evidence.
