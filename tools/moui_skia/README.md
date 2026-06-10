# moui_skia Tools

This directory contains MoonBit tools that belong to the `moui_skia` binding
surface. They may depend on shared helpers from the root `tools` package, but
should not depend on MoUI framework packages.

When `moui_skia` is split into its own repository, this directory should move
with it together with any shared helper subset it still needs.

Current tool groups:

- `native_smoke_log_contract/` contains the shared parser/verifier for
  `skia-platform-status.json` native smoke marker contracts.
- `skia_acceptance/` contains shared acceptance-log and revision-pin text
  helpers for `moui_skia` maintenance commands.
- `verify_native_ownership/` validates `native/ownership.json` against the
  MoonBit handle/type declarations and C++ wrapper/finalizer implementation.
- `verify_native_smoke_log/` validates saved native smoke executable logs
  against the canonical marker contract in `skia-platform-status.json`.
- `verify_real_skia_artifact/` validates real Skia artifact log bundles by
  combining wrapper, native smoke, acceptance, provider-lock, and optional
  source-build checks.
- `verify_acceptance_state_patch/` validates the pure Linux acceptance-state
  patch contract and patched Linux acceptance fields while the PowerShell entry
  point keeps the temporary `git apply` replay.
- `verify_platform_status/` validates the Skia platform acceptance matrix,
  pinned revision/provider-lock alignment, CI gate evidence wiring, native smoke
  capability coverage, expected marker values, and Markdown status table
  contract.
- `verify_*` packages are read-only validators used by existing script and CI
  entrypoints.
- `pin_skia_revision/` is a guarded writer for `skia-revision.txt`.
