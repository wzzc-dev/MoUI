# MoUI Android Template

This template is published with the `wzzc-dev/moui` package. Copy it into an
application workspace as `android_app/`, then replace `my_app`,
`MoUIMobileAndroid`, and Android package metadata with the app's values.

Build through the published package script:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-android-apk.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --android-project "$PWD/android_app"
```

The app's `mobile.json` must provide Android native export metadata under
`android.native` unless the app id is listed in
`moui/mobile/build-contracts.json`.
