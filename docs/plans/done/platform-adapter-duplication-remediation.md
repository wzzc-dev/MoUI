# Plan: eliminate cross-platform behavioral duplication

- **Status**: done; superseded by `backend-render-package-convergence.md`; manual
  `wzzc-dev/window` release validation remains independent
- **Goal**: make shared behavior single-owner code. Platform packages may retain
  nominal type adapters, native payload decoding, and ABI-specific FFI symbols,
  but not duplicated lifecycle state machines, request routing, services, or
  redraw coordination.
- **Decisions**: ADR 0018 (neutral backend contracts), ADR 0020/0025
  (`backend/common` boundary), and the 2026-08-05 decision to remove similarity
  budgets and allowlists instead of accounting for known duplication.

## Workstreams

1. Delete the platform file-similarity gate, duplication baseline, and old
   validator. Replace them with a budget-free backend common boundary check.
2. Add `moui/backend/common/desktop` as the single owner of desktop
   service routing and filesystem-backed text/binary/directory operations.
3. Make `WindowCoordinator` the single owner of desktop request dispatch,
   resize application, host-event state updates, and redraw state transitions.
4. Keep `wzzc-dev/window/internal/embedded_dispatch` as a stateless physical
   callback dispatcher. `moui/backend/common` owns Android/iOS/HarmonyOS
   lifecycle, surface generation, primary-window routing, and exit state;
   platform packages retain public `HostCmd` payloads and nominal
   event-loop/window adapters.
5. Keep post-window session, renderer-surface, redraw, and IME behavior in
   `moui/backend/common/embedded/HostedWindowBackend`.
6. Flatten host-service ownership into symmetric internal packages:
   `moui/backend/common/desktop` for direct desktop handlers,
   `moui/backend/common/native` for shared native filesystem
   and raw image-byte I/O, and `moui/backend/common/embedded/services` for the asynchronous
   embedded callback queue. Keep neutral `HostService*` contracts in
   `moui/backend`, and split the embedded runtime host bridge by IME,
   semantics, platform-view, service, transport, and lifecycle responsibility.

## Ownership and interfaces

- `moui/backend` remains contracts-only; concrete filesystem behavior is
  not added there.
- `window/core` remains neutral public value types. The embedded host kernel is
  an internal sibling package importing only `window/core` and `window/dpi`.
- Desktop platforms implement `WindowSurfaceActions`; native resize and present
  differences are closures invoked by shared runtime coordination.
- Embedded platforms decode native payloads to shared `WindowEvent` values,
  apply kernel effects to their local app state, then enter MoUI through
  `HostedWindowBackend`.
- Desktop and embedded service implementations both produce the neutral
  `HostServiceBridge`; desktop requests complete directly, while embedded
  requests return `Pending(id)` and complete through native callbacks.

## Validation

- Focused package tests for every changed package and table-driven kernel tests.
- `moon info` plus generated interface review for intended API changes.
- PR/platform profiles, platform services checks, desktop window smoke, and
  embedded host-sim coverage.
- Local window work uses `scripts/window-dev-mode.sh on`; the committed
  workspace returns to `off`. Publishing `wzzc-dev/window` remains a manual
  release step before consumer pins are updated.

## Completion criteria

- The similarity source, budget JSON, old validator, old adapter-budget policy, and all
  active references to them are removed.
- Desktop service routing/filesystem behavior, window request dispatch, redraw
  state, and embedded host lifecycle each have one implementation.
- Neutral `HostService*` contracts have one owner; desktop and embedded service
  packages expose only their required direct/callback execution models, and
  mobile platform packages cannot import the embedded queue directly.
- The old `host_services` and `embedded_runtime_backend` package paths,
  `Embedding*` symbols, and desktop compatibility APIs are absent.
- Remaining cross-platform lookalikes contain only nominal type adaptation,
  native decoding, platform composition, or ABI-specific FFI declarations.

## Progress

| Date | Note |
|---|---|
| 2026-08-01 | Earlier convergence established `WindowCoordinator`, `HostedWindowBackend`, a shared event-conversion layer, and shared renderer-provider helpers. |
| 2026-08-05 | Replaced the budget/allowlist remediation strategy with full behavioral convergence and an internal window embedded-host kernel. Implementation started. |
| 2026-08-05 | Completed all five code workstreams: removed similarity accounting, centralized desktop services, request/resize/redraw state, embedded-host lifecycle, and post-callback mobile runtime assembly. Added direct coordinator completion tests and removed the macOS test that copied the redraw algorithm. |
| 2026-08-05 | `moon info`, focused desktop/mobile/window tests, host-sim, static validators, PR profile, and platform profile pass in default mooncakes mode. The published `wzzc-dev/window@0.5.4-0.1.6` archive lacks the documented macOS smoke helper, so published-package desktop smoke remains a manual post-release check; local macOS window tests pass 110/110. |
| 2026-08-05 | Started the follow-up package flattening: symmetric `host_services_desktop` / `host_services_embedded`, `embedded_runtime` path cleanup, and responsibility-based embedded bridge file split without changing public HostService contracts or native wire payloads. |
| 2026-08-05 | Completed the follow-up flattening. Added desktop filesystem and embedded FIFO/completion/dispose tests, enforced 3/3 desktop, 3/3 mobile, and 1/1 embedded-service import ownership, regenerated interfaces, restored mooncakes mode, and passed focused host/mobile tests, host-sim, PR profile, and platform profile. |
| 2026-08-05 | ADR 0025 and the backend/render convergence plan supersede the package-shape portions of this plan; shared state now lives under `backend/common`, while the window dispatcher remains physical-only. |
