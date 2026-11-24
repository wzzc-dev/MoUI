# 0073: Linux native dev hot reload — same bridge host, PIC plugin image

- **Date**: 2026-11-24
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: `native-dev-hot-reload-linux` (plan row in
  `docs/plans/done/INDEX.md`), ADR 0072, ADR 0068

## Context

ADR 0072 brought in-place native hot reload to macOS: a generated bridge host
owns the window, renderer, input and platform services, while the app is
rebuilt as a `foreign_library` and linked into a uniquely named plugin image
loaded over a small ABI. `moui dev --hot` rejected every other host, so the
canonical Linux route (`moui/backend/linux` + `moui_skia_renderer`) still
restarted the process and recreated the window on every edit.

Linux adds two constraints beyond the macOS design:

1. MoonBit's native backend has no shared-library package type. Its
   `foreign_library` is a static archive whose MoonBit runtime objects are
   compiled without `-fPIC`, so linking an ELF `.so` fails with
   `R_X86_64_PC32` relocations against libc symbols. `-Wl,-z,notext` does not
   fix the relocations.
2. The Linux window event loop polls X11/Wayland directly and does not iterate
   the GLib default main context. `linux_timer_source` attaches `g_timeout_add`
   sources to that context, so a `@services.TimerSource` subscription — the
   250 ms generation-marker poll used by the bridge host — never ticked.

## Decision

Port the bridge-host design to Linux without a second protocol:

- The generator takes an explicit `--platform macos|linux`; the Linux host is a
  normal MoUI entrypoint that owns the window/renderer/input and paints
  `DevBridgeView` through `@render_skia.from_env(platform=Linux)` and
  `@linux_backend.entry()`. Generated sources stay under the gitignored
  `moui_devhost/dev_hot/`, and the app module stays listed in
  `moui_devhost/moon.mod`.
- The app plugin is still a `foreign_library`. Its generated package compiles
  with `link.native.cc-flags: "-fPIC"`. For each generation the runner copies
  `plugin.a`, recompiles every `$MOON_HOME/lib/runtime/*.c` member with the same
  flags plus `-fPIC`, replaces those members in the copy, then links:

  ```sh
  cc -shared -Wl,-Bsymbolic -Wl,--whole-archive plugin.pic.a \
     -Wl,--no-whole-archive "$MOON_HOME/lib/libbacktrace.a" -lm -o plugin.so
  ```

  `-Bsymbolic` keeps the plugin's own MoonBit symbols from being preempted by
  the host executable's copy. Each generation is published as a new
  `gen-<n>/plugin.so`; the marker is renamed atomically, never rewritten.
- Load/swap keeps ABI v1 and the macOS order: `dlopen`, call `moonbit_init`,
  check `dev_abi_version == 1`, flush the old session, create the new one, then
  destroy and `dlclose` the old image. A failed build/load leaves the previous
  generation interactive. Only UTF-8 JSON and copied byte buffers cross images.
- The Linux backend pumps the GLib default context from its `about_to_wait`
  hook and sets the loop's `WaitUntil` deadline from the next GLib timeout.
  This makes `TimerSource` subscriptions work in ordinary Linux apps as well as
  in the dev host.
- `moui dev --hot` is accepted on native Linux and macOS hosts only; Web/wasm
  target or package combinations are rejected at parse time and in the runner.
- The fast rebuild plan replays the generated plugin C compile step after
  `moonc link-core`; omitting it left the previous `plugin.o` in the archive and
  silently reloaded stale app code. This filter is shared, so it also fixes the
  same-shape fast path on macOS.
- macOS keeps the 32-swap re-exec budget. The Linux runner sets
  `MOUI_HOT_RELOAD_LIMIT=0` because Linux `dlclose` actually unmaps the image
  (measured `images=1` after every swap); there is no per-swap image retention
  to bound.

## Options Considered

- **`MOON_CC` wrapper that adds `-fPIC`.** It changes the allocator to
  `MOONBIT_ALLOCATOR_SYSTEM`, drops `libmoonbitrun.o`, and needs a matching
  `ar` shim in the same directory. Rejected in favour of rewriting only the
  runtime members of a copied archive.
- **`-Wl,-z,notext` or linking the archive directly.** Rejected; the runtime
  objects still carry non-PIC relocations against libc data.
- **Polling only on input/frame callbacks.** Rejected; an idle window would
  never pick up a new generation.
- **A second Linux-only plugin protocol.** Rejected; reusing the existing
  `moui_devhost` host/bridge/protocol keeps one ABI and one failure model.
- **A background thread that calls into the MoonBit runtime.** Rejected;
  MoonBit closures are not a supported cross-thread surface.

## Rationale

The host/plugin split already isolates everything that must survive an edit:
the window, renderer, input path and platform services. Linux only needs a
different plugin link recipe and a timer pump; everything above the C bridge
stays identical, so failure retention, state/transient handoff, generation
paths and DevTools wiring are reused unchanged.

## Consequences

- Edits keep the window and PID on Linux. On the matching host, warm reloads
  over 20 probes measured p50 8.43 s (range 8.22–8.63 s), dominated by compiling
  the ~9.4 MB generated `plugin.c` in debug mode (~6.9 s of `cc`). The fast plan
  still avoids moon workspace planning; a full `moon build` is slower.
- A forced compile error kept the previous generation interactive (counter
  stayed clickable; generation marker unchanged). Fixing the error swapped in
  generation 3 with the same host PID.
- 20 reloads retained PID and window; RSS moved 27.6 → 32.8 MB (~0.26 MB per
  swap from allocator/state churn), and every swap logged `images=1`, so there
  is no mapped-image leak.
- Core, renderer, backend and ABI edits still require a restart.
  IME/semantics/platform-view state remains Phase 2, as on macOS.
- Windows and Web are unchanged.

## Agent Notes

- `dlopen` keys images by path: always publish a new `gen-<n>/plugin.so`.
- The plugin must be loaded with `RTLD_NOW | RTLD_LOCAL`; the ABI entry points
  are resolved before `dev_create` is called.
- `moui_devhost/host/moui_devhost_bridge.c` needs `_GNU_SOURCE` before system
  headers for `dl_iterate_phdr` under plain `cc`.
- Do not remove the generated-C compile step from the fast plan; the archive
  otherwise reuses a stale object.
- The Linux timer pump is required for any `TimerSource` subscription, not just
  hot reload; keep `MOUI_LINUX_GLIB_*` overrides in mind on hosts without
  `pkg-config` GLib.

## References

- `docs/decisions/0072-native-dev-hot-reload.md`
- `docs/plans/done/INDEX.md` (`native-dev-hot-reload`,
  `native-dev-hot-reload-linux`)
- `docs/development.md` (dev section)
- `docs/platform-notes-linux.md`
- `memories/repo/native-dev-hot-reload-linux.md`
