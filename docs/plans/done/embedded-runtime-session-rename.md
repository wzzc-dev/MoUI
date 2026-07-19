# Plan: embedded runtime session rename

- **Status**: complete
- **Goal**: Rename MoUI's private embedded-host runtime assembly from
  `backend/internal/embedded_session` to
  `backend/internal/embedded_runtime_session`.
- **Non-goals**: Change the Embedding API v1 ABI, move MoUI runtime assembly
  into `moui_shell`, alter public backend APIs, or change platform readiness.

## Acceptance

- [x] The internal MoonBit package and native ABI-provider source use the new
  path and import name.
- [x] Android, iOS, and HarmonyOS remain the only importers.
- [x] Generated/ejected shell source lists and platform CMake files use the
  new provider source path.
- [x] Architecture/invariant documentation uses the precise runtime-session
  term.
- [x] Focused package, ABI, import-guard, formatting, and API-surface checks
  pass.

## Decision log

| Date | Decision |
| --- | --- |
| 2026-07-19 | Retain `EmbeddedSessionCore` as an implementation type; rename only the package boundary to clarify that it assembles MoUI runtime behavior for an embedded host, not the independent `moui_shell` SDK. |

## Validation

- Passed: native tests for `embedded_runtime_session` and all three platform
  backends; API-surface validator tests; CLI tests; embedding ABI header,
  ownership, ASan, and symbol audits; Android/iOS/HarmonyOS managed/plugin/
  ejected fallback preparation matrices; maintenance, API-surface, guidance,
  and website-documentation guards.
- `moon info` confirms the native-only package interface at its new path. The
  existing non-fatal MoonBit `runtime.o` input-verification warnings and
  package-native-versus-canonical-WasmGC interface notice remain unchanged.
