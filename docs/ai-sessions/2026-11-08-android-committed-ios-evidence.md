# 2026-11-08: Android → `committed`; iOS → `committed`

- **Goal**: advance the Android and iOS window-hosted routes toward
  `committed` (one VM at a time, per the user constraint).
- **Outcome**: Android promoted to `committed` (ADR 0066) and iOS promoted
  to `committed` (ADR 0067) — both with every R6 capability observed on the
  matching emulator/simulator under the single-VM constraint. The iOS arc
  closed the named-key channel and the UIAccessibility bridge, spent a
  rotation-automation attempt against the host's TCC permissions, then an
  R6 audit settled the promotion: rotation is NOT in R6's capability list
  (pixels, input, detach, IME, clipboard, accessibility, async image), so it
  is recorded as an evidence limitation rather than a pending capability.

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

## iOS second pass (named keys + a11y → ADR 0067)

| Commit | Slice |
|---|---|
| window `887d463` | `MBW_IOS_HOST_NAMED_KEY` 16 (pressesBegan/Ended + `insertText:@"\n"` Return interception) + `mbw_ios_template_a11y_publish` (flat traversal-ordered UIAccessibilityElement array) |
| `f738e14bc` | `ios_accessibility.mbt` projection + `pump_accessibility` cursor |
| `99d463e8c` | Promotion: rendererL2 passed (`cpu-blit-calayer`), matrix/manifests/governance, ADR 0067 |

Evidence: idb describe-all exposes 19 semantic nodes with labels/roles/
frames; hardware Return submits ("Last: Probe submit 1"); clipboard
round-trip cross-checked with `simctl pbpaste`.

Traps: ObjC string literals cannot carry `\u001E` (control-char universal
character names) — use `\x1E`; `??` is not Objective-C; `printf` needs
`<stdio.h>` in the window host C.
Rotation-automation dead ends on this host (all TCC-blocked): System Events
sees no Simulator windows (Finder also reports 0 — the AX window query is
untrustworthy), AppleScript menu clicks report success but do not rotate,
CGEvent `postToPid` keystrokes and `activateIgnoringOtherApps` fail, `simctl
ui` has no rotate, screencapture lacks permission. When auditing a
promotion gate, re-read the invariant's letter first: R6's capability list
never included rotation, and an entire committed_with_gaps detour was
avoided by that check.

## 0.5.0 / 0.5.1 release (same day)

- `node scripts/bump-release-line.mjs <version>` advances all 25 public
  modules + workspace pins; release notes in `docs/releases/<v>.md`;
  `releaseCoupling.line` in `checks/portfolio-governance.json` must move to
  the new line (its validator rejects modules outside the declared line);
  `docs/compatibility-matrix.md` base pins are hand-synced.
- **Publishing order matters**: the registry resolves each module's pinned
  deps at publish time, so publish the base (`wzzc-dev/moui`) first, then
  downstream in dependency order, retrying as versions propagate.
- **`moon update` refreshes the client registry index** — after each publish,
  newly uploaded versions become resolvable only after an index refresh
  (the upload 200 is async); a retry loop of publish -> moon update -> sleep
  drained all 25 modules.
- `git push` with drifted submodules aborts under the default
  recurse-submodules check; `--recurse-submodules=no` pushes the superproject
  (pre-existing momark/moui_studio drift, untouched by this work).
- window 侧发布：`modules/window` 单独 `moon publish`（0.5.4-0.2.6 含移动端
  剪贴板/a11y/命名键 embedder 代码）。0.5.0 曾带旧 window pin 发布——需要新
  公开符号的依赖变更必须在同一发布窗口内完成依赖侧发布。

## Remaining

- iOS: a matching-device pass may add the live rotation observation;
  metal-direct GPU seven-gate claim stays the renderer item.
- Android follow-ups: vulkan-direct presenter seven-gate claim; TalkBack
  action-focus on matching hardware.
- The `window` submodule gitlink in MoUI still pins the pre-IME commit; the
  `moui-support` commits (e54822d..a0ee0ff) await push, then the pin bumps.
