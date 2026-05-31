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
  sample fixtures, and platform-neutral Pi transport event model.
- `examples/mo_workbench/native_transport` owns the native
  `moonbitlang/async` process driver for JSONL stdin/stdout sessions. It
  imports the shared app package only for `PiTransportEvent`, keeping the app
  model reusable by Web and other future hosts.
- `examples/mo_workbench/macos_skia` is a thin entrypoint that selects
  `backend/macos/skia` and runs the shared app runtime.
- Future Web or other native entrypoints should reuse the same app package and
  feed the same `PiTransportCommand` / `PiTransportEvent` model.

## Current Vertical Slice

The first slice establishes the dogfood app without changing framework
packages:

- A session-first desktop shell named `Mo Workbench`.
- Header subtitle `A Pi agent desktop`.
- macOS Skia native entrypoint with first-frame exit support through
  `MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`.
- A platform-neutral `PiTransportState` with native JSONL, Web bridge, and
  fixture transport kinds.
- Typed transport commands for starting RPC, sending prompts, cancelling runs,
  and shutdown.
- Typed transport events for process lifecycle, JSONL sent/received lines, and
  failures.
- A native-only async transport package whose default command is
  `pi --mode rpc`, with focused tests that use a shell fixture to prove direct
  JSONL stdin/stdout process driving without C FFI or a Node bridge.
- Workbench panels for agent timeline, plan, diff/file context, command queue,
  and diagnostics.

The remaining V1 transport boundary is lifecycle ownership from the macOS app:
the native driver can start and drive a finite JSONL session, and the next slice
should keep a Pi RPC task alive for the desktop session, feed UI prompts into
its writer, and dispatch reader events back through the MoUI message loop.

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
moon test examples/mo_workbench/native_transport --target native
moon build examples/mo_workbench/macos_skia --target native
```

When real Skia is configured locally, also run:

```sh
MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/mo_workbench/macos_skia --target native
```
