# Plan: Relocate the Markdown editing domain model out of `moui_richtext`

- **Status**: active
- **RFC**: none (no invariant change; `moui_richtext` is an addon, and the
  target package follows the existing domain-facade pattern)
- **Goal**: Cut `wzzc-dev/moui_richtext`'s public surface from the current
  ~96 pub lines (compiler-pinned structural floor after privatization) toward
  the review target of ~30 by moving the Markdown editing domain model — the
  session, block/inline Markdown model, reference/table parsing, and
  Markdown-specific editing commands — into a dedicated domain package, and
  leaving `moui_richtext` as the generic rich-text document/editor layer.
- **Non-goals**: Changing the canonical-Markdown-source + session architecture;
  adding app features; touching the read-only viewer behaviour or the
  `@core.TextSystem` contract; weakening the hot-path (incremental parse,
  prefix-sum geometry, wrap memo) designs.

## Why the remaining surface cannot shrink in place

- `MarkdownDocumentSession` keeps `pub(all)` fields typed by dirty-range,
  height-index, and layout-cache internals; every internal type it exposes
  becomes public (error 4046 pinned ~40 restorations in the P3 pass).
- `examples/markdown_editor/app` consumes ~35 domain symbols via
  `using @moui_richtext`; accessor wrapping is useless under MoonBit field
  visibility (`pub` struct fields are always visible).
- Consumers that must keep working unchanged: `examples/code_editor/app`
  (generic rich-text editor only, no Markdown model) and
  `examples/showcase/app/diagnostics`.

## Decisions

| Date | Decision |
|---|---|
| 2026-09-02 | Relocate rather than wrap: a wrapper package adds a layer without reducing any consumer's import set. |
| 2026-09-02 | Target home is a new addon package `moui_markdown` (peer of `moui_richtext`, declared in `checks/release-modules.json` as `addons`), because the Markdown editing domain is reusable beyond one example and `code_editor` proves the generic layer must stay Markdown-free. |
| 2026-09-02 | No compatibility re-exports: `moui_richtext` must not `pub use` the relocated symbols, otherwise the mbti does not shrink. Consumers switch imports in the same slice. |

## Workstreams

1. **Slice boundary** — classify every current `moui_richtext` declaration as
   *generic rich text* (RichText{Block,Run,Document,Editor*}, wrap/caret/hit/
   paint/history, cache, code highlight, `MarkdownDocumentSession`-agnostic
   input transforms) vs *Markdown domain* (`editor_session.mbt` session +
   layout cache, `markdown_model*`, `input_blocks*` Markdown parsing,
   `commands_*` Markdown block/table/ref commands, `markdown_html_image_gallery`,
   `rich_text_markdown_session_editor`, `markdown_viewer`). Record the split in
   the plan before moving code.
2. **Break the coupling edges** — the generic layer must reference Markdown
   types only through parameters/callbacks provided by the session (e.g. pass
   parsed blocks in, never call the parser from inside); resolve the current
   upward references (wrap/caret consuming `MarkdownEditorBlock` metadata) by
   widening the generic block type or moving those consumers to the domain side.
3. **Create `moui_markdown`** — new package directory with `moon.pkg` importing
   `moui_richtext` + `moui` facades; move the Markdown-domain files and their
   `_wbtest.mbt` counterparts; keep hot-path counters with whichever package
   owns the measured path (geometry/session counters move, wrap counters stay).
4. **Consumer migration** — `examples/markdown_editor/app` imports
   `@moui_markdown` for the domain surface and keeps `@moui_richtext` only for
   generic editor primitives; `code_editor` and showcase diagnostics unchanged
   (assert their import set doesn't gain Markdown symbols).
5. **Surface + release bookkeeping** — regenerate `moui_richtext` and new
   `moui_markdown` mbti; update `checks/release-modules.json`,
   `checks/api-surface-report.json` (via `node scripts/generate-repo-docs.mjs
   --write`), `docs/view-catalog.md`/`docs/architecture-map.md` rows, and
   `checks/source-file-policy.json` ratchets; update
   `docs/markdown-editor.md` (+ zh-Hans) and `memories/repo/markdown-editor-hotpath.md`
   where they describe `moui_richtext`'s scope.
6. **Verification** — per-package tests stay green at every slice
   (`moon test moui_richtext|moui_markdown examples/markdown_editor/app examples/code_editor/app --target native`);
   the hot-path benchmark (`MOUI_EDITOR_HOT_BENCH=1`) must not regress
   (baseline: 11 845 µs/keystroke, wheel ≈284 µs, rebuild ≈19 ms); pre-push
   static trio + renderer-capability + doc-references validators green.

## Acceptance

- [ ] `moui_richtext` mbti ≤ ~35 pub lines and no `Markdown*` type appears in
      it except the shared block-metadata contract agreed in workstream 2.
- [ ] `moui_markdown` exists, is listed in `checks/release-modules.json`, and
      owns the session/parsing/Markdown-command surface.
- [ ] `examples/code_editor/app` compiles and tests green importing only the
      generic layer.
- [ ] `moon test moui_richtext moui_markdown examples/markdown_editor/app
      examples/code_editor/app --target native` green; wasm-gc build of
      `examples/markdown_editor/web_wasm` green.
- [ ] Hot-path benchmark counters within noise of the 2026-09-02 baseline.
- [ ] Guidance (EN + zh-Hans) describes the two-package split.
