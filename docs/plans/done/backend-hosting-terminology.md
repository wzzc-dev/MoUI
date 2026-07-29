# Plan: backend hosting terminology

- **Status**: done
- **Goal**: make host-ownership terminology consistent across code and guidance:
  `native host backend` for the macOS/Windows/Linux route and `embedded runtime
  backend` for the Android/iOS/HarmonyOS route.
- **Non-goals**: rename `wzzc-dev/window` APIs, alter platform readiness, or
  change renderer/provider behavior.

## Acceptance

- [x] Architecture and platform guidance define the two backend models by host
  ownership rather than form factor.
- [x] Android, iOS, and HarmonyOS source-facing names and comments use
  `embedded runtime backend`; macOS, Windows, and Linux identify as native host
  backends where their shared category is described.
- [x] Generated MoonBit interfaces and every in-repository call site agree with
  the renamed public symbols.
- [x] Focused backend tests and documentation/API validation pass.

## Decision log

| Date | Decision |
|---|---|
| 2026-07-29 | Classify by host ownership, not mobile/desktop device class. Keep `window-hosted` only for the concrete upstream entrypoint/template route. |

## Progress

| Date | Note |
|---|---|
| 2026-07-29 | Inventory complete; implementation in progress. |
| 2026-07-29 | Renamed the shared internal backend package/core, embedded-runtime backend application handlers, native-host backend handlers, validators, entrypoints, and architecture guidance. |
| 2026-07-29 | Passed `moon info`; Android/iOS/HarmonyOS/macOS/Windows/Linux backend tests; harness/API validator tests; API-surface and guidance-consistency guards. |
| 2026-07-29 | Known unrelated failures: the maintenance baseline reports seven existing line-budget files; `moon test moui_cli --target native` has six current-toolchain expectation-formatting failures (`Some(value)` versus `Some("value")`). |
