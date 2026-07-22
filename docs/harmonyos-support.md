# HarmonyOS Support

HarmonyOS uses the **window-hosted** mobile route and is currently
`runtime_partial`. `wzzc-dev/window/harmonyos` owns the Stage Ability,
XComponent surface, lifecycle, and input queue; `moui/backend/harmonyos`
adapts those callbacks into the MoUI runtime session.

## Entry Points

| Piece | Location |
|---|---|
| App logic | `examples/<app>/app` |
| Mobile metadata | `examples/<app>/moui.mobile.json` |
| MoonBit entrypoint | `examples/<app>/harmonyos_window_hosted` |
| HarmonyOS host template | `wzzc-dev/window/harmonyos/template` |
| MoUI adapter | `moui/backend/harmonyos/window_hosted.mbt` |

XComponent callbacks are the sole source for surface, pointer, resize, and
detach events. The hosted event loop forwards them to
`HarmonyOsWindowHostedApp`; do not inject a second surface or input route.

## Toolchain

- `HARMONYOS_SDK_HOME` points to the DevEco/OpenHarmony SDK
- Compatible API 20, target API 21, and model `6.0.1`
- `hvigorw` and `ohpm` available from the SDK/toolchain setup

Run `moui doctor --platform harmonyos` before a native build.

## Build And Run

```sh
moon check examples/harmonyos_demo/harmonyos_window_hosted --target native
moui build harmonyos harmonyos_demo \
  --mobile-config "$PWD/examples/harmonyos_demo/moui.mobile.json"
moui run harmonyos harmonyos_demo \
  --mobile-config "$PWD/examples/harmonyos_demo/moui.mobile.json"
```

`--prepare-only` stops before hvigor. `--fallback-skia` is packaging-only
diagnostic coverage and cannot promote runtime readiness.

## Validation And Evidence

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/harmonyos --target native
```

A device or HVD claim requires first frame, input, surface detach/recreate,
IME, clipboard, accessibility, and async-image observations. Signed-device
evidence is required before treating `checks/platforms/harmonyos.json` as more
than `partial`.

## Status

The source path and host-sim route are available, while actual presentation and
full service evidence are pending. See `docs/platform-readiness-declaration.md`
and `docs/window-hosted-moui.md` for the readiness boundary.
