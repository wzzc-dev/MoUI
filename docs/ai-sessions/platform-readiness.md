# Platform readiness (2026-07 → 2026-11)

Durable summary of the sessions that changed platform product classes and
window-hosted ownership. Canonical status: `docs/platform-readiness-declaration.md`,
`checks/platforms/*.json`, ADRs 0005/0006/0020/0031/0046/0066/0067.

## 2026-07-11 — mobile mainline and host services

- VSync-driven mobile frame ticks; fixed duplicate HarmonyOS ArkTS/native touch
  delivery; shared IME/clipboard/semantics channel contracts and native service
  adapters on Android/iOS/HarmonyOS; latest-wins frame mailbox; mobile build
  `--renderer auto|skia-gpu|skia-raster` records requested/selected mode and
  unpromoted GPU requests fall back to raster.
- Mobile smoke recorder (`hdc`): before/after pixels, app receipt + detach logs,
  IME, system clipboard, accessibility tree/focus/action, async-image observations.
  Clipboard proof needs write+read completion; resize needs two physical sizes.
- iOS Simulator limits: `simctl ui` has no tap/swipe injection (recorder uses `idb`
  accessibility frames); Xcode 26.3 has no `simctl io` rotate; Simulator VoiceOver
  writes do not start a screen reader. `UILaunchScreen` removes legacy 320×480
  compatibility scaling. Detach detection must require the target process line
  (log-query marker false positives).
- ADR 0005 / 0006.

## 2026-08-05 — cross-platform behaviour convergence

- Deleted file-similarity accounting and replaced it with a structural Platform
  Bridge boundary gate: ownership is structural, not a token score.
- Desktop service routing/filesystem → `moui/backend/common/desktop`; desktop
  resize/request/redraw → `WindowCoordinator`; Android/iOS/HarmonyOS logical
  lifecycle → `EmbeddedWindowCoordinator`; post-callback mobile runtime assembly
  stays in `moui/backend/common/embedded`; `wzzc-dev/window` keeps payload decoding
  and native ABI only.
- ADR 0020 amendment. Follow-up: the repository owner publishes the changed
  `wzzc-dev/window` and bumps consumer pins; matching-device evidence decides
  readiness claims.

## 2026-08-29 — Windows → `committed`

- Promoted on a local matching-host L3 capture (Win32 runtime smoke transcript +
  Showcase `windows_skia` first frame), not on CI: the weekly workflow only covers
  the first-frame smoke; local matching-host citations have precedent (Linux WSL2).
- Repairs needed: real Win32 FFI in the window library, `#define NOMINMAX` in the
  Windows accessibility host, and the evidence script injecting generated
  stub-cc-flags/cc-link-flags into the showcase executable package.
- Trap: `moon` on MSVC ignores `moui_skia/native/moon.pkg` `cc-link-flags` at final
  link; the prebuild `link_configs` carrier is what reaches `is-main` links, and
  `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` empties it unless `MOUI_SKIA_CC_LINK_FLAGS`
  is set. Injecting flags into the executable package is the working workaround.
- ADR 0031. `platform-runtime-evidence.json` no longer exists; Windows L3 status
  lives solely in `checks/platforms/windows.json`.

## 2026-11-08 — Android and iOS → `committed` (ADR 0066, ADR 0067)

Android slices:

- `e19634be6` Showcase pages pin `.frame(width=width)` — the "resize chain broken"
  report was a misdiagnosis: the probe reported 411×914; the page column had fallen
  back to intrinsic width (~292). Measured card borders found the truth.
- `bd7a13e18` clipboard through the embedder JNI bridge (UI-thread latch +
  `mbw_android_clipboard_*`); host-test stubs live in the window embedder
  unconditionally, never in `android_present.cpp` (duplicate symbols).
- `ef020ca98` semantics → `AccessibilityNodeProvider`: the host branch must call
  `host.onInitializeAccessibilityNodeInfo(info)`; `obtain(host)` alone reports
  zero-bounds subtrees invisible to TalkBack/uiautomator. Actions return as
  synthesized taps on the pointer channel.
- `88cda7d54` promotion (matrix/manifests/ADR 0066 + validator vocabulary).

iOS slices:

- `aedd44897` UIPasteboard clipboard bridge (`ios_clipboard.{mm,mbt}`) compiled by
  `build_ios.mbt`; window repo `a0ee0ff` template plist — without `UIDeviceFamily`
  SpringBoard rejects the app as "not valid application".
- `--sdk iphonesimulator` is mandatory for `moui build ios`; otherwise the linker
  emits a device-platform binary (LC_BUILD_VERSION IOS) rejected with error 163.
- `moui` CLI edits require rebuilding `moui_cli/cmd/moui` and copying to
  `~/.moon/bin/moui`. `idb` coordinates are points, not pixels.
- Evidence: iPhone 17 / iOS 26.3 — first frame 402×874, pointer tap, `idb ui text`
  insertion, backspace, clipboard round-trip, terminate/relaunch, iPad install/run.

Both promotions rest on matching emulator/simulator evidence under the single-VM
constraint. Rotation is *not* in R6's capability list (pixels, input, detach, IME,
clipboard, accessibility, async image) and is recorded as an evidence limitation,
not a pending capability.
