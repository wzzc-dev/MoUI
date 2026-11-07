# 0066: Android product class raised to `committed`

- **Date**: 2026-11-08
- **Status**: Accepted
- **Deciders**: Agent-assisted (ZCode Harness)
- **Related**: ADR 0011 (platform class and convergence), ADR 0021 (embedded
  runtime readiness downgrade), ADR 0046 (the HarmonyOS promotion this
  follows), `checks/platforms/android.json`, `checks/platform-matrix.json`,
  `checks/portfolio-governance.json`

## Context

ADR 0021 set the embedded-runtime mobile backends to `product_class=experimental`
because no matching-device evidence existed for the window-hosted path. For
Android the evidence gap closed in steps across 2026-11-05..08 on
emulator-5554 (Pixel 6 AVD, API 34, arm64), each closing a concrete defect in
the `wzzc-dev/window` embedder:

1. **The template had no IME text channel** — `adb shell input text` and
   Backspace never reached MoUI text fields. Fixed with an
   `InputConnection` on the hosted surface view plus a named-key JNI channel
   (window `moui-support` `e54822d`, 2026-11-07).
2. **The clipboard platform channel was unwired** — the Host services page
   reported "Unavailable" for both write and read. Fixed with
   `HostedActivity.writeClipboard`/`readClipboard` (ClipboardManager,
   UI-thread marshalled with a latch) and
   `mbw_android_clipboard_write_text`/`_read_text` over JNI (window
   `f20be5e`), bound into `AppServices` by
   `moui/backend/android/android_clipboard.mbt`.
3. **The accessibility adaptation was declared but published nothing** —
   uiautomator saw no text nodes from the MoUI surface. Fixed with
   `HostedActivity.publishAccessibility` +
   `HostedA11yProvider` (window `be96543`), fed by
   `moui/backend/android/android_accessibility.mbt`'s semantics projection
   pumped from `about_to_wait` with a generation cursor. The load-bearing
   provider detail: the HOST branch must call
   `host.onInitializeAccessibilityNodeInfo(info)` — `obtain(host)` only sets
   the source, and without it the host node reports zero bounds and
   invisible, which hides the entire virtual subtree from TalkBack and
   uiautomator.
4. **A Showcase app defect masqueraded as a runtime resize bug** — the
   platform `view_body` ignored the shell's measured content width, so page
   columns fell back to intrinsic width (~292 logical) and looked like the
   runtime never resized. Measured card-border evidence showed the resize
   chain worked all along; the fix pins the matched page with
   `.frame(width=width)` (`e19634be6`).

With those closed, every R6 capability is observed on the matching emulator:
pixels (Skia first frame through the ANativeWindow CPU blit presenter),
pointer (probe action counts), keyboard/IME text + named keys
(Ime(Commit)/Backspace/Enter), resize + app-visible viewport (411x914),
surface detach/recreate, clipboard write + read (system clipboard bubble
evidence), accessibility node publishing (uiautomator exposes 16 text nodes
with correct screen bounds), and async image (the probe's data-URI image
paints).

## Decision

Raise the `android-skia` route to `productClass=committed` with `ready=true`,
and `checks/platforms/android.json` to `runtimeL3=passed`,
`rendererL2=passed` with `presenterRoute=cpu-blit-anative-window`
(`actualPresenterRoute` corrected from the aspirational `vulkan-direct` to
what actually runs).

## Honest gap carried forward

The route presents through the **ANativeWindow CPU blit presenter**
(`moui/backend/android/android_backend.mbt` "Android host CPU presenter" ->
`moui_android_present_pixels_to_surface`). The vulkan-direct GPU route
(policy default for Android in `moui_skia_renderer/native_gpu_policy.mbt`)
is **not claimed**: no direct-present log marker, no GPU seven-gate
manifests. This is the same standing the HarmonyOS `committed` had at
ADR 0046 ("GPU seven-gate claim" left open), and it stays recorded as the
route's "Not yet committed" column entry. A vulkan-direct claim requires
the GPU promotion runbook's seven-gate manifests on matching hardware, not
a silent manifest edit.

## Consequences

- `checks/platform-matrix.json`: `android-skia` -> `productClass=committed`,
  `ready=true`; the platform-matrix validator's
  `ready == (committed || committed_with_gaps)` rule stays satisfied.
- `checks/portfolio-governance.json`: `android-skia` intent -> `product`;
  graduation records that any promotion beyond `committed` requires a GPU
  claim ADR.
- `docs/platform-readiness-declaration.md` Android row and the
  `AGENTS.md`/`README.md` embedded-runtime lines move to `committed`.
- Tier 3 stays **non-blocking** for releases; the route's scheduled/manual
  coverage and evidence file are unchanged.
- Follow-ups: the vulkan-direct presenter claim (seven-gate manifests), and
  TalkBack action-focus verification on a matching device (the ACTION_CLICK
  synthetic-tap path is implemented; node publishing is verified via
  uiautomator).
