# macOS Dock Icon

## Fact

- The macOS Dock icon is app-global AppKit state
  (`NSApplication.setApplicationIconImage`), not per-window. The API lives in
  `wzzc-dev/window/macos` (`set_application_icon_path` /
  `set_application_icon_data` / `application_is_bundled` in
  `window/modules/window/macos/app_icon.mbt`).
- Unbundled binaries (`moon run` output) get the embedded MoUI Moonbud icon by
  default (`moui/backend/macos/macos_branding_icon.mbt`, generated from
  `resource/branding/moonbud-mascot-100.png` by
  `scripts/generate-macos-branding-icon.mjs`). Bundled `.app` binaries keep
  their bundle icon unless `MacosHostAppOptions::new(dock_icon_path=...)` is
  set.
- Apps can override per-run with `MacosHostAppOptions::new(dock_icon_path=
  Some(path))`; runtime swaps call the window-level setters directly on the
  main thread.

## Gotcha (cost a debug round)

Setting the icon **before** `did_finish_launching` gets silently reset to the
generic gear: the launch-policy switch (`setActivationPolicy:` in
`app_state_apply_launch_policy`) re-registers the app with the Dock and
discards the early icon. The backend therefore applies the icon from the
`on_ready` hook (`macos_app_runtime.mbt`), which runs after launch policy and
menu installation. Any future refactor that moves icon application earlier will
reintroduce the bug; unit tests that only call the setter (no real launch)
cannot catch it — verify with a real app run and a Dock screenshot.

## MoonBit FFI note

MoonBit `Bytes` extern params pass **only the raw pointer** — the callee never
infers the length. Every native stub taking bytes must declare an explicit
`len : Int` parameter and the caller must pass `data.length()`; otherwise the
stub reads garbage from the next argument slot (looks like random huge values,
and only fails at runtime).
