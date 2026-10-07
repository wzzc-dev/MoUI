# Plans

Executable work memory for multi-step agent and human efforts.
Formal specs and standing decisions live in **`docs/`** (ADRs under
`docs/decisions/`), not in tool-specific plan folders.

## Layout

```text
docs/plans/
  README.md                 # this file
  active/<id>.md            # in-flight exec plans
  done/<id>.md              # finished plans (keep for audit)
  debt/<id>.md              # known tech debt with acceptance notes
```

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
| [architecture-review-followups](active/architecture-review-followups.md) | Land the 2026-09 architecture review: renderer open-extension gates, runtime dirty-path optimization, overlay closure with macOS modal presenter, and backend close-order evidence |
| [semantic-id-ergonomics-and-path-targeting](done/semantic-id-ergonomics-and-path-targeting.md) | Declare semantic ids inline and let agents walk the committed semantics hierarchy with a filtered `ByPath` target |
| [native-accessibility](active/native-accessibility.md) | Complete native accessibility adapters and matching-host evidence for the Showcase Probe |
| [webview-controller-bridge](active/webview-controller-bridge.md) | Replace the WebView command queue with controller-owned navigation, JSON bridge security, and HostPatch across desktop hosts |
| [linux-riscv64-support](active/linux-riscv64-support.md) | Add non-blocking Linux Skia Raster L0-L2 cross-build evidence for `riscv64-linux-gnu` |
| [linux-x11-backend](active/linux-x11-backend.md) | Add an X11 (Xlib) windowing backend to the Linux package with runtime selection and UTM VM validation |
| [mo-workbench-message-windowing](active/mo-workbench-message-windowing.md) | Mo Workbench 消息列表窗口化与重建优化 |
| [release-module-dependency-closures](done/release-module-dependency-closures.md) | Split concrete renderers and integration tests out of the base publication closure |
| [backend-renderer-lifecycle-convergence](active/backend-renderer-lifecycle-convergence.md) | Split backend-common state owners and collapse renderer binding to provider/session |
| [runtime-state-render-ownership-convergence](active/runtime-state-render-ownership-convergence.md) | Move accessibility out of runtime, unify app state ownership, and make renderer sessions own render resources |
| [mo-desktop-example](active/mo-desktop-example.md) | Add a responsive macOS-inspired MoUI desktop simulation with Web and macOS Skia entrypoints |
| [moui-studio](active/moui-studio.md) | MoUI Studio：中英双语的积木/代码同源可视化编程环境，单一程序 IR 支撑设计/积木/双语代码三视图与结构化 AI 提案，取代 Mo易/MoBlocks 双 Studio |
| [moui-studio-capability-upgrade](active/moui-studio-capability-upgrade.md) | MoUI Studio 能力升级：真编辑器/诊断面板/运行时检查器/键盘与进程卫生/积木形状/语言层(函数·数组·整数)/属性 schema 与新控件事件/MoonBit 情报 |
| [moui-studio-workbench](active/moui-studio-workbench.md) | MoUI Studio 工程工作台：代码真源(handlers.mbt/form.mbt)+ 三模式预览(画布快览/web+webview/native)+ 拖拽布局设计器 + 工程导入与资源管理器 + 积木长成 Blockly for MoonBit(IR 逐构造生长)，.studio.json 迁移退役 |
| [moui-studio-props-v2](active/moui-studio-props-v2.md) | MoUI Studio 可视化属性 v2：ControlProps（字号/加粗/颜色/对齐/可见/禁用 + TextField 三件）typed 字段 + codec 缺省兼容 + form_widget 主题覆盖渲染 + 检查器属性面板（走撤销点） |
| [moui-studio-blocks-standalone](active/moui-studio-blocks-standalone.md) | MoUI Studio 积木独立：OnStart 启动事件（两轨+导出）+ ForEach 九面全套 + 列表/字符串/数学内建补全 + 骨架表全可达，双轨差分门用例守住 |
| [moui-studio-workspace-feel](active/moui-studio-workspace-feel.md) | MoUI Studio 工作区手感：多标签编辑(光标随 tab/脏关闭确认/保存全部) + 文件 CRUD(新建/改名三步链) + 全文搜索(BtSearch 页签+跳转) + 保存即自动构建 live 诊断 |
| [moui-studio-markdown-plugin](active/moui-studio-markdown-plugin.md) | MoUI Studio Markdown 插件：.md 打开即 MoMark 引擎格式编辑（moui_richtext.markdown_editor）+ 草稿/写盘通道零新机制;无状态视图贡献（terminal 先例） |
| [moui-studio-workspace-import](active/moui-studio-workspace-import.md) | MoUI Studio 工作区导入：moon.work 成员逐模块导入 + 规模治理(入口候选不深读/三级上限/进度节流) + 工程记录持久化(.studio/projects.json v1, 启动静默重扫) |
| [moui-studio-ai-chat](active/moui-studio-ai-chat.md) | MoUI Studio AI 模式改造为对白转录工作台：用户气泡/AI 消息/工作卡时间线 + composer 信息层(工程/模型/姿态) + 会话列表(相对时间/分组/置顶/搜索) + native 会话落盘 |
| [moui-studio-ai-look](done/moui-studio-ai-look.md) | MoUI Studio AI 模式二期：向 VS Code 智能体模式空态基准复刻——双行会话行(常显时间)/区头动作/双下拉芯片/提示行并入卡头/单模式下拉/空态居中+姿态读数 |
| [window-cross-platform-parity](active/window-cross-platform-parity.md) | Align window (Windows/Linux/Web) with macOS reference in MoUI-ready semantics |
| [view-node-trait-refactor](active/view-node-trait-refactor.md) | Complete the public ViewNode trait migration |
| [crater-browser-integration](active/crater-browser-integration.md) | Pure-MoonBit browser demo: crater HTML engine + js_engine scripts rendered through MoUI canvas |
| [moui-tier-tea-debt-convergence](active/moui-tier-tea-debt-convergence.md) | Converge platform tiers, strict TEA boundaries, entrypoints, and documentation debt |
| [window-scene-family-relocation](done/window-scene-family-relocation.md) | Move the window scene resolution family from runtime to backend/common/lifecycle, the P10 neutral-lifecycle owner |
| [moui-cli-desktop-commands](done/moui-cli-desktop-commands.md) | Extend moui build/run/package to all platforms with in-process MSVC env configuration and script-absorbed packaging |
| [3d-moui-viewer](active/3d-moui-viewer.md) | Independent static glTF/GLB viewer addon with explicit GPU capability status |
| [richtext-markdown-domain-relocation](active/richtext-markdown-domain-relocation.md) | Move the Markdown editing domain model out of `moui_richtext` into `moui_markdown` to converge its public surface toward ~30 pub lines |
| [line-level-viewport-window](active/line-level-viewport-window.md) | Window the visible range at line granularity inside one oversized markdown block so open and scroll cost track the viewport instead of the document |
| [overlay-system-redesign](done/overlay-system-redesign.md) | Ordered `OverlayHost + PresentationSpec` with runtime placement/input/focus and neutral host-modal transport |
| [overlay-placement-portal-unification](active/overlay-placement-portal-unification.md) | Move anchoring out of the layout fixpoint (post-layout placement pass), add the portal path for control popups, unify popup mechanisms, and add LayerStack/hit/transition/native-modal completion |
| [feature-scope-composition](active/feature-scope-composition.md) | Add `Feature[Model, Msg]` + `Feature::scope` lens composition to core, `FieldAction` keyed forms, and settings/workbench pilots |
| [moui-studio-plugin-kernel](done/moui-studio-plugin-kernel.md) | MoUI Studio 插件化改造：静态插件内核（Plugin 契约/服务注册表/事件总线）+ 三模式工作台 + AI 满配（多会话/Markdown/流式/真终端）+ 编辑器完善 + 教学版 profile |

## Debt

| Debt note | Summary |
|-----------|---------|
| [viewnode-trait-decomposition](debt/viewnode-trait-decomposition.md) | Split the fat 14-method `ViewNode` trait once MoonBit supports blanket impls |
| [view-state-slot-storage](debt/view-state-slot-storage.md) | Replace copy-on-write `Map[DeclarationKey, Bytes]` slot storage if event-path profiles demand it |
| [renderer-session-closure-style](debt/renderer-session-closure-style.md) | Revisit `RendererSession` closure record vs trait when renderer duplication or capability mistakes justify an RFC |

## Done (recent)

| Plan | Summary |
|------|---------|
| [view-framework-remediation](done/view-framework-remediation.md) | 消除声明键覆盖、flex 紧约束重测、shaping 缓存、map 放大与 Effect 键防撞等实现不合理点 |
| [p1-daily-developer-efficiency](done/p1-daily-developer-efficiency.md) | Add the dev loop, structured Inspector, performance budgets, and scalable data-view primitives |
| [p2-platform-ecosystem](done/p2-platform-ecosystem.md) | Expand platform services, deterministic packaging, and compatibility governance |
| [macos-first-present-visibility](done/macos-first-present-visibility.md) | Reveal Mo Desktop and Mo Workbench only after their first successful macOS presentation |
| [webview-window-drag](done/webview-window-drag.md) | Preserve clickable WKWebView top-bar controls while blank space drags the macOS window |
| [webview-moui-overlay](done/webview-moui-overlay.md) | Expose MoUI overlay pixels and pointer input above macOS WKWebView siblings |
| [backend-render-package-convergence](done/backend-render-package-convergence.md) | Replace host/bridge packages with symmetric backend/render protocol and common implementation layers |
| [platform-adapter-duplication-remediation](done/platform-adapter-duplication-remediation.md) | Eliminate shared platform behavior copies and remove similarity budgets |
| [moui-support-upstream-workspace](done/moui-support-upstream-workspace.md) | Complete the upstream-layout migration, compatibility release, and published-dependency handoff |
| [window-host-lifecycle-unification](done/window-host-lifecycle-unification.md) | Move all logical window lifecycle and frame coordination into MoUI window_host |
| [backend-renderer-extraction](done/backend-renderer-extraction.md) | Move renderer construction out of platform backends and into composition roots |
| [renderer-backend-decoupling](done/renderer-backend-decoupling.md) | Historical predecessor superseded by backend renderer extraction |
| [renderer-provider-trait-refactor](done/renderer-provider-trait-refactor.md) | Historical provider proposal superseded by architecture convergence |
| [validation-hygiene-cleanup](done/validation-hygiene-cleanup.md) | Remove validator self-tests and retain product/evidence validation |
| [moonbit-tooling-formalization](done/moonbit-tooling-formalization.md) | Move formalizable repository rules into MoonBit tools |
| [all-target-diagnostics-cleanup](done/all-target-diagnostics-cleanup.md) | Restore clean `moon check --target all` output outside window packages |
| [moui-architecture-convergence](done/moui-architecture-convergence.md) | Converge package ownership and dependency direction per ADRs 0014/0015/0017–0020 (Phases A–G) — complete |
| [core-component-theme-to-views](done/core-component-theme-to-views.md) | Component theme → views control set (superseded by ADR 0017; `Theme.components` removed) — complete |
| [i18n-website](done/i18n-website.md) | Add a pure i18n addon and localize the complete public website and docs |
| [web-input-router-consolidation](done/web-input-router-consolidation.md) | Make moui/backend/web the single owner of trusted browser pointer routing |
| [website-showcases-single-scroll](done/website-showcases-single-scroll.md) | Single-scroll Showcases page with accurate platform/source metadata |
| [window-hosted-legacy-cleanup](done/window-hosted-legacy-cleanup.md) | Remove retired mobile packaging and embedding entrypoints |
| [agent-semantic-actions](done/agent-semantic-actions.md) | Declaration invalidation, committed Agent semantics, four-channel ViewDeclaration |
| [web-first-click-dpr-fix](done/web-first-click-dpr-fix.md) | Fix Website first-click activation by synchronizing browser DPR |
| [window-upstream-sync](done/window-upstream-sync.md) | Rebase MoUI fork onto upstream moonbit-community/window workspace layout |
| [backend-hosting-terminology](done/backend-hosting-terminology.md) | Classify backends by host ownership: native-host and embedded-runtime routes |
| [harness-mechanize-invariants-batch1](done/harness-mechanize-invariants-batch1.md) | Map-style AGENTS/docs + P1/P2/A6/R3/M5/G1/G2 machine checks |
| [website-scroll-performance](done/website-scroll-performance.md) | Remove Website scroll-path DOM churn and ship optimized showcase previews |
| [markdown-html-image-gallery](done/markdown-html-image-gallery.md) | Render the safe HTML image-gallery subset in Markdown Editor |
| [row-child-hit-testing](done/row-child-hit-testing.md) | 原报 `row` 子级按钮与 `on_drag` 不命中；2026-09-26 复核在 moon 0.1.20260920 下不再复现（8 形状探针 + canvas/按钮/普通 view 拖拽全部正常），行为由 `moui/runtime/row_child_pointer_input_test.mbt` 固定 |
| [repo-format-and-ratchet-drift](done/repo-format-and-ratchet-drift.md) | 仓库级格式漂移与 ratchet 过期：2026-09-26 已修复（生成 facts 重写、6 个 ratchet 重登记、5 个漂移文件 `moon fmt`，`moon fmt --check` 全仓 0 差异） |
| [moblocks-studio](done/moblocks-studio.md) | MoBlocks Studio（积木工作流 + AI 提案 + 导出）——已完成，2026-09-27 归档：被 MoUI Studio 取代，对应代码删除 |
| [moblocks-studio-v2](done/moblocks-studio-v2.md) | MoBlocks Studio v2（Web 拖拽回归、拼图积木、四区布局）——已完成，2026-09-27 归档：被 MoUI Studio 取代 |
| [moeui-studio](done/moeui-studio.md) | Mo易 Studio（中文 DSL + 表单设计器 + 提案式 AI）——已完成，2026-09-27 归档：被 MoUI Studio 取代，对应代码删除 |

Move finished plans to `done/` in the same PR that closes the work.
