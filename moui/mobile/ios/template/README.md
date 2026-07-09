# MoUI iOS Template

This template is published with the `wzzc-dev/moui` package. Copy it into an
application workspace as `ios_app/`, then replace `my_app`, bundle ids, product
names, scheme names, and `Info.plist` values with the app's values.

Build through the published package script:

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

The app's `mobile.json` must provide iOS native export metadata under
`ios.native` unless the app id is listed in
`moui/mobile/build-contracts.json`.
