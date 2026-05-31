# Mo Workbench

Mo Workbench is a macOS Skia native-first Pi agent desktop prototype. Its first
product target is a coding-agent workbench in the spirit of Codex or Claude
Code desktop: project sessions, code understanding, task planning, execution
feedback, diff and file context, command queues, and diagnostics all live in
one session-first surface.

The subtitle is **A Pi agent desktop**. The app is deliberately not modeled as
only a code editor. The same session, transport event, context, plan, command,
and diagnostic concepts should later support document workflows, research,
automation runs, and knowledge organization.

## Package Shape

- `examples/mo_workbench/app` owns the shared TEA model, view composition,
  sample fixtures, platform-neutral Pi transport event model, and injectable
  `PiTransportRuntime` effect boundary.
- `examples/mo_workbench/native_transport` owns the native
  `moonbitlang/async` process driver for JSONL stdin/stdout sessions. It
  imports the shared app package for `PiTransportCommand`,
  `PiTransportEvent`, and `PiTransportRuntime`, keeping process ownership out
  of the shared model while reusing the same command/event contract. Its
  `PiNativeTransportOwner` is the native lifecycle owner that accepts queued UI
  command batches through an async queue, lazily starts one JSONL process, and
  emits stdout, stderr, and process events back through the app runtime
  dispatch hook. Unexpected process exits end only the child process; the owner
  remains available and restarts the JSONL process for the next command batch.
- `examples/mo_workbench/macos_skia` is a thin entrypoint that selects
  `backend/macos/skia`, injects the owned native Pi transport runtime, and runs
  the shared app runtime with the macOS Skia async pump.
- Future Web or other native entrypoints should reuse the same app package and
  feed the same `PiTransportCommand` / `PiTransportEvent` model.

## Current Vertical Slice

The current slices establish the dogfood app without changing framework
packages:

- A session-first desktop shell named `Mo Workbench`.
- Header subtitle `A Pi agent desktop`.
- A Codex / Claude Code-style native shell with macOS chrome, a gray session
  sidebar, a compact workspace summary, state-driven transcript, compact
  activity/workspace digests, and a restrained composer.
- macOS Skia native entrypoint with first-frame exit support through
  `MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`.
- A platform-neutral `PiTransportState` with native JSONL, Web bridge, and
  fixture transport kinds.
- Typed transport commands for starting RPC, sending prompts, running shell
  commands, refreshing Pi messages and command catalogs, syncing Pi session
  names, refreshing Pi session stats, cancelling runs, switching Pi sessions,
  and shutdown.
- Typed transport events for process lifecycle, JSONL sent/received lines,
  stderr diagnostics, and failures.
- A platform-neutral `PiTransportRuntime` that turns command batches into
  MoUI effects, so prompt, command, and cancel actions can dispatch transport
  events back through the same TEA message loop.
- A native-only async transport package whose default command is
  `pi --mode rpc`, maps command batches to the real Pi RPC JSONL commands
  (`get_state`, `get_messages`, `get_commands`, `get_session_stats`,
  `cycle_thinking_level`, `set_steering_mode`, `set_follow_up_mode`,
  `switch_session`, `prompt`, `set_session_name`, `bash`, `abort_bash`, and
  `abort`; shutdown is stdin EOF), and uses shell fixtures to prove direct
  JSONL stdin/stdout process
  driving without C FFI or a Node bridge.
- A native interactive session primitive that keeps one JSONL process alive
  across multiple command batches in the same async task group.
- A native multi-batch session runner that accepts an array of command batches
  and proves the same JSONL process can serve the start, prompt, follow-up,
  and cancel phases that would otherwise arrive through separate UI dispatches.
- A native `PiNativeTransportOwner` that turns repeated
  `PiTransportRuntime.dispatch` calls into one long-lived JSONL process
  lifecycle using `moonbitlang/async/aqueue`, without changing the
  platform-neutral app transport contract.
- A macOS Skia entrypoint wired to `PiNativeTransportOwner::runtime()` and
  `backend/macos/skia.run_app_with_options_async_pump`, so the AppKit pump and
  Pi transport worker cooperate on the same native async loop.
- Conversation-first workbench UI that keeps session state, transcript,
  command evidence, command discovery, file context, diff review, diagnostics,
  transport status, and the next prompt in one visible flow. The current shell
  avoids screenshot-only filler: the old validation transcript, hard-coded
  shell command block, fake attachment cards, copy/vote toolbar, and
  future-workflow placeholder session were replaced with compact panels driven
  by `WorkbenchModel` state. The default fixture now leaves transcript and
  diagnostics empty until Pi or command evidence arrives, and empty digest rows
  render quietly instead of placeholder punctuation.
- File context rows in the Workspace digest can queue an `Inspect <path>`
  prompt for Pi. The action reuses the platform-neutral `SendUserInput` command
  so file evidence becomes an agent workflow entrypoint without native-only
  transport.
- The Workspace diff review control queues a `Review diff: ...` prompt through
  the same path, making code review a first-class coding-agent action while
  keeping PiTransport platform-neutral.
- Pending transport command counts now drain as `JsonLineSent` events arrive
  and clear on process exit or failure, so the visible queue reflects work
  still waiting to be handed to Pi instead of a historical command log.
- The current session can be refreshed manually from the session panel. The
  shared app reuses the same platform-neutral command batch as session
  selection: state, messages, command catalog, and session stats.
- Workbench command queue entries now use Pi RPC `bash` directly instead of
  prompt text such as `run: ...`; the shared app keeps command/cwd evidence and
  lets the native encoder emit `{"type":"bash","command":...}`. Successful
  bash responses preserve Pi's optional `fullOutputPath` on `CommandRun`, and
  Activity rows display that output path when it is available.
- Command evidence rows in the Activity digest can be rerun from the UI. The
  action reuses the existing shared-app `QueueCommand` reducer and native Pi
  RPC `bash` encoder instead of adding a separate native shortcut.
- The Activity digest surfaces the latest shared-app timeline event, so Pi RPC,
  streaming agent, tool, and stderr progress stays visible next to command
  evidence without opening a separate log view.
- Session selection now refreshes Pi messages after state binding. The shared
  app maps Pi RPC `get_messages` responses into generic `TranscriptItem`
  records so the conversation surface can replay user, assistant, tool result,
  bash, compaction, branch summary, and future workflow messages.
- Session selection also refreshes Pi's available command catalog through
  `get_commands`. The shared app maps prompt, extension, and skill commands
  into generic `PiCommandInfo` rows so coding-agent command discovery can later
  grow into document, research, automation, and knowledge workflows without
  changing the platform-neutral transport contract.
- The command catalog can invoke a listed command by sending `/<name>` through
  the existing platform-neutral `SendUserInput` prompt path. This keeps slash
  command execution usable in the native UI without adding a native-only
  transport command or process bridge.
- Session selection refreshes Pi session stats through `get_session_stats`.
  The shared app maps message counts, tool counts, token totals, cost, and
  optional context usage into `PiSessionStatsSnapshot`, then surfaces compact
  metrics in the session status panel without adding native-only state.
- The workbench can explicitly sync the selected Workbench session title into
  Pi through `set_session_name`. Pi's `session_info_changed` event updates the
  same `PiSessionBinding`, so user-visible Workbench session identity and Pi's
  runtime session display name stay aligned without native-only state.
- The workbench can cycle Pi's thinking level from the session status panel.
  The shared app emits a platform-neutral `CycleRpcThinkingLevel` command,
  ingests `cycle_thinking_level` responses and `thinking_level_changed` events,
  and keeps `PiAgentSnapshot.thinking_level` visible without native-only state.
- The composer exposes compact steering and follow-up mode controls. The shared
  app emits platform-neutral `SetRpcSteeringMode` and `SetRpcFollowUpMode`
  commands, ingests their acknowledgements, and refreshes both modes from
  `get_state` so Pi remains the source of truth for input queue policy.
- Run cancellation is command-aware: active Workbench shell commands queue a
  platform-neutral `CancelShellCommand` that the native encoder maps to Pi RPC
  `abort_bash`, while prompt/agent cancellation continues to use `abort`.
- Structured Pi JSONL ingestion for coding-agent evidence:
  `command_started`, `command_finished`, `diagnostic`, `file_context`, and
  `diff_summary` payloads update the shared model, timeline, diagnostics,
  file context, and diff overview while still preserving raw JSONL transport
  events.
- Real Pi RPC `response` ingestion for the current CLI protocol. Successful
  `get_state` responses update a small `PiRpcSnapshot`, refresh the selected
  Workbench session with the Pi session id, model label, message count, and
  pending count, and append a timeline event. Successful `get_messages`
  responses replace the visible transcript with normalized `TranscriptItem`
  rows. Successful `get_commands` responses replace the visible command catalog
  with normalized `PiCommandInfo` rows that preserve command name, kind,
  description, source scope, and source path. Successful `get_session_stats`
  responses refresh `PiSessionStatsSnapshot` with message, tool, token, cost,
  and optional context counters. Successful `cycle_thinking_level` responses
  update the agent snapshot when Pi returns the new level, while
  `thinking_level_changed` events remain the authoritative stream update.
  Successful `set_steering_mode` and `set_follow_up_mode` responses acknowledge
  the compact composer controls; `get_state` refreshes the current mode values.
  Successful `set_session_name` responses mark the session-name sync as
  acknowledged; the preceding
  `session_info_changed` event carries the actual display name and updates
  `PiSessionBinding`. Successful `bash` responses mark the latest
  queued/running Workbench command as passed, failed, or cancelled and add
  diagnostics for nonzero, missing, truncated, or cancelled output. Failed RPC
  responses append a diagnostic without involving the native transport layer.
- Pi RPC session event ingestion for the real streaming protocol. The shared
  app now recognizes `agent_start` / `agent_end`, `turn_start` / `turn_end`,
  `message_start` / `message_update` / `message_end`, `tool_execution_*`,
  `queue_update`, thinking-level changes, compaction, and auto-retry events.
  These update a small `PiAgentSnapshot`, selected-session status, timeline
  entries, and command evidence while keeping stdout payload parsing out of the
  native transport package.
- Workbench session ids now have explicit Pi session bindings. A
  `WorkbenchSession` can carry a `pi_session_path`; selecting that session
  through an injected transport emits a platform-neutral `SwitchRpcSession`
  followed by a `get_state` refresh. `switch_session` and `get_state` responses
  update `PiSessionBinding` entries keyed by Workbench session id, recording the
  live Pi session id, session file, display name, model, and binding status.
  The session status panel now displays the active binding as a compact Pi row,
  including the live Pi session name/id and model when Pi has reported them.
- Native stderr surfacing through platform-neutral `ProcessStderr` events,
  warning diagnostics, and timeline entries without parsing stderr as Pi JSONL.
- The workspace digest surfaces the current diagnostics count and latest
  diagnostic row, with a shared-app `ClearDiagnostics` action for clearing
  visible Pi stderr/RPC/bash diagnostics without touching native process state.
- Nonzero native process exits now emit `TransportFailed` with the exit code and
  the last stderr line, clear pending transport commands, and leave the app in a
  failed transport state instead of silently disconnecting.
- The native owner now supervises the Pi child process: unexpected exits surface
  as transport failures, but the owner stays alive and lazily starts a fresh
  JSONL process for the next UI command batch. Explicit `Shutdown` still closes
  the owner.
- The native encoder is aligned with the installed Pi RPC protocol and has
  no-model smoke paths using offline `get_state`, `get_messages`,
  `get_commands`, `get_session_stats`, `cycle_thinking_level`,
  `set_steering_mode`, `set_follow_up_mode`, `set_session_name`, and
  `abort_bash` over `pi --mode rpc`.

The remaining V1 transport boundary is production lifecycle polish: the native
owner now keeps one process alive across real runtime dispatches, reports
stderr/nonzero-exit failures, restarts after unexpected child exits, speaks the
current Pi RPC command names, and the shared app ingests command responses,
streaming session events, and Workbench-to-Pi session bindings. The next
transport slice should add real end-to-end prompt smoke evidence when a model
can be used safely and decide how session creation/forking should appear in the
Workbench UI.

## Pi JSONL Workbench Events

The app treats Pi stdout as transport evidence first and product state second.
Every `JsonLineReceived(session, line)` updates `PiTransportState` with the raw
line. If the line is a supported JSON object, the app also applies a typed
Workbench update:

```json
{"type":"command_started","id":9,"command":"moon check","cwd":"/repo","status":"running"}
{"type":"command_finished","id":9,"exit_code":0}
{"type":"diagnostic","source":"moon check","severity":"warning","message":"unused value"}
{"type":"file_context","id":"app","path":"examples/mo_workbench/app/app.mbt","summary":"Reducer update","change_kind":"modified","lines_changed":12}
{"type":"diff_summary","changed_files":6,"additions":180,"deletions":12,"status":"requires_review"}
```

Malformed or unsupported lines are intentionally ignored by the product model
after the raw transport event is recorded. This keeps the platform-neutral
`PiTransportEvent` contract stable for native, Web, and fixture transports
while allowing the Workbench app to grow coding-agent affordances at the
application layer.

Pi RPC responses use the same path. A successful
`{"type":"response","command":"get_state","success":true,...}` line updates
`WorkbenchModel.pi_rpc`, refreshes the selected session summary/status with the
Pi session id, model label, and pending count, and appends a `Pi RPC response`
timeline event. A successful
`{"type":"response","command":"get_messages","success":true,...}` line replaces
the visible transcript with normalized `TranscriptItem` rows while preserving
the raw JSONL transport event. A successful
`{"type":"response","command":"get_commands","success":true,...}` line replaces
the visible command catalog with normalized `PiCommandInfo` rows for prompt,
extension, and skill commands. A successful
`{"type":"response","command":"get_session_stats","success":true,...}` line
refreshes `PiSessionStatsSnapshot` with message/tool/token/context metrics and
updates the Workbench-to-Pi binding from the reported `sessionId` and
`sessionFile`. A successful
`{"type":"response","command":"cycle_thinking_level","success":true,...}` line
acknowledges the compact Thinking control and, when Pi includes a `data.level`,
updates `PiAgentSnapshot.thinking_level`. The streamed
`{"type":"thinking_level_changed","level":"..."}` event can still arrive
separately and is treated as the authoritative level change. A successful
`{"type":"response","command":"set_session_name","success":true}` line confirms
the app's session-name sync request, while a preceding
`{"type":"session_info_changed","name":"..."}` event updates the binding's
visible session name. A successful
`{"type":"response","command":"bash","success":true,...}` line updates the
latest queued/running command evidence for that Workbench session using Pi's
`BashResult.exitCode`, `cancelled`, `truncated`, and optional
`fullOutputPath` fields. A failed `response` line records a `Pi RPC`
diagnostic and a failure timeline event. The native transport does not parse
these payloads; it only delivers stdout JSONL as `JsonLineReceived`.

Session selection is also app-layer state. If a selected `WorkbenchSession` has
`pi_session_path`, the shared app queues:

```json
{"type":"switch_session","sessionPath":"/tmp/mo-workbench-pi-rpc-session.jsonl"}
{"type":"get_state"}
{"type":"get_messages"}
{"type":"get_commands"}
{"type":"get_session_stats"}
```

The `switch_session` response marks the Workbench session binding as switching
or cancelled. The following `get_state` response binds that Workbench session id
to Pi's concrete `sessionId`, `sessionFile`, optional `sessionName`, and current
model plus thinking, steering, and follow-up modes. The following
`get_messages` response fills the transcript panel from Pi's `AgentMessage[]`,
and the following `get_commands` response fills the command catalog from Pi's
slash command registry. Invoking a catalog row sends `/<name>` through the same
prompt RPC channel used by manual user input. The following
`get_session_stats` response fills the
compact status metrics from Pi's session statistics. This keeps
`PiTransportEvent` platform-neutral while letting the app separate Mo Workbench
sidebar ids from Pi's runtime session identity.

Manual refresh uses the same app-layer batch without changing the selected
Workbench session. This gives the macOS Skia UI a direct resync affordance while
keeping process ownership in the native async transport and state ownership in
the shared app package.

Streaming Pi session events also use the same app-layer path:

```json
{"type":"agent_start"}
{"type":"turn_start","turnIndex":2}
{"type":"message_update","message":{"role":"assistant","content":[{"type":"text","text":"Inspecting renderer route"}]},"assistantMessageEvent":{"type":"text_delta","delta":"Inspecting renderer route"}}
{"type":"tool_execution_start","toolCallId":"call-bash-1","toolName":"bash","args":{"command":"moon test examples/mo_workbench/app --target native","cwd":"/Volumes/Data/Code/moon/MoUI"}}
{"type":"tool_execution_end","toolCallId":"call-bash-1","toolName":"bash","result":{"details":{"exitCode":0}},"isError":false}
{"type":"queue_update","steering":[],"followUp":["update docs"]}
```

`PiAgentSnapshot` tracks the current phase, turn index, streamed message
preview, active tool, queue counts, and thinking level. Tool execution start/end
events upsert `CommandRun` evidence using Pi's `toolCallId`, so bash and future
coding tools can appear in the command evidence surface without changing the
transport event enum.

Stderr remains separate from stdout JSONL. `ProcessStderr(session, line)` updates
the raw transport tail as `stderr: ...`, adds a warning diagnostic sourced from
`Pi stderr`, and records a warning timeline event. If the native process exits
with a nonzero status, `TransportFailed(reason)` uses the command label, exit
code, and last stderr line so the UI can explain the failure without depending
on native-only process details.

Restart is owner-scoped rather than app-scoped. A nonzero child exit emits
`ProcessExited(code)` and `TransportFailed(reason)`, then the owner returns to
its command queue. The next `PiTransportRuntime.dispatch` starts a new child
process and sends the queued commands through the same platform-neutral event
contract. Dispatching `Shutdown` is the only normal path that stops the owner.

The native encoder intentionally uses the Pi CLI's current RPC command shape:
`StartRpc` sends `{"type":"get_state"}` as a cheap liveness/state probe,
`FetchRpcMessages` sends `{"type":"get_messages"}`,
`FetchRpcCommands` sends `{"type":"get_commands"}`,
`FetchRpcSessionStats` sends `{"type":"get_session_stats"}`,
`CycleRpcThinkingLevel` sends `{"type":"cycle_thinking_level"}`,
`SetRpcSteeringMode` sends `{"type":"set_steering_mode","mode":...}`,
`SetRpcFollowUpMode` sends `{"type":"set_follow_up_mode","mode":...}`,
`SwitchRpcSession` sends `{"type":"switch_session","sessionPath":...}`,
`SetRpcSessionName` sends `{"type":"set_session_name","name":...}`,
`SendUserInput` sends `{"type":"prompt","message":...}`, `RunShellCommand`
sends `{"type":"bash","command":...}`, `CancelShellCommand` sends
`{"type":"abort_bash"}`, `CancelRpcRun` sends `{"type":"abort"}`, and
`Shutdown` closes stdin instead of sending a JSON command. Workbench session ids
remain part of the Mo Workbench event labels and state; `PiSessionBinding`
records which concrete Pi session the current process reported for each
Workbench session.

The smallest real CLI smoke avoids model calls and validates the stdin/stdout
contract only:

```sh
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
printf '{"type":"set_steering_mode","mode":"all"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_follow_up_mode","mode":"one-at-a-time"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_session_name","name":"Mo Workbench smoke"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"abort_bash"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
```

The first command should return a JSONL `response` object for `get_state`, the
second should return a `get_messages` response with a `messages` array, the
third should return a `get_commands` response with a `commands` array, the
fourth should return a `get_session_stats` response with message, tool, token,
and cost counters, the fifth should return a successful
`cycle_thinking_level` acknowledgement, the sixth and seventh should acknowledge
the steering/follow-up mode changes, the eighth should emit
`session_info_changed` and a successful `set_session_name` response, and the
ninth should return a successful
`abort_bash` response even when no bash command is active. All exit through
stdin EOF.

## Skia Native-First Notes

The macOS app intentionally selects the Skia provider instead of the default
WGPU provider. When workbench UI needs renderer capabilities that are missing
from `.local_repos/skia_mbt`, add clean fallback-safe APIs there first, then
wire MoUI `DrawCommand` support through `render/skia`, update renderer
capability reporting, and add focused tests.

Fallback compilation is not renderer readiness. Real native smoke still
depends on local Skia link flags and should use the existing macOS Skia helper
when validating presenter pixels.

## Focused Validation

Use these checks while working on the first app slices:

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
printf '{"type":"set_steering_mode","mode":"all"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_follow_up_mode","mode":"one-at-a-time"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_session_name","name":"Mo Workbench smoke"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"abort_bash"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
```

When real Skia is configured locally, also run:

```sh
MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/mo_workbench/macos_skia --target native
```
