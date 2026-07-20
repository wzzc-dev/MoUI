# MoUI Canonical HarmonyOS Shell

This directory is the framework-owned HarmonyOS shell for shell API v1 and
Shell Runtime ABI v1. Applications do not copy it into their repositories.
`moui build harmonyos` resolves `shell.json`, stages this template into the
build directory, writes identity/system UI/plugin configuration, and then
runs Hvigor.

```sh
moui build harmonyos my_app \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app-config "$PWD/shell.json" \
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

`--fallback-skia` is packaging evidence only. Applications that need native
runner ownership use `moui shell eject harmonyos`; the resulting versioned
ejected shell is the supported long-term customization path.
