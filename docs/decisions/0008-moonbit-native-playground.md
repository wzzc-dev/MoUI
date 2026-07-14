# 0008: MoonBit-Native Browser Playground

- **Date**: 2026-07-13
- **Status**: Accepted
- **Deciders**: Agent-assisted (Codex, GPT-5)
- **Related**: `moui_richtext/code_editor`, `website/playground`, `scripts/generate-playground-assets.mjs`

## Context

MoUI needs an interactive browser tutorial with editable MoonBit source,
in-browser compilation, and an isolated live preview. A DOM editor such as
CodeMirror would make the visible editing model and much of the interaction
logic JavaScript-owned, which conflicts with the goal of exercising MoUI's own
rich-text and Web input stack. Browsers still require a host boundary for
Workers, sandbox iframes, object URLs, local storage, and Wasm startup.

## Decision

Implement the Playground as a MoonBit Web application:

- `moui_richtext/code_editor` owns reusable editor state, diagnostics,
  completions, searching, indentation, selections, and MoonBit tokenization.
- `website/playground/app` owns every visible control and product state.
- `website/playground/web_wasm` is a thin MoUI Web runtime entrypoint.
- `website/playground/host` contains JavaScript only for the compiler Worker,
  persistence/share URLs, sandbox iframe lifecycle, and Wasm module loading.
- The Worker uses a pinned `@moonbit/moonc-worker`, a generated `.mi/.core`
  manifest, and an app-safe import allowlist. Runtime, renderer, backend, and
  arbitrary registry imports are rejected.
- Compile, project-load, and preview messages cross the host boundary through
  revisioned JSON protocols and small character-stream Wasm imports/exports.
  Results for obsolete revisions are discarded.
- Successful programs run in an iframe with exactly `sandbox="allow-scripts"`.
  The fixed runtime modules and generated Wasm are recreated as Blob URLs
  inside the opaque iframe origin; errors return through nonce-checked
  `postMessage` events.

No CodeMirror, TypeScript, editor framework, or unpinned CDN dependency is
part of the published bundle.

## Options Considered

### CodeMirror DOM adapter

- Pros: mature editing behavior and broad browser compatibility.
- Cons: makes the visible editor JavaScript-owned and bypasses the MoUI text
  input, selection, semantics, and rendering paths.

### Fully MoonBit browser implementation with no JavaScript

- Pros: one implementation language.
- Cons: browsers do not expose Worker construction, sandbox iframe creation,
  Blob URL lifetime, or Wasm startup without a JavaScript host boundary.

### Server-side compilation

- Pros: avoids shipping the compiler and dependency cores.
- Cons: adds service availability, cost, abuse prevention, and project storage
  concerns; it does not provide the requested static Pages deployment.

## Rationale

The selected boundary keeps product behavior and editor correctness testable
in MoonBit while retaining the Rabbita-style static browser workflow. The
host protocol is narrow enough to audit, the package allowlist preserves the
app package boundary, and the sandbox starts a fresh runtime for every
successful compile.

The MoonBit Web linker is sensitive to `.core` input order for this closure.
The Worker therefore uses a deterministic shallow-stack order, covered by a
real browser compile-and-preview smoke, instead of dependency-first DFS order.

## Consequences

- Web text input, selection, clipboard, IME, and scrolling defects must be
  fixed in `moui_richtext` or the Web backend rather than hidden by a DOM
  editor fallback.
- Static assets are larger because the pinned compiler and dependency cores
  ship with the site.
- Compiler upgrades require regenerating and validating the hash manifest and
  re-running the real browser Worker smoke.
- Share links remain URL-sized; oversized projects are rejected rather than
  uploaded to a backend.

## Agent Notes

- **Session context**: Implement the MoonBit-native Playground, editor,
  tutorials, compiler Worker, isolated preview, persistence, sharing, and
  Pages packaging.
- **Agent model**: Codex (GPT-5)
- **Key prompt or instruction**: Do not use CodeMirror, TypeScript, or a
  JavaScript editor framework; keep only the minimum browser host.
- **Validation**: focused MoonBit tests and wasm-gc builds, six lesson builds,
  asset/hash validation, desktop/mobile Playwright checks, real Worker compile
  and iframe render, and `sh scripts/check.sh --profile daily`.

## References

- `docs/getting-started.md`
- `docs/moui-app-package-boundary.md`
- `docs/testing.md`
