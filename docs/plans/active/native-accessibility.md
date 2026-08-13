# Plan: Native accessibility and Agent evidence

- **Status**: active
- **ADR**: [0029](../../decisions/0029-native-accessibility-adapters-and-evidence.md)
- **Goal**: Complete the path from committed neutral semantics through real
  native accessibility objects to matching-screen-reader evidence, while
  keeping Agent automation on the same generation-checked protocol.
- **Non-goals**: replacing the committed semantics runtime, moving native
  objects into `core` or `runtime`, treating AccessKit-shaped data as native
  evidence, or raising a capability before matching-host proof exists.

## Delivery sequence

1. Record ADR 0029, the Probe contract, Agent work packages, evidence schema,
   and current capability baseline before production changes.
2. Freeze the expanded neutral semantics DTO and migrate runtime, Agent wire,
   AccessKit conversion, Web ARIA, controls, and tests in one API change.
3. Complete focus-trap/modal behavior, independent accessibility focus, live
   announcements, relationship resolution, and stale-action invalidation.
4. Add the fixed Showcase Accessibility Probe and L1 contract matrix.
5. Harden Web, then complete a macOS NSAccessibility vertical slice with AX
   query/action proof and VoiceOver evidence.
6. Implement Windows UIA and Linux AT-SPI adapters without changing readiness
   until their matching-host evidence passes.
7. Add layered PR/platform/release gates and synchronize capability docs.

## Acceptance

- [x] Every public Probe control has role/name/value/state/relation/action
  contract tests.
- [x] Snapshot relations resolve stable `SemanticId` declarations into
  committed `SemanticsNodeId` values and report missing/ambiguous targets.
- [x] Focus traps constrain keyboard and explicit semantic focus; modal close
  restores a stable target without retaining an obsolete `ElementId`.
- [x] Accessibility browsing focus is distinct from keyboard input focus.
- [x] Live-region deltas produce announcements without moving either focus.
- [x] Web exposes legal DOM/ARIA roles, relations, ranges, collections, modal,
  and live metadata through a real Chrome accessibility-tree smoke.
- [ ] macOS publishes real NSAccessibility objects and passes AX query/action
  plus VoiceOver navigation evidence for the Showcase Probe.
- [x] Windows and Linux remain `native_accessibility_available=false` until
  real UIA/AT-SPI client evidence exists.
- [x] Agent MCP remains exactly `read_semantics` and `perform_action`, backed by
  the same committed generation/action/receipt protocol as native adapters.
- [x] L1 runs on PRs, L2 on controlled platform/nightly hosts, and L3 only on
  matching screen-reader hosts; generated evidence stays under `artifacts/`.

## Agent work protocol

Work ownership and dependency order are canonical in
`checks/accessibility-work-packages.json`. Each handoff uses:

```json
{
  "task": "NA-xxx",
  "changed_files": [],
  "tests": [],
  "api_diff": true,
  "evidence": [],
  "known_gaps": [],
  "blocked_by": []
}
```

No platform work package may modify `moui/core/semantics.mbt`. Platform work
starts only after NA-01 freezes the DTO and its wire codes.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-12 | Keep `moui/backend/accesskit` as the neutral AccessKit-shaped mapping and implement narrow platform-native adapters. |
| 2026-08-12 | Make the semantics DTO migration once, without compatibility aliases, and migrate all in-repository consumers atomically. |
| 2026-08-12 | Use stable SemanticId values for declarations and resolve committed relations to SemanticsNodeId values in runtime. |
| 2026-08-12 | Make the macOS Showcase Probe plus VoiceOver the first native vertical-slice acceptance target. |
| 2026-08-12 | Separate PR L1, controlled-host L2, and matching-screen-reader L3 evidence. |

## Progress

| Date | Note |
|------|------|
| 2026-08-12 | Plan, ADR, Probe manifest, Agent work packages, and conservative Linux baseline established. |
| 2026-08-12 | Neutral DTO, runtime focus/modal/live/delta behavior, control contracts, Agent wire shape, and AccessKit mapping migrated and covered by L1 tests. |
| 2026-08-12 | Web DOM/ARIA hardening and Chrome Accessibility Tree L2 Probe passed; evidence is recorded under `artifacts/accessibility/web/`. |
| 2026-08-12 | Added a matching-host macOS AX client and evidence recorder; it emits a failed L2 manifest when Accessibility permission or the external tree/action trace is unavailable. Capability remains false until `--require-passed` succeeds. |
| 2026-08-12 | Added Windows UIA and Linux GDBus transport implementations. Linux now carries exact-generation actions, removals, frames, collection metadata, and lifecycle cleanup, but remains non-native-ready until AT-SPI accessibility-bus/Registry integration and matching-client evidence pass. Windows likewise remains false pending Windows SDK build and UIA client evidence. |
| 2026-08-12 | Extended embedded, Web, macOS, Windows, and Linux wire payloads with numeric/text/collection/relations/live/announcement data and independent semantic browsing focus. Added live announcements for newly inserted nodes, UIA action gating, and host-loop synchronization of existing contrast/reduced-motion/text-scale Environment settings where the platform exposes them. |
| 2026-08-13 | Added Windows TextScaleFactor and Linux GNOME `gsettings`/environment-backed contrast, reduced-motion, and text-scale synchronization. macOS remains limited to settings with a stable AppKit API; unsupported text-scale sources preserve the existing Environment value. |
