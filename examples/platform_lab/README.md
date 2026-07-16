# Platform Lab

Runnable copy-paste recipes for host `Effect` / `Subscription` wiring and a
small canvas demo. Use this when you need more than Counter but less than
Markdown Editor.

## Cards

| Card | Recipe |
| --- | --- |
| Timer | `HostTimerSource::subscription` while running |
| Window size | `HostWindowEventSource` + `HostEvent::Resized` |
| Clipboard / file | `Effect::host_service` + `completion_subscription` |
| Canvas | `@views.canvas` + `PaintContext` + `on_drag` |
| Shortcuts | `ActionCommandMap` installed on the runtime |

## Run

```sh
moon test examples/platform_lab/app --target native
moon run examples/platform_lab/macos_skia --target native
moon run examples/platform_lab/windows_skia --target native
moon run examples/platform_lab/linux_skia --target native
moon build examples/platform_lab/web_wasm --target wasm-gc
```

## Platform notes

- Desktop entrypoints inject `HostAppServices`, `HostTimerSource`, and
  `HostPlatformEventSources` (window resize).
- macOS also installs an L2 **application menu bar** via
  `HostAppServices::set_application_menu` in `on_ready`.
- Web has no `HostTimerSource` adapter yet; timer/animation cards stay idle.
  Clipboard and file dialogs use async host services when available.
- Application menu bars are unavailable on Windows/Linux/Web for now; the host
  returns `Unavailable` honestly.

See also:

- `docs/non-render-component-cookbook.md`
- `docs/canvas-and-custom-paint.md`
- `docs/tea-program-model.md`
