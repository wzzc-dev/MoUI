# 移动真机证据运行手册

本手册记录 committed 移动路线的匹配真机证据。它是操作指南，不是产品承诺：
路线的 `committed` 状态以其已记录证据为准，真机运行是额外的质量记录，不替代
`checks/platforms/*.json` 中已有的 emulator/simulator 证据。

## Android

签名密钥只从环境读取，绝不提交 keystore。

```sh
export MOUI_ANDROID_KEYSTORE=/secure/path/release.keystore
export MOUI_ANDROID_KEYSTORE_PASSWORD=...
export MOUI_ANDROID_KEY_ALIAS=...
export MOUI_ANDROID_KEY_PASSWORD=...

moui build android <app> --mobile-config "$PWD/moui.mobile.json" --release
adb devices
adb -s <serial> install -r artifacts/android/<app-id>.apk
moui verify android <app> --device <serial> --require-passed
```

未设置 `MOUI_ANDROID_KEYSTORE` 时，`--release` 保留 unsigned fallback APK。
`moui verify` 使用 `android.applicationId` 启动应用，并写入
`artifacts/android/<app>/verify-manifest.json`。

## iOS

release 构建使用 `-O2`；真机安装需要真实 identity 和 provisioning profile。

```sh
moui build ios <app> --mobile-config "$PWD/moui.mobile.json" --release \
  --sdk iphoneos \
  --signing-identity "Apple Development: <name> (<team>)" \
  --provisioning-profile /secure/path/profile.mobileprovision

xcrun devicectl list devices
xcrun devicectl device install app --device <udid> artifacts/ios/<app-id>.app
```

提供 `--signing-identity` 时，CLI 会把 profile 写入
`embedded.mobileprovision` 并运行 `codesign`。没有 identity 的 `iphoneos`
构建会明确记录为 unsigned，不能安装到真机。

`moui verify ios` 目前只支持 simulator（`simctl`）。通过 `devicectl` 的真机
probe 是后续工作；在此之前，把设备安装/启动 transcript 和像素/输入观察记录到
平台 JSON 中作为 evidence limitation，而不是声称一次通过的 L3。

## 记录证据

- 日志、截图、manifest 放在 `artifacts/`；该目录被 gitignore。
- 只把实际观察到的证据写进 `checks/platforms/android.json` / `ios.json`。
- 保持 `docs/platform-readiness-declaration.md` 和支持页与 JSON 一致；治理
  validator 会拒绝活跃文档里 Android/iOS 的过时状态声明。
- 真机运行本身不会提升路线，也不会关闭 GPU seven-gate claim。
