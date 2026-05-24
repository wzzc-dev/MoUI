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

Local setup defaults to the SSH fork URL. CI defaults to the HTTPS fork URL so
GitHub Actions can clone the dependency without a deploy key. Set
`MOUI_WINDOW_REMOTE` when you need to force a specific fork URL.

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

## Native Packaging Helpers

The packaging helpers wrap already-supported native example packages into
platform-shaped output directories. They are intentionally thin wrappers around
`moon build` and do not replace release signing, notarization, installers, or
store packaging.

macOS `.app` bundle:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase
```

The bundle is written under `dist/macos/<name>.app` by default. Pass
`--no-build` to package an already-built executable from `_build/native`.

Windows distributable folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase
```

The folder is written under `dist\windows\<AppName>` by default and includes the
built executable plus the MSYS2 Vulkan and pthread runtime DLLs expected by the
current static `wgpu-native` setup.

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

- `Milky2018/moon_taffy` is allowed in `core/` because layout is
  platform-neutral. MoUI maps ordinary flex/grid/list/stack placement through
  Taffy and keeps custom layout delegates, dirty marking, and render tree
  ownership in MoUI.
- `Milky2018/moon_accesskit` is the native accessibility tree representation
  used by `backend/host`; `@core.SemanticsNode` remains platform-neutral, and
  Web continues to use its ARIA adapter.
- `Milky2018/moon_zeno` powers renderer path tessellation from MoUI
  `DrawPath` / `PathSpec` values into triangle meshes. SVG parsing remains the
  importer frontend's job.
- `mizchi/markdown` powers the Markdown Editor's package-local parser adapter
  and rich text mapping. See [Markdown Editor](markdown-editor.md) for the
  app-level editing model.
- `mizchi/svg` powers `render.import_svg(String) -> SvgImportResult`, lowering
  parsed SVG scene graph nodes into MoUI `DrawCommand` values.
- `moonbitlang/quickcheck` and `mizchi/pixelmatch` are exercised from
  `tests/tooling/` for property and pixel-diff coverage.

The text stack has its own maintenance page because it spans `core`,
`render/wgpu`, backend startup options, and browser host assets. See
[Text system](text-system.md) before changing `TextSystem`, native text
providers, embedded font registration, or Web text measurement.

## Guidance Maintenance

When a development change affects package layout, docs placement, validation
commands, platform setup, renderer capability status, example structure, or the
text system, also check `AGENTS.md` and the repo-local skills under `skills/`.
Update them in the same change when their instructions would otherwise become
stale.
