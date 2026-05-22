# Development

This page collects local setup, example run commands, and validation guidance
for MoUI development.

## Local Dependencies

The upstream `Milky2018/window` package does not currently cover the targets
MoUI needs, so use the modified local checkout instead.

From the repository root:

```sh
sh scripts/setup-local-deps.sh
sh scripts/check-local-deps.sh
```

This keeps `Milky2018/window` resolved through the local path override in
`moon.mod.json`:

```json
"Milky2018/window": {
  "path": ".local_repos/window"
}
```

The checkout is intentionally a normal editable Git repository, not a submodule.
MoUI uses the `wzzc-dev/window` fork on the `moui-support` branch because the
current upstream package is macOS-only.

- Upstream: `https://github.com/moonbit-community/window.git`
- MoUI fork: `git@github.com:wzzc-dev/window.git`
- Fork branch: `moui-support`

`scripts/setup-local-deps.sh` configures the fork as `origin` and upstream as
`upstream`. When merging new upstream commits into the fork, fetch `upstream`
inside `.local_repos/window` and merge into `moui-support`. Keep fork changes
focused on the Web, Windows, and Linux platform packages when possible. Avoid
touching macOS or shared window logic unless a task explicitly requires that
broader change.

## Validation

For routine local development, prefer the bounded daily check:

```sh
sh scripts/dev-check.sh
```

It runs stable package-level tests, native renderer contract tests, and Web
wasm-gc example builds without invoking all-repository native or wasm-gc test
targets.

## Preview Loop

Use the lightweight preview loop when iterating on Showcase or another Web
wasm-gc example:

```sh
sh scripts/preview-loop.sh
sh scripts/preview-loop.sh --watch
sh scripts/preview-loop.sh --package examples/markdown_editor/web_wasm --watch
```

The loop rebuilds the selected package with `moon build` and watches MoonBit,
docs, and browser asset inputs by modification time. It is intentionally a
hot-reload-like developer loop rather than VM state preservation: app state is
rebuilt with the package, while the command gives fast feedback and keeps the
preview target explicit.

Implementation skeletons live in `docs/tutorials.md`, and reusable package,
host-service, renderer, and Showcase checklists live in `docs/templates.md`.

Current-platform backend tests can be included without native example builds:

```sh
sh scripts/dev-check.sh --platform-examples-test
```

Native platform example builds such as
`moon build examples/showcase/macos --target native` link platform stubs and
`wgpu-native`, so cold builds can be slow. Include them only when validating
the current host platform's executable examples:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

Useful focused commands:

```sh
moon test render/wgpu --target native
moon test render/webgpu_adapter --target wasm-gc
moon test tests/tooling --target native
moon test backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon test --target native
moon build examples/showcase/macos --target native
moon build examples/markdown_editor/macos --target native
moon build examples/markdown_editor/windows --target native
```

## Mooncakes Integration Notes

MoUI keeps production runtime boundaries explicit when using Mooncakes
frontends and tooling:

- `Milky2018/moon_cosmic` is the default `core` text measurement fallback.
  `FontSpec` carries a structured family stack rather than a raw family string.
  The default stack is just `SystemUi`; MoUI does not name concrete fonts unless
  the app asks for them. Native and Web backends resolve that through their
  platform system defaults.
  Runtime text measurement is injectable: `core` keeps Cosmic as the fallback
  measurer for headless tests and platforms without a real text engine,
  `render/wgpu` exposes the native provider hook, `render/wgpu/cosmic` exposes
  Moon Cosmic as a standalone native WGPU text provider, macOS installs the
  `render/wgpu/coretext` provider by default, Windows installs the
  `render/wgpu/directwrite` scaffold provider, Linux has the
  `render/wgpu/fontconfig` scaffold provider ready for a future host, and Web
  installs a browser Canvas-backed measurer that uses the same `system-ui` stack
  as WebGPU text drawing. The CoreText provider uses shared
  `render/wgpu/text_protocol` `FontSpec` payloads and measurement decoding,
  attempts named families from the structured family stack before falling back to
  system fonts, maps generic families such as `ui-monospace`, `serif`, and
  `emoji` to suitable macOS fonts, then CoreText glyph runs for glyph ids and
  positions before rasterizing into the shared atlas, while retaining a
  renderer-private glyph payload boundary; glyph payloads include the CoreText
  run's PostScript font identity so fallback font runs can be rasterized with
  the same font that shaped them. The DirectWrite and
  fontconfig/HarfBuzz/FreeType scaffolds use the same text protocol package for
  native UTF-32 input encoding, versioned `FontSpec` payloads that carry size,
  weight, style, and the structured family stack, private versioned measurement
  payload parsing, and a generic run-layout envelope that converts shaped glyph
  placements plus platform-private raster payloads into renderer glyph keys. The
  same protocol package also parses single-channel raster glyph bitmaps for
  providers that use the shared raster envelope, and it owns the versioned
  embedded-font registration payload encoder/decoder so platform providers do
  not need package-local ad hoc formats. Their native stubs return empty data
  until the real platform implementations are wired. The Windows and Linux
  providers intentionally fall back to Cosmic until their DirectWrite and
  fontconfig/HarfBuzz/FreeType engines are implemented. Apps can register
  embedded font bytes through
  `AppRuntime::register_font_data`; native WGPU forwards those bytes through the
  active text provider's `register_font_data` hook before keeping the Cosmic
  fallback cache warm. CoreText v1 consumes installed named families and attempts
  process-local registration of app-provided font bytes under the requested
  family alias; future DirectWrite and fontconfig/HarfBuzz/FreeType providers
  can use the same hook for private font collections. Remote font loading is
  intentionally out of scope.
  Native hosts can choose the text engine at startup through
  `run_app_with_options(..., options=MacosAppOptions::new(text_engine=NativeTextEngineSetting::MoonCosmic))`
  or the Windows equivalent. `MoonCosmic` selects the shared Cosmic provider;
  `PlatformDefault` selects the platform provider path.
  Native text providers should use `NativePlatformTextProvider::new` plus the
  `NativeGlyphPlacement::new`, `NativeTextLayout::new`, and
  `NativeRasterGlyph::new` constructors from `render/wgpu`. Provider payloads
  are opaque to the renderer, but glyph cache keys must include all
  raster-affecting inputs such as glyph identity, font size, style, weight, and
  scale. Measurement layouts must report valid metrics and monotonic caret
  positions covering the input text; render layouts must report valid metrics
  and glyph placements. Invalid layout or raster glyph data is rejected at the
  renderer boundary and falls back to Cosmic.
- `Milky2018/moon_accesskit` is the native accessibility tree representation
  used by `backend/host`; `@core.SemanticsNode` remains platform-neutral, and
  Web continues to use its ARIA adapter.
- `Milky2018/moon_taffy` is allowed in `core/` because layout is
  platform-neutral. MoUI maps ordinary flex/grid/list/stack placement through
  Taffy and keeps custom layout delegates, dirty marking, and render tree
  ownership in MoUI.
- `Milky2018/moon_zeno` powers renderer path tessellation from MoUI
  `DrawPath` / `PathSpec` values into triangle meshes. SVG parsing remains the
  importer frontend's job.
- `mizchi/markdown` powers the Markdown Editor parser adapter while preserving
  `markdown_to_rich_text(String) -> @core.RichTextDocument`.
- `mizchi/svg` powers `render.import_svg(String) -> SvgImportResult`, lowering
  parsed SVG scene graph nodes into MoUI `DrawCommand` values.
- `moonbitlang/quickcheck` and `mizchi/pixelmatch` are exercised from
  `tests/tooling/` for property and pixel-diff coverage.
