# Mo Workbench

Mo Workbench is a macOS Skia native-first desktop agent shell. Its shared app
is a task workbench with a responsive task sidebar, `Work` / `Code`
/ `Design` top tabs, and a settings overlay. `Code` is the interactive
conversation surface; `Work` projects the session list into a task dashboard,
and `Design` exposes a live product-state and palette preview without claiming
a design-document workflow.

## Package Shape

- `examples/mo_workbench/app` owns the shared TEA shell model, its `Code` and
  `Settings` sub-models, task projection, update routing, and view composition.
  It is portable
  (native + wasm-gc) and does not depend on any native-only LLM SDK. The
  backend is injected as an `AgentBackendRuntime` closure boundary, so the app
  package can be tested without a network. Its public surface is intentionally
  narrow: `program_with_backend`, `AgentBackendRuntime`, `AgentBackendFixture`,
  `AgentCommand`, `AgentEvent`, `ThinkingChoice`, `TurnStatus`,
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

## Shell Architecture

`WorkbenchModel` holds the active `TopTab`, `CodeWorkspace`,
`SettingsWorkspace`, shared chrome state, and a derived sidebar task tree.
`code.sessions` is the source of truth for task history; `sync_task_tree`
rebuilds the searchable, filterable, expandable sidebar projection after code
state changes. `CodeMsg(...)` and `SettingsMsg(...)` are delegated to their
sub-updates and their effects are lifted back to `Effect[WorkbenchMsg]`.

### Top Tabs and Settings

- **Work**: a session-backed dashboard with total/running/failed/done summary
  cards, next actions, and recent tasks. Its Review, Running, and All tasks
  actions apply the matching sidebar filter and open the `Code` tab.
- **Code** (`CodeWorkspace`): the conversation-first coding-agent surface:
  sessions, message timeline, prompt composer, steering/cancel, OpenSeek model
  and thinking controls, ACP mode/config controls, and streaming state. It owns
  `AgentBackendRuntime` dispatch and `AgentEvent` projection.
- **Design**: a live preview of task count, current model, approval/sandbox
  settings, typography, controls, and palette tokens. It is not a
  design-document editor.
- **Settings** (`SettingsWorkspace`): an overlay with API, Agent, and Editor
  sections for backend/provider configuration, ACP command settings, approval
  policy, sandbox mode, working directory, appearance, and font size.

### Message Routing

- `SwitchTab(TopTab)` changes the selected Work/Code/Design surface.
- `NewTask` and `SelectTask(id)` delegate to `CodeWorkspace` and open `Code`.
- `ShowAllTasks`, `ShowRunningTasks`, and `ShowFailedTasks` set the sidebar
  filter and open `Code`; search, folder expansion, and sidebar visibility are
  handled by the shell.
- `CodeMsg(CodeMsg)` delegates to `CodeWorkspace::update(msg, backend)` and
  lifts the resulting effect; `ReceiveAgentEvent(AgentEvent)` keeps backend
  event projection inside the Code workspace.
- `SettingsMsg(SettingsMsg)` delegates to the settings sub-model.
- `ToggleAppearance` cycles `System → Light → Dark → System` from the sidebar
  footer; `ToggleSettings` opens the settings overlay.

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

Backend injection only affects `CodeWorkspace::update`; task/sidebar routing
and Settings state remain portable app behavior.

## UI Layout

- **Sidebar**: 280px on wide desktop, 248px below 1120px, and 200px below
  760px. It contains the Work/Code/Design segmented control, New Task, a
  searchable/filterable session tree with expandable task groups, Settings,
  and the accessible appearance toggle.
- **Topbar**: a 50px strip inside the center column showing the selected tab
  identity and contextual subtitle.
- **Center work surface**: Work renders the task dashboard; Code renders
  starter cards or the message timeline with evidence-colored rows and a bottom
  composer; Design renders product-state, control, and palette previews.
- **Settings overlay**: grouped API, Agent, and Editor cards are rendered over
  the shell rather than as a top-level tab.

Message rows in the Code workspace are rendered by role: user (right-aligned
bubble), assistant (left-aligned bubble with optional reasoning), tool result
(diff/status-colored evidence card), runtime notice (muted caption), and
terminal (status badge + message). Repeated cards use 8px radii; chips and
badges remain pill-like through the view library.

The current UI intentionally does not implement design-document editing, phone
pairing, scheduled-task execution, plugin installation, local diff application,
or command catalogs. ACP v1 support is transport-level and deliberately does
not advertise client filesystem or terminal capability.

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

## Follow-up Scope

Future expansions are not part of the current prototype:

- richer Work history/status once transports expose sufficient session metadata;
- a real Design workflow beyond the current state and palette preview;
- cross-platform entrypoints: only macOS Skia is wired today, while
  Linux/Windows/Web entrypoints can be added as `linux_skia` / `windows_skia` /
  `web_wasm` subpackages without changing the shared app.
