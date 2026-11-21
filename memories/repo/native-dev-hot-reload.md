# Native dev hot reload: host + app plugin

2026-11-22, plan `docs/plans/active/native-dev-hot-reload.md`, ADR 0072.

## Shape

A generated macOS host (normal MoUI entrypoint) keeps window/renderer/input and
paints a full-window `DevBridgeView`; a generated `foreign_library` plugin owns
the app `Program` + `AppRuntime`. `moui dev <app> --hot` builds the plugin,
links a uniquely named `gen-<n>/plugin.dylib`, and atomically repoints a marker
the host polls (250 ms timer). A failed build/load keeps the old generation.

Link recipe: `cc -shared -Wl,-force_load,<plugin.a> "$MOON_HOME/lib/libbacktrace.a" -lm -o plugin.dylib`.
Host must `dlsym("moonbit_init")` and call it before `dev_abi_version`/`dev_create`.
ABI v1: `dev_abi_version/create/destroy/event/frame/frame_len/frame_release/flush/resize`;
UTF-8 JSON and copied byte buffers only — no MoonBit objects across images.

## Gotchas

- `dlopen` keys images by path: reloading a rewritten path returns the old image
  and produced a blank window. Publish `gen-<n>/plugin.dylib` instead.
- macOS `dlclose` does not unmap MoonBit dylibs (~1.9 MB retained per swap).
  Host re-execs after 32 swaps (`MOUI_HOT_RELOAD_LIMIT`, `0` disables).
- Do not put generated packages under `.moui/`: `moon build .moui/...` says
  "no work to do". Use gitignored `moui_devhost/dev_hot/`.
- Fast path replays `moon build --dry-run -v` app/plugin compile + link-core +
  libtool steps; the source-shape cache must strip mtime floats
  (`:\d+(?:\.\d+)?:\d+$`) or it never hits (was 2.5-3.5 s/reload).
- Warm reload measured p50 ~0.63 s (n=9); 20-reload run retained PID/window,
  count 2, RSS 88→128 MB. Build error kept generation and UI interactive.
