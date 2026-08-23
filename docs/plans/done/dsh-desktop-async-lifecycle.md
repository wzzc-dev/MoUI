# Plan: DSH desktop async lifecycle

- **Status**: done
- **Goal**: Replace the example-local native C process bridge with
  `moonbitlang/async@0.21.0`, while preserving real DSH start/stop behavior and
  terminating only processes started by the desktop app when it exits.
- **Non-goals**: Change DSH itself, terminate an externally started DSH server,
  or add DSH-specific lifecycle policy to MoUI framework packages.

## Acceptance

- [x] Keep the shared `app` package native/wasm-gc compatible and isolate the
  async process implementation in a native-only sibling package.
- [x] Start DSH with `@process.spawn`, probe its configured TCP endpoint, and
  cancel plus reap an owned process on explicit stop.
- [x] Keep owned DSH processes in the desktop composition root's `TaskGroup` so
  normal application shutdown cancels and waits for them.
- [x] Detect an externally running DSH endpoint without claiming ownership or
  terminating it.
- [x] Give macOS, Windows, and Linux native entries a cooperative async event
  pump so process and probe tasks can run while the window is open.
- [x] Pass focused app, async lifecycle, backend, formatting, and interface
  validation.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-23 | Use structured concurrency from `moonbitlang/async@0.21.0`; remove the example's C FFI process registry. |
| 2026-08-23 | Keep DSH policy in `examples/deepseek_harness_desktop/app/dsh_async`; backend changes provide only the generic cooperative event pump. |
| 2026-08-23 | Describe ownership in terms of the spawned process and `TaskGroup`; the async POSIX cancellation API signals the direct child rather than exposing process-group control. |

## Progress

| Date | Note |
|------|------|
| 2026-08-23 | Added the native-only async service, injected it from all desktop roots, removed `dsh_native.c/.mbt`, and added lifecycle tests. |
| 2026-08-23 | Added Linux and Windows async pump implementations matching the existing macOS backend contract. |
| 2026-08-23 | Passed 5 async lifecycle tests, 27 shared app tests, 25 Linux backend tests, 26 Windows backend tests, all relevant repository validators, and a local real-DSH start/probe/stop smoke using `/opt/homebrew/bin/dsh`. |
