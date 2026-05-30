# AI Collaboration

MoUI benefits from AI assistance when changes remain small, reviewable, and
aligned with the framework architecture. This guide records the project-specific
workflow for agents and maintainers.

## Goals

- Preserve the public `View[Msg]` / internal runtime tree pipeline.
- Keep package boundaries clear and platform-neutral code out of platform hosts.
- Prefer focused edits, focused tests, and explicit validation over broad churn.
- Keep public API changes visible through generated interface diffs.
- Keep renderer capability status synchronized across code, tests, docs, and
  Showcase.
- Keep `AGENTS.md` and repo-local skills synchronized with fast-moving docs,
  validation commands, package layout, examples, and text/rendering boundaries.

## Project Invariants

- Public view constructors return opaque `@core.View[Msg]`; `ViewSpec` stays an
  internal core representation.
- The runtime pipeline stays:

  ```text
  View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
  ```

- `core/` owns runtime, state, layout, input, semantics, and draw commands.
- `views/` owns public constructor helpers and should reuse core primitive
  builders, bindings, styles, and modifiers without exposing lowering details.
- `backend/host/` owns `HostEvent`, surface metrics, input contracts, file
  drag/drop normalization, text-input session state, and redraw driver behavior.
- Platform packages convert native events into `HostEvent`; they do not mutate
  element trees directly.
- Renderers consume `DrawCommand` values and do not depend on view constructors.
- `examples/*/app/` packages contain shared app logic; platform subpackages stay
  thin.
- Linux has a minimal Wayland host core plus WGPU provider path; keep its
  remaining platform service, IME, AT-SPI, and native font-provider gaps
  explicit.

## Recommended Agent Workflow

1. Read `AGENTS.md` for repository rules.
2. Read the relevant docs page before editing architecture, backend, renderer,
   example, or testing behavior.
3. Locate the package boundary by reading the relevant `moon.pkg`.
4. Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, or
   `moon ide find-references` for MoonBit API discovery when names are unclear.
5. Edit package-locally and preserve `///|` top-level delimiters.
6. Add or update focused tests in the package touched.
7. Run the smallest useful validation command first.
8. Run `moon fmt` before handoff.
9. Run `moon info` after public API changes and review generated
   `pkg.generated.mbti` diffs.
10. Update docs when commands, platform behavior, public APIs, renderer
    capabilities, or examples change.
11. Check `AGENTS.md` and `skills/` when guidance would otherwise become stale.
    If no edits are needed, say they were checked and left unchanged.

## Prompt Templates

### Add A View Constructor

```text
Add a MoUI view constructor for <control>. Keep it in views/, return @core.View[Msg],
reuse existing core primitive builders/styles/modifiers where possible, add focused tests in
views/views_test.mbt, update docs/view-catalog.md if public coverage changes, and
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
normalize through backend/host HostEvent, add focused backend tests, and validate with
moon test moui/backend/host --target native plus the affected backend package test.
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
- If backend behavior changed, do events still flow through `HostEvent`?
- If an example changed, is shared app logic still under `examples/*/app/`?

## Anti-Patterns

- Putting platform window or renderer logic in `core/`.
- Returning legacy view types from public constructors.
- Letting backend packages directly modify runtime element or render trees.
- Duplicating renderer fallback decisions inside view constructors.
- Updating renderer behavior without updating the capability report and tests.
- Running broad native checks as the first validation step for a small package
  edit.
- Creating compatibility shims for removed APIs unless explicitly requested.
