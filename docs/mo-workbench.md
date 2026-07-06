# Mo Workbench

Mo Workbench is a macOS Skia native-first, multi-workspace desktop agent shell
mirroring DeepSeek-GUI's workbench/entry model. The shell hosts a responsive
workspace rail, center work surface, topbar controls, optional right inspector,
and low-noise status bar. Code is the only interactive agent workspace today;
Write, Connect Phone, Scheduled Tasks, and Plugins render product-shaped static
surfaces so the information architecture is visible without claiming backend
behavior that is not wired yet.

## Package Shape

- `examples/mo_workbench/app` owns the shared TEA shell model, per-workspace
  sub-models, update routing, and view composition. It is portable
  (native + wasm-gc) and does not depend on any native-only LLM SDK. The
  backend is injected as an `AgentBackendRuntime` closure boundary, so the app
  package can be tested without a network. Its public surface is intentionally
  narrow: `program_with_backend`, `AgentBackendRuntime`, `AgentBackendFixture`,
  `AgentCommand`, `AgentEvent`, `ModelChoice`, `ThinkingChoice`, `TurnStatus`,
  `SessionSummary`, `WorkbenchModel`, `WorkbenchMsg`, and `MoWorkbenchApp`.
- `examples/mo_workbench/openseek_native_transport` is a native-only package
  that bridges `AgentCommand` / `AgentEvent` to the in-process OpenSeek agent
  (`run_turn_in_scope`, `SessionStore`, tool registry). It depends on the
  `openseek` git submodule (`https://github.com/moonbitlang/openseek`).
- `examples/mo_workbench/macos_skia` injects
  `openseek_native_transport::openseek_backend_from_env()` when
  `OPENAI_API_KEY` or `DEEPSEEK` is set (`OPENAI_BASE_URL` overrides the
  DeepSeek client URL); otherwise `AgentBackendRuntime::stub()`. Enable the
  submodule in the workspace with `sh scripts/openseek-dev-mode.sh on` (adds
  `./openseek` to `moon.work`).

## Workspace Architecture

The shell (`WorkbenchModel`) holds the active workspace enum + one sub-model
per workspace + shared chrome state (appearance) + the injected backend
runtime. Workspace-scoped messages are wrapped in `CodeMsg(...)` /
`SettingsMsg(...)` / `WriteMsg(...)` variants on `WorkbenchMsg`; the shell
routes each wrapper to the matching sub-update and lifts the sub-effect back
to `Effect[WorkbenchMsg]` via `Effect::map`. Sub-views are lifted to
`View[WorkbenchMsg]` via `View::map` in the shell view dispatcher.

### Workspaces

- **Code** (`CodeWorkspace`): the conversation-first coding-agent chat surface
  (sessions, messages, prompt, steering, model/thinking controls, streaming
  state). Owns `AgentBackendRuntime` dispatch + `AgentEvent` projection. This
  is where the Codex-style chat surface lives.
- **Write** (`WriteWorkspace`): static Markdown writing shell with document and
  assistant panels. It currently holds no state and does not save files,
  request completions, or call export services.
- **Settings** (`SettingsWorkspace`): agent runtime + chrome settings form
  (API key / base URL / approval policy / sandbox mode / working directory /
  font size). UI-only in this prototype; persistence is reserved for the
  future backend integration.
- **ConnectPhone / ScheduledTasks / Plugins** (reserved): product-shaped static
  shells for future IM/webhook automation, scheduled prompts, and Skills/MCP
  management. They route through `SwitchWorkspace(...)` but have no sub-model
  or sub-update yet.

### Message Routing

`WorkbenchMsg` variants:

- `SwitchWorkspace(Workspace)` — handled at the shell level; updates
  `active_workspace`. Workspace state is preserved across switches (each
  sub-model lives on the shell).
- `CodeMsg(CodeMsg)` — delegates to `CodeWorkspace::update(msg, backend)`;
  the returned `Effect[CodeMsg]` is lifted via `Effect::map(m => CodeMsg(m))`.
- `SettingsMsg(SettingsMsg)` — delegates to `SettingsWorkspace::update(msg)`;
  the returned `Effect[SettingsMsg]` is lifted via
  `Effect::map(m => SettingsMsg(m))`.
- `WriteMsg(WriteMsg)` — currently a no-op (`WriteWorkspace` is reserved).
- `ToggleAppearance` — handled at the shell level; cycles
  `System → Light → Dark → System`.

`CodeMsg` includes `ReceiveAgentEvent(AgentEvent)` so the code workspace owns
its backend dispatch + event projection end-to-end (the shell does not need
to know about agent events).

On startup, the shared app dispatches `FetchSessionList`. When the returned
session list is non-empty and no session is active yet, Code automatically
selects the first session and dispatches `SwitchSession` so the workbench
resumes an existing conversation instead of staying on a blank empty state.

## Backend Boundary

The app package stays LLM-agnostic through the `AgentBackendRuntime` closure:

```
UI side  -> Effect::run callback (sync) -> runtime.run(commands, emit)
backend  -> async worker -> emit(event) -> dispatch(map(event)) into UI queue
```

- `AgentCommand`: `SendTask`, `Steer`, `NewSession`, `SwitchSession`,
  `SetModel`, `SetThinking`, `FetchSessionList`, `Shutdown`.
- `AgentEvent`: `UserMessageAdded`, `AssistantMessageAdded`,
  `ToolResultAdded`, `RuntimeNoticeAdded`, `TurnTerminal`, `ProgressNotice`,
  `SessionRebuilt`, `SessionListed`, `ActiveSessionChanged`.

The `AgentBackendFixture` is a scripted backend for portable tests: it records
dispatched commands and replays a caller-supplied event sequence per command.

Backend injection only affects `CodeWorkspace::update` — Settings/Write do
not dispatch backend effects in this prototype.

## UI Layout

The shell view follows the DeepSeek-GUI macro grammar:

- **Left workspace rail**: 268px on wide desktop, 236px below 1120px, 188px
  below 760px. It contains icon+label workspace buttons for Code, Write,
  Connect Phone, Scheduled Tasks, and Plugins; Settings and Appearance live in
  the footer. The body changes with the active workspace: Code shows workspace
  policy and session history, Write shows writing spaces, Connect Phone shows
  channels, Scheduled Tasks shows queues, Plugins shows capability groups, and
  Settings summarizes current preferences.
- **Topbar**: 52px strip inside the center column. It shows active workspace
  identity and subtitle.
- **Center work surface**: Code renders the message timeline, starter cards,
  evidence-colored message rows, and bottom composer. The Code prompt row keeps
  compact model and thinking-level pickers directly beside Send. Settings
  renders grouped cards. Write, Connect Phone, Scheduled Tasks, and Plugins
  render static product-shaped surfaces.
- **Right inspector**: 360px on viewports at least 1180px wide; hidden on
  narrower layouts. Code shows Plan / Todo / Changes / Context cards. Other
  workspaces show matching static inspector cards.
- **Status bar**: 28px strip with runtime readiness and session identity.

Message rows in the Code workspace are rendered by role: user (right-aligned
bubble), assistant (left-aligned bubble with optional reasoning), tool result
(diff/status-colored evidence card), runtime notice (muted caption), and
terminal (status badge + message). Repeated cards use 8px radii; chips and
badges remain pill-like through the view library.

The current UI intentionally does not implement Write persistence/completion,
phone pairing, task execution, plugin installation, Pi/ACP/Local backend
switching, diff application, or command catalogs.

## OpenSeek integration (current)

The macos_skia entrypoint uses `openseek_native_transport`, which:

- enqueues commands from MoUI `Effect::run` and runs them on a dedicated
  `openseek_worker_loop` task alongside the Skia async pump (`@async.all`);
- persists session events through `@store.SessionStore` under
  `MO_WORKBENCH_SESSION_ROOT` (default `<workspace>/.openseek`);
- maps `SessionItem` / `TurnTerminal` into `AgentEvent` for the Code workspace;
- supports `NewSession`, `SwitchSession`, and `FetchSessionList` against the
  store.

Follow-up work: a long-lived `AgentRuntime` + background worker (serve-mode
shape) so mid-turn `Steer` shares the same runtime as the active turn, and
optional `spawn_bg` integration with the Skia async pump instead of per-turn
blocking.

## Reserved Full-Alignment Plan

Future expansions (not in scope for the current prototype):

- **ConnectPhone**: ADB/device pairing UI + file transfer + log stream.
- **ScheduledTasks**: cron-like task scheduler + task history.
- **Plugins**: plugin loading + configuration panel.
- **Write workspace**: Markdown editor surface (the `examples/markdown_editor`
  package already demonstrates the building blocks).
- **Cross-platform entrypoints**: only macOS Skia is wired today; Linux/Windows
  /Web entrypoints can be added as `linux_skia` / `windows_skia` / `web_wasm`
  subpackages without touching the shared app.
