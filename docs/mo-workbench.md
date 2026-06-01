# Mo Workbench

Mo Workbench is a macOS Skia native-first Pi agent desktop prototype. Its first
product target is a coding-agent workbench in the spirit of Codex or Claude
Code desktop: project sessions, code understanding, task planning, execution
feedback, diff and file context, command queues, and diagnostics all live in
one session-first surface.

The visible subtitle is **Pi agent 桌面工作台**. The app is deliberately not
modeled as only a code editor. The same session, transport event, context,
plan, command, and diagnostic concepts should later support document workflows,
research, automation runs, and knowledge organization.

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
- Header subtitle `Pi agent 桌面工作台`.
- A Codex / Claude Code-style native shell with macOS chrome, a quiet
  task-history sidebar, a clean white main work canvas, readable transcript
  blocks, on-demand evidence digests, and a floating composer.
- macOS Skia native entrypoint with first-frame exit support through
  `MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`.
- A platform-neutral `PiTransportState` with native JSONL, Web bridge, and
  fixture transport kinds.
- Typed transport commands for starting RPC, sending prompts, running shell
  commands, refreshing Pi messages, model catalogs, and command catalogs,
  syncing Pi session names, refreshing Pi session stats, creating fresh Pi
  sessions, compacting context, cancelling runs, switching Pi sessions,
  exporting Pi sessions to HTML, and shutdown.
- Typed transport events for process lifecycle, JSONL sent/received lines,
  stderr diagnostics, and failures.
- A platform-neutral `PiTransportRuntime` that turns command batches into
  MoUI effects, so prompt, command, and cancel actions can dispatch transport
  events back through the same TEA message loop.
- A native-only async transport package whose default command is
  `pi --mode rpc`, maps command batches to the real Pi RPC JSONL commands
  (`get_state`, `get_available_models`, `get_messages`, `get_commands`,
  `get_session_stats`, `set_model`, `cycle_model`, `compact`, `cycle_thinking_level`,
  `set_steering_mode`, `set_follow_up_mode`, `new_session`, `switch_session`,
  `fork`,
  `get_fork_messages`, `export_html`, `prompt`, `steer`, `follow_up`,
  `set_session_name`, `bash`,
  `abort_bash`, and `abort`; shutdown is stdin EOF), and uses shell fixtures to
  prove direct JSONL stdin/stdout process
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
  is rebuilt from `ViewEnvironment.viewport_size()` instead of a fixed
  `1200x750` surface, so the macOS Skia runtime responds to window resize
  events with adaptive sidebar, panel, scroll, and composer dimensions, including
  narrower panel/composer widths when the main region is smaller than the old
  fixed desktop frame. The right-side workflow is now a scrollable main canvas
  with an explicit scrollbar, multi-line transcript message blocks for long Pi
  replies, an on-demand current-state strip, and a centered floating composer.
  The visible hierarchy uses quieter Chinese section labels (`当前会话`, `Pi 运行状态`,
  `会话记录`, `运行证据`, `工作区证据`) once their evidence exists while preserving
  Pi/RPC protocol nouns. The default chrome shows short project names and
  signal-bearing localized session status labels, while full project paths
  remain in the shared model and Pi transport commands. The default shell keeps
  only top-bar refresh/new-session controls and the composer input prominent,
  while typed input adds a compact `选项`/`发送` row instead of opening every
  secondary control. Active/idle session rows omit status meta instead of
  showing fake active, queue, or idle labels. Context chips, the idle Pi RPC
  footer, the `Pi 运行状态` panel, agent focus controls, advanced session actions,
  steering/follow-up composer controls, and focused-check presets stay collapsed
  until Pi state, expanded composer options, non-default context, selected
  focus, or command evidence makes them relevant.
  It also avoids screenshot-only filler: the old validation transcript, hard-coded
  shell command block, fake attachment cards, copy/vote toolbar, and
  future-workflow placeholder session were replaced with compact panels driven
  by `WorkbenchModel` state. The default fixture now leaves transcript,
  metrics, command catalog, file context, diff summary, command evidence, and
  diagnostics empty until Pi or user command evidence arrives, and no longer
  displays sample active-task text. Zero queues, unbound Pi state, idle
  transport/agent state, and contextless actions render quietly instead of
  placeholder punctuation; transcript/activity/workspace panels stay unmounted
  while empty, and empty wide windows no longer reserve space for workflow-rail
  placeholder cards.
- Wide Workbench windows now add a screenshot-style right workflow rail beside
  the conversation canvas only when there is live evidence to summarize. The
  rail is still driven only by shared app state: `进度` summarizes live
  `PlanStep` rows, `执行` reflects plan owners or recent activity events, and
  `工作文件夹` shows the active project plus the latest file evidence. Empty or
  compact windows collapse the rail and keep the conversation flow primary.
- Agent focus controls for `通用`, `编码`, and `校验` now live in the composer's
  optional `焦点` row instead of the default sidebar. They appear after opening
  composer options or when a focus is selected, keeping the idle shell closer to
  Codex's session-first layout.
  Selecting a role does not create a native-only worker or transport command;
  it appends an `agent focus: ...` hint to the existing prompt, steering, and
  follow-up text context before the shared app emits the same platform-neutral
  `SendUserInput`, `SendSteeringInput`, or `SendFollowUpInput` commands.
- Pi `plan_update` JSONL now fills the existing shared-app `PlanStep` model and
  renders a compact `当前计划` row in the current session panel. The row shows
  the current active/open step, open-step count, and a `继续` action that reuses
  the platform-neutral follow-up prompt path.
- The current session panel now derives one `下一步` row from live state when
  there is actionable evidence. It prioritizes cancelable Pi runs, failed
  command evidence, diagnostics, active plan steps, reviewable diffs, file
  context, transcript rows, and latest activity events,
  then routes the chosen button back through the existing shared-app messages
  such as `CancelRun`, `FixCommandRun`, `FixDiagnostic`, `InspectCommandRun`,
  `FollowActivity`, `ReviewDiff`, `InspectFile`, `FollowTranscript`, or
  `InvokeCommand`.
- Transcript rows can queue a `Follow up on <role> transcript: ...` prompt for
  Pi through the existing platform-neutral `SendUserInput` path, so visible
  conversation evidence can become the next agent action without native-only
  transport.
- The composer now exposes explicit context chips for repository, examples,
  evidence, and Pi session scope after opening composer options, after
  selecting an agent focus, or after changing the default context. Direct
  prompt, steering, and follow-up submits prefix the selected context labels
  into the text payload before it enters the existing platform-neutral
  `SendUserInput`,
  `SendSteeringInput`, or `SendFollowUpInput` paths; no new transport command
  or native bridge is required, and users can turn all context chips off to send
  the raw text.
- Activity timeline rows can queue a
  `Follow up on <phase> activity: ...` prompt through the same
  `SendUserInput` path, so visible Pi RPC, stderr, tool, and stream events can
  become the next agent action without adding event-specific transport
  commands.
- File context rows in the Workspace digest can queue an `Inspect <path>`
  prompt for Pi. The action reuses the platform-neutral `SendUserInput` command
  so file evidence becomes an agent workflow entrypoint without native-only
  transport.
- The Workspace diff review control queues a `Review diff: ...` prompt through
  the same path, making code review a first-class coding-agent action while
  keeping PiTransport platform-neutral.
- Latest diagnostic rows in the Workspace digest can queue a
  `Fix <severity> diagnostic from <source>: ...` prompt through
  `SendUserInput`, preserving the current context chips and selected agent
  focus while turning build/check failures into the next coding-agent task
  without adding a diagnostic-specific native transport command.
- Pending transport command counts now drain as `JsonLineSent` events arrive
  and clear on process exit or failure, so the visible queue reflects work
  still waiting to be handed to Pi instead of a historical command log.
- The current session can be refreshed manually from the top bar. The
  shared app reuses the same platform-neutral command batch as session
  selection: state, messages, command catalog, and session stats.
- Workbench command queue entries now use Pi RPC `bash` directly instead of
  prompt text such as `run: ...`; the shared app keeps command/cwd evidence and
  lets the native encoder emit `{"type":"bash","command":...}`. Successful
  bash responses preserve Pi's optional `fullOutputPath` on `CommandRun`, and
  Activity rows display that output path when it is available.
- Command evidence rows in the Activity digest can queue an
  `Inspect command output for ...` prompt through `SendUserInput`, carrying the
  command text, status, cwd, and output path back into Pi without adding a
  native-only output-opening bridge. These prompts preserve the current context
  chips and selected agent focus, so evidence actions keep the same repo,
  examples, and coding/verification intent as composer prompts. The digest
  normally shows up to three recent command evidence rows, then expands to the
  full focused-check batch when the newest command group matches those presets,
  so the batch remains visible while the newest bash result is still easy to act
  on.
- Failed command evidence rows use a `修复` primary action that queues a
  `Fix failed command ...` prompt through the same `SendUserInput` path,
  carrying the output path when Pi provided one and the same context/focus
  wrapper as analysis prompts. This keeps the fix loop inside the shared app
  model instead of adding an output-opening bridge or native-only command
  shortcut.
- Command evidence rows in the Activity digest can be rerun from the UI. The
  action reuses the existing shared-app `QueueCommand` reducer and native Pi
  RPC `bash` encoder instead of adding a separate native shortcut.
- The Activity digest also exposes compact focused-check presets for the
  Workbench app package native test, app package wasm-gc test, macOS Skia
  entrypoint build, and macOS Skia first-frame smoke. They use the same
  `QueueCommand` / Pi RPC `bash` path as manual command reruns, so validation
  evidence stays in the shared model.
  The `全部` action queues all four checks in one platform-neutral command
  batch, reusing a single session start and recording each check as its own
  `CommandRun`; the Activity digest keeps those four recent command rows
  visible together for inspection or rerun.
- The Activity digest surfaces the latest shared-app timeline event, so Pi RPC,
  streaming agent, tool, and stderr progress stays visible next to command
  evidence without opening a separate log view. The visible event can also be
  sent back as a follow-up prompt through the shared app command path.
- Session selection now refreshes Pi messages after state binding. The shared
  app maps Pi RPC `get_messages` responses into generic `TranscriptItem`
  records so the conversation surface can replay user, assistant, tool result,
  bash, compaction, branch summary, and future workflow messages.
- Visible transcript rows can send a follow-up prompt through `SendUserInput`.
  The action keeps the transcript model generic while letting coding-agent users
  continue from a specific user, assistant, bash, or tool message.
- Session selection also refreshes Pi's available command catalog through
  `get_commands`. The shared app maps prompt, extension, and skill commands
  into generic `PiCommandInfo` rows so coding-agent command discovery can later
  grow into document, research, automation, and knowledge workflows without
  changing the platform-neutral transport contract.
- Session selection and manual refresh also query Pi's available model catalog
  through `get_available_models`. The shared app normalizes provider/id/name
  rows into `PiModelInfo` and shows a compact session-panel summary only when
  models are reported, keeping no-model offline smoke quiet.
- The model catalog summary has compact use/cycle actions. The shared app emits
  platform-neutral `SetRpcModel` for the visible model and `CycleRpcModel` for
  Pi's scoped model cycle, ingests `set_model` and `cycle_model` responses, and
  updates the active `PiSessionBinding` model plus thinking level when Pi
  reports a new scoped model.
- The session panel has a manual context compaction action. The shared app emits
  platform-neutral `CompactRpcSession`, ingests successful `compact` responses
  into the transcript as compaction summaries, and records offline/no-provider
  failures as normal Pi RPC diagnostics.
- The command catalog can invoke a listed command by sending `/<name>` through
  the existing platform-neutral `SendUserInput` prompt path. This keeps slash
  command execution usable in the native UI without adding a native-only
  transport command or process bridge. Typed slash prompts such as `/review`
  are sent raw rather than wrapped in composer context.
- The composer now shows a compact slash-command suggestion strip only when Pi
  has returned a command catalog and the user starts the prompt with `/`. The
  slash mode hides context/focus/steering controls because slash prompts are
  sent raw, filters `PiCommandInfo` commands by the typed query, lists up to
  three matches near the prompt input, and each shortcut reuses the same
  `InvokeCommand` / `SendUserInput` route while catalog-only refreshes do not
  add Activity command rows or focused-check presets.
- Session selection refreshes Pi session stats through `get_session_stats`.
  The shared app maps message counts, tool counts, token totals, cost, and
  optional context usage into `PiSessionStatsSnapshot`, then surfaces compact
  metrics in the session status panel without adding native-only state.
- The session panel can export the current Pi session through `export_html`.
  The shared app emits `ExportRpcSessionHtml`, ingests Pi's returned path as
  `FileContext` evidence in the Workspace digest, and keeps the export artifact
  in app state rather than adding a native file-opening bridge.
- The workbench can explicitly sync the selected Workbench session title into
  Pi through `set_session_name`. Pi's `session_info_changed` event updates the
  same `PiSessionBinding`, so user-visible Workbench session identity and Pi's
  runtime session display name stay aligned without native-only state.
- The session panel can request a fresh Pi session through a platform-neutral
  `NewRpcSession` command. The native encoder emits `{"type":"new_session"}`,
  then the shared app waits for the `new_session` success response before
  queuing the state, message, fork-candidate, command catalog, and stats
  refresh. This keeps the Workbench-to-Pi binding updated from Pi's next
  `get_state` response rather than from native process state or JSONL write
  order.
- The session panel can discover Pi fork points through `get_fork_messages`.
  The shared app stores Pi's `{entryId,text}` rows as `PiForkMessage` values,
  shows a compact fork affordance in the transcript panel only when candidates
  exist, and sends `ForkRpcSession(session, entryId)` for the selected user
  message. After an uncancelled `fork` response, the app waits for the
  acknowledgement before refreshing state, messages, fork candidates, command
  catalog, and stats so Pi's new session file remains the source of truth.
- The workbench can cycle Pi's thinking level from the session status panel.
  The shared app emits a platform-neutral `CycleRpcThinkingLevel` command,
  ingests `cycle_thinking_level` responses and `thinking_level_changed` events,
  and keeps `PiAgentSnapshot.thinking_level` visible without native-only state.
- The composer exposes compact steering and follow-up mode controls only inside
  expanded composer options or when Pi reports non-default queue modes. The
  shared app emits platform-neutral `SetRpcSteeringMode` and
  `SetRpcFollowUpMode` commands, ingests their acknowledgements, and refreshes
  both modes from `get_state` so Pi remains the source of truth for input queue
  policy. The same optional composer row also has explicit steering and
  follow-up submit actions:
  `SendSteeringInput` maps to Pi RPC `steer`, while `SendFollowUpInput` maps to
  Pi RPC `follow_up`.
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
  rows. Successful `get_fork_messages` responses replace the visible fork
  candidate list with normalized `PiForkMessage` rows containing Pi's fork
  `entryId` and display text. Successful `fork` responses mark the binding as
  forking or cancelled; accepted forks then trigger the same chained refresh as
  new-session creation. Successful `get_available_models` responses replace
  the visible model catalog with normalized `PiModelInfo` rows that preserve
  provider, id, name, and a display label. Successful `get_commands` responses
  replace the visible command catalog with normalized `PiCommandInfo` rows that
  preserve command name, kind, description, source scope, and source path.
  Successful
  `get_session_stats` responses refresh `PiSessionStatsSnapshot` with message,
  tool, token, cost, and optional context counters. Successful `export_html`
  responses add the returned HTML path as Workspace file evidence. Successful
  `set_model` responses update the active Workbench-to-Pi binding and session
  summary with Pi's selected model. Successful `cycle_model` responses do the
  same when Pi returns a new scoped model, or acknowledge that no alternate
  model is available when Pi returns `null`. Successful `compact` responses append the
  returned summary to the transcript and update the active Workbench session
  summary with the pre-compaction token count when Pi reports it. Successful
  `cycle_thinking_level` responses update the agent snapshot when Pi returns
  the new level, while
  `thinking_level_changed` events remain the authoritative stream update.
  Successful `set_steering_mode` and `set_follow_up_mode` responses acknowledge
  the compact optional composer controls; `get_state` refreshes the current mode
  values.
  Successful `steer` and `follow_up` responses acknowledge explicit queued
  steering/follow-up input submissions, while `queue_update` remains the source
  of truth for visible queued input counts.
  Successful `set_session_name` responses mark the session-name sync as
  acknowledged; the preceding
  `session_info_changed` event carries the actual display name and updates
  `PiSessionBinding`. Successful `bash` responses mark the next queued/running
  Workbench command as passed, failed, or cancelled, preserving FIFO attribution
  for batched checks even when Pi's response only says `command: "bash"`, and
  add diagnostics for nonzero, missing, truncated, or cancelled output. Visible
  bash evidence can be sent back as a prompt for analysis through the same
  app-layer command path. Failed RPC responses append a diagnostic without
  involving the native transport layer.
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
  no-model smoke paths using offline `get_state`, `new_session`, `get_messages`,
  `get_available_models`, `get_fork_messages`, `get_commands`,
  `get_session_stats`, `set_model`, `cycle_model`, `compact`, `cycle_thinking_level`, `set_steering_mode`,
  `set_follow_up_mode`,
  `steer`, `follow_up`, `set_session_name`, and `abort_bash` over
  `pi --mode rpc`; it also records
  the expected `export_html`, `set_model`, and `compact` failure boundaries for
  in-memory `--no-session` smoke runs.

The remaining V1 transport boundary is production lifecycle polish: the native
owner now keeps one process alive across real runtime dispatches, reports
stderr/nonzero-exit failures, restarts after unexpected child exits, speaks the
current Pi RPC command names, and the shared app ingests command responses,
streaming session events, and Workbench-to-Pi session bindings. The next
transport slice should add real end-to-end prompt smoke evidence when a model
can be used safely and broaden fork smoke evidence once a persisted session
with real user-message entry ids is available.

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
{"type":"plan_update","steps":[{"id":"inspect","title":"Inspect renderer path","status":"done","owner":"Pi","detail":"Core route mapped"},{"id":"fix","title":"Fix Skia smoke","status":"in_progress","owner":"Pi","detail":"Run focused checks"}]}
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
`{"type":"response","command":"get_available_models","success":true,...}` line
replaces the compact model catalog with normalized `PiModelInfo` rows and shows
a session-panel model summary only when Pi reports at least one model. A
successful
`{"type":"response","command":"get_fork_messages","success":true,...}` line
fills compact fork candidates from Pi's `messages[].entryId` and
`messages[].text` values. A successful
`{"type":"response","command":"get_commands","success":true,...}` line replaces
the visible command catalog with normalized `PiCommandInfo` rows for prompt,
extension, and skill commands. A successful
`{"type":"response","command":"get_session_stats","success":true,...}` line
refreshes `PiSessionStatsSnapshot` with message/tool/token/context metrics and
updates the Workbench-to-Pi binding from the reported `sessionId` and
`sessionFile`. A successful
`{"type":"response","command":"export_html","success":true,...}` line adds the
returned HTML path as a Workspace file evidence row, so exported Pi sessions can
become coding, documentation, or knowledge artifacts without native-only state.
A successful
`{"type":"response","command":"set_model","success":true,...}` line updates
the active binding model and status panel from Pi's returned model object.
Failed `set_model` responses, such as no matching model in offline smoke, use
the normal Pi RPC diagnostic path. A successful
`{"type":"response","command":"cycle_model","success":true,...}` line updates
the active binding model and status panel when Pi returns a model. If Pi
returns `data:null`, the app records the acknowledgement without changing the
current model. A successful
`{"type":"response","command":"compact","success":true,...}` line appends Pi's
returned compaction summary to the transcript and updates the active session
summary with `tokensBefore` when Pi reports it. A failed compact response, such
as the no-provider response from offline smoke, is recorded through the normal
Pi RPC diagnostic path. A successful
`{"type":"response","command":"cycle_thinking_level","success":true,...}` line
acknowledges the compact `思考` control and, when Pi includes a `data.level`,
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
{"type":"get_available_models"}
{"type":"get_messages"}
{"type":"get_fork_messages"}
{"type":"get_commands"}
{"type":"get_session_stats"}
```

The `switch_session` response marks the Workbench session binding as switching
or cancelled. The following `get_state` response binds that Workbench session id
to Pi's concrete `sessionId`, `sessionFile`, optional `sessionName`, and current
model plus thinking, steering, and follow-up modes. The following
`get_available_models` response fills the compact model catalog from Pi's model
registry, the following `get_messages` response fills the transcript panel from
Pi's `AgentMessage[]`, the following `get_fork_messages` response fills the
fork affordance from Pi's user-message entry ids, and the following
`get_commands` response fills the command catalog from Pi's slash command
registry. Invoking a catalog row sends `/<name>` through the same prompt RPC
channel used by manual user input. The following `get_session_stats` response
fills the compact status metrics from Pi's session statistics. This keeps
`PiTransportEvent` platform-neutral while letting the app separate Mo Workbench
sidebar ids from Pi's runtime session identity.

Manual refresh uses the same app-layer batch without changing the selected
Workbench session. This gives the macOS Skia UI a direct resync affordance while
keeping process ownership in the native async transport and state ownership in
the shared app package.

The top bar's new-session control first queues:

```json
{"type":"new_session"}
```

After the `new_session` success response arrives, `ReceiveTransport` queues a
second platform-neutral refresh batch:

```json
{"type":"get_state"}
{"type":"get_available_models"}
{"type":"get_messages"}
{"type":"get_fork_messages"}
{"type":"get_commands"}
{"type":"get_session_stats"}
```

The `new_session` response marks the current Workbench session binding as
creating or cancelled. If Pi accepts the request, the chained `get_state`
response binds the Workbench session id to Pi's fresh `sessionId` /
`sessionFile` / `sessionName`, keeping session creation in the
platform-neutral command/event contract. Pi 0.77.0 accepts `new_session` over
RPC, but batched follow-up reads can be answered before the `new_session`
acknowledgement, so Mo Workbench intentionally waits for that acknowledgement
before refreshing.

Forking follows the same acknowledgement-first pattern. `get_fork_messages`
returns user-message fork points:

```json
{"type":"response","command":"get_fork_messages","success":true,"data":{"messages":[{"entryId":"entry-user-1","text":"Inspect the Skia route"}]}}
```

Selecting a fork candidate sends:

```json
{"type":"fork","entryId":"entry-user-1"}
```

If Pi accepts the fork, Mo Workbench queues the same second-stage refresh batch
shown above and binds the Workbench session id from the next `get_state`
response. If Pi reports `cancelled:true`, the binding records the cancellation
and no refresh is queued.

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
`FetchRpcAvailableModels` sends `{"type":"get_available_models"}`,
`FetchRpcMessages` sends `{"type":"get_messages"}`,
`FetchRpcForkMessages` sends `{"type":"get_fork_messages"}`,
`FetchRpcCommands` sends `{"type":"get_commands"}`,
`FetchRpcSessionStats` sends `{"type":"get_session_stats"}`,
`ForkRpcSession` sends `{"type":"fork","entryId":...}`,
`ExportRpcSessionHtml` sends `{"type":"export_html"}` or includes
`"outputPath"` when the app supplies one,
`SetRpcModel` sends
`{"type":"set_model","provider":...,"modelId":...}`,
`CycleRpcModel` sends `{"type":"cycle_model"}`,
`CompactRpcSession` sends `{"type":"compact"}` or includes
`"customInstructions"` when the app supplies them,
`CycleRpcThinkingLevel` sends `{"type":"cycle_thinking_level"}`,
`SetRpcSteeringMode` sends `{"type":"set_steering_mode","mode":...}`,
`SetRpcFollowUpMode` sends `{"type":"set_follow_up_mode","mode":...}`,
`NewRpcSession` sends `{"type":"new_session"}`,
`SwitchRpcSession` sends `{"type":"switch_session","sessionPath":...}`,
`SetRpcSessionName` sends `{"type":"set_session_name","name":...}`,
`SendUserInput` sends `{"type":"prompt","message":...}`,
`SendSteeringInput` sends `{"type":"steer","message":...}`,
`SendFollowUpInput` sends `{"type":"follow_up","message":...}`, `RunShellCommand`
sends `{"type":"bash","command":...}`, `CancelShellCommand` sends
`{"type":"abort_bash"}`, `CancelRpcRun` sends `{"type":"abort"}`, and
`Shutdown` closes stdin instead of sending a JSON command. Workbench session ids
remain part of the Mo Workbench event labels and state; `PiSessionBinding`
records which concrete Pi session the current process reported for each
Workbench session.

The smallest real CLI smoke does not require a successful model call and
validates the stdin/stdout contract only:

```sh
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

The first command should return a JSONL `response` object for `get_state`, the
second should return a successful `new_session` acknowledgement, the third
should return a `get_messages` response with a `messages` array, the fourth
should return a `get_available_models` response with a `models` array, the fifth
should return a `get_fork_messages` response with a fork `messages` array, the
sixth should return a `get_commands` response with a `commands` array, the
seventh should return a `get_session_stats` response with message, tool, token,
and cost counters, the eighth should return an `export_html` failure explaining
that in-memory `--no-session` sessions cannot be exported, the ninth should
return a failed `set_model` response when the offline smoke has no matching
model, the tenth should return a successful `cycle_model` response with
`data:null` when no alternate scoped model is available, the eleventh should
emit compaction start/end events
and return a failed `compact` response when the offline smoke has no API
provider available for compaction, the twelfth should return a successful
`cycle_thinking_level` acknowledgement, the
thirteenth and fourteenth should acknowledge the steering/follow-up mode changes,
the fifteenth and sixteenth should emit `queue_update` events and acknowledge
the explicit steering/follow-up inputs, the seventeenth should emit
`session_info_changed` and a successful
`set_session_name` response, and the eighteenth should return a successful
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

When real Skia is configured locally, also run:

```sh
MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/mo_workbench/macos_skia --target native
```
