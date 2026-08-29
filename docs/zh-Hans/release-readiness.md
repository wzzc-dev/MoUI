# 发布就绪性

本页描述当前预览发布的验证策略。它是新发布工作的清单，
不是永久观察台账。

## 基线

当仓库能够证明以下事项时，MoUI 即可进行预览交接：

- 平台中立 runtime 流水线保持显式：
  `View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer`。
- 公开 view 构造器返回不透明的 `@moui.View[Msg]`；app 代码使用
  TEA 形态的 `Program` surface，包含 typed messages、需要时用于后续工作的显式
  `Effect[Msg]`、用于持续回调和待完成 host-service 的 app 级
  `Subscription[Msg]` event sources，并在支持的平台上通过 Web wasm-gc、macOS native
  和 Windows native entrypoints 共享逻辑。
- Renderer capability 状态在
  `render/capabilities.mbt`、`render/capabilities_test.mbt` 和
  `docs/renderer-capability-report.md` 之间保持同步。
- 高风险行为使用相同的四层 conformance 模型：`core`
  contract tests、host routing tests、implementation/provider tests，以及
  matrix/diagnostic conformance entrypoints。
- Showcase 和 Markdown Editor 作为可运行文档，而不是隐藏的 smoke tests。
- Showcase 仍是框架功能首选的可见验证 surface：新的用户可见 views、renderer capabilities、host-service flows
  或值得作为示例的平台行为，应添加 Showcase 覆盖，除非在其中展示不可能或会造成误导。
- Platform backends 保持为围绕 `backend` 的 adapters；不支持的平台路径标记为 scaffolds，
  而不是暗示已经完整。
- 开发验证有边界、可重复且有文档记录。
- `AGENTS.md` 和 repo-local skills 与 package boundaries、validation commands、examples、
  renderer capability rules 以及 text-system architecture 保持一致。

## 当前证据

| 领域 | 证据 | 状态 |
| --- | --- | --- |
| 每日验证 | `sh scripts/check.sh --profile daily` 运行有边界的 mainline package tests、runner self-tests、maintenance baseline ratchets、API surface guard、checked conformance artifact guard、用于 capture/Web/platform/renderer-proof manifests 的专用 checked-artifact validators，以及 Showcase 和 Markdown Editor 的 Web wasm-gc builds。Design Systems 通过 `sh scripts/check.sh --profile theme` 作为 addon diagnostic coverage。 | 就绪 |
| Package boundaries | `docs/architecture.md`、`AGENTS.md` 和 repo-local skills 描述相同的 `core` / `views` / `backend` / `render` / `examples` 划分。 | 就绪 |
| 公开 view model | `View`、`Program`、`Effect`、`Subscription`、`ProgramCommand` 和 `Program::with_commands` 是类型化 TEA API。`ServiceTask[T]` 把 app service 的成功、失败和取消映射为 `Msg`；`TimerSource` 与 `RouteSource` 直接创建 core subscription。Runtime 将 view、effect、service、快捷键、系统菜单和 context menu 消息按 FIFO 送入同一个 update。 | 就绪 |
| 示例形态 | `examples/*/app` 的生产依赖不包含 runtime、backend 或 render 包。示例模块根集成包向 app 传递中立 DTO。File Importer 演示不暴露 host request id 或 completion subscription 的 typed service task。 | 就绪 |
| Renderer capability tracking | Capability 状态记录在代码、测试和 `docs/renderer-capability-report.md` 中。 | 就绪，存在已跟踪缺口 |
| Platform contracts | `backend` 拥有 wire request、`HostServiceBridge`、completion queue、input/IME 和 renderer-neutral host contract；`moui/services` 拥有 app-facing capability surface。具体 backend 暴露 `app_environment()` 与 `PlatformEntry`，composition root 通过 `@runtime.run_app` 组装。平台 runtime claim 仍以 matching-host artifact 为准。 | macOS/Web 当前有效；Windows/Linux 与 Tier 3 继续按证据推进 |
| Text system | `docs/text-system.md` 记录 `TextSystem`、paragraph layout geometry、provider composition、embedded fonts、Skia `skia_text_system()` diagnostic coverage、native SkParagraph routing 以及支持的 text/emoji proof。Stable 和 diagnostic text conformance checks 通过了 paragraph line metrics/selection/hit-test 覆盖，Skia text maturity preflight 现在跟踪 bidi reordering、paragraph line breaking、Unicode 17 grapheme boundaries 以及 deterministic color emoji readiness。 | 就绪 |
| Devtool counters | Core inspector snapshots 暴露 runtime、cached layout、cached semantics、cached render command、带 dirty element ids 的 structured dirty-state summaries（用于 pending rebuild/layout/paint/redraw work）、rebuild/layout/paint/draw-command pass counters、区分 send、anonymous dispatch、structured run 和 one-shot task effects 的 TEA dispatch/update/message-queue/effect-plan/effect-kind counters、带 structured effect descriptors 的 latest effect summaries、aggregate duplicate effect descriptor-key counters/names、active/completed/cancelled effect-task counters 和 lifecycle entries、带 planned source descriptors 的 subscription-plan counters/summaries、aggregate duplicate subscription-key counters/names、active subscription descriptors、active subscription kind-count summaries、app subscription lifecycle entries、ignored stale effect-task/subscription dispatch counters，以及 runtime destruction 后 late anonymous 或 structured effect callbacks 的 ignored program-dispatch counters；message queue diagnostics 现在通过把超额 synchronous self-queued click/effect/task/subscription messages 留在 `pending_message_count` 中，而不是无限制 drain，证明有边界的 per-turn drains；聚焦 core tests 还证明 pending `Effect::send`、structured `Effect::run` 和 subscription-start work 会在下一个 host callback 上按 FIFO 恢复，而 one-shot `Effect::task` dispatch 只完成一次，并把 immediate synchronous redispatch 计为 stale；inspector capture 不会 drain pending dirty work，render snapshots 也报告 open clip/layer/filter scopes 和 unbalanced pops，Showcase Diagnostics 则呈现 render command/scope counters 以及 dirty summary、TEA message、structured effect、effect-task、subscription plan、active subscription、subscription kind summary 和 descriptor labels，并带有 app-test 覆盖。 | 已为命令级诊断就绪 |
| Guidance surface | `docs/ai-collaboration.md`、`AGENTS.md` 和 `skills/` 定义聚焦的 agent workflows。 | 就绪 |

## 必需门禁

| 门禁 | 必需观察 | 命令 |
| --- | --- | --- |
| daily baseline | 有边界的 package checks、guidance consistency、maintenance baseline ratchets、API surface guardrails、renderer/provider static checks、Showcase 和 Markdown Editor app tests 以及 Web wasm-gc builds 通过。Design Systems 通过 `--profile theme` 作为 addon diagnostic coverage。 | `sh scripts/check.sh --profile daily` |
| 发布模块闭包 | 基础 archive 不包含 concrete renderer、renderer binding、WGPU/Cosmic/Swash/image、quickcheck、pixelmatch 或集成测试包；renderer module 只向内依赖，`moui_tests` 保持不发布，workspace pins 与当前模块版本一致，并且受检的发布阶段拓扑有效。 | `node scripts/validate-release-module-closures.mjs`；`docs/testing.md` 中的 package-mode base/Skia/Web 命令 |
| maintenance ratchets | 超大 source/test files、源码级 `pub(all)` 以及 root facade forwarding counts 不增长；已完成 refactors 将其预算下调。 | `node scripts/validate-maintenance-baseline.mjs` |
| Public API audit | Public API 变化后审查生成接口，并确保 package budget 与 boundary token 仍通过。 | `moon info`，然后运行 `node scripts/validate-api-surface.mjs` |
| Focused conformance | Input/focus、layout、render、platform service 和 text slices 在各自 owning layer 通过。 | 编辑期间运行聚焦的 `moon test ...` 命令；current-host platform services 使用 `sh scripts/check.sh --profile platform`；广泛交接前使用 `sh scripts/check.sh --profile full`。 |
| Text conformance | Stable text contracts 和 diagnostic gaps 保持当前。 | `sh scripts/check.sh --profile full` |
| Native Skia paragraph/bidi proof | macOS、Windows 和 Linux native Skia renderer-proof manifests 以真实 SkParagraph 证据通过 paragraph wrapping、bidi visual order、selection rectangles 和 hit testing。Fallback geometry、caret-only diagnostics、heuristic visual-order logs、package tests、provider preflights，以及没有 GitHub Actions provenance 的 local manifests 均不满足此门禁。 | 在每个匹配主机上运行 `MOUI_SKIA_REQUIRE_SKPARAGRAPH=1 moon run moui_tests/skia_text_emoji_smoke/native --target native`；renderer-proof manifests 由 `MoUI CI` GitHub Actions `Native Skia renderer proof` jobs 生成并验证（见下方证据表） |
| Web runtime presentation | 在 Web runtime claims 标记为 passed 前，Web Showcase 在 browser session 中运行，并具备 WebGPU、wasm startup、sized canvas、resize/input event-bridge delivery、text input、clean target close、clean console、nonblank screenshots、Showcase transform-scene pixel markers，以及用于 RGBA color emoji glyphs（带 font metadata 和 glyph key/size metadata）、ZWJ grapheme layout、bidi visual order、paragraph line metrics/pixels、selection rectangles/line ranges、grapheme edit boundaries/actions、IME candidate anchors/surrounding text、composition ranges/preedit pixels 和 async image second-frame ordering 的 Web renderer-proof events。Web fold 必须保留 provenance：由成功且非 skipped 的 `web-runtime-presentation` Actions job 生成时为带 CI workflow/job/run URL/runner 的 `github-actions`，在匹配主机上生成时为带 local browser-session artifact bundle 的 `matching-host-artifact`。 | 在 CI 或配置好的匹配主机上运行 `sh scripts/ci-web-runtime-presentation.sh`；手动等价命令：`node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed`，然后 `node scripts/validate-web-runtime-presentation-manifest.mjs artifacts/conformance/web-runtime-presentation.json --require-passed` |
| Platform contracts | Shared host/Web service checks 和 current-host backend/provider checks 保持覆盖；声称时，matching-host runtime evidence 具有已验证 manifest。Native passed entries 必须分别通过 Showcase runtime artifacts 证明 IME candidate anchors、surrounding text、composition visuals、commit/delete behavior、cursor updates、scroll anchors、scale/DPR anchors 和 resize anchors。 | platform behavior 变化时运行 `sh scripts/check.sh --profile platform`；该 profile 从 shared platform service checks 开始，并把 host-specific backend/provider package steps 留在 `checks/profiles.json` 中。Matching-host runtime evidence manifests 由 `MoUI CI macOS platform evidence dispatch` workflow 记录并验证（见下方证据表） |
| Examples | Showcase 和 Markdown Editor 保持为默认可运行文档；新的用户可见 framework features 具有可见 Showcase 覆盖，或记录跳过理由。Design Systems 是隔离在专用 `moui_theme` preview example 中的 addon diagnostic coverage。 | Mainline app package tests 加 Showcase/Markdown Editor Web wasm-gc builds；addon checks 使用 `sh scripts/check.sh --profile theme` |
| Guidance freshness | Docs、`AGENTS.md` 和 repo-local skills 在影响 guidance 的变更后保持一致。guidance-consistency guard 作为 MoonBit 工具在 `tools/moui/validate_guidance_consistency` 实现；使用 `moon run tools/moui/validate_guidance_consistency --target native` 直接运行，并在 handoff 中加入手动 audit notes。 |  |

只有在明确授权发布时，0.2 模块发布顺序才是：基础模块与 bindings；
Skia/Web/WGPU/Sun renderer modules；addons 与 agent；最后是 agent
MCP 与 CLI。`checks/release-modules.json` 是目录/阶段的唯一目录表。版本相等
只属于 0.2 迁移首发条件；后续模块独立演进。

## 当前证据快照

<!-- EVIDENCE_SNAPSHOT_PREAMBLE_START -->
此快照记录当前预览就绪证据。
下方 GitHub Actions 证据刷新表由
`scripts/refresh-evidence-table.mjs` 自动生成；下方快照、证据和状态
列由人工维护。
在发布候选交接前刷新完整门禁集。
<!-- EVIDENCE_SNAPSHOT_PREAMBLE_END -->

| 门禁 | 当前证据 | 状态 |
| --- | --- | --- |
| Daily baseline | 默认 `sh scripts/check.sh --profile daily` 现在覆盖 local dependency guards、guidance consistency、maintenance baseline ratchets、API surface guardrails、renderer/provider 和 native Skia entrypoint wiring、checked conformance artifacts、专用 capture/Web/platform/renderer-proof manifest validators、core/views/render/backend/package tests，以及 Showcase 加 Markdown Editor app/Web wasm-gc validation。`sh scripts/check.sh --profile theme` 将 Design Systems 和 `moui_theme` 保持为 addon diagnostic coverage，`sh scripts/check.sh --profile platform` 仍是 current-host backend/provider extension；在 Darwin 上，它此前覆盖 macOS backend/provider checks。2026-06-03，`scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke` 在 Darwin 上使用 pinned JetBrains Skia provider 通过，覆盖 MoUI renderer pixels 和 first-frame Showcase macOS Skia presentation。 | 当前默认门禁，加可选诊断和 Darwin 主机扩展 |
| Public API audit | `moon info` 与 `validate-api-surface.mjs` 审查根门面 TEA API、runtime-owned AppBuilder / PlatformEntry / AppLaunchRequest、不透明 HostSurface/NativeSurface、图片契约、RendererProvider/RendererSession、host diagnostics 及平台 options。根 `wzzc-dev/moui` 不依赖 runtime，也不暴露 `run_app`；具体 renderer 构造、平台策略和 decode API 只存在于 `moui_*_renderer`。 | 当前 |
| Web route/history API | Web route/history bridge 添加 `WebAppOptions.route_source`、`web_dispatch_route` 和 `web_history_push_route` / `web_history_replace_route` / `web_history_back` / `web_history_forward`，使 browser history 可以发布 typed route events，同时 shared app reducers 保持 route history app-owned。 | Web host route subscriptions 当前有效；native deep-link dispatch 仍是后续项 |
| Renderer sync | render/capabilities.mbt、renderer package tests 和 docs/renderer-capability-report.md 仍是事实来源。应用入口注册有序 RendererProvider；平台 backend 创建 HostSurface，frame owner 只接收中立 RendererSession。平台 HostImageSource 读取原始字节，Skia、Sun 与 WGPU 各自拥有 RendererImageDecoder 解码/completion 逻辑。backend image owner 只管理可取消 I/O task；opaque token 的 Applied/Stale/Disposed completion 由 session 判定，资源状态与 cache residency 不在 backend 镜像；跨 renderer 生命周期测试位于 `moui_tests/renderer_contract`。 | 当前 |
| Focused conformance | `sh scripts/check.sh --profile platform` 覆盖 shared platform service checks 加 host-specific backend/provider package tests，`sh scripts/check.sh --profile full` 添加 text diagnostics 和 capture scaffolds。shared service check 将 `wzzc-dev/window@0.5.4-0.1.5` registry package 作为 dependency source，并在可用时使用其缓存的 generated Wayland protocol sources 做非 Linux 上的 Linux protocol/cache sanity；Linux host backend/provider tests 位于 host-specific profile steps。 | 当前，带 host/setup-scoped Linux service evidence、已通过的 macOS 与 Windows platform runtime evidence，以及 pending Linux runtime manifest entries |
| Text conformance | Stable text conformance 覆盖 core、native renderer/provider validation、Web adapter 和 Web backend。Core fallback carets 现在保留 per-character arrays，同时 shared UAX-style `TextGraphemeBoundaries` scanner 稳定 cluster interiors，以获得 deterministic selection 和 IME-anchor geometry；basic left/right caret movement 和 shift-selection 使用相同 boundaries，并带有 core grapheme classes 的 generated Unicode 17.0 property predicates，以及 Indic_Conjunct_Break Linker/Consonant/Extend data。Core tests 覆盖 CRLF/control segmentation、high-plane controls、ZWNJ-as-Extend behavior、emoji ZWJ restrictions、keycap/tag emoji、regional-indicator pairing、Indic conjuncts、virama-plus-Latin/space break behavior、extended Hangul Jamo、representative combining/spacing-mark clusters、Arabic/Thai/Lao/Sinhala/Khmer/Myanmar mark or conjunct clusters、supplementary musical Extend marks，以及完整 vendored Unicode 17.0 default `GraphemeBreakTest.txt` fixture。生成的 full Unicode editing fixture 还覆盖 `is_boundary`、floor/ceil/nearest snapping、collapsed and expanded range normalization、surrounding delete ranges、raw boundary-to-UTF-8 offset conversion，以及每个 fixture row 上 every-index `nearest_boundary_utf8_offset` snapping；生成的 layout fixture 覆盖相同行的 fallback paragraph caret rectangles、collapsed selection rectangles 和 hit-test offsets，因此 core selection、hit-test 和 IME offset primitives 现在共享相同的 Unicode 17 证据。Skia renderer tests 通过 `skia_grapheme_cluster_texts` 运行同一个 full fixture，并对照 Skia-produced boundaries 做 every-index normalized UTF-8 offset checks，因此 mixed-run fallback segmentation 在 font resolution 前已有 renderer-local Unicode 17 IME offset evidence。shared paragraph layout contract 现在暴露 wrapped line metrics、caret rectangles、selection rectangles 和 hit-test geometry，并带有显式 native paragraph/bidi readiness flags。Diagnostic matrix tests 覆盖 core fallback、Cosmic、platform-default composed fallback/scaffolds、malformed-provider fallback、Skia fallback paragraph geometry、optional SkParagraph geometry，以及可用时的 Web text systems。Web host capability reporting 现在声明 browser IME plumbing，因为 `window/web` 接受 `TextInputSession` IME requests 并发出 browser composition lifecycle events；shaping/color-emoji/native SkParagraph proof 和 matching-host native IME runtime evidence 仍分别跟踪。 | Unicode 17 core editing/selection/hit-test/IME-offset primitives 和 Skia grapheme segmentation 当前有效；未来 Unicode-data refreshes、shaping/color-emoji gaps、native SkParagraph proof gate 与 native IME runtime evidence 已记录 |
| Native Skia paragraph/bidi proof | `moui_skia` 暴露 `skia_paragraph_available()` 以及用于 UTF-8 layout、line metrics、selection boxes 和 hit testing 的 native `Paragraph` wrapper（默认构建）；`moui_skia_renderer` 在 SkParagraph 可用时使用它，否则保持 fallback readiness flags 为 false。Renderer-proof validation 现在要求 `paragraphWrapping` 带有 `engine=skparagraph native_paragraph_ready=true line-metrics later-line-pixels`，`bidiLayout` 带有 `engine=skparagraph bidi_visual_order_ready=true visual-order`，`selectionRects` 带有 `engine=skparagraph selection-rects line-range rect-geometry hit-test`。GitHub Actions run `27227687435` 产出了非 skipped 且成功的 macOS、Windows 和 Linux native Skia renderer-proof jobs，带有 `github-actions` provenance 和 `status=passed`；`Renderer proof summary` 验证了这些 manifests 以及 WebGPU wasm proof manifest。较早的 macOS platform runtime evidence dispatch `27217345886` 也在 macOS-only runtime artifact bundle 中上传了 passed `skia-native-macos.json`。 | 当前具备 macOS/Windows/Linux GitHub Actions renderer-proof provenance；platform runtime readiness 仍是独立 manifest gate |
| Platform contracts | `backend` 覆盖 window commands、host services、event sources、text input 与 IME diagnostics。共享 state 分属 `backend/common/{lifecycle,frame,image,input,services}`，root common 只保留无状态 workflow。具体平台包暴露 `PlatformEntry` 与不透明 `HostSurface` capabilities；composition root 通过 `@runtime.run_app` 提供 renderer providers。Web history 保持 backend-owned host behavior，native renderer 选择、平台策略与 decode 则位于所有 backend 之外。Package tests 验证 contract 与 boundary wiring，matching-host first-frame、IME、service 和 renderer artifacts 仍是 runtime claim 的证据来源。 | macOS platform runtime 已有记录 artifact；Web route/history 当前有效；Linux runtime evidence 仍为 matching-host pending（Windows 已于 2026-08-29 记录，ADR 0031） |
| Examples | 默认 daily check 运行 `moon test examples/showcase/app --target native`、`moon test examples/markdown_editor/app --target native`，以及 Showcase 和 Markdown Editor 的 Web wasm-gc builds。Showcase capability cards 现在首先呈现 follow-up rows，host capability card 对注入的 host summaries 具有 app-test coverage；native Showcase Skia entrypoints 会被静态验证为注入匹配的 platform capability summary。Markdown Editor app tests 覆盖 runtime undo/redo 中的 Unicode paste，`sh scripts/check.sh --profile theme` 则让 Design Systems app/Web validation 和 `moui_theme` checks 可作为 addon diagnostic coverage 使用。File Importer app tests 覆盖通过 typed TEA messages 的 pending file-dialog completion，以及 mapped parent/child effect/subscription diagnostics。2026-06-03，macOS Skia helper 在 renderer pixel smoke 后构建并启动 `examples/showcase/macos_skia`，带有 first-frame exit marker。Showcase 暴露 Windows/Linux Skia first-frame env flags 用于 matching-host smoke runs；package checks 证明 provider wiring，但 Linux runtime evidence 在这些命令记录 passed artifacts 前仍为 matching-host pending；Windows Showcase 路由已于 2026-08-29 记录首帧与运行时转录证据（ADR 0031）。`node scripts/conformance-capture-scaffold.mjs --mode benchmark` 也重建了 Showcase 和 Markdown Editor Web wasm-gc targets，验证其 static Web runtime handoff，并验证两个 examples 的 benchmark manifest targets。`scripts/record-web-runtime-presentation.mjs` 和 `scripts/validate-web-runtime-presentation-manifest.mjs` 定义 `artifacts/conformance/web-runtime-presentation.json` 的 browser-session evidence path；browser artifact 由 `web-runtime-presentation` GitHub Actions job fold 进 Web platform runtime entry。GitHub Actions run `27227687435` 具有非 skipped 且成功的 `web-runtime-presentation` job，运行了相同的 record/validate path 并上传 `moui-web-runtime-presentation`。 | 当前具备 Darwin Showcase Skia first-frame、daily Showcase/Markdown Editor package/Web coverage、可选 addon diagnostics、browser presentation evidence paths 和 current-head Web CI evidence；Linux platform runtime evidence 仍为 matching-host pending |
| Historical mobile first-frame | 非 fallback Component Gallery builds 已在 Android (HUAWEI SCM-W09)、iOS 和 HarmonyOS 设备上启动；nonblank first-frame screenshots 记录在 `resource/screenshots/{android,ios,harmonyos}-componentgallery`（2026-07-09/10）。 | Historical pixels 对这些 artifacts 仍有效，但不计作 window-hosted Showcase evidence；fresh Showcase evidence 仍 pending。 |
| 嵌入运行时 host services | `EmbedderHostChannel`、text input、clipboard、semantics 和 targeted actions 已通过 Android、iOS、HarmonyOS 的嵌入运行时后端接线。 | presentation、input、lifecycle 和 service claim 仍需要 matching-device evidence；HarmonyOS device evidence 还需要 signing material。 |
| Mobile GPU | 当 host GPU surface 可用时，`SkiaGpuNative`/`HostGpuSurface` 是所有 native Skia platforms 上的产品 `auto` 默认值。Worker-owned Metal/Vulkan/EGL/D3D paths 默认链接；iOS simulator、Android NDK/APK 和 HarmonyOS native/HAP builds 通过；macOS 具有 matching-host claim evidence。 | Physical mobile / Windows / Linux seven-gate quality manifests 仍不完整；raster 是显式 + recovery fallback。 |
| Guidance freshness | `AGENTS.md`、framework skill、app skill、docs、README entrypoint wording、provider package paths 和 example entrypoints 由 `tools/moui/validate_guidance_consistency` 上的 guidance-consistency guard 覆盖（使用 `moon run tools/moui/validate_guidance_consistency --target native` 运行），用于影响 guidance 的更新后。2026-06-02，在添加 capture manifest validator self-test 和 benchmark target checks 后，guidance guard 通过。 | 当前 |

Platform evidence guard refresh：platform runtime evidence manifest validator 会在 platform 或 native
Skia evidence block 标记为 `passed` 时拒绝 `README.md` placeholder artifacts，
包括嵌套的 `evidenceProvenance` artifact lists。Passed runtime claims 必须指向具体 logs、manifests、
screenshots 或 uploaded CI artifacts，而不是 scaffold documentation。该
manifest 由匹配主机上的 `MoUI CI macOS platform evidence
dispatch` workflow 生成并验证。

Skia async-image refresh：platform backend 只通过 `HostImageSource` 暴露
local-file 原始字节，`moui_skia_renderer` session 拥有 `RendererImageDecoder`、
资源缓存与 token completion。backend 只调度/取消 I/O 并回传同一 token。real Skia
smoke 在 Applied completion 请求 repaint 并于第二帧绘制时记录
`MoUI Skia async image second-frame smoke passed`。Focused tests 证明 token
completion scheduling、stale/disposed rejection、decoded cache insertion，以及
通过 host scheduler 的 redraw routing。

Deferred native async-image source refresh：platform loader 将 pending request
记录在 `WindowImageTasks`，稍后用相同 opaque token 交付 ready/failed completion。
Host tests 证明 schedule-return-first、redraw routing、cancellation cleanup 和
missing late completion diagnostics；renderer tests 证明 completion 只能在所属
session 应用后请求 redraw。

## GitHub Actions 证据刷新

<!-- 由 scripts/refresh-evidence-table.mjs 为下方 MoUI CI 行自动生成。
状态列和证据边界说明需要人工审查。
运行：node scripts/refresh-evidence-table.mjs（带 GITHUB_TOKEN）以刷新。
-->

| Workflow | Run | 关键成功 jobs | 上传的 artifact names | 证据边界 |
| --- | --- | --- | --- | --- |
| MoUI CI | [28964136358](https://github.com/wzzc-dev/MoUI/actions/runs/28964136358) | Windows MSVC native smoke、Linux platform contracts、Public API surface、Benchmark scaffold、macOS packaging smoke、PR profile gate。 | moui-webview-demo-windows-msvc-portable、moui-showcase-windows-msvc-portable、moui-showcase-macos-app。 | 证明 head SHA `91f596e80d5a5f80d30fa94a8510e5ce4653189e` 的 CI run 28964136358。 |
| MoUI Renderer Real Skia CI | [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550) | `macOS renderer real Skia`；`Linux renderer real Skia`；`Windows renderer real Skia`。 | `macos-renderer-real-skia-ci`；`linux-renderer-real-skia-ci`；`windows-renderer-real-skia-ci`。 | 证明 head SHA `91f596e80d5a5f80d30fa94a8510e5ce4653189e` 的当前三平台 native Skia renderer L2 claim：三个 jobs 均非 skipped 且成功，native smoke 和 acceptance summary verification steps 均通过。这是 renderer proof，不是完整 platform-service proof。 |
| MoUI macOS Platform Evidence | [27217345886](https://github.com/wzzc-dev/MoUI/actions/runs/27217345886) | `macOS platform runtime evidence`；`Native Skia renderer proof (macos)`。 | `moui-macos-platform-runtime-evidence`；`moui-renderer-proof-skia-native-macos`。 | 证明 head SHA `5bb2d810cd7e4cc63602caa431d5851827bd69d9` 的 macOS-only runtime claim：`macOS platform runtime evidence` job 非 skipped 且成功，上传了 platform manifest，其 macOS entry 为 `status=passed`，`evidenceProvenance.kind=github-actions`，`runId=27217345886`，每个 runtime/IME observation 均设为 `yes`，且 `skiaEvidence.status=passed`；下载的 `skia-native-macos.json` renderer-proof manifest 也通过 `--require-passed` 验证。workflow conclusion 为 `failure`，因为无关的 Linux Skia proof 和 renderer proof summary jobs 在后续 `2d568ecb` CI 修复前失败；仅将此行用于 macOS platform runtime evidence，并将上方 run `27227687435` 用于当前 all-green push CI state。 |
| MoUI Linux Platform Evidence | [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278) | `Linux platform runtime evidence`。 | `moui-linux-platform-evidence`。 | 证明 head SHA `8a054c5914adbfa34a6943570c1ceb01cc603ef5` 的 Linux first-frame Wayland route：job 在 headless Weston compositor 下用真实 Skia link flags 运行，记录预期 first-frame marker，验证 evidence marker，并上传 Linux platform evidence artifact。此项应仅作为 Linux first-frame/platform-route evidence 引用；Linux IME protocol functionality 已于 2026-07-11 通过 WSL2 验证（全部 8 个 IME probe fields 通过），但 IME interactive input（pointer/keyboard）以及 clipboard image read/write、directory listing 和 transparent titlebar 仍是已跟踪缺口，直到记录 matching-host Wayland desktop observations。 |
| Deploy Website | [28964136340](https://github.com/wzzc-dev/MoUI/actions/runs/28964136340) | `Build website`；`Deploy website`。 | `github-pages`。 | 证明 website workspace 会构建，且 GitHub Pages 接受了 head SHA `91f596e80d5a5f80d30fa94a8510e5ce4653189e` 的 uploaded artifact。这是 website deployment evidence，不是 renderer 或 platform runtime proof。 |
| MoUI Skia Provider Fallback CI | [27043267275](https://github.com/wzzc-dev/MoUI/actions/runs/27043267275) | `fallback (ubuntu-latest)`；`fallback (windows-latest)`。 | 无。 | 最新成功的手动 fallback-safe binding/workspace evidence，采集自 head SHA `045627245c5b320445e195e8f6eb7efe4d001de4`，不是当前 MoUI CI SHA。它覆盖 formatting、checks、all-target fallback compilation、ownership/borrow/capability/status verifiers、release-lock dry-run checks 和 Windows fallback gate。它不证明 real Skia presentation；发布候选引用 current-head fallback evidence 前必须刷新此 workflow。 |
| MoUI Skia Provider Real Skia Acceptance | [27043266794](https://github.com/wzzc-dev/MoUI/actions/runs/27043266794) | `Linux release Skia acceptance (static)`、`(dynamic)`；`macOS release Skia acceptance (static)`、`(dynamic)`；`Windows MSVC release Skia acceptance (static)`、`(dynamic)`。 | `linux-real-skia-acceptance-log-static`；`linux-real-skia-acceptance-log-dynamic`；`macos-real-skia-acceptance-log-static`；`macos-real-skia-acceptance-log-dynamic`；`windows-real-skia-acceptance-log-static`；`windows-real-skia-acceptance-log-dynamic`。 | 最新成功的手动 real release Skia binding acceptance，采集自 head SHA `045627245c5b320445e195e8f6eb7efe4d001de4`，不是当前 MoUI CI SHA。Windows dynamic job 保留 shared package path，并上传 `windows-real-skia-acceptance-log-dynamic`；它仍是 binding/provider acceptance evidence，不是每个 MoUI Windows platform runtime service 均 passed 的声明。发布候选引用 current-head real Skia acceptance 前请刷新此 workflow。 |

Skia fallback workflow 按设计不上传 artifacts，因此 run URL
和 successful job logs 是证据 handle。acceptance workflow 上传
per-platform/per-link-mode log bundles。Failed 或 missing artifacts 不得被
视为 passed evidence，且此表必须为发布候选刷新，
而不是作为永久 passed manifest 复用。

## 平台验证矩阵

预览交接必须说明哪个 host 产生了平台证据。Platform
claims 应限定在运行它们的 host 上；不要把 macOS check 用作
Windows 或 Linux native behavior 的 runtime evidence。
当 GitHub CI 作为权威时，只有非 skipped 且成功、带 uploaded logs、manifests、screenshots
或 first-frame artifacts 的 jobs 可以支撑
`status=passed` runtime claim。未运行的 workflow-dispatch paths、
build-only jobs、package-only jobs 和 provider/preflight audits 必须保持
pending，或描述为更窄的 setup evidence。

| Host | 常规命令 | 证明内容 | 仍不在范围内 |
| --- | --- | --- | --- |
| macOS / Darwin | sh scripts/check.sh --profile platform | Daily package checks 加当前 macOS host 上的 backend/macos 与 renderer package tests。scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke 是真实 Skia renderer 加 Showcase 首帧证据路径；平台 promotion 还需要 window package transcript 与 marker-validated native IME log。 | 其他宿主行为与慢速 native examples 需要各自 matching-host gate；package tests 与 window smoke 本身不是完整平台证据。 |
| Windows / MSVC | build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly | Windows native Skia composition-root build evidence；配合 moon test moui/backend/windows --target native 与 moon test moui_skia_renderer --target native。只为 WGPU 诊断运行 moon test moui_wgpu_renderer --target native。 | Packaged app runtime 与首帧/服务证据仍需要 matching Windows host。 |
| Linux | sh scripts/check.sh --profile platform；sh scripts/linux-platform-evidence.sh | 在有 Wayland headers 的 Linux host 上运行 backend/linux 与 moui_skia_renderer tests；evidence script 在 headless Weston 下分别记录 skia-raster、skia-gpu 与 auto 首帧日志，并收集忽略的 artifact。 | 该证据不是完整 platform-service proof；matching-host service 与 IME 缺口仍单独跟踪。 |
| Android / NDK | `sh scripts/window-hosted-hostsim-smoke.sh`；`moon test moui/backend/android`；`moon check examples/showcase/android_window_hosted`。 | HostCmd callback path、中立 Android surface binding 与 AppBuilder composition wiring。 | 仍需要 matching-device presentation、input、lifecycle、renderer 和 service evidence。 |
| iOS / Xcode | `sh scripts/window-hosted-hostsim-smoke.sh`；`moon test moui/backend/ios`；`moon check examples/showcase/ios_window_hosted`。 | HostCmd callback path、中立 iOS surface binding 与 AppBuilder composition wiring。 | 仍需要 matching simulator/device presentation、input、lifecycle、renderer 和 service evidence。 |
| HarmonyOS / SDK | `sh scripts/window-hosted-hostsim-smoke.sh`；`moon test moui/backend/harmonyos`；`moon check examples/showcase/harmonyos_window_hosted`。 | HostCmd callback path、中立 HarmonyOS surface binding 与 AppBuilder composition wiring。 | 仍需要 signed-device presentation、input、lifecycle、renderer 和 service evidence。 |
| `wzzc-dev/window@0.5.4-0.1.5` package evidence | 收集 dependency runtime evidence 时使用 matching-host `scripts/run-window-package-smoke.sh <platform>`。 | registry package 暴露面向 MoUI 的 smoke/evidence files，包括 Web/macOS smoke templates，以及包含在 window 包内的 Linux/Windows matching-host pending templates。 | 这些 scripts 证明 window package evidence surface 存在；passed native runtime evidence 仍必须在 matching hosts 上记录，且不会取代 MoUI Showcase platform entrypoint evidence。 |
| 本地 `moui_skia` status evidence | `moui_skia/scripts/verify-platform-status.sh`；`moui_skia/scripts/verify-native-capability-contract.sh`。 | repo-local editable Skia binding workspace 暴露 `skia-platform-status.json`、`skia-provider-lock.json`、`SKIA_PLATFORM_STATUS.md`、`native/capabilities.json`、`native/ownership.json`、verifier scripts、CI gate evidence wiring、fallback parity、FFI ownership/borrow metadata、native smoke capability markers，以及 pinned JetBrains provider artifact lock。 | 这是 binding-level dependency acceptance evidence。它不证明 MoUI renderer pixels 或 platform entrypoint runtime behavior；这些仍需要 `scripts/macos-skia-renderer-smoke.sh` 或 matching-host Showcase runs。 |
| Web runtime presentation manifest | `sh scripts/ci-web-runtime-presentation.sh` 或 `node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed`；然后 `node scripts/validate-web-runtime-presentation-manifest.mjs artifacts/conformance/web-runtime-presentation.json --require-passed` | recorder 在 Chrome DevTools Protocol browser session 中打开 Showcase 的 Advanced Rendering section，并记录 page status、WebGPU availability、adapter/device request signals、wasm startup、canvas sizing、resize delivery、representative pointer/keyboard input、text input、clean target close、console errors、screenshot nonblank thresholds、Showcase transform-scene pixel markers，以及用于 RGBA color emoji glyph pixels（加 font metadata 和 glyph key/size metadata）、one-cluster ZWJ layout、bidi visual-order reordering、paragraph line metrics/later-line pixels、selection rectangles/line ranges、grapheme edit boundaries/actions、IME candidate anchors/surrounding text、composition ranges/preedit pixels，以及 placeholder -> image load -> repaint -> ready second-frame image ordering 的 Web renderer-proof events。将该 manifest fold 进 platform evidence 时，如果 fold 在 `web-runtime-presentation` Actions job 中运行，则派生 `github-actions` provenance；如果是 local matching-host folds，则派生 `matching-host-artifact` provenance。 | 这是针对指定 Chrome run 的 browser-session evidence。它不证明 cross-browser behavior、marker thresholds 之外的 deterministic golden pixels，或 Windows/Linux native runtime behavior。CI provenance 证明 browser-session artifact 的生成和上传位置；它不取代 passed presentation manifest。Failed manifests 可以作为 failed evidence fold 进 Web platform evidence entry，但必须留在 passed Web runtime claims 之外。 |
| Renderer proof manifest | renderer-proof manifests 由 `MoUI CI` GitHub Actions `Native Skia renderer proof` 和 `Renderer proof summary` jobs 生成并验证；Web proof 来自 `scripts/record-web-runtime-presentation.mjs` 记录的 browser-session WebGPU path。 | Schema v1 renderer-proof manifests 要求 GitHub Actions provenance，并且正好包含 `radialGradient`、`transformPixels`、`colorEmojiPixels`、`zwjGrapheme`、`bidiLayout`、`paragraphWrapping`、`selectionRects`、`graphemeEditing`、`imeCandidateAnchor`、`imeCompositionVisual` 和 `asyncImageSecondFrame` observations。Passed observations 必须包含强 evidence tokens，例如 center/mid/edge radial pixels、transform pixel markers、high-saturation emoji pixels 或带 `font-metadata` 与 `glyph-metadata` 的 glyph/raster evidence、no-interior-caret ZWJ grapheme evidence、visual bidi order、带 later-line pixels 的 paragraph line metrics、带 line ranges 和 positive geometry 的 selection rectangles、带 edit actions 的 grapheme edit boundaries、带 surrounding text 的 IME candidate anchors、带 preedit pixels 的 composition ranges，以及 late-completion/repaint/second-frame async image pixels。Native Skia `paragraphWrapping`、`bidiLayout` 和 `selectionRects` observations 还必须按情况携带 `engine=skparagraph` 加 `native_paragraph_ready=true`、`bidi_visual_order_ready=true`、`line-metrics`、`later-line-pixels`、`visual-order`、`selection-rects`、`line-range`、`rect-geometry` 和 `hit-test` markers；native Skia `imeCandidateAnchor` observations 还必须携带来自 host IME diagnostics 的 `grapheme-boundary` 和 `utf8-offsets` evidence；native Skia `imeCompositionVisual` observations 还必须携带 `composition-cursor` evidence。`colorEmojiPixels` observation 还必须携带 structured `metadata.font` 和 `metadata.glyph` fields，包括非空 glyph key 加正数 glyph width/height；native Skia color emoji proof 还要求 `fallback-request`、`emoji-hint`、`stable-glyph-key`、fallback script/language tag-list/count metadata、fallback request character metadata、resolved missing-glyph count、missing-glyph recovery readiness，以及包含 recorded source/text-system/shaper/script/language-tags/language-count/fallback-request-character/format fields 的 glyph key。Skia proof matrix 在运行 real renderer/text smokes 前配置 locked release Skia artifact。 | Package tests、skipped jobs、missing uploaded artifacts、blank screenshots、caret-only diagnostics、heuristic visual-order logs、fallback paragraph geometry、coverage-only font matching、package-only checks、provider preflights、preflight-only checks、fallback-safe descriptor audits，以及没有 GitHub Actions provenance 的 local renderer-proof manifests 都不是 passed renderer proof。Local manifests 可以保留 passed observations 作为 diagnostics，同时保持 manifest status failed。Native WGPU proof 仍是非阻塞 diagnostic，并且仍需要可用 runner WGPU adapter 进行 offscreen readback smoke。metadata contract 是更强的 artifact-audit boundary，不是完整 deterministic typeface/glyph-id parity 本身。 |
| MoUI runtime evidence manifest | `sh scripts/check.sh --profile platform`；matching-host runtime evidence manifests 由 `MoUI macOS Platform Evidence` workflow 记录并验证，该 workflow 将 native IME/Skia log markers、window package smoke transcript 和匹配的 Showcase `macos_skia` first-frame log fold 进 platform runtime entry 后再 promotion。 | Schema v2 manifest 记录必需的 Web/macOS/Windows/Linux runtime evidence shape、预期 Showcase targets（包括 native Skia variants）、`wzzc-dev/window@0.5.4-0.1.5` package evidence command、consumer command、observations、artifact paths 和 passed-entry provenance。它将 window package monitor/cursor evidence 映射为 `monitorCursor`；native passed entries 必须把它记录为 `yes`，并且还必须将 native IME observations `imeCandidateAnchor`、`imeSurroundingText`、`imeCompositionVisual`、`imeCommitDelete`、`imeCursorUpdate`、`imeScrollAnchor`、`imeScaleDprAnchor` 和 `imeResizeAnchor` 设为 `yes`。Native entries 还包括 `skiaEvidence`，用于 Skia provider/preflight、fallback-unavailable、real renderer smoke、async image second-frame smoke 和 Showcase first-frame status；native platform `passed` 要求该 Skia block 也为 `passed`。workflow 验证 log markers，并只更新 scoped observations，然后委托 platform promotion；对于 Web，workflow 会从 browser presentation manifest 派生 passed 或 failed platform observations。 | Pending manifest 只是 contract。只有当 platform entry 为所声明的平台记录足够的 passed observations、artifacts 和 `evidenceProvenance` 后，它才成为 runtime evidence。Passed provenance 必须追溯到非 skipped 且成功的 GitHub Actions job/run，或 matching-host artifact bundle。Passed `skiaEvidence` block 是 Skia-route proof，不是完整 platform-service proof 本身，native Skia helper 有意保持更广的平台状态不变。Host-core unit tests、package logs、provider preflights、粗粒度 `textInput` observations、renderer-proof IME markers、window package smoke alone 或 placeholder README artifacts 都不能满足 native IME observations 或完整 macOS platform status。native IME helper 同样保持更广的平台状态不变，只记录 marker-validated IME observations。Web presentation manifest 只有在 browser session 包含 resize/input/text-input/shutdown platform observations 和 browser-session artifact provenance 时才标记为 passed；Web 可以将 `monitorCursor` 和 native IME observations 保持 pending，因为 browser CDP evidence 不证明 native monitor/current-monitor、cursor、IME candidate-window 或 platform-window anchor behavior。 |

对于配置好的 host 上的 release candidates，添加：

```sh
node scripts/smoke-gate.mjs --tier release --dry-run --json
```

## Smoke 边界

Manual smoke logs 可以证明 real Skia linking、renderer pixel output、
async image second-frame behavior、optional SkParagraph text behavior、WebGPU
browser-session startup、nonblank canvas output、representative input delivery，
或 current-platform first-frame presentation。

`smoke/gates.json` 是 smoke gate catalog，也是
将这些 observations 映射到 daily、nightly 和 release gates 的事实来源。使用
`node scripts/smoke-check.mjs --tier nightly --json` 或 `--tier release --json`
在触发
`.github/workflows/moui-runtime-gates.yml` 前打印 structured plan。使用
`node scripts/smoke-gate.mjs --tier release --dry-run --json` 在运行 release gate 前预览
精确的 catalog-backed commands。

这些 logs 是指定 host/session 的 runtime observation logs。它们不会
成为 checked-in manifest，也不会自动提升无关的
platforms 或 renderers。

## Artifact 策略

`artifacts/` 被忽略。该目录下生成的 JSON、screenshots、browser logs 和 smoke
logs 是一次性的 local 或 CI artifacts。Release notes
应引用实际检查过的 CI run、uploaded artifact name 或 local smoke log path。

Design Systems 是 addon diagnostic coverage。如果 release notes 提到
`moui_theme` 或 `examples/design_systems`，请在 daily baseline 旁同时包含 `sh scripts/check.sh --profile theme` 证据。
