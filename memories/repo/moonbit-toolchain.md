# MoonBit Toolchain Baseline

2026-11-26 / MoonBit 1.0.0-rc1:

- Pin is `moonc 1.0.0-rc1+3c0520448`, `moon 0.1.20261126`,
  `moonrun 0.1.20261126`, `moonc-worker 0.1.202611201`
  (`sha512-JF7NhLAJfG0m30fL2bMv6R9nHtB4Wg3TtxeLmvx0RAsSC4fn6bVGosd6U+hsP3Cxw+8WJfM6UU0zO3UAgmAvAQ==`);
  the npm `@moonbit/moonc-worker` latest was unchanged at `0.1.202611201`
  when the compiler pin moved.
- 1.0.0-rc1 migration is warning-only so far: `Map`/`Set` `add` is deprecated
  for `insert`; `Buffer::write_bytes` is deprecated for `write_bytesview`;
  `#cfg(target="llvm")` is deprecated for `target="native"`; legacy stdin JSON
  for `build.mbtx` prebuild scripts is deprecated for `MOON_*` environment
  variables; `link.wasm(-gc).exports` is deprecated for `#export_name`.
- Playground assets generated with `moonc 1.0.0-rc1+3c0520448` and
  `moonc-worker 0.1.202611201` validate (`scripts/test-playground-assets.mjs`),
  so the pinned worker still consumes the new compiler's artifacts.

2026-11-19 / post-0.6.2 dev:

- Pin is `moonc 0.10.21+06da1ed44`, `moon 0.1.20261117`,
  `moonrun 0.1.20261117`, `moonc-worker 0.1.202611179`
  (`sha512-/M+/I7ktMdOXdh9ftZQNrNEsnUkrOxNwTRui1C3hBX6ZloPWJBA78d9kHYRrx59cO/vLKpa6kX1wulFUIi6UvA==`).
- 0.10.21 migration: `Show` no longer exposes `to_string` as a method (bumped
  `mizchi/image` to 0.5.0 for its renderer decode path);
  `StringBuilder`/`Buffer` take `capacity=` instead of `size_hint=`;
  `Int64::from_int`/`Double::from_int` are deprecated for
  `.to_int64()`/`.to_double()`; `moon fmt` adds trailing commas in multi-line
  patterns and constructor payloads; core json renamed `JsonPath` to
  `DecodeContext` in generated interfaces.
- Every module `--moonbit-unstable-prebuild` hook is a `build.mbtx` script now
  (`moui`, `moui_webview`, `moui_text_providers`, `moui_metal_renderer`,
  `moui_tests`, `moui_skia`, `moui_skia_renderer`, `examples/pdf_workbench`).
  Imports go in a `---` frontmatter block; imports after the first declaration
  warn as `unfenced_import`.
- A hook that shells out must tolerate a missing helper: `pkg-config` is absent
  on Windows runners, so probe it only on `linux`, and `uname` needs a
  `PROCESSOR_ARCHITECTURE` fallback on Windows. `@process.run` with a missing
  program surfaces as `@process.run(): The system cannot find the file
  specified.` and fails the whole module build, so wrap it in `try`.
- Re-verified with `.github/workflows/ci.yml` run 44503349882 (Windows MSVC
  native smoke, Linux platform contracts, macOS packaging smoke all green).

2026-11-06 / MoUI 0.3.2:

- Pin lives in `.moonbit-toolchain` and Studio has its own copy:
  `moonc 0.10.20+65efd5b93`, `moonc-worker 0.1.202611052`,
  `moon 0.1.20261104`, `moonrun 0.1.20261104`.
- `#derive(...)` is an attribute above the type. `} derive(...)` is deprecated;
  `moon fmt` migrates it. The derive generator accepts the new form and rejects
  the suffix form. Embedded source templates (for example Studio's export
  kernel strings) are not touched by `moon fmt`; migrate and test those
  separately.
- `Json`/`ToJson` live in `moonbitlang/core/json`; generated `.mbti` spells the
  type as `@json.Json`. Use `Json(value)` for `ToJson` conversion.
- `Int`/`UInt` remain aliases for `Int32`/`UInt32`; prefer explicit widths in
  new FFI/wire code.
- `moon check` rewrites `pkg.generated.mbti` by default; use `--no-mbti` for a
  type-only loop. A clean `moon check --output-json` can emit an empty file
  while exiting 0, so do not parse it as report evidence.
- Release line `0.3.2` keeps all 25 public modules synchronized. Check
  `checks/release-modules.json` for stage order and use clean committed trees
  for publishing.
