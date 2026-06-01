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
| Mo Workbench | Pi agent desktop dogfood app | `examples/mo_workbench/app/` | Conversation-first coding-agent shell, lightweight agent focus routing, composer slash-command shortcuts, wide workflow rail for progress/agents/work folder evidence, platform-neutral Pi transport command/event model, Workbench-to-Pi session binding, manual RPC session refresh, fresh Pi session creation, RPC model/message transcript refresh, explicit model selection, fork candidate discovery and fork refresh, HTML export evidence, manual context compaction, RPC command catalog invocation and session stats refresh, thinking-level and input queue mode controls, RPC bash command evidence, RPC response plus streaming agent/tool/plan event ingestion, command/file/diff/plan transcript evidence, stderr/nonzero-exit diagnostics, macOS Skia native entrypoint |

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
It is named `Mo Workbench` with the subtitle `Pi agent 桌面工作台`, and starts as
a Codex / Claude Code-style coding-agent workbench for project sessions,
assistant transcripts, command evidence, diff/file context, and diagnostics.
Its current UI keeps the first screen focused on the current session row,
scrollable transcript blocks, compact activity/workspace evidence, and a
centered floating composer instead of long placeholder validation text,
future-workflow filler, or hard-coded attachment cards. The shell now derives
its sidebar, main canvas, scroll area, and composer dimensions from the runtime
viewport instead of a fixed `1200x750` surface, so the macOS Skia entrypoint can
be resized while preserving the session-first hierarchy, including narrower
panel/composer widths in smaller windows. The transcript uses multi-line
message blocks for long Pi replies and draws an explicit scrollbar when the
main workflow overflows. Primary section labels are quieter and consistently
Chinese (`当前会话`, `Pi 运行状态`, `会话记录`, `运行证据`, `工作区证据`), with Pi/RPC
left as protocol nouns. Secondary session controls now use quieter visual
treatment than the primary refresh/new-session actions. The workspace digest now
includes file, diff, and latest
diagnostic state with a short clear action so stderr/RPC/bash failures remain
visible without adding a separate diagnostics page. When actionable evidence is
present, the current session panel derives one quiet `下一步` row that points
to the next shared-app action, prioritizing cancelable Pi work, diagnostics,
failed command evidence, active plan steps, reviewable diffs, files, transcript
rows, command catalog entries, and activity events. Pi `plan_update` JSONL also
feeds a compact `当前计划` row so the visible session state includes current
planning evidence without opening a separate pane. The default fixture no
longer injects mock transcript, sample stats, command catalog rows, file rows,
diff rows, command runs, diagnostic prose, or sample active-task copy. Zero
queues, unbound Pi state, idle transport/agent state, and empty digest actions
stay visually quiet; transcript/activity/workspace panels shrink to their
headers until Pi or command evidence arrives.
On wide windows, the shell now mirrors the three-column desktop shape more
closely with a right workflow rail for live progress, agents, and work-folder
evidence. The rail reuses `PlanStep`, `AgentEvent`, session, and `FileContext`
state from the shared app model, and collapses on compact widths so the
conversation flow remains primary.
Transcript rows can queue a `Follow up on <role> transcript: ...` prompt through
the shared prompt transport, turning visible Pi conversation evidence into the
next agent task. The sidebar exposes lightweight `通用`, `编码`, and `校验`
agent focus controls; selecting one only appends an `agent focus: ...` hint to
the existing platform-neutral prompt, steering, and follow-up text payloads.
The composer exposes repository, examples, evidence, and Pi session context
chips; direct prompt, steering, and follow-up submits prefix the selected scopes
into the same platform-neutral text payloads, while turning all chips off sends
the raw input. Activity timeline rows can queue a
`Follow up on <phase> activity: ...` prompt the same way, so visible Pi RPC,
stderr, tool, and stream events can become the next agent action. File context
rows can queue an `Inspect <path>` prompt through the same platform-neutral
prompt transport, turning Pi-provided file evidence into the next coding-agent
action. The diff summary review button likewise queues a concise
`Review diff: ...` prompt, so code review starts from shared app state rather
than a native-only shortcut.
Latest diagnostic rows can queue a `Fix <severity> diagnostic from <source>: ...`
prompt through the same `SendUserInput` path, turning build/check failures into
the next agent task without adding a transport-specific command.
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
native encoder targets Pi's actual RPC command names: `get_state`,
`new_session`, `prompt`, `steer`, `follow_up`, `get_available_models`, `get_messages`,
`get_fork_messages`, `fork`, `get_commands`, `get_session_stats`,
`export_html`, `set_model`, `cycle_model`, `compact`, `cycle_thinking_level`,
`set_steering_mode`, `set_follow_up_mode`, `set_session_name`, `bash`,
`abort_bash`, and `abort`, with process shutdown handled by stdin EOF. The
focused smoke for machines with Pi installed is an
offline `get_state` JSONL round trip, a `new_session` acknowledgement, a
`get_messages` transcript response, an offline `get_available_models` model
catalog response, an offline `get_commands` command-catalog response, an
offline `get_fork_messages` response, a `get_session_stats` metrics response,
the expected in-memory `export_html` failure boundary, a
`set_model` no-matching-model failure boundary, a
`cycle_model` no-alternate-model acknowledgement, a
`compact` offline failure boundary, a
`cycle_thinking_level` acknowledgement,
steering/follow-up mode acknowledgements, a `set_session_name`
acknowledgement, steering/follow-up input acknowledgements, and an `abort_bash`
acknowledgement through `pi --mode rpc`,
so it validates the process protocol without requiring a successful model call.
The shared
app ingests
successful and failed Pi RPC `response` JSONL objects: `get_state` refreshes
the current Workbench session snapshot, `get_messages` refreshes the transcript
model, `get_available_models` refreshes the compact model catalog,
`get_fork_messages` refreshes forkable user-message entry ids, `get_commands`
refreshes the available slash/prompt/extension/skill command catalog, and
`get_session_stats` refreshes compact message/tool/token/context metrics.
`export_html` success responses add the returned path as Workspace file
evidence, so exported sessions can become handoff, documentation, or knowledge
artifacts without native-only state. Catalog rows can run a command by sending
`/<name>` through the same platform-neutral `SendUserInput` prompt path, so
native transport does not need a command-specific bridge. When command catalog
entries are available, the composer also shows up to three slash-command
shortcuts that reuse the same `InvokeCommand` / `SendUserInput` route as the
Activity digest command row. Diagnostics collected from Pi stderr, RPC
failures, structured diagnostic events, and bash results are
surfaced in the workspace digest and can be cleared from shared app state.
The model catalog summary can send platform-neutral `SetRpcModel` for the
visible model and `CycleRpcModel` for Pi's scoped model cycle; successful
`set_model` and `cycle_model` responses update the active binding model when Pi
returns one, while `cycle_model` `data:null` is treated as a no-op
acknowledgement.
The session panel can send platform-neutral `CompactRpcSession`; successful
`compact` responses append the returned summary to the transcript and update
the active session summary, while offline/no-provider failures remain Pi RPC
diagnostics.
`cycle_thinking_level` responses and `thinking_level_changed` events keep the
compact `思考` control and
`PiAgentSnapshot` aligned. `set_steering_mode` and `set_follow_up_mode`
responses acknowledge the compact composer controls, while `get_state` refreshes
the source-of-truth modes from Pi. The composer can also send explicit
platform-neutral steering and follow-up inputs that the native encoder maps to
Pi RPC `steer` and `follow_up`. `set_session_name` responses and
`session_info_changed` events keep the Workbench-to-Pi session binding display
name in sync, while RPC failures become diagnostics without leaking native
process details into the app model.
Workbench command queue actions now dispatch platform-neutral shell commands
that the native encoder maps to Pi RPC `bash`, and successful `bash` responses
mark command evidence as passed, failed, or cancelled inside the shared model
while preserving Pi's optional `fullOutputPath` as command evidence. Activity
rows display that output path when present, so long/truncated command output can
stay discoverable without native-only state. Activity command rows can now queue
an `Inspect command output for ...` prompt from the latest command status, cwd,
and output path, turning bash evidence into the next Pi task through
`SendUserInput`. The Activity digest keeps up to three recent command evidence
rows visible, so the focused-check batch can be inspected as a group without a
separate log page.
The Activity digest can rerun a visible command evidence row through the same
`QueueCommand` / `RunShellCommand` path, so common coding-agent checks can be
replayed without introducing a native-only shortcut.
It also exposes focused-check presets for the app native test, app wasm-gc test,
and macOS Skia build. Each preset uses the same `QueueCommand` /
`RunShellCommand` path, so checks started from the UI become normal Pi bash
evidence. The `全部` action batches all three focused checks through one
platform-neutral queue operation while preserving separate `CommandRun`
evidence rows in that recent-command digest.
It also surfaces the latest Pi/agent timeline event from shared app state, so
streaming transport, tool, and RPC progress is visible next to command evidence
without adding a separate log view.
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
`get_available_models`, `get_messages`, `get_fork_messages`, `get_commands`,
and `get_session_stats`, then records a `PiSessionBinding` from the Workbench
sidebar id to Pi's concrete session id, file/name, model, and binding status
while models and stats refresh the compact status panel.
The session panel now surfaces that binding directly with a compact Pi status
row, so a coding-agent run can show the live Pi session name/id and model
without opening a separate diagnostics view.
The current session can also be refreshed manually from the session panel using
the same platform-neutral command batch, so the native UI can resync Pi state,
model catalog, transcript, fork affordances, command catalog, and stats without
changing selection.
The session panel also includes a fresh-session control. It queues
`NewRpcSession` first; after the `new_session` success response arrives,
`ReceiveTransport` queues the state, model catalog, messages, fork candidates,
commands, and stats refresh through the same platform-neutral transport model.
The native encoder emits `{"type":"new_session"}`, and the chained `get_state`
response becomes the source of truth for the new Pi `sessionId` and session file.
This two-stage flow avoids relying on Pi's response order when multiple
JSONL requests are batched. The session panel also discovers forkable
user-message entry ids with `get_fork_messages`; selecting a visible fork
candidate sends `{"type":"fork","entryId":...}` and, after an uncancelled
acknowledgement, queues the same second-stage refresh before rebinding from
Pi's next `get_state` response.
The session panel also has an HTML export action. It sends Pi RPC
`export_html`, and a successful response appears as file evidence in the
Workspace digest.

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
printf '{"type":"new_session"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_messages"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_available_models"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_fork_messages"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_commands"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_session_stats"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"export_html","outputPath":"/tmp/mo-workbench-export-smoke.html"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_model","provider":"openai","modelId":"gpt-5"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"cycle_model"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"compact"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"cycle_thinking_level"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_steering_mode","mode":"all"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_follow_up_mode","mode":"one-at-a-time"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"steer","message":"Prefer narrow edits"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"follow_up","message":"Update docs"}\n' | \
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
