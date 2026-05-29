# Examples

MoUI examples are runnable documentation. Showcase is the visual catalog and
now follows the same TEA shape as ordinary apps: `Model / Msg / update / view`
driven by `Program::simple_with_environment`. It still contains the Counter and
Todo interaction patterns. The WYSIWYG Markdown editor stays separate because
it demonstrates a larger editing workflow with its own model and parser tests.
Showcase surfaces renderer capability follow-ups first so visible docs do not
hide partial or gap status behind ready features.

| Example | Purpose | Shared app package | Main coverage |
| --- | --- | --- | --- |
| Counter | Minimal model/update/view app | `examples/counter/app/` | Simple `Program::simple` flow, `center`/`card`, typed button messages |
| Showcase | Full view catalog and reusable example index | `examples/showcase/app/` | TEA-first `Model / Msg / update / view` app, public `views` constructors, built-in Counter/Todo patterns, light Markdown preview, theme, presentation, renderer capability status, advanced rendering demos, text diagnostics, interaction wiring |
| Settings | Settings shell pattern | `examples/settings/app/` | Form sections, sidebar navigation, segmented theme mode, toggle preferences, saveable state snapshot/restore |
| Markdown Editor | Typora-style editing prototype | `examples/markdown_editor/app/` | Editor snapshot core, `mizchi/markdown` parsing, source-range mapping, primary rich text editor, optional source preview |

## Counter

Counter is the smallest recommended app shape. It keeps user code in
`Model / Msg / update / view`, then lets `Program::simple` connect that pure
model loop to the runtime:

```moonbit
using @views {button, card, center, column, row, text}

pub struct Model {
  count : Int
}

pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
    Reset => { count: 0 }
  }
}

pub fn view(model : Model) -> @core.View[Msg] {
  center(
    card(
      column([
        text("MoUI Counter").title(),
        text("Count: \{model.count}").title(),
        row([
          button("-", on_click=Decrement),
          button("Reset", on_click=Reset),
          button("+", on_click=Increment),
        ]),
      ]),
    ),
  )
}
```

Showcase is organized around the main catalog order:
`Overview -> Text & Media -> Controls -> Forms -> Data -> Layout -> Navigation
Shell -> Feedback -> Runtime/Renderer -> Diagnostics`. The first eight sections
cover user-facing components and layout patterns. `Runtime/Renderer` displays
host capability and renderer status cards. `Diagnostics` links to the deeper
diagnostic routes for interaction wiring, text diagnostics, advanced rendering,
and reusable examples without crowding the main sidebar.

The hidden diagnostic routes remain directly addressable for focused tests and
development workflows:

- `Advanced Rendering`: app-local `custom_layout` demos for layer/blend,
  filter, shader effect, path, transform, and opacity draw commands.
- `Text Diagnostics`: CJK mixed text, RTL/bidi samples, emoji status labels,
  fixed-width wrapping, and a compact Markdown/rich text diagnostic.
- `Interaction Lab`: tooltip, file-drop modifier wiring, focus/shortcut
  affordances, button/text-field variants, and deterministic image lifecycle
  states.
- `Examples`: Counter and Todo reusable app patterns until the dedicated
  example apps cover those workflows.

The Markdown editor keeps Markdown source as the saved value while presenting a
formatted editor surface as the primary workflow. Source preview remains
available from the toolbar. See [Markdown Editor](markdown-editor.md) for the
editing model, source/visual mapping, contextual commands, and validation
guidance.

## Settings

The Settings example is a shared app package without platform entrypoints. It
shows the recommended non-render shell for account preferences: a public sidebar
constructor drives controlled section selection, form fields own validation
messages in the app model, segmented controls choose light/dark/system theme
mode, and `SaveableStateStore` snapshots restore the current settings without a
host service.

## Web Wasm-GC

Build any Web example from the repository root, then serve the repository with a
local static server:

```sh
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open the corresponding `examples/*/web_wasm/index.html` page from the local
server. The Web path uses `wasm-gc + window/web + browser WebGPU host imports`;
there is no JS-target fallback.

## macOS Native

macOS examples use the shared app package plus `backend/macos` and native
`render/wgpu` surface setup:

```sh
moon build examples/showcase/macos --target native
moon build examples/showcase/macos_cosmic --target native
moon build examples/showcase/macos_skia --target native
moon build examples/markdown_editor/macos --target native
```

The `macos_skia` entrypoint selects the native Skia raster renderer explicitly.
It requires the local Skia native link setup that makes `skia_mbt/native`
available at runtime.

After configuring real Skia link flags, run the opt-in real-Skia check to verify
both the binding smoke and MoUI renderer presenter pixels:

```sh
sh scripts/dev-check.sh --skia-real-smoke
```

On macOS, the helper below resolves the pinned JetBrains Skia binary provider,
temporarily wires the resulting include/library paths into `skia_mbt`, the MoUI
renderer smoke, and `macos_skia`, then runs the renderer pixel smoke and builds
the Showcase entrypoint:

```sh
scripts/macos-skia-renderer-smoke.sh
```

Pass `--enable-skshaper` when the selected Skia binary also provides the
SkShaper module libraries; the helper then verifies the MoUI renderer smoke ran
with the optional shaped-run path available.

For a fuller local smoke, pass `--run-showcase-smoke`. The helper then launches
the built `macos_skia` executable with a first-frame exit flag and verifies that
the Skia renderer presents a frame before the app exits:

```sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
```

Use `--skia-provider existing` when you already have a local Skia build:

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Run the generated executable under `_build/native/debug/build/...` for the
example you built. If `moon run` exposes linker issues, use the build-and-execute
flow described in `platform-notes.md`.

To wrap an example as a local `.app` bundle:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0
```

The bundle includes and validates a schema version 1
`Contents/Resources/moui-package.json` manifest so local packaging output can be
inspected without parsing `Info.plist`.

## Windows Native

Windows examples use MSYS2 UCRT64 and the static Windows GNU `wgpu-native`
release documented in `platform-notes.md`:

```sh
moon build examples/showcase/windows --target native
moon build examples/showcase/windows_cosmic --target native
moon build examples/markdown_editor/windows --target native
```

The Markdown editor can also use the helper script for the expected static
dependency layout:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\markdown_editor_windows_static.ps1 -BuildOnly
```

For a reusable distributable folder with the built executable and runtime DLLs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

The folder includes and validates a schema version 1 `moui-package.json` with
app, source MoonBit package, version, executable, and copied runtime DLL
metadata.

## Linux Native

Linux examples use the local fork-owned `window/linux` Wayland backend plus
native `render/wgpu` surface setup. Run them on a configured Linux host with a
Wayland compositor and Vulkan stack:

```sh
moon run examples/showcase/linux --target native
moon run examples/showcase/linux_cosmic --target native
```

For build-only validation, use:

```sh
moon build examples/showcase/linux --target native
moon build examples/showcase/linux_cosmic --target native
```

The `linux_cosmic` entrypoint selects the shared Moon Cosmic text provider
explicitly. The platform-default Linux entrypoint composes the fontconfig
provider scaffold with the same Cosmic fallback.

## Example Validation

Use package-level tests for shared app logic and Web builds for browser entry
points:

```sh
moon test examples/showcase/app --target native
moon test examples/settings/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Before changing platform entrypoints, include the affected host package tests and
current-platform example builds.
