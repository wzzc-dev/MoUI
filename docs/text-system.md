# Text System

MoUI keeps text measurement in the platform-neutral runtime while letting
native and Web hosts install the renderer-backed text system that matches their
platform. The public boundary is `@core.TextSystem`; measurement-only legacy
shapes are no longer part of the framework contract.

## Runtime Boundary

- `core/text_layout.mbt` defines `TextSystem`, `TextSystem::fallback()`, and
  font data registration.
- `AppRuntime` exposes `text_system()` and `set_text_system()` so hosts can
  install a platform text system before layout, painting, hit testing,
  selection, and IME anchor geometry are produced. The underlying
  `RuntimeState` stores the active system as an engine detail.
- `FontSpec` carries a structured family stack. The default stack is
  `SystemUi`; concrete font names are resolved by the active native or Web
  provider unless app code requests a named family.
- `core/` owns only the neutral contract and deterministic fallback. It does
  not import `Milky2018/moon_cosmic`, `Milky2018/moon_swash`, CoreText,
  DirectWrite, fontconfig, HarfBuzz, FreeType, or browser APIs.

The live text path is:

```text
View[Msg] -> internal ViewSpec -> DrawCommand::DrawText(TextRun) -> active TextSystem measurement -> renderer glyph path
```

Caret positions, selection geometry, wrapping, clipping, and IME request
coordinates should all use the same active `TextSystem` that layout uses.

## Native WGPU

`render/wgpu` owns the native provider protocol, provider response validation,
fallback composition, glyph atlas upload, and renderer-side cache keys. It does
not depend on the standalone Cosmic provider package.

Provider packages are intentionally separate:

- `render/wgpu/cosmic_text/`: Moon Cosmic provider used directly by examples
  that select `MoonCosmic`, and as the fallback provider for platform defaults.
- `render/wgpu/coretext/`: macOS CoreText/CoreGraphics provider. macOS defaults
  to this provider composed with Cosmic fallback.
- `render/wgpu/directwrite/`: Windows DirectWrite scaffold. Windows defaults to
  this scaffold composed with Cosmic fallback until the real DirectWrite engine
  returns platform layout and raster data.
- `render/wgpu/fontconfig/`: Linux fontconfig/HarfBuzz/FreeType scaffold. Linux
  defaults to this scaffold composed with Cosmic fallback until the real
  fontconfig provider returns platform layout and raster data.
- `render/wgpu/text_protocol/`: shared native-stub payload protocol for UTF-32
  input, versioned `FontSpec` encoding, measure/run/raster envelopes, and
  embedded-font registration payloads.

macOS, Windows, and Linux hosts choose the startup text engine through
`run_app_with_options(..., options=<Platform>AppOptions::new(text_engine=...))`.
`PlatformDefault` composes the platform provider with Cosmic fallback;
`MoonCosmic` selects the Cosmic provider directly. Showcase also has explicit
`macos_cosmic`, `windows_cosmic`, and `linux_cosmic` entrypoints for comparing
those paths.

Native provider responses must report valid metrics, monotonic caret positions
covering the input text, and raster glyph payloads whose cache keys include all
raster-affecting inputs such as glyph identity, font size, style, weight, and
scale. Invalid layout or raster data is rejected at the renderer boundary and
falls back when a fallback engine was supplied. Run-layout responses may omit
carets, but any non-empty caret array must be monotonic and cover the input
text before glyphs are accepted for atlas upload.

The Cosmic provider loads platform emoji fallback font candidates when they are
available. For provider-fragile emoji diagnostics, it safe-maps representative
single-codepoint, variation-selector, and ZWJ samples to equal-length layout
text before shaping, so measurement and native run-layout responses keep
monotonic caret coverage without claiming full emoji shaping parity.

## Web Wasm-GC

The Web path stays on `wasm-gc + window/web + browser WebGPU host imports`.
`backend/web` installs a browser Canvas-backed `TextSystem` and the WebGPU
runtime draws text through a DPR-aware canvas-rasterized glyph atlas. Measurement
and drawing use the same CSS `system-ui` stack generated from `FontSpec`.

The browser runtime assets live under `backend/web/*.js`; Web example packages
should only supply app-specific entrypoints, wasm URLs, canvas hosts, and UI
callbacks.

## Embedded Fonts

Apps can register embedded font bytes through `AppRuntime::register_font_data`.
Native WGPU forwards those bytes to the active provider and, when present, the
composed fallback provider. CoreText v1 attempts process-local registration
under the requested family alias. Future DirectWrite and
fontconfig/HarfBuzz/FreeType implementations should use the same hook for
private font collections.

Remote font loading is intentionally outside the current backend contract.

## Current Gaps

- Full bidi, line breaking, typography conformance, native emoji font fallback,
  ZWJ/color emoji conformance, and full grapheme-cluster parity remain follow-up
  work. Native WGPU can preserve RGBA color glyph payloads through the provider
  protocol and glyph atlas path, with Cosmic platform emoji fallback candidate
  loading, Cosmic color swash preservation, provider-safe emoji layout mapping,
  and a CoreText AppleColorEmoji RGBA path covered by focused tests. Stable and
  diagnostic tests assert caret counts, monotonicity, clamping, editor selection
  behavior, IME anchor geometry, and provider fallback safety across mixed bidi, CJK,
  single-codepoint emoji, variation-selector emoji, and ZWJ emoji samples;
  Cosmic run-layout tests additionally assert glyph output plus caret coverage
  through the safe-mapped layout path. They do not claim full Unicode shaping parity.
- Focused text inputs expose MoUI's default copy, cut, paste, undo, redo, and
  select-all commands through host context menus, so keyboard shortcuts and
  native menu selections share the same selection, clipboard, and Unicode paste
  dispatch path.
- Windows and Linux native platform providers are scaffolds; composed Cosmic
  fallback handles real text until those engines are implemented.
- Web can surface browser emoji and font fallback behavior, while stable Web
  adapter tests keep the host-backed `TextSystem` contract deterministic.
- Text changes that affect renderer feature status must update
  `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
  `docs/renderer-capability-report.md`.

## Validation

Text conformance is split into two layers:

- Stable tests run inside normal package checks and cover `core`,
  `render/wgpu`, `render/webgpu_adapter`, and `backend/web`.
- Diagnostic matrix tests live under `tests/text_conformance/` and are opt-in.
  They compare core fallback, Cosmic, platform-default composed fallback,
  malformed-provider fallback, and Web text systems where the current host can
  actually exercise them. Strict failures stay limited to contract invariants;
  width/baseline differences across engines are diagnostic unless the contract
  says otherwise.

Focused checks for text-system work:

```sh
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
moon test core --target native
moon test render/wgpu --target native
moon test render/webgpu_adapter --target wasm-gc
moon test backend/web --target wasm-gc
```

Platform text provider changes should also run the affected backend/provider
tests. Public API changes require `moon info` and review of generated
`pkg.generated.mbti` diffs.
