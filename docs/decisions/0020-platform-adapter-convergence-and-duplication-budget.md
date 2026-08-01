# 0020: Platform Bridge convergence and duplication budget

- **Date**: 2026-07-28, amended 2026-07-29, amended 2026-08-01
- **Status**: Accepted
- **Related**: ADR 0011 (platform product class), ADR 0018 (host contract
  split), ADR 0019 (renderer providers), invariants P5/M6

## Context

Native hosts and embedded hosts all translate a small set of platform-neutral
window lifecycle facts. Historically, copy-pasted resize, scale, focus, close,
redraw, surface-lifecycle, and coordinate-normalization helpers made that seam
drift while disguising it as native-platform code. The shared owner must not
decode native input or gain a reverse dependency on a platform package.

## Decision

`moui/backend/platform_bridge` is the single owner of the platform-to-neutral
host bridge. It imports only `moui/core`, `moui/backend/host`, and `window`
value types. There is no compatibility package at the previous path.

The bridge owns only these cross-platform operations:

- Close, focus, resize, scale, and redraw conversion to `HostEvent`.
- Surface attach/detach, metrics, and lifecycle state.
- Logical-coordinate normalization.

Platform packages retain native pointer, keyboard, IME, drag-and-drop, and
modifier decoding, platform capability declarations, pacing, and host wiring.
This preserves the native payload boundary while requiring every applicable
desktop, Web, Android, iOS, and HarmonyOS backend to invoke the bridge after
it has decoded a neutral lifecycle event.

WeChat is included in the capability inventory and duplication scan as the
`direct-canvas-callback` exception. It must not fabricate a `WindowEvent`
dependency; the validator instead confirms that its Canvas lifecycle does not
redefine bridge responsibilities.

The enforced PR gate is a MoonBit tool at
`tools/moui/validate_platform_adapter_duplication`, kept reachable through the
thin Node wrapper `scripts/validate-platform-adapter-duplication.mjs`. Its
schema-v2 baseline declares the bridge modules, normalization token budgets,
and only justified native exceptions. The wrapper passes the current UTC date;
expired `allowUntil` entries fail, as do missing bridge imports/uses, bridge
helper redefinitions, duplicated normalization over budget, and invalid WeChat
usage.

## Consequences

- `platform_bridge` has a small, testable neutral contract and no renderer or
  runtime ownership.
- New applicable platform hosts must import and use the bridge rather than
  recreate lifecycle conversion helpers.
- A genuine platform-specific duplication exception needs a baseline allowlist
  reason and an expiry date; the budget may otherwise only shrink or remain
  stable.
- Bridge behavior is covered by `moon test moui/backend/platform_bridge
  --target native`; the validator has its own MoonBit fixture tests and is part
  of the PR profile.

## Amendment (2026-08-01): window-host coordination and file-level similarity gate

The window-lifecycle state that was previously re-implemented per backend now
lives in `WindowHostCoordinator` (moui/runtime, with `WindowSurfaceActions`
per-window projections). macOS/Windows/Linux and the Web backend all delegate
window records, runtime slots, platform-window maps, surface attachment,
redraw/IME/close coordination, and host-event dispatch to it; embedded-runtime
backends share `moui/backend/internal/embedded_runtime_backend`
(`HostedWindowBackend`/`HostedRuntimeSession`), leaving each platform's
`window_hosted.mbt` as a thin shell.

The api-surface validator gains a file-level mirror similarity gate
(`validate_platform_file_similarity` in
`tools/moui/validate_api_surface/platform_file_similarity.mbt`): platform
identifiers are normalized to a placeholder token, mirror file pairs scoring
above 80% similarity are rejected unless registered in
`platform_file_similarity_budgets` with a reason and a per-pair budget row.
Registered pairs include the Wave 2 shared embedded-runtime shells, renderer
provider adapter shells, and pre-existing duplicate helper files
(`menu_helpers`, `file_dialog_helpers`); new platform files must fold shared
logic into the coordinator/shared packages instead of copying it.

## Rejected alternatives

- Putting platform logic in `backend/host` would create host knowledge of
  concrete platforms and violates the host-contract boundary.
- Translating raw pointer/keyboard/IME/drag payloads in the bridge would erase
  necessary platform semantics.
- Leaving each backend to maintain equivalent lifecycle helpers would make the
  duplication budget unenforceable.

## References

- `docs/invariants.md`
- `docs/architecture-map.md`
- `checks/platform-adapter-duplication-baseline.json`
