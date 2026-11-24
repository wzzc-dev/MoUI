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
Optional (resolved as a trio, all-or-nothing): `dev_semantics_action`,
`dev_semantics_action_len`, `dev_semantics_action_release`.

## Platform state (ADR 0076)

- Frame JSON carries additive `semantics`, `platform_views`, `overlay_bounds`,
  `clear_color` and `text_input`. Missing means absent; never invent state.
- Generated host passes `@devhost.driver_hooks()` into the backend options.
  Hooks override semantics reads/actions, focused text input and `augment_frame`;
  `augment_frame` overlays platform fields on the host frame and forces full
  damage. Production host paths keep defaults.
- Swap cleanup: `clear_after_reload` drops payload/text input and bumps a
  synthetic semantics generation, so the next `read_semantics` is an empty
  Full snapshot (old nodes cannot survive). `wrap_platform_view_plugin` calls
  `dispose_platform_views` when `host_reloads` changes, before syncing the new
  generation's first frame — macOS only hides unseen views, so absence is not
  disposal.
- Native platform views require the generator to be given
  `--platform-view-plugin <module> --platform-view-plugin-fn <fn>`; `moui dev`
  does not expose those flags yet, so default hot apps have no native views.
- Unverified without a matching host: live macOS AX query/action, live Linux
  AT-SPI client, native platform-view presentation. Portable codecs, bridge and
  cleanup are covered by `moui_devhost` tests.

## Gotchas

- `dlopen` keys images by path: reloading a rewritten path returns the old image
  and produced a blank window. Publish `gen-<n>/plugin.dylib` instead.
- macOS `dlclose` does not unmap MoonBit dylibs (~1.9 MB retained per swap).
  Host re-execs after 32 swaps (`MOUI_HOT_RELOAD_LIMIT`, `0` disables).
- Do not put generated packages under `.moui/`: `moon build .moui/...` says
  "no work to do". Use gitignored `moui_devhost/dev_hot/`.
- Fast path replays `moon build --dry-run -v` app/plugin compile + link-core +
  libtool steps; the source-shape cache must strip mtime floats
  (`:\d+(?:\.\d+)?:\d+$`) or it never hits (was 2.5-3.5 s/reload). The change
  watcher is the opposite: it must keep path+mtime+size, otherwise edits to an
  existing file never change the snapshot and no reload fires (fixed in Phase
  2B; `hotSourceShape` = fast-plan cache, `hotSourceSnapshot` = watcher).
- Warm reload measured p50 ~0.63 s (n=9); 20-reload run retained PID/window,
  count 2, RSS 88→128 MB. Build error kept generation and UI interactive.
