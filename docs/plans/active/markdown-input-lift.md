# Plan: Lift the shared Markdown input surface into `moui_richtext` / `moui_markdown` (0.8.0)

- **Status**: active
- **RFC**: none (additive public surface; both packages stay `addons` modules)
- **Target release**: `0.8.0` (a patch may not add public symbols per `docs/compatibility-policy.md`)
- **Goal**: move the Markdown input surface MoMark and MoSpace each reimplement into the two addons, so both apps take the published version and delete their copies.
- **Non-goals**: touching the canonical-source + session architecture; wikilinks on by default; a built-in `mospace-wiki:` scheme; a changed reader spacing default; moving `MarkdownDocumentSession` out of `moui_richtext` (`richtext-markdown-domain-relocation.md`); app-package edits here.

Consumer evidence: MoMark `editor_target_sync.mbt` (437), undo grouping in `editor_state_edits.mbt`, `editor_context_menu.mbt` (271), `view_format_bubble.mbt` (179); MoSpace `vendor/moui_richtext` patches `markdown_viewer` for a palette, parses wikilinks with a `mospace-wiki:` marker, and owns the table layout/caret/paint fixes.

## Public API contract

New parameters are defaulted; nothing existing is removed or renamed. `View` returns use the app-facing `@moui.View[Msg]` facade (the docs spelling the API-surface validator requires); inside the packages the same opaque type comes from core.

```moonbit
// moui_richtext/markdown_viewer.mbt — three NEW defaulted parameters
pub fn[Msg] markdown_viewer(
  source~ : String, size~ : @core.Size,
  font~ : @core.FontSpec = @core.FontSpec::new(),
  foreground~ : @core.Color = @core.Color::black(),
  background~ : @core.Brush = @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
  corner_radius~ : Double = 0.0,
  on_link_click~ : ((String) -> Msg)? = None,
  visible_scroll_y~ : Double = 0.0,
  visible_viewport_height~ : Double = 0.0,
  visible_overscan~ : Double = 320.0,
  key~ : String? = None,
  palette~ : MarkdownRichTextPalette? = None,          // NEW
  compact_blank_gaps~ : Bool = false,                  // NEW
  wiki_links~ : MarkdownWikiLinkOptions? = None,        // NEW
) -> @moui.View[Msg]

// moui_richtext/markdown_wiki_links.mbt (new)
pub(all) struct MarkdownWikiLinkOptions { scheme : String }
pub fn MarkdownWikiLinkOptions::new(scheme : String) -> MarkdownWikiLinkOptions
pub fn MarkdownWikiLinkOptions::resolve(self : MarkdownWikiLinkOptions, target : String) -> String
// moui_richtext/markdown_model_inline.mbt — one NEW defaulted field
pub(all) struct MarkdownInline { text : String; kind : MarkdownInlineKind; target : String?; wiki : Bool = false }

// moui_richtext/editor_session.mbt
pub fn MarkdownDocumentSession::with_wiki_links(
  self : MarkdownDocumentSession, options : MarkdownWikiLinkOptions?,
) -> MarkdownDocumentSession
// moui_richtext/markdown_editor_target.mbt (new)
pub(all) enum MarkdownEditorTargetKind { PlainSelection; LinkTarget; ImageTarget; FootnoteTarget; HtmlBlockTarget; TableTools }
pub(all) struct MarkdownEditorTarget {
  kind : MarkdownEditorTargetKind; block_kind : MarkdownBlockKind; block_label : String
  link_target : String?; image_target : String?; footnote_text : String?; html_block_text : String?
}
pub fn MarkdownDocumentSession::target_at(
  self : MarkdownDocumentSession, selection : MarkdownEditorSelection,
) -> MarkdownEditorTarget
pub fn MarkdownEditorTarget::has_openable_target(self : MarkdownEditorTarget) -> Bool

// moui_richtext/markdown_edit_history.mbt (new)
pub(all) enum MarkdownEditKind { Insert; Backspace; ForwardDelete; Other }
pub(all) struct MarkdownEditOutcome { source : String; caret : Int32; selection : MarkdownEditorSelection? }
pub struct MarkdownEditHistory { /* fields stay package-private */ }
pub fn MarkdownEditHistory::new() -> MarkdownEditHistory
pub fn MarkdownEditHistory::record(
  self : MarkdownEditHistory, before~ : String, after~ : String,
  kind~ : MarkdownEditKind, at_ms~ : Int64,
  selection_before~ : MarkdownEditorSelection? = None,
  selection_after~ : MarkdownEditorSelection? = None,
) -> Unit
pub fn MarkdownEditHistory::undo(self : MarkdownEditHistory, source~ : String) -> MarkdownEditOutcome?
pub fn MarkdownEditHistory::redo(self : MarkdownEditHistory, source~ : String) -> MarkdownEditOutcome?
pub fn MarkdownEditHistory::can_undo(self : MarkdownEditHistory) -> Bool
pub fn MarkdownEditHistory::can_redo(self : MarkdownEditHistory) -> Bool
pub fn MarkdownEditHistory::clear(self : MarkdownEditHistory) -> Unit

// moui_markdown/editor_menu.mbt (new)
pub(all) struct MarkdownMenuItem { action : String; label : String; group : String }
pub fn markdown_editor_surface_menu_items(
  target~ : @richtext.MarkdownEditorTarget, has_selection~ : Bool,
  in_task_item~ : Bool, has_openable_target~ : Bool,
) -> Array[MarkdownMenuItem]
// moui_markdown/format_bubble.mbt (new)
pub(all) enum MarkdownFormatBubbleAction {
  Bold; Italic; Strikethrough; Code; Highlight; Link; Heading1; Heading2; UnorderedList; Quote
}
pub fn markdown_format_bubble_actions() -> Array[MarkdownFormatBubbleAction]
pub fn markdown_format_bubble_glyph(action : MarkdownFormatBubbleAction) -> String
pub fn markdown_format_bubble_label(action : MarkdownFormatBubbleAction) -> String
pub fn markdown_format_bubble_rect(
  caret : @core.Rect, width~ : Double = 300.0, height~ : Double = 32.0,
  viewport_height~ : Double,
) -> @core.Rect
pub fn[Msg] markdown_format_bubble(
  on_action~ : (MarkdownFormatBubbleAction) -> Msg, caret~ : @core.Rect,
  viewport_height~ : Double, width~ : Double = 300.0, height~ : Double = 32.0,
) -> @moui.View[Msg]
```

Rules: `palette~` feeds the session the reader builds; `compact_blank_gaps~` folds inactive gaps via `markdown_editor_collapse_inactive_blank_gaps` for hit testing and painting too. Wikilinks: `[[t]]` → `Link` with `text = t`, `wiki = true`; `[[t|label]]` → `text = label`; empty target is not a link; syntax only under `with_wiki_links(Some(..))`. `target` keeps the raw text (lossless round-trips) and `resolve` applies only at `target_at`/click time; `wiki = true`, not a URL prefix, drives `[[...]]` write-back, so `[x](wiki:foo)` is never rewritten. Target precedence is `HtmlBlockTarget` > `FootnoteTarget` > `LinkTarget` > `ImageTarget` > `TableTools` > `PlainSelection`: footnote runs before link because `[^1]` is a legal CommonMark reference link once defined, and the link probe would hand the footnote body over as a URL. Undo merges same-kind single-character edits within 500 ms, with the clock passed in as `at_ms~`; `undo`/`redo` return `None` on a diverged source and hand back the recorded `MarkdownEditorSelection?` (pre-edit on undo, post-edit on redo; `None` falls back to the caret). Menu `action` is the existing command word (`"bold"`, `"table-row"`, …) so one string maps to one `Msg`; the bubble flips below the caret when it would leave the viewport, clamps y, never clamps x.

## Workstreams

1. **Contract** — this document, posted before code changes.
2. **Reader palette** — thread `palette~` into `MarkdownViewerNode` and the process-level document cache (key gains the palette digest).
3. **Wikilinks** — post-process each block array once (`markdown_apply_wiki_links_to_blocks`); cache keys and the materialised memo include the option; `markdown_editor_inline_source` writes `[[...]]` back only for `wiki = true`.
4. **Target / undo / menu / bubble** — the four new files above; **reader spacing** — opt-in `compact_blank_gaps~`.
5. **Table fixes** — visible-run source shift + grapheme cluster advance, `line_index~` on the caret-hit segment helper, per-cell paint clip, ported regression test.
6. **Bookkeeping and verification** — regenerate both `pkg.generated.mbti`, refresh `checks/api-surface-report.json`, register new files and logic-line increments in `checks/source-file-policy.json`; `moon test`, `sh scripts/check.sh --profile pr`, and `moon info` + API-surface green.

## Upgrade notes and migration (0.8.0)

Additions only; every default preserves behaviour. `MarkdownInline` gains `wiki : Bool = false`, so parser/`markdown_inline()` values compile unchanged and `to_json` gains a key (consumer golden fixtures need it). `0.9.0` may flip `compact_blank_gaps` on by default; that needs its own plan.

- MoMark: pin `moui_richtext@0.8.0` + `moui_markdown@0.8.0`; replace `editor_target_sync.mbt` with `session.target_at(selection)`, its undo grouping with `MarkdownEditHistory`, its context-menu label tables with `markdown_editor_surface_menu_items`, and `view_format_bubble.mbt` with `markdown_format_bubble*`.
- MoSpace: drop `vendor/moui_richtext`, switch `app/moon.pkg:17` to the registry import, and replace the palette patch with `palette~`, the wikilink marker with `wiki_links~ = Some(MarkdownWikiLinkOptions::new("mospace-wiki:"))`, the blank-gap fold with `compact_blank_gaps~ = true`, and the forked table file with the published one.

## Acceptance

- [ ] Every symbol above exists with the signature shown; nothing existing removed or renamed; no new parameter lacks a default; wikilinks and compact gaps stay opt-in with an app-injected scheme.
- [ ] `moon check --profile pr` + `moon test` green; `moon info` → API-surface and maintenance-budget validators green.
