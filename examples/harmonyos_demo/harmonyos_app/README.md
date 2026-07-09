# MoUI HarmonyOS Demo Shell

This directory owns the experimental HarmonyOS shell for the standalone
`examples/harmonyos_demo` app. It is intentionally separate from Counter so the
existing Android/iOS evidence remains stable while HarmonyOS support matures.

The shell is an embedded-session route:

- ArkTS Stage Ability owns the app lifecycle.
- XComponent owns the native drawing surface.
- NAPI/CMake glue owns calls into the MoonBit native exports in
  `examples/harmonyos_demo/harmonyos_skia`.
- `moui/backend/harmonyos/skia` presents Skia RGBA frames to the supplied
  native surface handle.

Use the repository helper for local packaging checks:

```sh
scripts/build-harmonyos-demo-app.sh --fallback-skia
```

`--fallback-skia` validates MoonBit C generation, native glue compilation, and
the staged HarmonyOS layout only. It does not prove runtime support. A real
HarmonyOS support claim still needs a device or emulator smoke that records a
nonblank first frame, pointer input reaching the demo, resize/lifecycle, and
real `libskia.so` loading from the locked HarmonyOS Skia release asset.
