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
- `views/` exposes public view constructors that return `@core.ViewSpec`.
- `backend/host/` and `backend/common/` define shared host event, surface, and
  input contracts.
- `backend/macos/`, `backend/windows/`, and `backend/web/` normalize platform
  events into `HostEvent`. `backend/linux/` is an explicit scaffold.
- `render/` is the renderer facade and shared reporting layer.
- `render/wgpu/` is the native wgpu renderer. `render/webgpu/` is the wasm-gc
  browser WebGPU host-import bridge.
- `examples/*/app/` packages are shared app logic. Platform subpackages are
  entrypoints only.

## Local Dependencies

The project expects the modified local `Milky2018/window` checkout at
`.local_repos/window`, as described in `README.md`. Local `moon.mod.json` and
`moon.pkg` files are the source of truth for imports and supported targets.

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
example builds for daily work. Use `sh scripts/dev-check.sh --platform-examples`
when you explicitly need current-platform native examples too.

Useful focused checks:

```sh
moon check
moon check --warn-list +unnecessary_annotation
moon test core --target native
moon test views --target native
moon test render/webgpu --target wasm-gc
moon test backend/web --target wasm-gc
moon build examples/counter/web_wasm --target wasm-gc
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

## Editing Notes

- Preserve the `///|` delimiter style in MoonBit files.
- Keep public API additions intentional and covered by tests.
- Put new tests in focused `*_test.mbt` files inside the package being changed.
- Do not remove generated `pkg.generated.mbti` files.
- Do not run platform entrypoint tests through the generic wasm-gc runner when
  they require browser host imports.
