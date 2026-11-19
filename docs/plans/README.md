# Plans

Executable work memory for multi-step agent and human efforts.
Formal specs and standing decisions live in **`docs/`** (ADRs under
`docs/decisions/`), not in tool-specific plan folders.

## Layout

```text
docs/plans/
  README.md                 # this file
  active/<id>.md            # in-flight exec plans
  done/INDEX.md             # one row per finished plan (bodies retired 2026-11-19)
  debt/<id>.md              # known tech debt with acceptance notes
```

Finished plans are summarized in [done/INDEX.md](done/INDEX.md); their full
bodies stay reachable from git history via the commit sha in each row. Only two
completed plans keep a file because live docs link them directly (see **Done**).

Historical topic pointers (pre-layout notes) remain useful:

| Topic | Canonical doc |
|-------|----------------|
| App package imports, sugar packages, `@core` vs prefixes | [moui-app-package-boundary.md](../moui-app-package-boundary.md) |
| Public API tiers and guards | [api-surface.md](../api-surface.md) |
| Facade / domain facade decision | [decisions/0003-core-package-and-api.md](../decisions/0003-core-package-and-api.md) |
| Agent workflow | [ai-collaboration.md](../ai-collaboration.md), [AGENTS.md](../../AGENTS.md) |
| Harness map + invariant mechanization | [done/harness-mechanize-invariants-batch1.md](done/harness-mechanize-invariants-batch1.md) |

## When to write a plan

| Scale | Artifact |
|-------|----------|
| Single package, clear acceptance | PR description only |
| Multi-package, platform, public API, or >1 session | `active/<id>.md` before coding |
| Deferred cleanup | `debt/<id>.md` |

## Plan skeleton

```markdown
# Plan: <title>

- **Status**: active | done | debt
- **Goal**:
- **Non-goals**:

## Acceptance
- [ ] ...

## Decision log
| Date | Decision |
|------|----------|

## Progress
| Date | Note |
|------|------|
```

## Active

| Plan | Summary |
|------|---------|
| [titlebar-controls-polish](active/titlebar-controls-polish.md) | Titlebar controls polish on top of the chrome work: policy-driven, theme-sized CSD buttons with hover/pressed feedback and state icons, titlebar insets exposed to apps, host event timestamps enabling double-click zoom, and matching-host Wayland evidence via nested weston |
| [cursor-and-window-chrome](active/cursor-and-window-chrome.md) | Issue #25 cursor style API and issue #24 window chrome controls: view-declared pointer shapes resolved through the runtime hit chain and pushed to the host once per change; maximize/restore/fullscreen/decorations requests plus honest per-host capability reporting and interactive Linux CSD |
| [maturity-program](active/maturity-program.md) | Umbrella program for closing the external-adopter loop: developer loop (transient handoff + DevTools), productization correctness, ecosystem seed, and governance truth, followed by public-quality and 1.0-readiness phases |
| [maturity-dev-loop](active/maturity-dev-loop.md) | `moui dev` transient handoff (scroll/focus/caret), DevTools read-only protocol/server/client, and diagnostics forwarding |
| [maturity-productization](active/maturity-productization.md) | Release packaging, Linux native bundle, bundle identity, `moui verify` provenance, mobile release/signing, and physical-device evidence |
| [maturity-ecosystem](active/maturity-ecosystem.md) | External app onboarding first, addon registry seed, and notifications/permissions device plugin slice |
| [maturity-governance](active/maturity-governance.md) | Align docs/backend readiness with `checks/platforms/*.json` and add drift validators |
| [visual-quality](active/visual-quality.md) | Pointer to the completed plan at [done/visual-quality.md](done/visual-quality.md); kept only while the active-goal link references this path |
| [architecture-hardening-program](active/architecture-hardening-program.md) | Umbrella program for the 2026-11 architecture review: host seam, `core`/`runtime` package split, open service registry, text cache ownership, executable renderer capability plan, unified diagnostics, async task semantics, and release-line/SemVer mapping (`0.3.3` internal-only, `0.4.0` minor) |
| [cohesion-governance-convergence](active/cohesion-governance-convergence.md) | Second-round maintainability: oversized core file domain splits (gesture/text_editing), views helper dedup, shared pressable-transition slot, non-breaking grouped semantics constructors, plan archival + session knowledge deposit, budget-catalog review cadence, and pre-written structure triggers (core split threshold, backend/common runtime-import allowlist, MoonBit-blocker reopen checklist) |
| [dev-state-persistence](active/dev-state-persistence.md) | State-preserving `moui dev` restarts: `Program::with_state_persistence` contract in core, transport-aware restore/save in the runtime, shared native file transport over `MOUI_DEV_STATE_FILE`, counter example wiring, and TEA/development doc coverage |
| [widget-test-harness](active/widget-test-harness.md) | One shared widget-test API in `moui/runtime/test_support` replacing seven hand-copied `text_frame`/`has_text`/`click_text` helpers across example app tests |
| [spring-animation](active/spring-animation.md) | Spring physics for `TransitionSpec` (damping-ratio presets, closed-form settle curve) plus an interruptible stateful solver with velocity handoff for app-driven motion |
| [architecture-review-followups](active/architecture-review-followups.md) | Land the 2026-09 architecture review: renderer open-extension gates, runtime dirty-path optimization, overlay closure with macOS modal presenter, and backend close-order evidence |
| [windows-gpu-resize-swapchain-fix](active/windows-gpu-resize-swapchain-fix.md) | Windows GPU live-resize fix: the resize path reuses the per-HWND D3D12 swap chain through the present-path drain/resize/recreate sequence instead of creating a second flip-model swap chain, which DXGI rejects and which routed interactive drag-resize into the invisible CPU fallback |
| [native-accessibility](active/native-accessibility.md) | Complete native accessibility adapters and matching-host evidence for the Showcase Probe |
| [pointer-input-parity](active/pointer-input-parity.md) | Make declared-but-inert input land for real: long press / double tap, touch selection, multi-pointer identity, scroll rebound, honest text semantics, RTL mirroring |
| [text-provider-native-completion](active/text-provider-native-completion.md) | Finish the scaffolded native text providers: DirectWrite shaping/IME, fontconfig/HarfBuzz measurement, and matching-host Windows IME evidence |
| [gpu-partial-repaint](active/gpu-partial-repaint.md) | Turn damage bookkeeping into GPU-side partial repaint: per-route capability queries, damage-rect presentation on Metal/SkiaGpuNative, and present-rect budgets |
| [in-process-hot-reload-rfc](active/in-process-hot-reload-rfc.md) | RFC for replacing the restart-based dev loop with in-process reload: transient-state transport, interpreter-driven swap, or web-first module reload |
| [rtl-step3-native-base-direction](active/rtl-step3-native-base-direction.md) | Plumb `TextLayoutInput.direction` into the native providers (SkParagraph/cosmic/DirectWrite/CoreText) with a shared direction-matrix fixture |
| [webview-controller-bridge](active/webview-controller-bridge.md) | Replace the WebView command queue with controller-owned navigation, JSON bridge security, and HostPatch across desktop hosts |
| [linux-riscv64-support](active/linux-riscv64-support.md) | Add non-blocking Linux Skia Raster L0-L2 cross-build evidence for `riscv64-linux-gnu` |
| [linux-x11-backend](active/linux-x11-backend.md) | Add an X11 (Xlib) windowing backend to the Linux package with runtime selection and UTM VM validation |
| [mo-workbench-message-windowing](active/mo-workbench-message-windowing.md) | Mo Workbench 消息列表窗口化与重建优化 |
| [backend-renderer-lifecycle-convergence](active/backend-renderer-lifecycle-convergence.md) | Split backend-common state owners and collapse renderer binding to provider/session |
| [harmonyos-scroll-frame-pacing](active/harmonyos-scroll-frame-pacing.md) | Make the HarmonyOS frame loop pace on vsync as intended, gate the a11y pump on a published-generation cursor, and instrument the frame path for the frozen-frames capture |
| [macos-frame-pacing-and-transient-scroll](active/macos-frame-pacing-and-transient-scroll.md) | Add a CVDisplayLink frame clock to the macOS window host, pace the async pump on refresh boundaries, move the markdown editor's live glide into element state (one settle message per gesture), and add frame-log/diagnostic evidence |
| [mo-desktop-example](active/mo-desktop-example.md) | Add a responsive macOS-inspired MoUI desktop simulation with Web and macOS Skia entrypoints |
| [moui-studio-shell-completion](active/moui-studio-shell-completion.md) | MoUI Studio 壳收敛（ADR 0039）：四项预算棘轮冻结 app 旧壳（37,279 行/53 文件/161 Model 字段/291 Msg 变体，只降不升），S1 chrome 出壳 + S2–S7 六域按 ai/terminal 先例提取为插件包，抵达完成线（≤18,000 行/≤30 文件/≤55 字段/≤90 变体） |
| [moui-studio-right-panel-vscode-form](active/moui-studio-right-panel-vscode-form.md) | MoUI Studio 右栏改成 VS Code 侧面板（side panel）交互形态：面板头 + ghost 动作簇、扁平页签行、单一滚动区（快速操作/运行时监视改为分区）、底部常驻 AI composer；AI 输入面宿主唯一化（取消底栏 AI 页签与停靠切换钮）**（部分被 sidebar 方案推翻：输入面卡片化并移出检查器页）** |
| [moui-studio-right-panel-vscode-sidebar](active/moui-studio-right-panel-vscode-sidebar.md) | MoUI Studio 右栏改成 VS Code **分页侧栏**：六页签合并为「检查器」页、AI 另起一页（页块切换器 + 按页分派的头部动作簇）、输入面卡片化（圆角 + 描边 + 抬起面，芯片行入卡内，卡下状态行）、对象身份下移到正文首段的对象条；含真机复查修掉的四个可见缺陷（转录宽与裁剪区不同源、diff 长行不截断、卡标题不吃徽标宽、恢复会话残留 in-flight 卡）与配色/默认宽调整 |
| [moui-studio-scaffold-convergence](active/moui-studio-scaffold-convergence.md) | MoUI Studio 新建项目脚手架收敛：依赖版本一处事实、模块名归一、骨架补平台入口包，最终与 `moui new` 共用 `moui_cli/scaffold_plan` 声明式文件计划并事务化落盘；内核由 vendoring 转为发布依赖 |
| [window-cross-platform-parity](active/window-cross-platform-parity.md) | Align window (Windows/Linux/Web) with macOS reference in MoUI-ready semantics |
| [view-node-trait-refactor](active/view-node-trait-refactor.md) | Complete the public ViewNode trait migration |
| [crater-browser-integration](active/crater-browser-integration.md) | Pure-MoonBit browser demo: crater HTML engine + js_engine scripts rendered through MoUI canvas |
| [3d-moui-viewer](active/3d-moui-viewer.md) | Independent static glTF/GLB viewer addon with explicit GPU capability status |
| [richtext-markdown-domain-relocation](active/richtext-markdown-domain-relocation.md) | Move the Markdown editing domain model out of `moui_richtext` into `moui_markdown` to converge its public surface toward ~30 pub lines |
| [line-level-viewport-window](active/line-level-viewport-window.md) | Window the visible range at line granularity inside one oversized markdown block so open and scroll cost track the viewport instead of the document |
| [no-third-party-gpu-route](active/no-third-party-gpu-route.md) | Apple-first Metal renderer that links no external graphics library (ADR 0044, supersedes 0043's conclusion). **Route parked at L0 (2026-10-27): the kill gate fired** — the shipped Skia-Metal route already holds `presentMs` at 0.10–0.76 ms p50 so there is no performance prize, and the license motive is struck; only size-versus-Skia + autonomy survive. L0.1 (provider-parametric harness) and L0.2 (neutral text-model extraction out of the wgpu-importing package) stay live as framework work |

## Debt

| Debt note | Summary |
|-----------|---------|
| [viewnode-trait-decomposition](debt/viewnode-trait-decomposition.md) | Fat 15-method `ViewNode` split stays parked behind three MoonBit limits (no bare-`T` impl target, single parent trait, no trait-object narrowing), not blanket impls alone |
| [view-state-slot-storage](debt/view-state-slot-storage.md) | Replace copy-on-write `Map[DeclarationKey, Bytes]` slot storage if event-path profiles demand it |
| [renderer-session-closure-style](debt/renderer-session-closure-style.md) | Revisit `RendererSession` closure record vs trait when renderer duplication or capability mistakes justify an RFC |
| [message-transform-chain](debt/message-transform-chain.md) | Remove recursive `View::map` adapter copies only if MoonBit gains safe existential/associated-source typing or profiles justify a larger runtime redesign |
| [skia-manual-smoke-prebuild-migration](debt/skia-manual-smoke-prebuild-migration.md) | Port the manual macOS/Linux/Windows Skia smoke runners off the retired `configure-*-native-pkg --write` + `MOON_CC` flow onto the `build.mbtx` environment exports; real-Skia hosts and pwsh needed before validating, so parked |

## Done

| Plan | Summary |
|------|---------|
| [done/INDEX](done/INDEX.md) | One row per retired plan (70 bodies, 2026-07 → 2026-11-19) with its outcome and landing commit; start here before reopening an archived subject |
| [visual-quality](done/visual-quality.md) | Default-theme visual baseline: Desktop preset metrics/typography, control craft, typography + icon expression, materials/motion defaults, and a `visual` gate with a per-control state matrix, rendered previews, and gallery-derived README/website screenshots. **Complete 2026-11-13**; the human blind-review gate is explicitly waived by the agent and remains available for a later real review |
| [harness-mechanize-invariants-batch1](done/harness-mechanize-invariants-batch1.md) | Map-style AGENTS/docs + P1/P2/A6/R3/M5/G1/G2 machine checks with agent-facing fix hints |

Move finished plans out of `active/` in the same PR that closes the work: add one
row to `done/INDEX.md` and drop the plan file.
