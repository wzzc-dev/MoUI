# Thin native-shell entrypoints

## Goal

Make the Android, iOS, and HarmonyOS Counter/Showcase executable entrypoints
contain only application-program and renderer configuration.  Move the fixed
Embedding API v1 exports and installed-session dispatch into their owning
platform backends, without changing the native ABI, shell API version, or
platform-readiness claims.

## Constraints

- Preserve the Embedding API v1 function names and semantics consumed by the
  package-published native embedders.
- `moui_shell` remains independent of `wzzc-dev/moui`; the ABI provider stays
  in MoUI's embedded-session implementation.
- Each platform keeps typed handles and lifecycle ownership in its own backend.
- Do not change `runtime_partial` status or infer real-device evidence from
  package, C/C++, or fallback-packaging checks.

## Work

- [x] Inventory the current ABI exports, adapter call sites, and MoonBit native
  export mechanism with `moon ide` before changing symbols.
- [x] Add one install/configuration boundary per Android, iOS, and HarmonyOS
  backend.  It owns the installed adapter singleton and the fixed Embedding API
  v1 forwarding exports.
- [x] Move native export declarations from the six example packages to the
  respective backend package metadata, then reduce every entrypoint to
  program/runtime factory and renderer configuration installation.
- [x] Add focused backend tests for installation/replacement and uninstalled
  ABI-safe behavior; retain existing adapter lifecycle tests.
- [x] Tighten the static thin-entrypoint validator to reject fixed ABI exports
  and adapter plumbing in app entrypoints.
- [x] Run focused MoonBit checks/tests, all six thin entrypoint checks, ABI
  header/ASan validation, the fallback shell matrix, static validators, and
  `moon info`; record any non-refactor profile blockers separately.

## Decision log

| Date | Decision |
| --- | --- |
| 2026-07-19 | Keep the C Embedding API v1 surface stable. The application configures an installed platform backend; native consumers continue to invoke the same exported symbols. |
| 2026-07-19 | Use separate Android, iOS, and HarmonyOS install types rather than a lowest-common-denominator platform API. |
| 2026-07-19 | The three `managed`/`plugin`/`ejected` fallback preparation matrices passed. A direct Android fallback APK attempt still stops before APK output at the pre-existing literal `${build.MOUI_SKIA_STUB_CC_FLAGS}` native build flag; it is outside this entrypoint/ABI relocation. |

## Validation

- Passed: backend tests for Android/iOS/HarmonyOS; all six fallback-Skia
  entrypoint checks; `moui_cli` and harness-validator tests; ABI header,
  ownership, symbol, and ASan audit; three platform shell matrices in
  `--prepare-only` mode; shell-config, entrypoint, maintenance, API-surface,
  guidance, website-doc, and diff checks.
- `moon info` verified the intended public backend surface: one typed
  `install_embedding` entrypoint plus the unchanged fixed Embedding API v1
  functions; adapters are package-private.
