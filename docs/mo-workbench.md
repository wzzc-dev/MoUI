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
- `examples/mo_workbench/acp_native_transport` is a native-only generic ACP
  stdio transport. It launches an ACP-compatible agent subprocess, speaks
  JSON-RPC newline messages over stdin/stdout, maps `session/update` and
  `session/request_permission` into `AgentEvent`, and keeps client filesystem
  and terminal capabilities disabled for v1.
- `examples/mo_workbench/macos_skia` injects
  `acp_native_transport` when `settings.json` selects `"agent_backend": "acp"`
  and `acp_command` is non-empty. Otherwise it uses
  `openseek_native_transport` when an API key is configured, falling back to
  `AgentBackendRuntime::stub()`.

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
  (sessions, messages, prompt, steering/cancel, OpenSeek model/thinking
  controls, ACP mode/config controls, streaming state). Owns
  `AgentBackendRuntime` dispatch + `AgentEvent` projection. This is where the
  Codex-style chat surface lives.
- **Write** (`WriteWorkspace`): static Markdown writing shell with document and
  assistant panels. It currently holds no state and does not save files,
  request completions, or call export services.
- **Settings** (`SettingsWorkspace`): agent runtime + chrome settings form
  (backend selection / provider settings / ACP command and args / approval
  policy / sandbox mode / working directory / font size). Provider/model
  persistence is wired for the native OpenSeek prototype. ACP command settings
  are consumed by the macOS Skia entrypoint.
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
  `SetModel`, `SetThinking`, `CancelTurn`, `SetSessionMode`,
  `SetSessionConfigOption`, `RespondPermission`, `FetchSessionList`,
  `Shutdown`.
- `AgentEvent`: `UserMessageAdded`, `AssistantMessageAdded`,
  `ToolResultAdded`, `RuntimeNoticeAdded`, `TurnTerminal`, `ProgressNotice`,
  streamed message/thought chunks, ACP mode/config updates, permission
  requests, session info updates, `SessionRebuilt`, `SessionListed`,
  `ActiveSessionChanged`.

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
phone pairing, task execution, plugin installation, local diff application, or
command catalogs. ACP v1 support is transport-level and deliberately does not
advertise client filesystem or terminal capability.

## OpenSeek integration (current)

The macos_skia entrypoint uses `openseek_native_transport`, which:

- enqueues commands from MoUI `Effect::run` and runs them on a dedicated
  `openseek_worker_loop` task alongside the Skia async pump (`@async.all`);
- persists session events through `@store.SessionStore` under
  `MO_WORKBENCH_SESSION_ROOT` (default `<workspace>/.openseek`);
- maps `SessionItem` / `TurnTerminal` into `AgentEvent` for the Code workspace;
- enables only the model ids currently parsed by OpenSeek
  (`deepseek-v4-flash`, `deepseek-v4-pro`, `kimi-k2.7-code`,
  `kimi-k2.7-code-highspeed`) while showing other provider-discovered ids as
  disabled options;
- supports `NewSession`, `SwitchSession`, and `FetchSessionList` against the
  store.

Follow-up work: a long-lived `AgentRuntime` + background worker (serve-mode
shape) so mid-turn `Steer` shares the same runtime as the active turn, and
optional `spawn_bg` integration with the Skia async pump instead of per-turn
blocking.

## ACP integration (current)

The macos_skia entrypoint can select `acp_native_transport` from
`.mo_workbench/settings.json`:

```json
{
  "agent_backend": "acp",
  "acp_command": "acp-agent",
  "acp_args": "[\"--stdio\"]",
  "acp_process_cwd": ""
}
```

The ACP backend:

- launches the configured command as a subprocess and uses ACP stdio JSON-RPC
  newline messages;
- sends `initialize` with conservative client capabilities
  (`fs.readTextFile=false`, `fs.writeTextFile=false`, `terminal=false`);
- maps `session/new`, `session/prompt`, `session/cancel`, optional
  `session/list`, `session/load`, `session/resume`, `session/set_mode`, and
  `session/set_config_option` through the neutral backend boundary;
- handles agent `session/update` notifications for message chunks, thought
  chunks, tool calls, plan/usage notices, mode/config updates, and session info;
- handles agent `session/request_permission` requests by rendering a permission
  card and replying with the selected option or `cancelled`.

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
