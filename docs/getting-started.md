# Getting Started with Playground

MoUI now ships a browser Playground for the first six bilingual lessons. Open
the website tutorial at `?section=tutorial`, or open the standalone
`/playground/` page to edit `main.mbt` and a controlled `moon.pkg` file.
Choose a lesson directly with `/playground/?example=03-state-events`.

The visible editor is implemented with MoUI and `moui_richtext`; it does not
depend on CodeMirror or TypeScript. The browser host keeps only the platform
bridge required for a Web Worker, Wasm loading, and the isolated preview
iframe.

## Local Preview

Build the Playground Web package and stage its static assets:

```sh
moon build website/playground/web_wasm --target wasm-gc
node scripts/generate-playground-assets.mjs --out dist/playground
```

Serve `dist/` from a static HTTP server and open `dist/playground/`. The
published asset manifest pins the MoonBit compiler worker version and records
SHA-256 hashes for the staged files.

## Package Boundary

User code is compiled for `wasm-gc` against an app-safe allowlist containing
MoUI facades and `views`. Runtime, renderer, platform backend, and arbitrary
registry imports are rejected before compilation. The fixed Runner owns the
Web runtime exports and starts the user `program()`.

The compiler and preview are revisioned: an old Worker response cannot replace
newer editor content, and every successful run reloads the sandbox iframe.
Recent projects are kept in same-origin `localStorage`; the Share button emits
an URL-safe project link and rejects projects that exceed browser URL limits.

## Editor Package

Reusable editing state lives in `moui_richtext/code_editor`. The package is
targeted at native and `wasm-gc`, and covers cursor/selection edits, automatic
indentation, bracket matching, find/replace, diagnostics, and completions.
The Playground Web app consumes the same MoonBit model while the browser host
handles only Worker and iframe APIs.
