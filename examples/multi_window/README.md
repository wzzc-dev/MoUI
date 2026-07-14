# Multi-Window Example

This example demonstrates MoUI's host-managed scene model.

- On macOS, Windows, and Linux, **Open Inspector** creates a second native
  window with its own `AppRuntime` and local counter state.
- On Web, the same action creates a second independent canvas in the current
  page. It does not open a browser popup or tab.

Each platform entrypoint creates one `HostWindowRequestQueue`, gives the app a
`HostWindowActions` capability backed by that queue, and installs a
`HostWindowSceneResolver`. The resolver creates a fresh runtime for the
requested `main` or `inspector` scene.

```sh
moon run examples/multi_window/macos_skia
moon run examples/multi_window/windows_skia
moon run examples/multi_window/linux_skia
moon build examples/multi_window/web_wasm --target wasm-gc
```

Mobile embedded-session hosts currently do not support this example's
multi-window model.
