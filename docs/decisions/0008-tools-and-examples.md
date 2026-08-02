# ADR 0008-0013: Tools and Examples (merged)

> 原编号保留为小节锚点: 0008-moonbit-native-playground,0012-showcase-consolidation-and-moui-cli-quickstart,0013-showcase-unified-shell

---

## 0008: MoonBit-Native Browser Playground

- **Date**: 2026-07-13
- **Status**: Accepted
- **Deciders**: Agent-assisted (Codex, GPT-5)
- **Related**: `moui_richtext/code_editor`, `website/playground`, `scripts/generate-playground-assets.mjs`

### Context

MoUI needs an interactive browser tutorial with editable MoonBit source,
in-browser compilation, and an isolated live preview. A DOM editor such as
CodeMirror would make the visible editing model and much of the interaction
logic JavaScript-owned, which conflicts with the goal of exercising MoUI's own
rich-text and Web input stack. Browsers still require a host boundary for
Workers, sandbox iframes, object URLs, local storage, and Wasm startup.

### Decision

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

### Options Considered

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

### Rationale

The selected boundary keeps product behavior and editor correctness testable
in MoonBit while retaining the Rabbita-style static browser workflow. The
host protocol is narrow enough to audit, the package allowlist preserves the
app package boundary, and the sandbox starts a fresh runtime for every
successful compile.

The MoonBit Web linker is sensitive to `.core` input order for this closure.
The Worker therefore uses a deterministic shallow-stack order, covered by a
real browser compile-and-preview smoke, instead of dependency-first DFS order.

### Consequences

- Web text input, selection, clipboard, IME, and scrolling defects must be
  fixed in `moui_richtext` or the Web backend rather than hidden by a DOM
  editor fallback.
- Static assets are larger because the pinned compiler and dependency cores
  ship with the site.
- Compiler upgrades require regenerating and validating the hash manifest and
  re-running the real browser Worker smoke.
- Share links remain URL-sized; oversized projects are rejected rather than
  uploaded to a backend.

### Agent Notes

- **Session context**: Implement the MoonBit-native Playground, editor,
  tutorials, compiler Worker, isolated preview, persistence, sharing, and
  Pages packaging.
- **Agent model**: Codex (GPT-5)
- **Key prompt or instruction**: Do not use CodeMirror, TypeScript, or a
  JavaScript editor framework; keep only the minimum browser host.
- **Validation**: focused MoonBit tests and wasm-gc builds, six lesson builds,
  asset/hash validation, desktop/mobile Playwright checks, real Worker compile
  and iframe render, and `sh scripts/check.sh --profile daily`.

### References

- `docs/getting-started.md`
- `docs/moui-app-package-boundary.md`
- `docs/testing.md`

---

## 0012: Showcase consolidation and moui_cli quick start

- **Date**: 2026-07-16
- **Status**: Accepted
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: ADR 0010, ADR 0011, `docs/examples.md`, `docs/showcases.md`

### Context

MoUI had three overlapping learning surfaces (`showcase`, `component_gallery`,
`platform_lab`) plus a `moui_example` submodule used as a clone-based quick
start. That split made discovery harder, duplicated component demos, and left
mobile CI identity mid-migration toward Showcase while gallery trees still
existed.

### Decision

1. **Quick start** is only `moui_cli`:
   ```sh
   moon install wzzc-dev/moui_cli/cmd/moui
   moui new my_app
   ```
   Do not document `git clone …/moui_example`.
2. **Showcase** is the only long-lived comprehensive example.
3. Showcase is one MoonBit module with a root TEA shell over four packages:
   - `app/components` — app-safe component catalog
   - `app/patterns` — application patterns
   - `app/platform` — host recipes / canvas / mobile probe (may use host)
   - `app/diagnostics` — runtime/render diagnostics exception
4. Canonical routes: `components|patterns|platform|diagnostics/<id>`.
   Desktop/Web default `components/welcome`; mobile default
   `platform/mobile-service-probe`. Keep bare aliases for
   `advanced-rendering` and `runtime-renderer`.
5. Mobile identity is Showcase-only (`dev.wzzc.moui.showcase`). No permanent
   compatibility aliases for deleted gallery wrappers.
6. Delete `examples/component_gallery`, `examples/platform_lab`, and the
   `examples/moui_example` gitlink/checkout.

### Options Considered

### Option A: Keep three examples and only re-link docs

- Pros: less code churn
- Cons: continued duplication and mixed mobile identity

### Option B: Merge into Showcase with four isolated packages (chosen)

- Pros: one catalog, clear copy-paste boundaries, single mobile identity
- Cons: larger one-time refactor; diagnostics still needs ongoing section trim

### Rationale

Users need one place to learn and one mobile proof app. Package isolation keeps
copy-paste guidance honest: ordinary apps should not depend on diagnostics'
core/runtime/render imports.

### Consequences

- Framework public API unchanged; Showcase routes and mobile IDs are the
  outward-facing example contract.
- Historical Component Gallery runtime artifacts remain labeled historical and
  are not Showcase evidence.
- Fresh Android/iOS/HarmonyOS Showcase device evidence is still pending and does
  not block packaging/tooling green.

### Agent Notes

- **Session context**: finish mid-flight Showcase consolidation
- **Validation**: `moon test examples/showcase/app --target native`; entrypoint
  `moon check` for desktop/mobile session packages

### References

- `examples/showcase/app/`
- `examples/catalog.json`
- `docs/getting-started.md`

---

## 0013: Showcase unified shell

- **Date**: 2026-07-16
- **Status**: Accepted
- **Related**: ADR 0012

### Context

After consolidating gallery/lab into four Showcase packages, the UI still felt
like four apps: root chrome plus each package's own header/nav, duplicate Mobile
Service Probe, and Diagnostics still exposing the old full catalog.

### Decision

1. **One chrome owner**: root shell only (workspace segment, catalog nav,
   history, list/detail on mobile).
2. Feature packages export **catalog metadata + `view_body`** only when hosted.
3. **Diagnostics catalog ≤ runtime labs** (inspector, runtime-renderer,
   advanced-rendering, text-diagnostics, interaction-lab).
4. **Mobile Service Probe** lives only under Platform.

### Consequences

- Clearer learning UX; package isolation retained for copy-paste.
- Dead dual-chrome code and non-diagnostic sections removed from the active
  navigation path.

