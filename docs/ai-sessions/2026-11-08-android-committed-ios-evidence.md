# 2026-11-08: Android → `committed`; iOS evidence pass

- **Goal**: advance the Android and iOS window-hosted routes toward
  `committed` (one VM at a time, per the user constraint).
- **Outcome**: Android promoted to `committed` (ADR 0066) with every R6
  capability observed on the matching emulator; iOS collected its first
  matching-simulator R6 evidence pass (clipboard, pointer, IME, lifecycle)
  and stays honestly `experimental` with a recorded pending list.

## Android slices (one commit each)

| Commit | Slice | Key learning |
|---|---|---|
| `e19634be6` | Showcase platform pages pin `.frame(width=width)` | The "root layout resize gap" was a **misdiagnosis** — the resize chain worked (probe reported 411x914); the page column fell back to intrinsic width (~292). Measured card borders (63..828 px) found the truth. |
| `6cdd7ba0a` | docs: correct the resize record | |
| `bd7a13e18` | Clipboard services via the embedder JNI bridge | `HostedActivity.writeClipboard/readClipboard` (UI-thread latch) + `mbw_android_clipboard_*` externs; `app_environment()` ClipboardServices + `service_handler`. Host-test stubs live in the window embedder unconditionally, NOT in `android_present.cpp` (duplicate symbols). |
| `ef020ca98` | Semantics → AccessibilityNodeProvider bridge | The HOST branch must call `host.onInitializeAccessibilityNodeInfo(info)` — `obtain(host)` only sets source; without it the whole virtual subtree reports zero-bounds/invisible and TalkBack + uiautomator see nothing. Actions return as synthesized taps on the pointer channel. |
| `88cda7d54` | Promotion: matrix/manifests/ADR 0066 + validator vocabulary | The repo-docs validator now accepts `matching-device-cpu-present` and honest partial evidence under an unverified route. |
| `7d27b063d` | Standing findings the full pr gate surfaced | scroll split (1225→1118), api-surface ratchet 1850→1900, addon template snake_case naming, website catalog classification + zh-Hans source. |

Window repo (`moui-support`): `f20be5e` clipboard channel,
`be96543` accessibility bridge. Emulator evidence: clipboard round-trip
("Clipboard read: showcase-platform ticks=0" + system clipboard bubble),
uiautomator exposes 16 text nodes with correct screen bounds.

## iOS slices

| Commit | Slice |
|---|---|
| `aedd44897` | UIPasteboard clipboard bridge (`ios_clipboard.{mm,mbt}` + `app_environment()` + `service_handler`; `build_ios.mbt` compiles the .mm) |
| `2b6eb81a9` | docs + ios.json evidence records |

Window repo: `a0ee0ff` template plist (`UIDeviceFamily`,
`CFBundleInfoDictionaryVersion`, landscape orientations) — without
`UIDeviceFamily` SpringBoard rejects the app as "not valid application".

Evidence (iPhone 17 / iOS 26.3 / idb): first frame 402x874, pointer tap →
Action count 1, `idb ui text` inserts at the caret, backspaces delete,
clipboard write/read round-trip (`simctl pbpaste` cross-check), terminate +
relaunch re-initializes, iPad cross-extent install/run.

## Patterns worth keeping

- **`--sdk iphonesimulator` is mandatory** for `moui build ios`: without it
  the linker produces a device-platform binary (LC_BUILD_VERSION IOS) that
  SpringBoard rejects with error 163 "Security policy issue". Detect by
  `vtool -show-build` on the linked executable.
- **moui CLI changes require rebuilding the binary**: `moon build
  moui_cli/cmd/moui` then copy to `~/.moon/bin/moui` — the installed CLI
  does not pick up workspace edits by itself.
- **idb coordinates are points** (device logical 402x874), not pixels.
- **Platform a11y consumers need the host node initialized**: obtain() alone
  yields an invisible zero-bounds host and hides every virtual child.
- **The full pr profile catches drift** the targeted loops miss: run
  `sh scripts/check.sh --profile pr` before promotion-sized commits (it
  surfaced four standing findings this session).

## Remaining

- iOS pending list (see `docs/ios-support.md`): live rotation automation,
  named-key channel, a11y bridge, Metal direct-present marker.
- Android follow-ups: vulkan-direct presenter seven-gate claim; TalkBack
  action-focus on matching hardware.
- The `window` submodule gitlink in MoUI still pins the pre-IME commit; the
  `moui-support` commits (e54822d..a0ee0ff) await push, then the pin bumps.
