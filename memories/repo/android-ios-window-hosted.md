# Android / iOS window-hosted: promotion state and traps

- Android is `committed` (ADR 0066, 2026-11-08): all R6 capabilities observed
  on emulator-5554; presenter honestly recorded as `cpu-blit-anative-window`
  (vulkan-direct seven-gate claim still open). iOS stays `experimental` with
  evidence recorded in `checks/platforms/ios.json` + `docs/ios-support.md`.
- The embedded clipboard contract: synchronous externs
  (`mbw_android_clipboard_*` in the window embedder,
  `mbw_ios_clipboard_*` via UIPasteboard) + `app_environment()`
  ClipboardServices + `HostedWindowBackend::service_handler`. Follow
  `moui/backend/harmonyos/harmonyos_backend.mbt` as the reference shape.
- Accessibility bridges: project the semantics snapshot flat
  (`android_accessibility.mbt`), pump from `about_to_wait` with a generation
  cursor, and on Android ALWAYS call
  `host.onInitializeAccessibilityNodeInfo(info)` in the provider's HOST
  branch — `obtain(host)` alone hides the whole virtual subtree.
- `moui build ios` **requires** `--sdk iphonesimulator`; without it the
  binary links device-platform and the simulator rejects it with launch
  error 163. Verify with `vtool -show-build <exe> | grep platform`.
- The packaged iOS .app needs `UIDeviceFamily` + landscape orientations in
  the template plist or SpringBoard says "not valid application".
- `moui` CLI edits: rebuild with `moon build moui_cli/cmd/moui` and copy the
  exe to `~/.moon/bin/moui`; the installed CLI never sees workspace changes
  otherwise.
- idb (installed at ~/.local/bin/idb + brew idb_companion) drives taps/text
  in POINTS on iOS; `simctl ui rotate` does not exist on iOS 26 runtimes and
  the Simulator Device menu is not scriptable via System Events (no windows
  visible) — live-rotation automation is still open.
- window embedder commits live on the `moui-support` branch (f20be5e,
  be96543, a0ee0ff); the MoUI `window` submodule pin still points at the
  pre-IME commit until those push and the pin bumps.
