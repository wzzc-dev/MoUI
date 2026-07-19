# Plan: Markdown HTML image gallery rendering

- **Status:** done
- **Goal:** Render the safe, presentation-oriented subset of raw HTML image
  galleries in Markdown Editor while keeping Markdown source and HTML export
  lossless.
- **Non-goals:** add a general-purpose HTML renderer, execute HTML, change
  renderer backends, or reinterpret unsupported/mixed HTML blocks.

## Delivery

1. Recognize gallery-only HTML blocks containing `div`/`center`, `img`, and
   `br`, retaining each original tag for source mapping.
2. Carry optional image width fractions and line alignment through the existing
   rich-text document model, then size and center image rows from the available
   content width.
3. Reuse the Markdown image source-resolution path for HTML `src` attributes;
   parse safe `alt`, `width`, and `height` attributes without altering source.
4. Preserve the current monospaced raw-HTML fallback for unsupported HTML and
   retain raw source in source mode and HTML export.
5. Add rich-text and Markdown Editor regression coverage, document the supported
   subset, then run targeted checks, formatting, interface review, and static
   validation.

## Acceptance

- [x] A centered `<div>` image gallery emits `DrawImage` commands for all valid
  `<img>` elements.
- [x] Percentage widths are resolved against the content width; pixel dimensions
  remain fixed and image rows retain aspect ratio.
- [x] `<br>` creates gallery row breaks and centered rows align as authored.
- [x] Relative HTML `src` values honor `base_dir` exactly like Markdown images.
- [x] Unsupported/mixed HTML remains the existing raw HTML presentation.
- [x] Source mode and HTML export preserve the original HTML byte-for-byte.

## Verification

- `moon test moui_richtext --target native`
- `moon test examples/markdown_editor/app --target native`
- `moon build examples/markdown_editor/web_wasm --target wasm-gc`
- `moon fmt`
- `moon info`
- `node scripts/validate-maintenance-baseline.mjs`
- `node scripts/validate-api-surface.mjs`
- `node scripts/validate-guidance-consistency.mjs`

All commands passed on 2026-07-19. Focused regression coverage verifies the
HTML-block parser keeps nested self-closing `<br/>` tags inside the enclosing
gallery, maps every `img`/`br` tag back to raw source, preserves export/source
mode content, and computes responsive gallery dimensions for both viewer and
session-window paths.
