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
  emits stdout/process events back through the app runtime dispatch hook.
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
  and shutdown.
- Typed transport events for process lifecycle, JSONL sent/received lines, and
  failures.
- A platform-neutral `PiTransportRuntime` that turns command batches into
  MoUI effects, so prompt, command, and cancel actions can dispatch transport
  events back through the same TEA message loop.
- A native-only async transport package whose default command is
  `pi --mode rpc`, maps command batches to Pi JSONL request lines, and uses
  shell fixtures to prove direct JSONL stdin/stdout process driving without C
  FFI or a Node bridge.
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

The remaining V1 transport boundary is production lifecycle polish: the native
owner now keeps one process alive across real runtime dispatches, and the next
slice should handle unexpected process exit, restart policy, stderr/error
surfacing, and real `pi --mode rpc` smoke evidence when the local Pi CLI is
available.

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
```

When real Skia is configured locally, also run:

```sh
MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/mo_workbench/macos_skia --target native
```
