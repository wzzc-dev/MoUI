# Markdown Editor Hot Path Facts

- `MarkdownDocumentSession::apply` re-parses only the affected block cluster and
  stitches with offset rebase; fence/HTML/table/footnote/bracket/global-context
  edits fall back to full parse. Never assume "apply == full parse".
- Scroll geometry = persisted measured-height prefix-sum index (font/width/source
  keyed, epoch-invalidated). Content height O(1); visible window by binary search.
- Soft wrap is one memoized layout per block per content width, shared by
  paint/height/caret/hit-test/copy/selection. Don't add a second wrap pass.
- Instrument counters are package-private `hot_path_*` Refs; bench harness is
  `MOUI_EDITOR_HOT_BENCH=1`. Wheel/rebuild tests assert 0 height-walk blocks.
- Keystroke undo merges contiguous same-kind single-char edits within 500 ms
  (`moui_richtext/rich_text_editor_history.mbt`); classifier takes the PRE-edit
  caret; tests drive it via `rich_text_history_fake_clock_ms` Ref (−1 = real clock).
- `moui_richtext` mbti floor is ~96 pub lines while `MarkdownDocumentSession`
  keeps `pub(all)` fields typed by index internals and the app uses ~35 domain
  symbols via `using @moui_richtext`. Getting to ~30 needs domain-model
  relocation to the app package, not more privatization (4046 will pin the rest).
- `markdown_editor_substring` in the app package is O(source) per call — known
  dominant residual of the steady ~19 ms rebuild.
- Blockquote parsing is PER SOURCE LINE (`editor_source_mapping.mbt` falls
  through to `parse_markdown(line.text)`): quoted ``` fence lines re-parse to
  empty Paragraphs, so `markdown_quote_block_text` keeps the marker-stripped
  source line when flattening yields "" and the content starts with a fence.
- `markdown_inline_text` must CONCATENATE per-node flatten results;
  SoftBreak/HardBreak nodes themselves already flatten to "\n" — joining with
  `markdown_join_lines` injects one newline per node (blank quote rows).
- Skia retained layers cache rasterized image placeholders; async image
  completion updates renderer-owned pixels without a runtime content revision.
  `SkiaRasterRenderer` advances an image-cache generation, clears old layer
  entries, and forces one full-damage frame until the decoded pixels present.
- macOS CPU presentation must use one persistent layer-backed `NSView` and
  replace `CALayer.contents` inside a transaction with actions disabled;
  recreating an `NSImage`/`NSImageView.image` per frame lets AppKit expose a
  clear (white) transaction when neighboring sidebar/editor views repaint.
