# MoUI Canonical HarmonyOS Shell

This directory is the framework-owned HarmonyOS shell for shell API v1 and
Mobile Runtime ABI v1. Applications do not copy it into their repositories.
`build-harmonyos-hap.sh` resolves `mobile.json`, stages this template into the
build directory, writes identity/system UI/plugin configuration, and then runs
Hvigor.

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-harmonyos-hap.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --renderer auto
```

The canonical shell owns Stage Ability lifecycle, displaySync pacing, IME,
clipboard, accessibility, PlatformView composition, and PlatformChannel
dispatch. Native XComponent callbacks are the exclusive source for surface
attach/resize/detach and pointer/scroll input. Do not add ArkTS
`onAreaChange`, touch, attach, resize, or detach forwarding.

Managed local plugins are declared through `moui.plugin.json`. The resolver
copies validated ArkTS/ETS sources and resources into the staged project and
generates `MoUIGeneratedPlugins.ets`; plugins cannot add Hvigor/CMake scripts,
remote dependencies, native libraries, or `moui.*` namespaces.

`--fallback-skia` is packaging evidence only. Release N app-owned shells remain
available only through `--legacy-shell --harmonyos-project <dir>` and emit a
machine-readable deprecation record. Ejected schema v2 shells are the stable
long-term customization path.
