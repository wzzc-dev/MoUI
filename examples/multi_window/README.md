# Multi-Window Example

This example demonstrates MoUI's host-managed scene model and the app-facing
`HostWindowActions` lifecycle helpers.

## What it shows

- **Open Inspector** enqueues `HostWindowActions::open` for scene id
  `inspector`. The host resolves the scene to a fresh `AppRuntime`.
- **Focus Inspector** / **Close Inspector** enqueue
  `HostWindowActions::focus` / `close` by window id. When the host has not
  reported an id back into the model, the demo uses a provisional id so the
  request shape is still visible in tests and queue drains.
- **Increment shared** updates app-owned shared state. Scenes do not share a
  runtime; reopen the inspector to snapshot a new payload string.
- On the retained **macOS** entrypoint, Open creates a second native window.
- On **Web**, Open creates a second independent canvas in the current page (not
  a browser popup or tab).
- **Mobile** embedded-session hosts do not support this multi-window model.

## Run

```sh
moon run examples/multi_window/macos_skia --target native
moon build examples/multi_window/web_wasm --target wasm-gc
moon test examples/multi_window/app --target native
```

## Entrypoint wiring

Each platform entrypoint:

1. Creates one `HostWindowRequestQueue`
2. Builds `HostWindowActions` on that queue
3. Installs a `HostWindowSceneResolver` that maps `main` / `inspector` to a new
   `AppRuntime`
4. Passes the queue through `AppBuilder::window_requests`

See `docs/platform-host-contract.md` for the host registry and request-queue
contracts.
