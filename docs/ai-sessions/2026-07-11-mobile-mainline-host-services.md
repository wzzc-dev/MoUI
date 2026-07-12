# Mobile Mainline And Host Services

- Date: 2026-07-11
- Scope: Android, iOS, HarmonyOS runtime sessions, host services, input, smoke,
  and GPU architecture scaffolding.

## Outcome

Added VSync-driven mobile frame ticks, fixed duplicate HarmonyOS ArkTS/native
touch delivery, implemented shared IME/clipboard/semantics channel contracts,
and connected native service adapters on all three platforms. Added targeted
semantics action routing, GPU renderer identity/selection, and a latest-wins
frame mailbox. Mobile build entrypoints now accept
`--renderer auto|skia-gpu|skia-raster` and record requested/selected modes;
unpromoted GPU requests explicitly fall back to raster.

The mobile smoke recorder now supports `hdc`, compares before/after pixels,
requires app receipt and detach logs, and tracks IME, system text clipboard,
accessibility tree/focus/action, and async-image observations. Component Gallery
now opens a dedicated `Mobile Service Probe` on mobile with stable text/action
labels, visible counters and viewport dimensions, a deferred PNG, and scroll
content. Clipboard proof requires both write/read completion, resize requires
two distinct physical sizes, and async image requires loading/ready frames.

## Evidence Boundary

Focused MoonBit tests and fallback iOS/HarmonyOS packaging passed locally.
After enabling the build-scoped `127.0.0.1:7897` proxy, non-fallback Counter
builds also passed for Android and iOS. The Android build used JDK 17 and wrote
`artifacts/android/counter/app-debug.apk`; the iOS build wrote
`artifacts/ios/counter/MoUICounter.app`. These remain build evidence, not
matching-device service or performance proof.

An iOS 26.3 Simulator smoke produced a nonblank first frame, lifecycle attach,
an accessibility tree, current-PID pointer receipt, changed pixels, and a real
HOME-triggered detach. Stock `simctl ui` does not provide tap/swipe injection,
so the recorder now uses `idb` accessibility frames. Adding `UILaunchScreen`
also removed legacy `320x480` compatibility scaling from Counter. The manifest
remains failed because Counter does not exercise the full IME, clipboard,
accessibility-action, async-image, or resize matrix. The run also exposed a
detach false positive caused by the log query command containing its own marker;
the recorder now requires the target application process line and current PID.
The iOS shell now observes UIScene background/foreground notifications, and a
repeat smoke recorded a real `MoUICounter` detach callback while preserving the
partial status for the still-missing service observations. Component Gallery
also recorded current-PID pointer input, scroll input, changed pixels, and
detach through the same accessibility-frame idb path. A later probe run
additionally recorded IME state/edit, system text clipboard write/read, and
async-image loading/ready. The semantics tree is present, but Simulator
VoiceOver preference writes did not activate a live screen-reader session, so
accessibility focus/action remain pending. Xcode 26.3 has no `simctl io` rotate
operation, and Simulator menu automation was denied macOS Accessibility
permission; resize therefore remains pending.
No Android or HarmonyOS target was connected. The local HarmonyOS API 20
installation still lacks native headers/toolchain files, so HarmonyOS
non-fallback compilation remains pending. Direct GPU window presentation and
renderer-thread integration also remain pending and were not promoted.

## Validation

- `sh scripts/check.sh --profile daily` passed after the lifecycle, renderer
  selection, smoke-recorder, and documentation updates.
- Non-fallback Counter builds passed for Android and iOS through the build-only
  proxy; HarmonyOS fallback packaging passed with an explicit GPU-requested to
  raster-selected record.
- The iOS Simulator manifest remains `partial` by design while preserving
  positive nonblank-frame, attach, current-PID input, changed-pixel, detach,
  clean-shutdown, accessibility-tree, Component Gallery scroll, IME, system
  text clipboard, and async-image observations. Accessibility focus/action and
  resize evidence remain pending.
- `adb devices` and `hdc list targets` had no connected targets. The physical
  iPhone was listed offline, and the current `iphoneos` builder emits an
  unsigned bundle, so no three-platform real-device acceptance claim was made.

## Decisions

- [ADR 0005](../decisions/0005-mobile-host-channel-ownership.md)
- [ADR 0006](../decisions/0006-mobile-gpu-surface-and-render-thread.md)
