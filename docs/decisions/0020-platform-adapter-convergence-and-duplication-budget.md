# 0020: Platform Bridge convergence and duplication budget

- **Date**: 2026-07-28, amended 2026-07-29
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
