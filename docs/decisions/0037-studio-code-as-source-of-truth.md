# 0037: MoUI Studio switches to code as the source of truth

- **Date**: 2026-10-05
- **Status**: Accepted
- **Deciders**: Agent-assisted (GLM plan sessions with repo owner review)
- **Related**: `docs/plans/active/moui-studio-workbench.md`, ADR 0021
  (embedded runtime product class), `docs/moui-studio.md`

## Context

MoUI Studio originally kept one in-memory IR serialized as `.studio.json`
(`moui.studio.project` v1). That single-file model made save/open trivial but
blocked three goals:

1. Imported MoonBit projects (`examples/counter`-style) could not be edited as
   projects — Studio needed project scan (`moon.mod`/`moon.pkg`), three preview
   modes, and a real build pipeline.
2. Blocks and the DSL could not graduate to real MoonBit semantics (structs,
   enums, match, field access) because there was no MoonBit file to host them.
3. External editors (VS Code) were locked out: the truth lived inside the app.

The workbench plan (`moui-studio-workbench.md`) therefore mandated switching the
source of truth to code files while keeping the IR as the in-memory editing
model.

## Decision

1. **On-disk truth = two code files per program package**: `form.mbt`
   (coordinate-layout subset consumed by the layout designer) and
   `handlers.mbt` (generated event-handler MoonBit, byte-identical to the
   export bundle). Both are derived from one IR snapshot; regeneration is
   deterministic.
2. **The IR remains the only in-memory editing model.** Blocks, the DSL, the
   designer, and AI proposals all edit the IR; the code files are written
   through regeneration (template apply, proposal accept) or span patches
   (designer drags). Editing the code display directly is a display-only
   surface until a MoonBit-subset text editor lands.
3. **`.studio.json` is demoted to a legacy interchange format.** Opening one
   runs a one-time migrator (decode → write the code project next to the old
   file → load the IR). Decode failures are structured errors that name the
   migrator; the old format is never silently loaded as program truth.
4. **The Code view defaults to the MoonBit appearance** (generated source,
   byte-identical to the export bundle); zh/en DSL renderings become display
   appearances. Commit/edit paths stay on the DSL appearance; the MoonBit
   display never mutates the IR.
5. **AI proposals keep the structured validation chain** (schema → invariants →
   bilingual parser → budgets → readability) and show a line-level **code text
   diff** of the regenerated files instead of structured entries only.

## Options Considered

### Option A: Keep `.studio.json` as the only format

- Pros: simplest save/open; one codec.
- Cons: external editors locked out; blocks cannot grow MoonBit semantics; no
  project-level build story; the file is a second representation that drifts
  from real MoonBit code.

### Option B: MoonBit project files as truth (chosen)

- Pros: VS Code becomes a first-class editor; code files compile with the real
  toolchain; blocks/DSL/designer become projections of the same truth; the
  export bundle and the on-disk source are byte-identical by construction.
- Cons: two derived files must stay in sync (solved: regeneration from IR is
  deterministic and gated); migration needed for existing files (solved:
  one-time migrator with structured errors).

### Option C: Dual-write both formats forever

- Pros: no migration.
- Cons: two sources of truth — the exact failure mode the invariants forbid;
  every feature pays double sync cost.

## Consequences

- Template apply and proposal accept regenerate `form.mbt` + `handlers.mbt`
  through `pending_code_project`; the composition root owns the writes.
- Opening `.studio.json` is now migration, not load.
- External-change reload for `form.mbt` is a manual refresh entry (the layout
  designer session re-parses and reloads with a notice; parse failures keep the
  current design).
- The `parse∘gen == id` inverse-parser contract and the two-track differential
  gate remain the hard guards for "the code you see is the code that runs".
