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
- A Codex / Claude Code-style native shell with macOS chrome, a gray
  session/project sidebar, a white assistant transcript, command output,
  attachment cards, a diff summary, and a rounded composer.
- macOS Skia native entrypoint with first-frame exit support through
  `MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`.
- A platform-neutral `PiTransportState` with native JSONL, Web bridge, and
  fixture transport kinds.
- Typed transport commands for starting RPC, sending prompts, cancelling runs,
  switching Pi sessions, and shutdown.
- Typed transport events for process lifecycle, JSONL sent/received lines,
  stderr diagnostics, and failures.
- A platform-neutral `PiTransportRuntime` that turns command batches into
  MoUI effects, so prompt, command, and cancel actions can dispatch transport
  events back through the same TEA message loop.
- A native-only async transport package whose default command is
  `pi --mode rpc`, maps command batches to the real Pi RPC JSONL commands
  (`get_state`, `switch_session`, `prompt`, and `abort`; shutdown is stdin
  EOF), and uses shell fixtures to prove direct JSONL stdin/stdout process
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
- Conversation-first workbench UI that keeps command evidence, file context,
  diff review, transport status, and the next prompt in one visible flow.
- Pending transport command counts now drain as `JsonLineSent` events arrive
  and clear on process exit or failure, so the visible queue reflects work
  still waiting to be handed to Pi instead of a historical command log.
- Structured Pi JSONL ingestion for coding-agent evidence:
  `command_started`, `command_finished`, `diagnostic`, `file_context`, and
  `diff_summary` payloads update the shared model, timeline, diagnostics,
  file context, and diff overview while still preserving raw JSONL transport
  events.
- Real Pi RPC `response` ingestion for the current CLI protocol. Successful
  `get_state` responses update a small `PiRpcSnapshot`, refresh the selected
  Workbench session with the Pi session id, model label, message count, and
  pending count, and append a timeline event. Failed RPC responses append a
  diagnostic without involving the native transport layer.
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
- Native stderr surfacing through platform-neutral `ProcessStderr` events,
  warning diagnostics, and timeline entries without parsing stderr as Pi JSONL.
- Nonzero native process exits now emit `TransportFailed` with the exit code and
  the last stderr line, clear pending transport commands, and leave the app in a
  failed transport state instead of silently disconnecting.
- The native owner now supervises the Pi child process: unexpected exits surface
  as transport failures, but the owner stays alive and lazily starts a fresh
  JSONL process for the next UI command batch. Explicit `Shutdown` still closes
  the owner.
- The native encoder is aligned with the installed Pi RPC protocol and has a
  no-model smoke path using offline `get_state` over `pi --mode rpc`.

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
timeline event. A failed `response` line records a `Pi RPC` diagnostic and a
failure timeline event. The native transport does not parse these payloads; it
only delivers stdout JSONL as `JsonLineReceived`.

Session selection is also app-layer state. If a selected `WorkbenchSession` has
`pi_session_path`, the shared app queues:

```json
{"type":"switch_session","sessionPath":"/tmp/mo-workbench-pi-rpc-session.jsonl"}
{"type":"get_state"}
```

The `switch_session` response marks the Workbench session binding as switching
or cancelled. The following `get_state` response binds that Workbench session id
to Pi's concrete `sessionId`, `sessionFile`, optional `sessionName`, and current
model. This keeps `PiTransportEvent` platform-neutral while letting the app
separate Mo Workbench sidebar ids from Pi's runtime session identity.

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
`SwitchRpcSession` sends `{"type":"switch_session","sessionPath":...}`,
`SendUserInput` sends `{"type":"prompt","message":...}`, `CancelRpcRun` sends
`{"type":"abort"}`, and `Shutdown` closes stdin instead of sending a JSON
command. Workbench session ids remain part of the Mo Workbench event labels and
state; `PiSessionBinding` records which concrete Pi session the current process
reported for each Workbench session.

The smallest real CLI smoke avoids model calls and validates the stdin/stdout
contract only:

```sh
printf '{"type":"get_state"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
```

It should return a JSONL `response` object for `get_state` and then exit through
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
```

When real Skia is configured locally, also run:

```sh
MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/mo_workbench/macos_skia --target native
```
