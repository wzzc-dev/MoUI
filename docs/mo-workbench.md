# Mo Workbench

Mo Workbench is a macOS Skia native-first, Codex-style agent desktop prototype.
Its product target is a multi-backend coding-agent workbench in the spirit of
Codex or Claude Code desktop: project sessions, code understanding, task
planning, execution feedback, diff and file context, command queues, and
diagnostics all live in one session-first surface.

The visible subtitle is **Agent 桌面工作台**. The app is deliberately not modeled
as a Pi-only client or only a code editor. Pi RPC is the first real backend
provider, while the Local (`fixture`) smoke backend is used to verify backend
switching and the quiet default UI. The same session, backend capability,
transport event, context, plan, command, and diagnostic concepts should later
support Codex, Claude, other local agents, document workflows, research,
automation runs, and knowledge organization.

## Package Shape

- `examples/mo_workbench/app` owns the shared TEA model, view composition,
  sample fixtures, agent backend profiles and capabilities, platform-neutral Pi
  transport event model for the Pi provider, and injectable
  `PiTransportRuntime` effect boundary. It also owns the backend-neutral
  `AgentBackendTransportKind`, agent connector profile/state/command/event
  model, injectable `AgentConnectorRuntime`, and UI projections that keep the
  shell from depending on Pi-specific state.
  Its public package surface is intentionally narrow: app consumers use
  `runtime`, `runtime_with_transport`, `runtime_with_agent_connectors`,
  `MoWorkbenchApp`, the Pi transport command/event/runtime protocol, and the
  agent connector profile/command/event/runtime protocol. The TEA model,
  messages, update helpers, selector/projection structs, and connector state
  remain package-internal white-box test surface.
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
  `backend/macos/skia`, injects the owned native Pi transport runtime plus the
  ACP Demo fixture connector runtime, and runs the shared app runtime with the
  macOS Skia async pump.
- Future Web or other native entrypoints should reuse the same app package.
  Pi-capable entrypoints feed the same `PiTransportCommand` / `PiTransportEvent`
  model, while additional providers should plug in through the agent connector
  profile/capability boundary instead of making the product shell Pi-only.

## Agent Connector Boundary

Mo Workbench is Pi-first, not Pi-only. The default backend registry exposes
three profiles:

- `Pi` uses `PiJsonlRpcTransport` and remains the only real provider in this
  slice.
- `ACP Demo` uses `AcpConnectorTransport` and a fixture
  `AgentConnectorRuntime`. It loads `agentprofile`-style metadata, binds a
  demo provider session, accepts session/message/command requests, and emits
  JSON-shaped connector events back through the shared TEA loop.
- `Local` uses `FixtureTransport` and keeps prompt evidence inside the shared
  model for UI switching smoke tests.

The connector public protocol is intentionally small:
`AgentConnectorProfile`, `AgentConnectorCommand`, `AgentConnectorEvent`, and
`AgentConnectorRuntime`. Connector state is owned inside the app package. The UI
consumes package-internal backend-neutral projections for Pi and
connector-backed agents: run overview, activity queue, request summaries,
provider registry, composer routing, composer request summary, timeline, status
bar, session binding, runtime signal, command catalog, and metrics.

ACP v1 is a framework placeholder only. It records the product shape needed by
Agent Connect Protocol style discovery and messaging, but it does not implement
HTTPS, WSS, SSE, remote authentication, heartbeat, remote message delivery, or
network reconnection. Those concerns belong in a later connector-runtime slice,
outside the Codex-like UI and shared projection work.

## Current Vertical Slice

The current slices establish the dogfood app without changing framework
packages:

- A session-first desktop shell named `Mo Workbench`.
- Header subtitle `Agent 桌面工作台`.
- The default top bar keeps only session identity; the current-agent chip
  appears there only for non-default backends or provider failures, while
  normal Pi startup/running state stays in the compact `Agent：...` task signal.
  Hidden backend/status chips no longer reserve layout width, so quiet sessions
  give that space back to the current title and project line.
  The backend selector lives inside a compact expanded-composer `Agent` row with
  refresh/new-session actions, with Pi as the first real provider and Local as
  the UI/switching smoke provider; provider descriptions stay out of the row so
  the expanded composer does not read like a backend configuration panel.
  Each Workbench session records a `backend_id`; switching the current session
  backend clears provider transcript, catalog, fork, metrics, command,
  diagnostic, and transport state so backend-specific evidence does not leak
  across providers. Backend switch events stay as control history and do not
  create a `当前证据` card by themselves.
- Agent backend capabilities gate advanced UI. Pi exposes session refresh, new
  session, model and command catalogs, fork, HTML export, context compaction,
  thinking level, input queue modes, shell commands, and session stats. ACP Demo
  exposes connector-backed session refresh, session creation, command catalog,
  and message/stat fixture signals without pretending to be a network provider.
  Local keeps the prompt flow local and intentionally hides Pi-only controls,
  proving the shell can remain useful without looking like an RPC diagnostics
  panel.
- Backend chrome consumes a small `AgentBackendStatus` projection. The sidebar
  footer and top-bar backend chip decide from backend-neutral status instead of
  raw Pi transport state, so normal Pi startup/running activity stays in the
  compact task signal while non-default backends and provider failures remain
  visible without turning the shell into a transport panel.
- A Codex / Claude Code-style native shell with macOS chrome, a quiet
  task-history sidebar, a clean white main work canvas, readable compact
  transcript rows, current-turn evidence summaries, and a bottom composer.
  The sidebar now includes a default-visible `新对话` entry that creates and
  selects a new Workbench session in task history immediately. The lower-level
  Pi `新会话` RPC control stays in expanded composer options for replacing the
  active provider session binding. New user prompts, local fixture replies, Pi
  streaming/response events, and queued command evidence pin the main scroll to
  the latest content so the conversation does not remain above the newest
  message.
- macOS Skia native entrypoint as a normal interactive app; first-frame smoke
  lives in `moui_tester` rather than this app package.
- A platform-neutral `PiTransportState` with native JSONL, Web bridge, and
  fixture transport kinds for the Pi provider path. Empty command batches no
  longer mark the transport as starting, so non-Pi fixture backend actions can
  remain local without fake transport activity.
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
  compact Agent status, and the next prompt in one visible flow. The visible
  shell now uses a compact Codex-like chrome that follows the runtime
  light/dark color scheme, with low-contrast panel borders, distinct
  sidebar/main/status surfaces, and slightly raised cards for conversation,
  composer, and inspector content. A lower-left `设置` entry opens a dedicated
  settings page for appearance mode, composer/detail visibility, context scope,
  and backend selection. The current shell is rebuilt from
  `ViewEnvironment.viewport_size()` instead of a fixed
  `1200x750` surface, so the macOS Skia runtime responds to window resize
  events with adaptive sidebar, scroll, and composer dimensions. The main
  canvas now follows Codex's hierarchy: a compact `当前任务` strip for the
  single next action, transcript rows as the primary conversation thread, and
  at most one `当前证据` card for the most relevant command, event, diagnostic,
  diff, or file signal. The old separate `会话记录`, `运行证据`, and `工作区证据`
  panel titles no longer compete for attention once data arrives. The default
  chrome shows one two-line current-session identity with shortened title,
  project, and branch labels plus signal-bearing localized session status
  labels, while full project paths remain in the shared model and Pi transport
  commands. The default shell keeps the top bar to identity, gives hidden chip
  and removed action-button space back to the session title, shows the
  current-agent chip there only when it carries non-default backend or failure
  signal, and moves backend switching plus refresh/new-session controls into one
  compact expanded-composer `Agent` row. The bottom composer input stays
  prominent, while typed input adds a compact `选项`/`发送` row instead of
  opening every secondary control. Context chips, agent focus controls,
  advanced session details, model/session stats,
  steering/follow-up composer controls, and focused-check presets stay collapsed
  until expanded options, non-default context, selected focus, or actionable
  diagnostics make them relevant. Expanded session details separate information
  rows from actions: binding, model, and metrics can render without fanning out
  fork/export/compact/thinking/name-sync buttons, and each advanced action now
  appears only with matching transcript, metrics, thinking, or name-mismatch
  evidence. The sidebar defaults to brand and task history only; project and
  branch identity stay in the top bar instead of repeating as a separate
  workspace card or empty-state line. The
  default fixture still leaves transcript, metrics, command catalog, file
  context, diff summary, command evidence, and diagnostics empty until Pi or
  user command evidence arrives. When the main conversation has no task,
  transcript, or evidence yet, it shows only a quiet two-line session prompt
  instead of mounting fake task or evidence cards.
- Wide Workbench windows now use a clear three-panel workbench shell: task
  history sidebar, conversation/composer column, and a right inspector. The
  inspector has compact `上下文`, `运行`, and `诊断` tabs, auto-selects the most
  actionable panel for diagnostics, command/tool output, file/diff context, or
  activity events, and keeps empty states quiet when no evidence has arrived.
  The context tab shows session/project/branch scope plus file and diff cards,
  the run tab shows active tools, activity events, focused-check batches, and
  expandable command output, and the diagnostics tab shows fix/clear actions
  plus focused-check shortcuts. Compact windows collapse the inspector and keep
  the older single `当前证据` card inside the conversation flow.
- The main workspace now has a low-noise bottom status bar. It reports the
  latest user-facing reducer status and only mounts queue, context, diagnostic,
  run, or file counters when they carry signal, avoiding default `0` value
  chrome while still making interaction state verifiable.
- Transcript rows no longer expose a message-level `跟进` action. Pi fork
  candidates are still fetched and can still queue a `fork` RPC, but matching
  candidates render as a compact Codex-style `分叉` affordance directly under
  the corresponding assistant reply. When Pi returns a fork `entryId` for a
  user message, the app attaches that fork action to the following assistant
  reply instead of collecting fork rows at the end of the transcript.
- Pi `message_end` and non-retry `agent_end` JSONL events merge assistant replies
  into the local transcript immediately, then queue a lightweight
  messages/forks/stats refresh to reconcile the formal RPC state.
- While Pi is running, streaming agent events, active tools, and command
  evidence remain visible. Once the final assistant reply completes, that
  process evidence is collapsed into a compact `已处理` row beside the reply;
  expanding it reveals the tool, command, and event trail without making the
  final answer compete with the processing log. Assistant `thinking` /
  `toolCall` blocks and Pi `toolResult` / bash transcript entries are kept as
  process evidence instead of ordinary conversation rows.
- Agent focus controls for `通用`, `编码`, and `校验` now share the composer's
  compact `范围` row with repository, examples, evidence, and backend-session
  context chips. That row appears after opening composer options, after
  selecting a focus, or after changing the default context, keeping scope and
  role selection to one quiet line instead of separate settings rows. Selecting
  a role does not create a native-only worker or transport command; it appends
  an `agent focus: ...` hint to the existing prompt, steering, and follow-up
  text context before the shared app emits the same platform-neutral
  `SendUserInput`, `SendSteeringInput`, or `SendFollowUpInput` commands.
- Pi `plan_update` JSONL now fills the existing shared-app `PlanStep` model and
  renders a compact `当前计划` row in the current task strip. The row shows
  the current active/open step, open-step count, and a `继续` action that reuses
  the platform-neutral follow-up prompt path.
- The current task strip now derives one `下一步` row from live state when
  there is actionable evidence. It prioritizes cancelable Pi runs, failed
  command evidence, diagnostics, active plan steps, reviewable diffs, file
  context, and other independent action signals,
  then routes the chosen button back through the existing shared-app messages
  such as `CancelRun`, `FixCommandRun`, `FixDiagnostic`, `InspectCommandRun`,
  `FollowActivity`, `ReviewDiff`, `InspectFile`, or `InvokeCommand`.
  Generic transcript-only and event-only activity no longer creates a duplicate
  `下一步` row. Failed-command next actions include a compact command label,
  exit code, and output path when Pi provided them, so the repair loop has the
  same evidence as the current-turn evidence card without opening another panel.
- Direct prompt, steering, and follow-up submits prefix the selected context
  labels into the text payload before it enters the existing platform-neutral
  `SendUserInput`, `SendSteeringInput`, or `SendFollowUpInput` paths; no new
  transport command or native bridge is required, and users can turn all scope
  chips off to send the raw text.
- Current-turn event rows are read-only process evidence in the shell. They
  keep Pi RPC, stderr, tool, and stream state inspectable without adding
  message-level follow-up controls or event-specific transport commands.
- File context rows in the current-turn evidence card can queue an `Inspect <path>`
  prompt for Pi. The action reuses the platform-neutral `SendUserInput` command
  so file evidence becomes an agent workflow entrypoint without native-only
  transport.
- The compact workspace summary queues a `Review diff: ...` prompt through
  the same path, making code review a first-class coding-agent action while
  keeping PiTransport platform-neutral. It defaults to a one-line files, diff,
  and diagnostic summary and expands the current diff details only on demand.
- Latest diagnostic rows in the current-turn evidence card can queue a
  `Fix <severity> diagnostic from <source>: ...` prompt through
  `SendUserInput`, preserving the current context chips and selected agent
  focus while turning build/check failures into the next coding-agent task
  without adding a diagnostic-specific native transport command.
- Pending transport command counts now drain as `JsonLineSent` events arrive
  and clear on process exit or failure, so the visible queue reflects work
  still waiting to be handed to Pi instead of a historical command log.
- The current session can be refreshed manually from the expanded composer
  `Agent` row. The shared app reuses the same platform-neutral command batch as
  session selection: state, messages, command catalog, and session stats.
- Workbench command queue entries now use Pi RPC `bash` directly instead of
  prompt text such as `run: ...`; the shared app keeps command/cwd evidence and
  lets the native encoder emit `{"type":"bash","command":...}`. Successful
  bash responses preserve Pi's optional `fullOutputPath`, stdout preview, and
  truncation flag on `CommandRun`. Current-turn command rows default to a compact
  status/command/result summary; the log path and stdout detail are mounted only
  after expanding that command row.
- Command evidence rows in the current-turn evidence card can queue an
  `Inspect command output for ...` prompt through `SendUserInput`, carrying the
  command text, status, exit code, cwd, and output path back into Pi without
  adding a native-only output-opening bridge. These prompts preserve the current
  context chips and selected agent focus, so evidence actions keep the same
  repo, examples, and coding/verification intent as composer prompts. Outside a
  focused-check batch, the card chooses the highest-priority command evidence:
  failed first, active next, latest otherwise.
- Failed command evidence rows use a `修复` primary action that queues a
  `Fix failed command ...` prompt through the same `SendUserInput` path,
  carrying the exit code and output path when Pi provided them plus the same
  context/focus wrapper as analysis prompts. This keeps the fix loop inside the
  shared app model instead of adding an output-opening bridge or native-only
  command shortcut. The `下一步` row mirrors the latest failed
  command's exit code and output path, keeping the next repair action
  self-contained. When a Pi bash failure or cancellation already has visible
  command evidence, the evidence card suppresses that duplicate bash
  diagnostic row and leaves the command row plus `下一步` repair action as the
  primary signal; unrelated structured diagnostics still surface normally.
- Command evidence rows in the current-turn evidence card can be rerun from the UI. The
  action reuses the existing shared-app `QueueCommand` reducer and native Pi
  RPC `bash` encoder instead of adding a separate native shortcut.
- The current-turn evidence card exposes compact focused-check presets for the Workbench
  app package native test, app package wasm-gc test, macOS Skia entrypoint
  build, and macOS Skia first-frame smoke only when actionable diagnostics need
  a validation entry and no command evidence is already displayed. Once command
  evidence exists, the card keeps the command row primary and relies on its
  inline `分析`, `修复`, and `重跑` actions instead of adding another preset row.
  The presets use the same `QueueCommand` / Pi RPC `bash` path as manual command
  reruns, so validation evidence stays in the shared model.
  The `全部` action queues all four checks in one platform-neutral command
  batch, reusing a single session start and recording each check as its own
  `CommandRun`; the evidence card keeps those four focused-check rows
  visible together for inspection or rerun.
- The current-turn evidence card ignores raw transport lifecycle events such as
  process start and JSONL send/receive; normal backend activity is summarized as
  a compact `Agent：...` task signal instead. It still surfaces actionable
  agent/tool/diagnostic timeline events when no higher-priority command evidence
  is present, so useful progress stays inspectable without turning the shell
  back into a transport log. Event rows are read-only shell evidence and no
  longer expose message-level follow-up controls.
- Session selection now refreshes Pi messages after state binding. The shared
  app maps Pi RPC `get_messages` responses into generic `TranscriptItem`
  records so the conversation surface can replay user, assistant, tool result,
  bash, compaction, branch summary, and future workflow messages.
- Session selection also refreshes Pi's available command catalog through
  `get_commands`. The shared app maps prompt, extension, and skill commands
  into Pi-provider `PiCommandInfo` rows, then projects them to backend-neutral
  `AgentCommandInfo` values for composer filtering and display so coding-agent
  command discovery can later grow into document, research, automation, and
  knowledge workflows without changing the platform-neutral transport contract.
- Session selection and manual refresh also query Pi's available model catalog
  through `get_available_models`. The shared app normalizes provider/id/name
  rows into Pi-provider `PiModelInfo`, then projects them to backend-neutral
  `AgentModelInfo` values before the UI renders expanded secondary session
  details, keeping no-model offline smoke quiet.
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
  sent raw, filters `AgentCommandInfo` commands by the typed query, lists up to
  three matches near the prompt input, and each shortcut reuses the same
  `InvokeCommand` / `SendUserInput` route while catalog-only refreshes do not
  add current-turn command rows or focused-check presets.
- Session selection refreshes Pi session stats through `get_session_stats`.
  The shared app maps message counts, tool counts, token totals, cost, and
  optional context usage into `PiSessionStatsSnapshot`, then projects them to
  backend-neutral `AgentSessionMetrics` before the expanded secondary session
  details render compact metrics without adding native-only state.
- The session panel can export the current Pi session through `export_html`
  once transcript evidence exists. The shared app emits `ExportRpcSessionHtml`,
  ingests Pi's returned path as `FileContext` evidence in the current-turn
  evidence card, and keeps the export artifact in app state rather than adding a
  native file-opening bridge.
- The workbench can explicitly sync the selected Workbench session title into
  Pi through `set_session_name` when the provider name is missing or differs
  from the Workbench title. Pi's `session_info_changed` event updates the same
  `PiSessionBinding`, so user-visible Workbench session identity and Pi's
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
  projects them to backend-neutral `AgentForkPoint` rows, shows a compact fork
  affordance in the transcript panel only when candidates exist, and sends
  `ForkRpcSession(session, entryId)` for the selected user message. After an
  uncancelled `fork` response, the app waits for the
  acknowledgement before refreshing state, messages, fork candidates, command
  catalog, and stats so Pi's new session file remains the source of truth.
- The workbench can cycle Pi's thinking level from the session status panel
  after Pi reports a thinking-level state. The shared app emits a
  platform-neutral `CycleRpcThinkingLevel` command, ingests
  `cycle_thinking_level` responses and `thinking_level_changed` events, and
  keeps `PiAgentSnapshot.thinking_level` visible without native-only state.
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
  `entryId` and display text; the transcript consumes their `AgentForkPoint`
  projection. Successful `fork` responses mark the binding as forking or
  cancelled; accepted forks then trigger the same chained refresh as
  new-session creation. Successful `get_available_models` responses replace
  the provider model catalog with normalized `PiModelInfo` rows that preserve
  provider, id, name, and a display label; the session panel consumes their
  `AgentModelInfo` projection. Successful `get_commands` responses
  replace the provider command catalog with normalized `PiCommandInfo` rows that
  preserve command name, kind, description, source scope, and source path; the
  composer consumes their `AgentCommandInfo` projection.
  Successful
  `get_session_stats` responses refresh `PiSessionStatsSnapshot` with message,
  tool, token, cost, and optional context counters; the UI consumes their
  `AgentSessionMetrics` projection. Successful `export_html`
  responses add the returned HTML path as current-turn file evidence. Successful
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
  add diagnostics for nonzero, missing, truncated, or cancelled output. The
  shared app stores stdout and optional log paths on command evidence so the UI
  can expand details locally; visible bash evidence can still be sent back as a
  prompt for analysis through the same app-layer command path. Failed RPC
  responses append a diagnostic without involving the native transport layer.
- Pi RPC session event ingestion for the real streaming protocol. The shared
  app now recognizes `agent_start` / `agent_end`, `turn_start` / `turn_end`,
  `message_start` / `message_update` / `message_end`, `tool_execution_*`,
  `queue_update`, thinking-level changes, compaction, and auto-retry events.
  These update a small `PiAgentSnapshot`, selected-session status, timeline
  entries, and command evidence. Tool execution results can attach stdout/log
  evidence to the matching command row while keeping stdout payload parsing out
  of the native transport package.
- Workbench session ids now have explicit backend session bindings. A
  `WorkbenchSession` can carry a `pi_session_path`; selecting that session
  through an injected transport emits a platform-neutral `SwitchRpcSession`
  followed by a `get_state` refresh. `switch_session` and `get_state` responses
  update `PiSessionBinding` entries keyed by Workbench session id, recording the
  live Pi session id, session file, display name, model, and binding status.
  The shared UI consumes the backend-neutral `AgentSessionBinding` projection,
  so expanded secondary session details display a compact backend session row
  with the live provider session name/id and model when Pi has reported them.
- Runtime activity also flows through the backend-neutral `AgentRuntimeSignal`.
  The compact task signal, workflow rail, process summary, and cancellation
  affordance consume that projection instead of reading Pi transport or
  `PiAgentSnapshot` directly, so fixture sessions stay quiet even if stale Pi
  provider state remains in memory.
- Thinking level, steering mode, follow-up mode, and queued input counts flow
  through `AgentInputSettings`. Session controls and composer secondary actions
  consume that backend-neutral projection, keeping Pi queue details out of the
  default product surface and preventing fixture sessions from inheriting stale
  Pi input-mode UI.
- Native stderr surfacing through platform-neutral `ProcessStderr` events,
  warning diagnostics, and timeline entries without parsing stderr as Pi JSONL.
- The current-turn evidence card surfaces the latest non-duplicated diagnostic
  row, with a shared-app `ClearDiagnostics` path still available from the
  current task strip for clearing visible Pi stderr/RPC/bash diagnostics without
  touching native process state. Pi bash exit/cancel diagnostics stay in shared
  state but are hidden from the card when command evidence already shows the
  same failure.
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
replaces the provider model catalog with normalized `PiModelInfo` rows, then
projects them to `AgentModelInfo` for the session-panel summary only when the
active backend supports model catalogs and Pi reports at least one model. A
successful
`{"type":"response","command":"get_fork_messages","success":true,...}` line
fills compact fork candidates from Pi's `messages[].entryId` and
`messages[].text` values. A successful
`{"type":"response","command":"get_commands","success":true,...}` line replaces
the provider command catalog with normalized `PiCommandInfo` rows for prompt,
extension, and skill commands, while the UI uses their `AgentCommandInfo`
projection. A successful
`{"type":"response","command":"get_session_stats","success":true,...}` line
refreshes `PiSessionStatsSnapshot` with message/tool/token/context metrics,
projects it to `AgentSessionMetrics` for expanded session details, and updates
the Workbench-to-Pi binding from the reported `sessionId` and `sessionFile`. A
successful
`{"type":"response","command":"export_html","success":true,...}` line adds the
returned HTML path as a current-turn file evidence row, so exported Pi sessions can
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
`fullOutputPath` fields, and stores the returned stdout on `CommandRun` for
local expand/collapse details. A failed `response` line records a `Pi RPC`
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

The expanded composer session row's new-session control first queues:

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
from `moui_skia`, add clean fallback-safe APIs there first, then
wire MoUI `DrawCommand` support through `render/skia`, update renderer
capability reporting, and add focused tests.

Fallback compilation is not renderer readiness. Real native smoke still
depends on local Skia link flags and should use the existing macOS Skia helper
when validating presenter pixels. Direct local commands such as
`moon run examples/mo_workbench/macos_skia --target native` use the
`moui_skia` prebuild hook for real Skia; set
`MOUI_SKIA_LINK_MODE=dynamic|static|auto` to choose the library mode. Helper
smoke runs can pass `--link-mode dynamic|static|auto` to override the
environment for that invocation.

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

For a local real-Skia app build plus tester first-frame check, run:

```sh
export MOUI_SKIA_LINK_MODE=dynamic
moon build examples/mo_workbench/macos_skia --target native
moon build moui_tester/macos_skia_first_frame_smoke --target native
```
