# 2026-06-29: Richtext Blackbox Tests Verification (Workflow 4)

- **Agent**: Trae AI
- **Goal**: Verify that Workflow 4 of the moui_richtext optimization plan — adding stable blackbox tests — is complete. All 5 test files were created/expanded with 82 new test cases.
- **Outcome**: Success (82 new tests verified, no API changes needed)

## Summary

Workflow 4 of the moui_richtext optimization plan required stable blackbox tests for the addon's core capabilities. All planned test files were created/expanded with 82 new test cases (well above the 30+ target). No source code changes were needed — only verification commands were executed to confirm all tests pass.

## Changes Made

| Package/File | Tests | Coverage |
|---|---|---|
| `moui_richtext/rich_text_document_test.mbt` (new) | 22 | `RichTextDocument::plain` split, `RichTextDocument::new`, markdown parse (heading, paragraph, list, task, quote, code, table, front matter), source_range/content_range invariants |
| `moui_richtext/editor_commands_test.mbt` (new) | 16 | Bold/Italic/Code/Strikethrough wrap/unwrap symmetry, Heading/List/Quote block transforms, HorizontalRule, inline marker queries |
| `moui_richtext/editor_input_transforms_test.mbt` (new) | 15 | Pair delimiter input, selection wrapping, tab indent/outdent, hard break, blockquote indent |
| `moui_richtext/editor_session_test.mbt` (extended) | 20 (7+13 new) | Transaction immutability, source diff (insert/replace/delete), caret/selection preservation, fingerprint stability |
| `moui_richtext/editor_source_mapping_test.mbt` (new) | 16 | Format detection, format_for_selection, focus_mode dimming, snapshot parsing, active selection/block label, preview text |

## Key Decisions

- All tests are pure blackbox: only exercise public symbols from
  `pkg.generated.mbti`.
- New test files only — no changes to `moui_richtext` source code.
- `MarkdownEditReason` uses `assert_true(txn.reason == CommandEdit)` rather than
  `inspect()` since it doesn't implement `Show`.
- Indentation tests use two-space prefix (`"  "`), matching the actual
  `markdown_editor_indent_segment` behavior.

## Discoveries

- `MarkdownEditReason` derives `Eq, ToJson, @debug.Debug` — not `Show`, so
  `inspect()` on it won't compile.
- All 82 planned scenarios were achievable through public API; no scenarios were
  skipped due to insufficient API surface.

## Validation

```sh
moon check moui_richtext --target native
moon test moui_richtext --target native
moon fmt
moon info
```

All 82 new tests pass alongside 22 pre-existing tests (~104 total).
`moon info` showed no public API changes (test files only).
