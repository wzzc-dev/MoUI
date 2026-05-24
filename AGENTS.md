# Project Agents.md Guide

This repository is a MoonBit multi-platform GUI framework prototype. Keep
changes small, package-local, and consistent with the existing spec-first
runtime.

The project is still in an early prototype stage. Backward compatibility is not
a requirement unless a task explicitly asks for it. Prefer clear, simple
architecture and direct API cleanup over compatibility shims, duplicate legacy
paths, or abstractions that only preserve old shapes.

## Project Shape

- `core/` owns the platform-neutral runtime, state, layout, input, semantics,
  and draw command model.
  It remains one MoonBit package; internal files are grouped by responsibility
  (`runtime_state`, `component_context`, `input_*`, `paint_*`, `rich_text_*`,
  etc.) rather than by additional package boundaries.
- `views/` exposes public view constructors that return `@core.ViewSpec`.
- `backend/host/` defines shared host event, surface, input, async
  host-service, window lifecycle, window scene resolution,
  per-window runtime slots, request/completion, and window event conversion
  contracts.
- `backend/macos/`, `backend/windows/`, and `backend/web/` normalize platform
  events into `HostEvent`. `backend/linux/` is an explicit scaffold.
- `render/` is the renderer facade and shared reporting layer.
- `render/wgpu/` is the native wgpu renderer. `render/webgpu_adapter/` is the
  wasm-gc browser WebGPU host-import bridge.
- Native text providers live in `render/wgpu/cosmic_text/`,
  `render/wgpu/coretext/`, `render/wgpu/directwrite/`,
  `render/wgpu/fontconfig/`, and the shared `render/wgpu/text_protocol/`
  package. `core/` owns only the neutral `TextSystem` contract.
- `examples/*/app/` packages are shared app logic. Platform subpackages are
  entrypoints only. Showcase also has `macos_cosmic` and `windows_cosmic`
  entrypoints for explicit Moon Cosmic text-provider comparison.

## Local Dependencies

The project expects the modified local `Milky2018/window` checkout at
`.local_repos/window`, as described in `docs/development.md`. Local
`moon.mod.json` and `moon.pkg` files are the source of truth for imports and
supported targets.

Use `sh scripts/setup-local-deps.sh` to create or repair the local checkout and
`sh scripts/check-local-deps.sh` to verify that it points at the
`wzzc-dev/window` fork on the `moui-support` branch. The upstream remote is
`https://github.com/moonbit-community/window.git`; the MoUI fork remote is
`git@github.com:wzzc-dev/window.git`.

`.local_repos/window` is an editable local dependency, not a vendored snapshot
or submodule. It exists because upstream `moonbit-community/window` currently
only covers macOS, while MoUI needs Web, Windows, and Linux support. Changes in
that checkout should stay limited to the `web/`, `windows/`, and `linux/`
platform packages and their package-local tests/docs when possible. Avoid
changing `macos/`, shared packages such as `core/` and `dpi/`, or common
behavior unless the task explicitly requires it; keeping the fork narrow makes
future upstreaming safer.

When asked to merge upstream `window` changes, work inside `.local_repos/window`
on `moui-support`, fetch `upstream`, and merge the upstream branch into the fork
branch. Preserve upstream macOS and shared behavior where possible; resolve
conflicts by keeping MoUI-specific additions scoped to Web, Windows, and Linux
unless the user explicitly approves broader fork changes.

## MoonBit Package Rules

MoonBit package boundaries are directories with `moon.pkg` files. File names do
not create modules or namespaces, and declarations in the same package can
refer to each other regardless of file. Imports use module/package paths such
as `wzzc-dev/moui/core`, never source file names.

Before adding new APIs or refactoring existing ones, discover local symbols with
the MoonBit IDE tools where practical:

```sh
moon ide doc <query>
moon ide outline <file>
moon ide peek-def <file>:<line>:<col>
moon ide find-references <file>:<line>:<col>
```

## Development Checks

Use the daily validation script for routine work:

```sh
sh scripts/dev-check.sh
```

This intentionally avoids all-repository `moon test --target native`,
`moon test --target wasm-gc`, and native platform example builds by default.
Those commands can pull in incompatible platform stubs, browser-only wasm-gc
host imports, or slow native links. Prefer package-level tests and Web wasm-gc
example builds for daily work. Use
`sh scripts/dev-check.sh --platform-examples-test` when you need
current-platform backend tests too. Use
`sh scripts/dev-check.sh --platform-examples-build` only when you explicitly
need slow current-platform native example builds.

Useful focused checks:

```sh
moon check
moon check --warn-list +unnecessary_annotation
moon test core --target native
moon test views --target native
moon test render/webgpu_adapter --target wasm-gc
moon test backend/web --target wasm-gc
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
moon build examples/showcase/web_wasm --target wasm-gc
node --check scripts/validate-package-manifest.mjs
```

Run `moon info` after public API changes and review generated
`pkg.generated.mbti` diffs.

For narrow validation, prefer package or file scoped tests:

```sh
moon test <dir-or-file> --target native
moon test <dir-or-file> --filter '<glob>'
```

If a change touches `render/wgpu/`, also run:

```sh
moon test render/wgpu --target native
```

## Renderer Capability Tracking

Renderer feature status is tracked in `render/capabilities.mbt` and summarized
in `docs/renderer-capability-report.md`. Update both the structured report and
tests when changing image, clip, opacity, transform, or other draw command
support.

## Documentation Updates

When development changes affect package layout, build commands, validation
commands, platform setup, renderer capabilities, or user-facing behavior, update
the relevant files under `docs/` in the same change. Keep `README.mbt.md` as a
short entry point and move detailed development guidance into
`docs/development.md`.

The project moves quickly, so guidance files are part of the maintenance
surface. When changes affect architecture, package boundaries, docs placement,
validation commands, platform behavior, examples, renderer capabilities, or the
text system, also check whether `AGENTS.md` and the repo-local skills under
`skills/` need updates. If they do not need edits, say they were checked and
left unchanged in the handoff.

Current focused docs:

- `docs/text-system.md` covers `TextSystem`, native provider composition,
  Web text measurement/drawing, embedded fonts, and shaping gaps.
- `docs/markdown-editor.md` covers the WYSIWYG Markdown Editor model,
  source/visual mapping, commands, platform entrypoints, and validation.

## Editing Notes

- Preserve the `///|` delimiter style in MoonBit files.
- Keep public API additions intentional and covered by tests.
- Put new tests in focused `*_test.mbt` files inside the package being changed.
- Do not remove generated `pkg.generated.mbti` files.
- Do not run platform entrypoint tests through the generic wasm-gc runner when
  they require browser host imports.
