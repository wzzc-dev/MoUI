# Mobile Device Evidence Runbook

This runbook records matching-device evidence for the committed mobile routes.
It is an operator guide, not a product claim: a route stays `committed` on its
recorded evidence, and a physical-device run is an additional quality record,
not a substitute for the emulator/simulator evidence already in
`checks/platforms/*.json`.

## Android

Signing secrets come from the environment; never commit a keystore.

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

Without `MOUI_ANDROID_KEYSTORE`, `--release` keeps the unsigned fallback APK.
`moui verify` launches the app with `android.applicationId` and writes
`artifacts/android/<app>/verify-manifest.json`.

## iOS

The release build compiles with `-O2`; pass a real identity and provisioning
profile for a device build.

```sh
moui build ios <app> --mobile-config "$PWD/moui.mobile.json" --release \
  --sdk iphoneos \
  --signing-identity "Apple Development: <name> (<team>)" \
  --provisioning-profile /secure/path/profile.mobileprovision

xcrun devicectl list devices
xcrun devicectl device install app --device <udid> artifacts/ios/<app-id>.app
```

The CLI embeds the provisioning profile as `embedded.mobileprovision` and runs
`codesign` when `--signing-identity` is present. Without an identity, an
`iphoneos` build logs that it is unsigned and cannot be installed on a device.

`moui verify ios` is currently simulator-only (`simctl`). A physical-device
probe through `devicectl` is a follow-up; until it lands, record the device
installation/launch transcript and any pixel/input observations in the platform
JSON as an evidence limitation rather than claiming a passed L3 run.

## Recording evidence

- Keep generated logs/screenshots/manifests under `artifacts/`; it is
  gitignored.
- Update `checks/platforms/android.json` / `ios.json` only with the evidence
  that was actually observed.
- Keep `docs/platform-readiness-declaration.md` and the support pages aligned
  with the JSON; the governance validator rejects live Android/iOS
  `experimental` claims.
- A physical-device run does not by itself promote a route or close the GPU
  seven-gate claim.
