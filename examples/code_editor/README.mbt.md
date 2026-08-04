# Code Editor

Code Editor is a native-only MoUI code editor shell. It uses
`moui_richtext.controlled_rich_text_editor` for the editable surface, adds an
app-owned editor chrome around it, and keeps language-service behavior in the
shared app package.

The example demonstrates:

- a VS Code-style shell with activity rail, file tab, line-number gutter, and
  status bar
- syntax highlighting through tokenizer-backed rich text runs
- bracket matching, auto indentation, multi-cursor insertion, and hidden
  find/replace overlay
- typed Program-command shortcut metadata
- completion overlay plus diagnostic, hover, and go-to-definition providers
- a main-editor Diff Editor mode for review and patch inspection
- custom language registration through app-owned provider callbacks

Focused checks:

```sh
moon test examples/code_editor/app --target native
moon check examples/code_editor/macos_skia --target native
```

Run the macOS native Skia entrypoint:

```sh
moon run examples/code_editor/macos_skia --target native
```
