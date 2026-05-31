# Examples

MoUI examples are runnable documentation. Showcase is the visual catalog and
now follows the same TEA shape as ordinary apps: `Model / Msg / update / view`
driven by `Program::simple_with_environment`. It still contains the Counter and
Todo interaction patterns. The WYSIWYG Markdown editor stays separate because
it demonstrates a larger editing workflow with its own model and parser tests.
Showcase surfaces renderer capability follow-ups first so visible docs do not
hide partial or gap status behind ready features.

Use the [Non-render component cookbook](non-render-component-cookbook.md) when
you want to copy a pattern rather than inspect a full example package. It maps
forms, tables, shells, menus, host services, and virtual lists to the examples
that exercise them.

Use [App templates](app-templates.md) when starting a new shared app package.
The templates cover counter, dashboard, and document-editor skeletons without
introducing a generator.

| Example | Purpose | Shared app package | Main coverage |
| --- | --- | --- | --- |
| Counter | Minimal model/update/view app | `examples/counter/app/` | Simple `Program::simple` flow, `center`/`card`, typed button messages |
| Showcase | Full view catalog and reusable example index | `examples/showcase/app/` | TEA-first `Model / Msg / update / view` app, public `views` constructors, built-in Counter/Todo patterns, light Markdown preview, theme, presentation, renderer capability status, advanced rendering demos, text diagnostics, interaction wiring |
| Settings | Settings shell pattern | `examples/settings/app/` | Form sections, sidebar navigation, segmented theme mode, toggle preferences, saveable state snapshot/restore |
| Data Table | Operational data browser pattern | `examples/data_table/app/` | Table, tree filters, search, loading/error/empty states, selected row summary, model-level sort and pagination |
| File Importer | File import workflow pattern | `examples/file_importer/app/` | Drop zone, file dialog facade, unavailable service state, pending completion handling, selected file list |
| Command Palette | Command metadata and menu pattern | `examples/command_palette/app/` | Command palette rows, shortcut labels, enabled/disabled dispatch, command menu, context menu fallback |
| Markdown Editor | Typora-style editing prototype | `examples/markdown_editor/app/` | Editor snapshot core, `mizchi/markdown` parsing, source-range mapping, primary rich text editor, optional source preview |
| Mo Workbench | Pi agent desktop dogfood app | `examples/mo_workbench/app/` | Conversation-first coding-agent shell, platform-neutral Pi transport command/event model, Workbench-to-Pi session binding, RPC message transcript refresh, RPC command catalog and session stats refresh, thinking-level control, RPC bash command evidence, RPC response plus streaming agent/tool event ingestion, command/file/diff transcript evidence, stderr/nonzero-exit diagnostics, macOS Skia native entrypoint |

## Counter

Counter is the smallest recommended app shape. It keeps user code in
`Model / Msg / update / view`, then lets `Program::simple` connect that pure
model loop to the runtime. It has Web, macOS, Windows, Linux, and
`windows_cosmic` entrypoints, so it is also the quickest way to verify a thin
platform package without the full Showcase surface:

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

Focused Counter checks:

```sh
moon test examples/counter/app --target native
moon build examples/counter/web_wasm --target wasm-gc
```

Showcase is organized around the main catalog order:
`Overview -> Text & Media -> Controls -> Forms -> Data -> Layout -> Navigation
Shell -> Feedback -> Runtime/Renderer -> Diagnostics`. The first eight sections
cover user-facing components and layout patterns. `Runtime/Renderer` displays
host capability and renderer status cards. `Diagnostics` shows a compact
inspector snapshot with runtime, view, layout, semantics, render command, and
render-scope counters, then links to the deeper diagnostic routes for
interaction wiring, text diagnostics, advanced rendering, and reusable examples
without crowding the main sidebar.

The hidden diagnostic routes remain directly addressable for focused tests and
development workflows:

- `Advanced Rendering`: app-local `custom_layout` demos for layer/blend,
  filter, shader effect, path, transform, and opacity draw commands.
- `Text Diagnostics`: CJK mixed text, RTL/bidi samples, emoji status labels,
  fixed-width wrapping, a narrow `TextRun.frame` clipping sample, and a compact
  Markdown/rich text diagnostic.
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

## Data Table

The Data Table example is also shared-app only. It models the data workflow that
operational tools usually need before renderer-specific polish: controlled tree
filters, text search, stable model-level sorting, page navigation, selected-row
summary, plus empty/loading/error panels built from public `views` constructors.

## File Importer

The File Importer example demonstrates the non-render file workflow surface. The
view uses `drop_zone` and `file_import_panel`; the pure model accepts dropped
paths, while the effect-capable runtime uses `Program::new` and
`Effect::dispatch` to request an app-level host file dialog through
`HostAppServices` and feed unavailable, immediate, or pending responses back as
typed `HostCompleted` messages. Pending file-dialog responses register
`HostAppServices::on_completed`, so the later host completion dispatches through
the same typed TEA update path as synchronous responses. Its app tests also
compose the importer as a child feature with `View::map` and `Effect::map`,
which is the recommended pattern when a parent TEA model owns a child workflow
that can still return follow-up effects. Browser hosts commonly expose file
names while native hosts can expose filesystem paths, so production apps should
treat these strings as host-provided display or import handles rather than
assuming one platform shape.

## Command Palette

The Command Palette example keeps command definitions in `ActionCommand`
metadata, renders them through the public palette and command menu views, and
uses `ActionCommandMap` for shortcut dispatch. Disabled commands stay visible
for discoverability but do not dispatch through model actions or runtime command
bindings.

## Mo Workbench

Mo Workbench is the real product-shaped dogfood app for the native Skia route.
It is named `Mo Workbench` with the subtitle `A Pi agent desktop`, and starts as
a Codex / Claude Code-style coding-agent workbench for project sessions,
assistant transcripts, command evidence, diff/file context, and diagnostics.
Its current UI keeps the first screen focused on live session state,
transcript, Pi command catalog, command evidence, context files, and diff
status instead of long placeholder validation text or hard-coded attachment
cards.
The shared app package keeps the Pi boundary as platform-neutral
`PiTransportCommand` and `PiTransportEvent` values so future Web or
automation-focused workflows can reuse the same event model. Structured Pi
JSONL payloads such as command starts/completions, diagnostics, file context,
and diff summaries are ingested inside the shared app model rather than the
native process driver. The native transport also exposes a
`PiNativeTransportOwner` so the macOS Skia entrypoint can keep one
`pi --mode rpc` JSONL process alive across repeated app runtime dispatches
while the shared app remains platform-neutral. Native stderr is surfaced as a
platform-neutral warning event and nonzero process exits become
`TransportFailed` events with the exit code and last stderr line. Unexpected
child exits do not close the native owner; the next UI command batch restarts a
fresh JSONL process, while explicit `Shutdown` remains the close path. The
native encoder targets Pi's actual RPC command names: `get_state`, `prompt`,
`get_messages`, `get_commands`, `get_session_stats`, `cycle_thinking_level`,
`set_session_name`, `bash`, `abort_bash`, and `abort`, with process shutdown
handled by stdin EOF. The focused smoke for machines with Pi installed is an
offline `get_state` JSONL round trip, a `get_messages` transcript response, an
offline `get_commands` command-catalog response, a `get_session_stats` metrics
response, a `cycle_thinking_level` acknowledgement, a `set_session_name`
acknowledgement, and an `abort_bash` acknowledgement through `pi --mode rpc`, so
it validates the process protocol without making a model request. The shared app
ingests
successful and failed Pi RPC `response` JSONL objects: `get_state` refreshes
the current Workbench session snapshot, `get_messages` refreshes the transcript
model, `get_commands` refreshes the available slash/prompt/extension/skill
command catalog, and `get_session_stats` refreshes compact
message/tool/token/context metrics. `cycle_thinking_level` responses and
`thinking_level_changed` events keep the compact Thinking control and
`PiAgentSnapshot` aligned. `set_session_name` responses and
`session_info_changed` events keep the Workbench-to-Pi session binding display
name in sync, while RPC failures become diagnostics without leaking native
process details into the app model.
Workbench command queue actions now dispatch platform-neutral shell commands
that the native encoder maps to Pi RPC `bash`, and successful `bash` responses
mark command evidence as passed, failed, or cancelled inside the shared model.
Cancelling while such a shell command is active now maps to Pi RPC `abort_bash`;
prompt/agent cancellation still maps to Pi RPC `abort`.
The shared app also ingests Pi's streaming session events such as
`agent_start`, `message_update`, `tool_execution_start`,
`tool_execution_end`, `queue_update`, thinking-level changes, compaction, and
auto-retry updates. These refresh a `PiAgentSnapshot`, selected-session status,
timeline events, and command evidence while leaving the native transport as a
JSONL process driver.
Workbench sessions can now carry a Pi `sessionPath`; selecting one through an
injected transport sends `switch_session` followed by `get_state`,
`get_messages`, `get_commands`, and `get_session_stats`, then records a
`PiSessionBinding` from the Workbench sidebar id to Pi's concrete session id,
file/name, model, and binding status while stats refresh the status metrics.

The first native entrypoint is macOS Skia:

```sh
moon test examples/mo_workbench/app --target native
moon test examples/mo_workbench/app --target wasm-gc
moon test examples/mo_workbench/native_transport --target native
moon test moui/backend/macos --target native
moon build examples/mo_workbench/macos_skia --target native
printf '{"type":"get_state"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_messages"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_commands"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_session_stats"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"cycle_thinking_level"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_session_name","name":"Mo Workbench smoke"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"abort_bash"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
```

See [Mo Workbench](mo-workbench.md) for the app architecture, current slice,
and transport follow-up notes.

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

macOS examples use the shared app package plus the macOS host core and renderer
provider packages. The default and Cosmic entrypoints import
`backend/macos/wgpu`; `macos_skia` imports `backend/macos/skia`:

```sh
moon build examples/showcase/macos --target native
moon build examples/showcase/macos_cosmic --target native
moon build examples/showcase/macos_skia --target native
moon build examples/markdown_editor/macos --target native
moon build examples/markdown_editor/macos_skia --target native
moon build examples/mo_workbench/macos_skia --target native
```

The `macos_skia` entrypoints select the native Skia raster renderer explicitly.
They require the local Skia native link setup that makes `skia_mbt/native`
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

Windows native examples use the MSVC toolchain, vcpkg `zlib:x64-windows`, and
`wgpu_mbt` dynamic mode with the official MSVC `wgpu_native.dll` release. The
default and Cosmic entrypoints import `backend/windows/wgpu`; `windows_skia`
imports `backend/windows/skia` and selects the native Skia raster provider
explicitly.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_cosmic `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows_cosmic `
  -BuildOnly
```

To run an entrypoint directly, import the MSVC environment in the same
PowerShell process:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows --target native }"
```

`windows_skia` follows the same Skia availability rules as the backend provider:
if `skia_mbt/native` is only in fallback mode, renderer creation reports a
diagnostic instead of opening an empty HWND.

For a reusable distributable folder with the built executable and runtime DLLs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

The package is written under `dist\windows-msvc\MoUIShowcase` and includes a
schema version 1 `moui-package.json`, `run.cmd`, `wgpu_native.dll`, WGPU release
metadata, and the vcpkg zlib runtime DLL. Launch the packaged app through
`run.cmd` so `MBT_WGPU_NATIVE_ROOT` points at the bundled WGPU release.

## Linux Native

Linux examples use the local fork-owned `window/linux` Wayland host core. The
default and `linux_cosmic` Showcase entrypoints use the `backend/linux/wgpu`
renderer provider; `linux_skia` uses `backend/linux/skia` and presents Skia CPU
pixel frames through the Wayland `wl_shm` path. Run them on a configured Linux
host with a Wayland compositor and renderer stack:

```sh
moon run examples/showcase/linux --target native
moon run examples/showcase/linux_cosmic --target native
moon run examples/showcase/linux_skia --target native
```

For build-only validation, use:

```sh
moon build examples/showcase/linux --target native
moon build examples/showcase/linux_cosmic --target native
moon build examples/showcase/linux_skia --target native
```

The `linux_cosmic` entrypoint selects the shared Moon Cosmic text provider
explicitly. The platform-default Linux entrypoint composes the fontconfig
provider scaffold with the same Cosmic fallback. The `linux_skia` entrypoint
selects the native Skia raster renderer explicitly; configure real Skia link
flags before relying on Skia-rendered pixels.

## Example Validation

Use package-level tests for shared app logic and Web builds for browser entry
points:

```sh
moon test examples/showcase/app --target native
moon test examples/counter/app --target native
moon test examples/settings/app --target native
moon test examples/data_table/app --target native
moon test examples/file_importer/app --target native
moon test examples/command_palette/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Before changing platform entrypoints, include the affected host package tests and
current-platform example builds.
