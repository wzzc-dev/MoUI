# Plan: Window upstream workspace sync and branch split

- **Status**: complete
- **Scope**: `window/` submodule branch split and upstream reference branches.
  The fork-facing compatibility migration continues in
  `docs/plans/active/moui-support-upstream-workspace.md`.
- **Upstream baseline**: `moonbit-community/window` `upstream/main` at `4640089`.

## Objective

Move the MoUI fork onto the upstream workspace layout so changes can be
reviewed and proposed independently upstream. The upstream layout owns the
public modules under `modules/window/` and `modules/windowing/`; no new
top-level package roots may remain after migration.

## Layout mapping

| Current fork | Upstream workspace |
|---|---|
| `core/`, `dpi/`, `macos/`, `examples/` | `modules/window/<path>` |
| `windowing/` | `modules/windowing/` |
| `windows/`, `linux/`, `web/`, mobile, WeChat | `modules/window/<platform>` |
| root module metadata | `modules/window/moon.mod` and `modules/windowing/moon.mod` |

## Branch plan

1. Create an isolated sync branch from `upstream/main` and replay the fork
   history with rename-aware merges.
2. Separate shared module/API changes from platform-specific work.
3. Produce independent upstream branches for macOS, Web, Windows, Linux,
   mobile hosted backends, and WeChat only when each branch has a coherent
   dependency boundary and focused validation.
4. Keep MoUI-only smoke evidence, release metadata, and fork packaging out of
   upstream proposals unless upstream explicitly owns them.

## Acceptance

- [x] All source packages use the upstream `modules/` workspace layout.
- [x] Every proposed branch is based on `upstream/main` or an explicitly declared
  prerequisite branch.
- [x] The pre-migration `moui-support` snapshot remains recoverable on a
  dedicated legacy branch.
- [x] Each migrated unit passes its closest upstream-supported validation command.

## Result

- Rebased 63 fork commits onto `upstream/main` at `4640089` in
  `codex/window-upstream-sync`.
- Moved Android, iOS, HarmonyOS, and WeChat packages to `modules/window/`,
  removed the duplicate root `windowing/` package, and kept the canonical
  `Milky2018/window` and `Milky2018/windowing` module names.
- Preserved the pre-migration `moui-support` snapshot at `2723fb9` on
  `codex/moui-support-legacy`; it contains the
  `mbw_menu_action_trampoline_t` declaration that fixes the original AppKit
  build failure.
- Moved `moui-support` to the workspace-layout baseline `a39726a`; its
  fork-facing compatibility work is tracked in the active migration plan.

## Upstream Branches

| Branch | Base | Scope |
| --- | --- | --- |
| `codex/window-upstream-wasm-core` | `upstream/main` | Enable `core` and `dpi` browser targets. |
| `codex/window-upstream-web` | `wasm-core` | Browser `wasm-gc` backend and example. |
| `codex/window-upstream-wechat` | `wasm-core` | WeChat Mini Program backend. |
| `codex/window-upstream-native-build` | `upstream/main` | Native Windows/Wayland build linkage. |
| `codex/window-upstream-windows` | `native-build` | Win32 backend and example. |
| `codex/window-upstream-linux` | `native-build` | Wayland backend and example. |
| `codex/window-upstream-macos-menu` | `upstream/main` | AppKit system menu callbacks and regressions. |
| `codex/window-upstream-android` | `upstream/main` | Android embedded backend. |
| `codex/window-upstream-ios` | `upstream/main` | iOS embedded backend. |
| `codex/window-upstream-harmonyos` | `upstream/main` | HarmonyOS embedded backend. |
| `codex/window-upstream-sync` | `upstream/main` | Full integration/reference branch; do not submit as one PR. |

Submit prerequisite branches first, then their dependent backend branches.
The three mobile branches are independent proposals and remain separate from
desktop backend reviews.

## Validation

- Passed on the integration branch: `moon test modules/window/core --target
  native --release`, `moon test modules/windowing --target native --release`,
  `moon test modules/window/macos --target native --release`, all three mobile
  package tests, and Web/WeChat `wasm-gc` tests.
- Passed on the candidate branches: `wasm-core` core/dpi `wasm-gc` tests,
  macOS menu tests (113/113), Android/iOS/HarmonyOS tests, Web and WeChat
  tests, plus `moon info` source/interface checks for Windows and Linux.
- Passed in the MoUI checkout with local window development mode enabled:
  `moon build examples/showcase/macos_skia --target native`.
- Windows and Linux runtime tests still require matching host environments;
  this macOS session only ran their portable source/interface checks.
- The root guidance now uses the new version and nested workspace paths. While
  local development mode is intentionally enabled, its validator correctly
  rejects the two local members; published-mode validation remains pending the
  `wzzc-dev/window@0.5.4-0.1.0` mooncakes release.
