# Plan: shell embedding transport consolidation

- **Status**: active
- **Goal**: make `moui_shell` the single owner of neutral embedding transport
  state while keeping all MoUI runtime, host-contract, and renderer semantics
  in `moui`.
- **Non-goals**: change the fixed C Embedding API v1, add a desktop shell
  profile, promote platform-readiness claims, or make `moui_shell` depend on
  `wzzc-dev/moui`.

## Constraints

- `moui_shell/embedding` owns exactly one session generation, surface epoch,
  frame coalescer, request correlation, and neutral JSON envelope lifecycle.
- `moui_shell/embedding` also owns every fixed Embedding API MoonBit
  implementation and the canonical `link.native.exports` list. The final
  executable may mirror that list and contain same-name mechanical forwarders
  only because current MoonBit native dependency exports are not promoted to
  final executable C symbols; those root shims never own callback state or ABI
  behavior.
- MoUI owns the conversion between neutral wire payloads and `HostEvent`,
  `HostServiceRequest`/`Response`, `AppRuntime`, and renderer types.
- The three platform shell packages expose and are used through their typed
  native surface/view handles; platform-specific coordinate and input mapping
  remain in MoUI platform backends.
- `backend/host` remains reusable by desktop, Web, and embedded backends. Its
  embedded-only bridge and image coordination logic move into the private
  `backend/internal/embedded_runtime_session` package.

## Work

- [ ] Replace the unused shell channel path and separate embedded host channel
  generations with one shell-owned transport state.
- [x] Move and rename the embedded-only host bridge, wire decoding, and image
  coordinator into `backend/internal/embedded_runtime_session`.
- [x] Replace duplicated Android/iOS/HarmonyOS raw-handle wrappers with the
  corresponding `moui_shell/<platform>` typed handles.
- [ ] Extract the common callback adapter behaviour so each platform backend
  owns only raw platform conversion and session/provider construction.
- [x] Move renderer preference ownership out of shared `backend/host`, thin
  mobile entrypoint configuration, and remove stale legacy-fixture guidance.
- [x] Reconcile final-executable native symbol reachability with the thin
  entrypoint invariant: retain framework ABI ownership, allow only canonical
  root-package export mirrors/forwarders, and enforce both sides in the harness
  validator.
- [x] Add focused transport, session, platform-handle, and adapter tests;
  regenerate MoonBit interfaces and run ABI/static validation.

## Decision log

| Date | Decision |
| --- | --- |
| 2026-07-19 | A minimal native-link experiment showed that an exported function in a dependency package is not promoted to the final app's C symbols. Keep implementation, callback state, and canonical export configuration in `moui_shell/embedding`; require final mobile executable roots to mirror the list and forward each symbol mechanically. This is a linker constraint, not app ownership of the ABI. |
| 2026-07-19 | Final merge audit kept this plan active: `EmbeddingHostBridge` still retains a second generation/envelope path, and the three platform callback adapters still duplicate common callback wiring. Transport ownership and common-adapter extraction remain follow-up work. |

## Validation

- `moon test moui_shell/embedding --target native`
- `moon test moui/backend/internal/embedded_runtime_session --target native`
- `moon test moui/backend/{host,android,ios,harmonyos} --target native`
- `moon test tools/moui/validate_harness_invariants --target native`
- `node scripts/validate-harness-invariants.mjs`
- `moon info`
- `node scripts/validate-maintenance-baseline.mjs`
- `node scripts/validate-api-surface.mjs`
- `node scripts/validate-guidance-consistency.mjs`
