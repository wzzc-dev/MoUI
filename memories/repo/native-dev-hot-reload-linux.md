# Linux native dev hot reload: host + PIC plugin

2026-11-24, plan `docs/plans/active/native-dev-hot-reload-linux.md`, ADR 0073.

## Shape

The macOS host/plugin design (ADR 0072, `native-dev-hot-reload.md`) is reused
on Linux. `scripts/moui-dev-hot-generate.mjs --platform linux` emits a host
that uses `@linux_backend.entry()`, `@linux_backend.linux_timer_source()` and
`@render_skia.from_env(platform=Linux)`. The plugin is a `foreign_library`;
each generation is published as `moui_devhost/dev_hot/out/gen-<n>/plugin.so`
and the `current` marker is renamed atomically. ABI v1, state/transient
transports and failure retention are unchanged.

## Linux link recipe

MoonBit native has no shared-library pkgtype and its runtime C objects are not
PIC. Build `plugin.a` normally, then:

1. Copy `plugin.a` to `dev_hot/pic/plugin.pic.a`.
2. Recompile every `$MOON_HOME/lib/runtime/*.c` compile line from
   `moon build ... -v --dry-run` with `-fPIC` and an output under
   `dev_hot/pic/`, then `ar r` those objects into the copied archive.
3. Generated plugin `moon.pkg` sets `link.native.cc-flags: "-fPIC"` for the
   app-side object.
4. Link:
   `cc -shared -Wl,-Bsymbolic -Wl,--whole-archive plugin.pic.a
   -Wl,--no-whole-archive "$MOON_HOME/lib/libbacktrace.a" -lm -o plugin.so`.

Do not use a `MOON_CC` wrapper: it switches to `MOONBIT_ALLOCATOR_SYSTEM`,
drops `libmoonbitrun.o`, and needs an `ar` shim. `-Wl,-z,notext` does not fix
the non-PIC relocations.

## Gotchas

- The Linux window loop polls X11/Wayland and never iterates GLib. The backend
  now pumps `g_main_context_default()` from `about_to_wait` and sets
  `WaitUntil` from the next GLib timeout; without that, every
  `@services.TimerSource` subscription (including the 250 ms hot marker poll)
  silently never ticks.
- The fast rebuild plan must replay the generated
  `__moonbit_link_core__/plugin.o` compile after `moonc link-core`. The older
  filter skipped it, so the archive kept the previous `plugin.o` and the UI
  showed stale app code even though a new generation was published.
- Warm reload is gcc-bound: p50 8.43 s (n=20, 8.22–8.63 s) for the counter,
  because the 9.4 MB generated `plugin.c` takes ~6.9 s at `-g -O0`. The fast
  plan still avoids moon workspace planning.
- Linux `dlclose` unmaps the plugin image (`images=1` after every swap), so the
  runner sets `MOUI_HOT_RELOAD_LIMIT=0`; macOS keeps 32. RSS still creeps
  ~0.26 MB/swap from allocator/state churn (27.6 → 32.8 MB over 20 swaps).
- `dlopen` keys images by path: never rewrite a published plugin path.
- The bridge C needs `_GNU_SOURCE` before headers for `dl_iterate_phdr`.
- `moui dev --hot` rejects Web/wasm combinations in both `moui_cli/dev.mbt` and
  `scripts/moui-dev.mjs`; help text lives in both places.
