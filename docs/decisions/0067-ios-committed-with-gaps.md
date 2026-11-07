# 0067: iOS product class raised to `committed_with_gaps`

- **Date**: 2026-11-08
- **Status**: Accepted
- **Deciders**: Agent-assisted (ZCode Harness)
- **Related**: ADR 0011, ADR 0021, ADR 0046 (HarmonyOS two-step promotion
  pattern), ADR 0066 (Android `committed`), `checks/platforms/ios.json`,
  `checks/platform-matrix.json`, `checks/portfolio-governance.json`

## Context

ADR 0021 set the embedded-runtime mobile backends to `experimental` for lack
of matching-host evidence. For iOS the evidence closed in steps across
2026-11-07..08 on the iPhone 17 simulator (iOS 26.3), each fixing a concrete
defect:

1. **The simulator .app could not launch at all.** Three blockers landed:
   the runtime compat shims for the missing SDK headers (2026-11-07), the
   template `Info.plist` missing `UIDeviceFamily` +
   `CFBundleInfoDictionaryVersion` (SpringBoard rejected the bundle as "not
   valid application"), and `--sdk iphonesimulator` being non-default —
   omitting it silently links a device-platform binary
   (`LC_BUILD_VERSION platform=IOS`) that AMFI rejects at launch with error
   163 "Security policy issue".
2. **The clipboard platform channel was unwired.** Fixed with
   `ios_clipboard.mm` (general UIPasteboard) bound into `app_environment()`
   ClipboardServices and the window-hosted `service_handler`.
3. **No hardware named keys.** The hidden-UITextView IME adapter only
   forwards text diffs. Fixed with `MBW_IOS_HOST_NAMED_KEY` (16): the proxy
   forwards `pressesBegan/Ended` HID codes and intercepts
   `insertText:@"\n"` (Return) so the runtime submits instead of editing.
4. **No accessibility publishing.** Fixed with the UIAccessibilityElement
   bridge: the MoonBit semantics projection (same encoding as Android) is
   forwarded through `mbw_ios_accessibility_publish` into
   `mbw_ios_template_a11y_publish`, which builds a flat, traversal-ordered
   element array with absolute frames; `accessibilityActivate` synthesizes a
   tap on the existing pointer channel.

With those closed, the observed capability set on the matching simulator is:
pixels (CALayer CPU blit, viewport 402x874), pointer (idb tap -> probe action
count), IME text + delete, named keys (Return submits — "Last: Probe submit
1"), clipboard write + read (`simctl pbpaste` cross-check), accessibility
node publishing (idb describe-all exposes 19 nodes with labels, roles and
frames), surface detach/recreate, async image, and cross-extent install/run
on the iPad simulator.

## Decision

Raise the `ios-skia` route to `productClass=committed_with_gaps` with
`ready=true`, `checks/platforms/ios.json` `rendererL2=passed` with
`presenterRoute=cpu-blit-calayer` (declared == actual), and
`runtimeL3=partial`.

This mirrors **ADR 0046's first step**: the HarmonyOS route spent a day at
`committed_with_gaps` with `runtimeL3=partial` while its last capabilities
closed. The honest state here is identical — every capability except one is
observed, and the exception is an **evidence-collection limitation, not a
runtime defect**.

## Honest gap carried forward

**Live rotation/resize is not observed.** The template plist now declares
landscape orientations, and the shared `HostedWindowBackend` resize chain is
verified on the sibling Android route — but the Simulator's Device > Rotate
action is not scriptable from this host (System Events cannot see the
Simulator windows, and `simctl ui` exposes no rotation on this runtime), so
no live extent change was captured. The final `committed` step additionally
expects a metal-direct GPU presenter claim (the route presents through the
CALayer CPU blit today) with the seven-gate manifests.

## Consequences

- `checks/platform-matrix.json`: `ios-skia` ->
  `productClass=committed_with_gaps`, `ready=true`.
- `checks/portfolio-governance.json`: `ios-skia` intent -> `product`; the
  graduation records the two conditions for the final step.
- `docs/ios-support.md`, `AGENTS.md`, `README.md`, and the generated
  readiness tables move to `committed_with_gaps`.
- Tier 3 stays non-blocking for releases.
