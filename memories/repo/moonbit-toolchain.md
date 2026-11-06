# MoonBit Toolchain Baseline

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
