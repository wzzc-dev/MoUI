# MoUI HarmonyOS Template

This template is published with the `wzzc-dev/moui` package. Copy it into an
application workspace as `harmonyos_app/`, then replace `my_app`, bundle names,
labels, and native export metadata to match your app.

Build through the package script:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-harmonyos-hap.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --harmonyos-project "$PWD/harmonyos_app" \
  --fallback-skia
```

The app's `mobile.json` must provide HarmonyOS native export metadata under
`harmonyos.native` unless the app id is listed in
`moui/mobile/build-contracts.json`.

`--fallback-skia` validates MoonBit C generation, native glue compilation, and
the staged HAP layout only. A runtime support claim still requires a non-fallback
build plus matching device or emulator smoke evidence.
