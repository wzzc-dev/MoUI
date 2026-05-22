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
sh scripts/preview-loop.sh --package examples/counter/web_wasm --watch
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
`moon build examples/todo/macos --target native` link platform stubs and
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
moon build examples/todo/web_wasm --target wasm-gc
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon test --target native
moon build examples/todo/macos --target native
moon build examples/counter/macos --target native
moon build examples/showcase/macos --target native
moon build examples/markdown_editor/macos --target native
moon build examples/todo/windows --target native
moon build examples/counter/windows --target native
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
  measurer for headless tests and platforms without a real text engine, macOS
  native WGPU installs a CoreText-backed platform text engine, and Web installs
  a browser Canvas-backed measurer that uses the same `system-ui` stack as
  WebGPU text drawing. Windows and Linux are expected to add DirectWrite and
  fontconfig/HarfBuzz/FreeType engines behind the same renderer/runtime boundary
  while falling back to Cosmic until those engines exist. Apps can register
  embedded font bytes through
  `AppRuntime::register_font_data`; remote font loading is intentionally out of
  scope.
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
