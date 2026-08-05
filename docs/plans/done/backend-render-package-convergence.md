# Plan: Backend / render package convergence

- **Status**: done
- **Goal**: Replace `backend/host` and `platform_bridge` with symmetric root
  protocol and common implementation packages, then close lifecycle, frame,
  mapping, DPI, and teardown ownership gaps.
- **Non-goals**: Change renderer/platform readiness, replace runtime renderer
  factories with Rust-style generic compositors, or change the external
  `wzzc-dev/window` `HostCmd` ABI.

## Acceptance

- [x] `moui/backend` and `moui/render` contain only neutral protocol/value APIs.
- [x] Shared implementations live in `backend/common*` and `render/common`.
- [x] `backend/host` and `platform_bridge` no longer exist or appear in imports.
- [x] Platform backends do not import concrete renderer packages.
- [x] Lifecycle effects cannot be ignored; teardown and mappings have one owner.
- [x] Resize/scale payloads and Windows DPI are authoritative and tested.
- [x] Focused tests, host-sim, static gates, PR, and platform profiles pass.

## Workstreams

- [x] WS1: Add target dependency validators and protocol API names.
- [x] WS2: Split `render` protocol/common and migrate renderer consumers.
- [x] WS3: Split `backend` protocol/common and migrate all platform consumers.
- [x] WS4: Delete Platform Bridge and relocate or remove each responsibility.
- [x] WS5: Make lifecycle/frame/mapping/teardown ownership executable and private.
- [x] WS6: Update generated APIs, docs, guidance, checks, and validation evidence.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-05 | ADR 0025 chooses root protocol + common implementation packages, an atomic breaking migration, and complete Platform Bridge removal. |

## Progress

| Date | Note |
|------|------|
| 2026-08-05 | Plan opened on top of the staged ADR 0024 lifecycle convergence work. |
| 2026-08-05 | Root protocol and common implementation packages landed; old host, bridge, and internal package paths were removed atomically. |
| 2026-08-05 | Lifecycle/frame/mapping/DPI tests, dependency/API validators, generated interfaces, ADR/guidance, and source-file ratchets were updated. |
| 2026-08-05 | Native/all-target checks, focused backend/renderer tests, host-sim, static gates, PR profile, and platform profile passed. No readiness classification changed. |
