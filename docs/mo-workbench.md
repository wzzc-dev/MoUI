# Mo Workbench

Mo Workbench is a macOS Skia native-first, Codex-style agent desktop prototype.
Its product target is a conversation-first coding-agent shell in the spirit of
Codex CLI: a clean sidebar with session history, a scrolling message transcript
with user/assistant/tool/runtime/terminal rows, a minimal top bar showing the
active model and thinking mode, and a single composer with prompt + steering
inputs.

## Package Shape

- `examples/mo_workbench/app` owns the shared TEA model, update loop, and
  Codex-style view composition. It is portable (native + wasm-gc) and does not
  depend on any native-only LLM SDK. The backend is injected as an
  `AgentBackendRuntime` closure boundary, so the app package can be tested
  without a network. Its public surface is intentionally narrow:
  `program_with_backend`, `AgentBackendRuntime`, `AgentBackendFixture`,
  `AgentCommand`, `AgentEvent`, `ModelChoice`, `ThinkingChoice`, `TurnStatus`,
  `SessionSummary`, `WorkbenchModel`, `WorkbenchMsg`, and `MoWorkbenchApp`.
- `examples/mo_workbench/macos_skia` is a thin entrypoint that selects
  `backend/macos/skia`, injects a backend runtime, and runs the shared app
  program with the macOS Skia pump. Currently it injects
  `AgentBackendRuntime::stub()` — a canned-reply stub that makes the UI fully
  interactive without an LLM. Once the upstream `bobzhang/openseek@0.2.1`
  mooncakes resolution bug is fixed, this entrypoint will inject the real
  openseek agent loop (`run_turn_in_scope` + `agent_session/store`).

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

## UI Layout

The view is a two-pane layout:

- **Sidebar** (~220px): brand title, "New Chat" button, session history list,
  and an appearance toggle (System / Light / Dark) at the bottom.
- **Main surface**: a top bar (model chip, thinking chip, session label,
  streaming presence dot), a scrollable message list, and a composer.

The composer shows the prompt input + Send button, plus a steering input +
Steer button that appears only while a turn is streaming.

Message rows are rendered by role: user (right-aligned bubble), assistant
(left-aligned bubble with optional collapsed reasoning), tool result (inline
card with badge + mono content), runtime notice (muted caption), and terminal
(status badge + message).

## Planned openseek Integration

Once `bobzhang/openseek@0.2.1` resolves from mooncakes, the macos_skia
entrypoint will replace the stub with an `OpenSeekBackendOwner` that:

- owns an `@aqueue.Queue[AgentCommand]` bridging the UI effect boundary to an
  async worker (same pattern as the old `PiNativeTransportOwner`);
- lazily initializes one `AgentRuntime` + `AgentTaskScope` + `Tools` registry
  (built once with `@agent.build_tools`);
- maps `SendTask` to `@agent.run_turn_in_scope(...)` with an `append_item`
  callback that projects each `SessionItem` into an `AgentEvent` and emits it
  back to the UI;
- maps `Steer` to `@agent.steer(runtime, text)`;
- maps `NewSession` / `SwitchSession` / `FetchSessionList` to
  `@store.SessionStore` operations;
- runs in a `@async.with_task_group` `spawn_bg` alongside the Skia pump.

The app package needs no changes for this — only the entrypoint's backend
injection changes.
