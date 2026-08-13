# 0029: Native accessibility adapters and evidence

- **Date**: 2026-08-12
- **Status**: Accepted
- **Deciders**: Agent-assisted
- **Related**: [native accessibility plan](../plans/active/native-accessibility.md), [ADR 0028](0028-runtime-state-render-ownership-convergence.md)

## Context

MoUI already commits an atomic neutral semantics snapshot, retains deltas, and
dispatches generation-checked typed actions. Web has a DOM adapter and
`moui/backend/accesskit` translates the same snapshot to an AccessKit-shaped
data model. The latter is not a native AppKit, UI Automation, or AT-SPI object
adapter. Treating that representation or an in-memory binding as native proof
would overstate platform accessibility.

## Decision

Keep `moui/core` as the owner of complete cross-runtime semantics DTOs,
`moui/runtime` as the sole committed snapshot/delta/action authority, and
`moui/backend/accesskit` as a reusable neutral mapping. Concrete backends own
narrow native adapters:

- macOS attaches NSAccessibility elements to the window content view;
- Windows handles `WM_GETOBJECT` and exposes UI Automation providers;
- Linux registers and exports AT-SPI D-Bus objects;
- Web maintains a legal semantic DOM/ARIA tree.

Physical window handles, event-loop hooks, and destruction callbacks remain in
`wzzc-dev/window`; it exposes only the narrow hooks required by the backend.
Native actions always become exact-generation `PerformSemanticsActionRequest`
values and never coordinate input.

`native_accessibility_available` means that a real system object bridge passed
a matching native-client L2 probe. Screen-reader L3 evidence is recorded
separately. A data-model conversion or package test cannot flip the flag.

The Agent interface remains the existing `read_semantics` and
`perform_action` MCP pair. Agent work orchestration uses a checked-in work graph
and evidence manifest, not a second UI automation protocol.

## Options Considered

### Bind only to the current MoonBit AccessKit package

- Pros: one data model and less apparent platform code.
- Cons: the installed package exposes tree data and actions, not verified
  AppKit/UIA/AT-SPI native adapters.

### Implement every mapping independently

- Pros: direct control of every native API.
- Cons: duplicates neutral role/state/action conversion and increases drift.

### Neutral mapping plus narrow native adapters

- Pros: preserves one semantics authority and shared mapping while making
  native ownership and proof explicit.
- Cons: requires small platform-specific host hooks and matching-host tests.

## Rationale

The hybrid design matches the existing package boundaries, avoids speculative
dependency capability, and makes readiness mechanically tied to observable
system objects. It also lets a future verified AccessKit adapter replace a
native implementation behind the same backend boundary.

## Consequences

- The public semantics DTO changes once and all repository consumers migrate
  together; no compatibility aliases are added.
- Platform adapters may develop in parallel only after the neutral DTO freezes.
- Linux native accessibility is reported unavailable until D-Bus export proof
  exists; Windows and macOS follow the same rule.
- Evidence is layered: L1 PR contracts, L2 controlled native clients, and L3
  matching screen readers. Evidence artifacts are never committed.

## Agent Notes

- **Session context**: Native accessibility and AI Agent evidence foundation.
- **Agent model**: OpenAI Codex.
- **Key prompt or instruction**: Complete neutral semantics to real native
  objects and screen-reader evidence without replacing the existing runtime.
- **Validation**: Focused package tests, API/interface review, native-client
  probes, and matching-screen-reader manifests.

## References

- [Committed semantics and Agent actions](../agent-semantics.md)
- [Platform host contract](../platform-host-contract.md)
- [Cross-platform evidence policy](../platform-readiness-declaration.md)
