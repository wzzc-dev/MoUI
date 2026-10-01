# Desktop entrypoint task lifetime (macOS)

## Rule

Join the window pump with long-lived workers using
`@macos.run_window_with_workers(window=..., workers=[...])`.
Never use `@async.all([window, ...workers])`.

## Why

`@async.all` waits for **every** sibling to finish. Entrypoint workers are almost
always `while true { queue.get() }` loops (provider, compile, launch, agent/MCP,
ACP, PTY). Closing the window returns only the window task; the workers stay
parked forever, so `all` never returns and the process outlives its window.

Symptom the user sees: clicking the traffic lights appears to do nothing —
the window may vanish from screen while the Dock icon and process remain, and the
app can only be force-quit ("关不掉 / 卡住").

## Fix shape

`run_window_with_workers` spawns workers in a task group, awaits the window task
as primary, then calls `TaskGroup::return_immediately(())`, which records the
result **and cancels every child**.

## Evidence

- Framework test: `moui/backend/macos/macos_backend_test.mbt`
  ("run_window_with_workers returns when the window loop finishes"). Verified it
  genuinely guards the bug: with `@async.all` restored the test hangs (>90s);
  with the helper it passes.
- End-to-end: a real Skia/AppKit window closed through
  `WindowRequestQueue::close_window` with three endless workers exited 0 in
  ~6.2s; the same harness using `@async.all` was still alive 12s after the window
  closed.

## History

Present in four entrypoints before the fix: `moui_studio`, `agent_counter`,
`terminal`, `mo_workbench`. The helper lives in `moui/backend/macos` so the
correct composition is the default one.
