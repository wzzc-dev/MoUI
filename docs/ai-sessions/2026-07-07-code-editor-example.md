# 2026-07-07: Native Code Editor Example

- **Agent**: Codex
- **Goal**: Add an `examples/code_editor` example that demonstrates native code-editing workflows without WebView/Monaco.
- **Outcome**: Success.

## Summary

Added a native-only Code Editor example with shared app logic and macOS, Windows, and Linux Skia entrypoints. The example demonstrates tokenizer-backed highlighting, bracket matching, auto indentation, multi-cursor edits, find/replace, shortcut metadata, IntelliSense-style providers, diagnostics, hover, go-to-definition, Diff Editor preview, and custom language/provider registration. Later in the same session, the UI was upgraded from a feature-demo panel into a VS Code-style native editor shell with activity rail, file tab, line-number gutter, status bar, hidden find/completion overlays, and main-editor Diff mode.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `examples/code_editor/app` | Added app model/update/view, editing helpers, language registry, diff model, generated API summary, and focused tests. | Keep code-editor behavior platform-neutral and testable. |
| `examples/code_editor/{macos_skia,windows_skia,linux_skia}` | Added thin native Skia entrypoints that register action commands. | Provide native routes without WebView or `web_wasm`. |
| `moui_richtext` | Added `visible_scroll_state` to rich text editor constructors and a wheel-event scroll-state regression test. | Let native editor surfaces share scroll state with gutters and overlays. |
| `docs/examples.md`, `docs/architecture.md`, `docs/development.md`, `moon.work` | Registered the example in docs and workspace membership. | Make the example discoverable and included in workspace validation. |

## Key Decisions

- Use `moui_richtext.controlled_rich_text_editor` as the editable native surface rather than embedding Monaco/WebView.
- Keep language-service APIs app-owned in the example package; do not promote editor-specific provider contracts into `moui/core` or `moui/views`.
- Use a simple LCS line diff for review/patch preview instead of pulling in a dependency.

## Discoveries

- `ActionCommandMap` is sufficient for native host shortcut metadata in this example.
- Language providers should include diagnostics as a callback alongside tokenizer, completion, hover, and definition to avoid hard-coding diagnostics into the app loop.
- Website docs are generated and ignored under `website/web_wasm/docs`; run `node scripts/sync-website-docs.mjs` before `--check`.

## Validation

```sh
moon fmt --check examples/code_editor/app examples/code_editor/macos_skia examples/code_editor/windows_skia examples/code_editor/linux_skia examples/code_editor/README.mbt.md
moon test examples/code_editor/app --target native
moon check examples/code_editor/macos_skia --target native
moon check examples/code_editor/windows_skia --target native
moon check examples/code_editor/linux_skia --target native
moon test moui_richtext --target native
moon info moui_richtext --target wasm-gc
moon info examples/code_editor/app --target native
node scripts/validate-guidance-consistency.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
```

Windows Skia check passed with an existing unrelated `moui_windows_async_image_spawn_sync` unused extern warning.

## Follow-Up

- [ ] A real platform smoke can be run later if release notes need runtime artifact evidence.
