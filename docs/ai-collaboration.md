# AI Collaboration

MoUI benefits from AI assistance when changes remain small, reviewable, and
aligned with the framework architecture. This guide records the project-specific
workflow for agents and maintainers.

## Goals

- Preserve the public `View[Msg]` / runtime tree pipeline.
- Keep package boundaries clear and platform-neutral code out of platform hosts.
- Prefer focused edits, focused tests, and explicit validation over broad churn.
- Keep public API changes visible through generated interface diffs.
- Keep renderer capability status synchronized across code, tests, docs, and
  Showcase.
- Keep `AGENTS.md` and repo-local skills synchronized with fast-moving docs,
  validation commands, package layout, examples, and text/rendering boundaries.

## Project Invariants

- Public view constructors return opaque `@moui.View[Msg]`; concrete built-in
  behavior lives in `moui/views` as `@core.ViewNode` implementations constructed
  with `@core.View::from_node`.
- The runtime pipeline stays:

  ```text
  View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
  ```

- `core/` owns platform-neutral contracts, opaque views, events, geometry,
  draw/semantics/text/theme contracts, and the public message-independent
  `ViewNode` extension protocol wrapped by typed `View[Msg]` adapters;
  `moui/runtime` owns `AppRuntime`, runtime state, tree/layout/paint, event
  dispatch, program message drain, effect tasks, subscriptions, and runtime
  diagnostics.
- `views/` owns public constructor helpers and concrete custom view behavior,
  reusing bindings, styles, and modifiers without exposing runtime internals.
- `backend/` owns `Event`, surface metrics, input contracts, file
  drag/drop normalization, text-input session state, and redraw driver behavior.
- Platform packages convert native events into `Event`; they do not mutate
  element trees directly.
- Renderers consume `DrawCommand` values and do not depend on view constructors.
- `examples/*/app/` packages contain shared app logic; platform subpackages stay
  thin.
- Linux has a Wayland host core plus WGPU provider path; keep remaining
  matching-host runtime evidence and native font-provider gaps explicit.

## Recommended Agent Workflow

1. Read `AGENTS.md` as a **map** (task router + hard-boundary summary only).
2. Open `docs/INDEX.md`, then only the linked canonical pages for the task.
   Prefer `docs/architecture-map.md` over the full architecture narrative until
   needed. Standing constraints: `docs/invariants.md`. Validation: `docs/testing.md`.
3. For multi-package or platform work, add or update `docs/plans/active/<id>.md`
   before large coding loops.
4. Locate the package boundary by reading the relevant `moon.pkg`.
5. Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, or
   `moon ide find-references` for MoonBit API discovery when names are unclear.
6. Edit package-locally and preserve `///|` top-level delimiters.
7. Add or update focused tests in the package touched.
8. Run the smallest useful validation command first (see the AGENTS task router).
9. Run `moon fmt` before handoff.
10. Run `moon info` after public API changes and review generated
    `pkg.generated.mbti` diffs.
11. Update docs when commands, platform behavior, public APIs, renderer
    capabilities, or examples change. Do not fork invariant tables into skills;
    link `docs/invariants.md`. Taste rules: `docs/golden-principles.md`.
12. Check `AGENTS.md` and `skills/` when guidance would otherwise become stale.
    If no edits are needed, say they were checked and left unchanged.

## Prompt Templates

### Add A View Constructor

```text
Add a MoUI view constructor for <control>. Keep it in views/, return @moui.View[Msg],
implement reusable behavior in views/ as a concrete @core.ViewNode and construct it with @core.View::from_node, reuse existing styles/modifiers where possible, add focused tests in
the moui/views tests (tests/smoke), update docs/view-catalog.md if public coverage changes, and
run moon test moui/views --target native plus moon info if the public API changes.
```

### Change Renderer Capability

```text
Improve renderer support for <feature>. Keep DrawCommand as the renderer boundary,
update render/capabilities.mbt, render/capabilities_test.mbt, docs/renderer-capability-report.md,
and Showcase if visible. Validate with renderer package tests and a Showcase Web wasm-gc build.
```

### Change Backend Event Handling

```text
Change backend handling for <event>. Keep platform-specific code in backend/<platform>,
normalize through backend Event, add focused backend tests, and validate with
moon test moui/backend --target native plus the affected backend package test.
```

### Update An Example

```text
Update the <example> example. Keep shared logic in examples/<example>/app and platform
entrypoints thin. Add app-package tests for behavior, build the Web wasm-gc entrypoint
if browser behavior changes, and update docs/examples.md if commands or coverage change.
```

### Update Documentation

```text
Update MoUI docs for <topic>. Keep the root README.md as the short entrypoint, put
detailed commands in docs/development.md, platform caveats in docs/platform-notes.md,
example behavior in docs/examples.md, text architecture in docs/text-system.md,
Markdown Editor behavior in docs/markdown-editor.md, and validation policy in
docs/testing.md. Also check AGENTS.md and skills/ when the guidance surface changes.
```

## Review Checklist

- Does the change preserve the runtime pipeline?
- Are package boundaries respected?
- Does public API surface change intentionally?
- Were focused tests added or updated?
- Did `moon fmt` run?
- Did `moon info` run for public API changes?
- Are docs updated for user-facing behavior, commands, or platform constraints?
- Were `AGENTS.md` and repo-local skills checked when docs placement,
  validation, package layout, examples, platform behavior, renderer status, or
  text architecture changed?
- If renderer behavior changed, are capability code, tests, report, and Showcase
  synchronized?
- If backend behavior changed, do events still flow through `Event`?
- If an example changed, is shared app logic still under `examples/*/app/`?

## Decision & Session Logging

MoUI maintains a three-layer record system for AI-agent-assisted development.

### Layer 1: Memory Quick Notes (`memories/repo/`)

Short bullet-point facts that agents load automatically each session.
Use for: key patterns, common pitfalls, validated conventions.
Keep entries under 20 lines per file.

### Layer 2: Architecture Decision Records (`docs/decisions/`)

Formal structured records for significant technical decisions.
Create an ADR when:

- Choosing between two or more architectural approaches.
- Changing a public API contract or package boundary.
- Introducing a new dependency or external protocol.
- Changing renderer, backend, or runtime pipeline behavior.
- Decisions that affect how agents should work in this repo.

Use the template at `docs/decisions/TEMPLATE.md`.
Number sequentially (`0001-`, `0002-`, ...) and update the index in
`docs/decisions/README.md`.

### Layer 3: AI Session Logs (`docs/ai-sessions/`)

Summaries of significant multi-file or architecture-touching sessions.
Log a session when:

- Multi-file changes that touch architecture boundaries.
- The session produced an ADR.
- Significant debugging or discovery happened.
- A new pattern or anti-pattern was established.

Use the template at `docs/ai-sessions/TEMPLATE.md`.
Name files `YYYY-MM-DD-short-description.md`.

### Workflow Integration

After a significant agent session:

1. Update `memories/repo/` with any new quick-reference facts.
2. If a formal decision was made, create an ADR in `docs/decisions/`.
3. If the session was complex or educational, log it in `docs/ai-sessions/`.
4. Reference the ADR/session log in the commit message or PR description.

## Anti-Patterns

- Putting platform window or renderer logic in `core/`.
- Returning legacy view types from public constructors.
- Letting backend packages directly modify runtime element or render trees.
- Duplicating renderer fallback decisions inside view constructors.
- Updating renderer behavior without updating the capability report and tests.
- Running broad native checks as the first validation step for a small package
  edit.
- Creating compatibility shims for removed APIs unless explicitly requested.
- Growing `AGENTS.md` into an encyclopedia instead of routing to `docs/`.
- Restating full invariant tables in skills or session notes (link instead).
- Leaving critical rules only in chat or session prose without promotion to
  `memories/repo/`, ADR, plan, or a validator.
