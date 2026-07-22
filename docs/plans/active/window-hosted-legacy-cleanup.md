# Plan: window-hosted legacy cleanup

- **Status**: completed
- **Goal**: remove retired mobile packaging and embedding entrypoints, leaving
  `wzzc-dev/window` templates as the only mobile host path.

## Scope

- Delete obsolete CLI eject, CI, runtime-evidence, and validator routes.
- Retarget active checks and guidance to window-hosted templates and host-sim
  validation.
- Remove stale generated API references and archived plans that describe the
  retired product path as current.

## Validation

- `moon test moui_cli --target native`
- `moon test moui/backend/android --target native`
- `moon test moui/backend/ios --target native`
- `moon test moui/backend/harmonyos --target native`
- `node scripts/validate-guidance-consistency.mjs`
- Repository-wide retired-package scan

## Outcome

- Removed the retired mobile-shell CLI, CI, packaging, evidence, and guidance
  routes.
- Kept Android, iOS, and HarmonyOS on the single window-hosted route:
  `HostCmd` → `EventLoop` → `ApplicationHandler` → `*WindowHostedApp`.
- Retargeted the host-sim wrapper to the upstream nested window packages
  (`window/modules/window/<platform>`), replacing removed `window/scripts`
  wrappers.

## Follow-up

`wzzc-dev/window@0.5.4-0.1.0` is not yet published in the MoonBit registry.
The latest published `0.5.1-0.1.7-3` package lacks the mobile hosted modules,
so the checked-in nested window workspace remains necessary until the new
version is published. After publication, switch the workspace back to the
default mooncakes dependency mode and rerun the dependency validator.
