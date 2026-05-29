# Development

This page collects local setup, example run commands, and validation guidance
for MoUI development.

## Local Dependencies

The upstream `Milky2018/window` package does not currently cover the targets
MoUI needs, so use the `wzzc-dev/window` fork checkout instead.
MoUI also uses `wzzc-dev/skia_mbt` as an editable local checkout while the Skia
renderer backend and binding surface evolve together.

From the repository root:

```sh
sh scripts/setup-local-deps.sh
sh scripts/check-local-deps.sh
```

This keeps `wzzc-dev/window` declared in `moon.mod` and resolved through the
local workspace member in `moon.work`:

```moonbit
import {
  "wzzc-dev/window@0.5.1",
  "wzzc-dev/skia_mbt@0.1.1",
}
```

```toml
members = [
  "./moui",
  "./.local_repos/window",
  "./.local_repos/skia_mbt",
  "./examples/counter",
  "./examples/showcase",
  "./examples/markdown_editor",
]
```

The checkout is intentionally a normal editable Git repository, not a submodule.
MoUI uses the `wzzc-dev/window` fork on the `moui-support` branch because the
current upstream package is macOS-only.

- Upstream: `https://github.com/moonbit-community/window.git`
- MoUI fork: `git@github.com:wzzc-dev/window.git`
- Fork branch: `moui-support`

The local `window` checkout must declare `name = wzzc-dev/window` in `moon.mod`
or `moon.mod.json`; otherwise MoUI imports resolve to the published package
rather than the editable fork. `scripts/check-local-deps.sh` verifies this
because the Linux Skia presenter lives behind the local `window/linux` API.

The Skia binding checkout is also editable:

- MoUI Skia binding repo: `git@github.com:wzzc-dev/skia_mbt.git`
- HTTPS fallback: `https://github.com/wzzc-dev/skia_mbt.git`
- Branch: `master`

Set `MOUI_SKIA_MBT_REMOTE` to override the clone URL. The default daily check
only validates fallback-safe Skia package tests. Use `--skia-real-smoke` after
configuring real Skia native link flags.

`scripts/setup-local-deps.sh` configures the fork as `origin` and upstream as
`upstream`. When merging new upstream commits into the fork, fetch `upstream`
inside `.local_repos/window` and merge into `moui-support`. Keep fork changes
focused on the Web, Windows, and Linux platform packages when possible. Avoid
touching macOS or shared window logic unless a task explicitly requires that
broader change.

When updating this repository, update all Git checkouts that participate in the
workspace, not just the root checkout. That includes the main MoUI repository,
Git submodules such as `.agents/skills/moonbit-skills`, and every editable
repository under `.local_repos/` such as `.local_repos/window`.

On Windows, use the repository update helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

That helper also creates or updates `.local_repos/window` on the `moui-support`
branch and `.local_repos/skia_mbt` on `master`.

Local setup defaults to the SSH fork URL. CI defaults to the HTTPS fork URL so
GitHub Actions can clone the dependency without a deploy key. Set
`MOUI_WINDOW_REMOTE` when you need to force a specific fork URL.

## Validation

For routine local development, prefer the bounded daily check:

```sh
sh scripts/dev-check.sh
```

It runs stable package-level tests, native renderer contract tests, fallback-safe
Skia checks, and Web wasm-gc example builds without invoking all-repository
native or wasm-gc test targets. Fallback-safe Skia checks prove API shape and
unavailable diagnostics; they do not mean a real Skia renderer is ready.

Run the real Skia native smoke only after configuring local Skia link flags:

```sh
sh scripts/dev-check.sh --skia-real-smoke
```

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
`moon build examples/showcase/macos --target native`,
`moon build examples/showcase/macos_skia --target native`, or
`moon build examples/showcase/linux --target native` link platform stubs and
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
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0 \
  --build-version 1
```

The bundle is written under `dist/macos/<name>.app` by default. Pass
`--no-build` to package an already-built executable from `_build/native`. The
bundle includes `Contents/Resources/moui-package.json` using schema version 1
with platform, output kind, app name, source MoonBit package, bundle id,
version, build number, executable, bundle name, and runtime file metadata. The
helper validates that manifest before reporting success.

Windows distributable folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase `
  -Version 0.1.0 `
  -BuildNumber 1
```

The folder is written under `dist\windows\<AppName>` by default and includes the
built executable plus the MSYS2 Vulkan and pthread runtime DLLs expected by the
current static `wgpu-native` setup. It also writes the same schema version 1
`moui-package.json` manifest with Windows platform metadata and copied runtime
file names, then validates that manifest before reporting success.

Manual manifest validation:

```sh
node scripts/validate-package-manifest.mjs \
  "dist/macos/MoUI Showcase.app/Contents/Resources/moui-package.json" \
  --platform macos
```

Useful focused commands:

```sh
moon test moui/render/wgpu --target native
moon test moui/render/skia --target native
moon test .local_repos/skia_mbt --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/tests/tooling --target native
moon test moui/backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon test --target native
moon build examples/showcase/macos --target native
moon build examples/showcase/macos_skia --target native
moon build examples/markdown_editor/macos --target native
moon build examples/markdown_editor/windows --target native
moon build examples/showcase/linux --target native
moon build examples/showcase/linux_cosmic --target native
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
