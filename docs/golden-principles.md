# Golden Principles

Short, opinionated rules optimized for **future agent runs**. Prefer encoding
these into validators (`tools/moui/*`, `checks/`) over restating them in prose.

When a principle is mechanical, point `docs/invariants.md` Detection at the
script. When it is still taste, keep it here and clear AI residue in small PRs.

## Boundaries

1. **One owning package per capability** — extend the owner; do not fork helpers into examples or sibling packages.
2. **Parse at boundaries** — host payloads, manifests, and FFI results are validated or typed at the edge; no YOLO field poking deep in app logic.
3. **App packages stay app-safe** — only `wzzc-dev/moui`, domain facades, and `views` (see P8/P9).
4. **Platform entrypoints are wiring** — no product state machines in `*_skia` / `web_wasm`.
5. **Renderers consume `DrawCommand`** — no view-constructor dependency in reverse.

## Mainline honesty

6. **Native Skia is mainline; native WGPU is experimental (engineering gate `diagnostic`)** — do not soft-reclassify in docs or examples; do not present WGPU as product-capable.
7. **Mobile claims need evidence grades** — `passed` / `partial` / `failed` only via manifests; packaging ≠ runtime proof.
8. **Embedded runtime backends are canonical for Android/iOS/HarmonyOS** — `wzzc-dev/window` owns platform lifecycle, surface, and input; examples keep only thin MoonBit entrypoints.

## Agent-operable repo

9. **Maps over manuals** — `AGENTS.md` stays a directory; depth lives under `docs/` with `INDEX.md` links.
10. **Single source of truth** — invariants, validation policy, and package boundary each have one canonical file; other files link.
11. **Smallest useful check first** — path-local `moon test` / validators before `daily` / `platform`.
12. **Fix hints in tools** — validator failures should name the invariant and the fix doc anchor.
13. **Plans for multi-package work** — `docs/plans/active/` before large coding loops.
14. **Promote discoveries** — session logs → `memories/repo/` (short) or ADR (decisions); do not leave critical rules only in chat.

## Residue control

15. **Prefer shared utilities** already in-tree over new one-off helpers.
16. **No compatibility shims** for removed APIs unless explicitly requested.
17. **Garbage-collect weekly patterns** — duplicated helpers, stale docs, forbidden imports: small automated or agent-driven PRs, not quarterly rewrites.

## Related

- Constraints table: `docs/invariants.md`
- Mechanization batch1: `docs/plans/done/harness-mechanize-invariants-batch1.md`
- Agent workflow: `docs/ai-collaboration.md`
