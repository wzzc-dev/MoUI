# Plan: Complete window iOS/HarmonyOS templates

- **Status**: completed
- **Goal**: make `window/ios/template` and `window/harmonyos/template` real thin host templates, matching Android package co-location without reintroducing `moui_shell` or Embedding API v1.
- **Related**: ADR 0015, `docs/window-hosted-moui.md`, `window/docs/mobile-hosted-backend.md`, `docs/plans/active/window-only-mobile-no-shell-embedding.md`

## Scope

| Platform | Deliverable |
|---|---|
| iOS | Template-owned UIKit host sources and metadata; package build script compiles template sources into simulator `.app`. |
| HarmonyOS | Template-owned Stage Ability / XComponent project skeleton plus NAPI bridge files that forward lifecycle/surface/input to `window/harmonyos/native_*` HostCmd symbols. |

## Non-goals

- Do not restore `moui_shell`.
- Do not restore Embedding API v1 or inject/bind surface APIs.
- Do not claim HarmonyOS HVD/device pass without `hdc` install+launch evidence.

## Validation

- `bash scripts/window-hosted-hostsim-smoke.sh` - passed; iOS/HarmonyOS
  package/template checks are included.
- `bash scripts/build-window-hosted-ios-sim-app.sh` - passed; the resulting
  app installed and launched on the iPhone 17 Simulator, then the simulator was
  shut down.
- `bash scripts/build-window-hosted-harmonyos-hap.sh` - passed with local
  DevEco SDK; produced an unsigned HAP with the HostCmd NAPI bridge. `hdc` had
  no target, so no HVD/device runtime claim is made.
