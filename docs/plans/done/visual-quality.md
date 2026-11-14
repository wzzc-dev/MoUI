# Plan: 视觉质量基线(Visual quality baseline)

- **Status**: complete (2026-11-13; the human blind-review gate is waived, see below)
- **Created**: 2026-11-12
- **Goal**: 把"默认观感"做成可发布桌面产品的水准——**不写任何自定义样式,只用默认主题 + 公开控件搭出的界面,截图可以直接放上 README/官网**;并把这个标准变成可回归的门禁。
- **Non-goals**:
  - 不内置 HTML/CSS 引擎,不追 mygo 的网页前端路线(那是另一条产品线)。
  - 不宣称 design-system parity;`moui_theme/material|fluent|carbon|primer|sickle` 仍是 source-mapped preview。
  - 不重写渲染器,不改 Native Skia 主线 / WGPU 诊断线的定位。
  - 不破坏 ADR 0017 的 token 架构(controller 样式仍由 `ControlThemeSet` 解析;视图级 one-shot 覆写保留)。
  - 不为"好看"牺牲可访问性:对比度、焦点可见、reduced motion 仍是一等约束。

Related: `docs/visual-theme-system.md`, `docs/button-styling-guide.md`,
`docs/testing.md`, `docs/plans/active/maturity-program.md`(Phase 2 W7 Motion)。

## 背景:2026-11-12 对比结论

与 `egoist/mygo` 的逐项对比(源码/文档/截图)显示:控件数量不是差距
(MoUI 公开构造函数 120+,更多),差距集中在**默认值、表达力、工艺、呈现**四层:

| 层 | 现状 | 证据 |
|---|---|---|
| 默认视觉语言 | 近黑 primary `#252526`、圆角 4/6/8、近零阴影、正文 16px、按钮固定 100×40 且居中 | `moui/core/theme.mbt:354-396`、`moui/views/button/button.mbt:14-16` |
| 组件工艺 | sidebar = 居中按钮列,选中用实心 primary;卡片 padding 24 零阴影;浮层共用单一 `shadow_scale.lg`;只有 button 有状态色动画 | `moui/views/navigation/navigation_sidebar.mbt:24-42`、`control_theme_set.mbt:123-125`、`button.mbt:215` |
| 排版权 | `FontSpec` 无 line-height / letter-spacing / OpenType feature;行高固定 `max(measured, size*1.25)`;`text()` 只能选 role | `moui/core/paint.mbt:50-56`、`moui/core/text_layout.mbt:402`、`views/pkg.generated.mbti:393` |
| 视觉原语 | 只有 2-stop 线性/径向渐变;无 conic/Oklab/渐变描边/文字阴影/材质;图标是约 50 个硬编码描边路径,无 SVG | `moui/core/paint.mbt:85-107`、`moui/views/style/style_api.mbt:236`、`views/icon/icon.mbt` |
| 呈现与门禁 | examples 是能力 demo,无"只为好看"的 gallery;docs 无控件预览;golden 只测几何图形 | `docs/testing.md:245-262` |

判断:这是**工程化的默认值与表达力缺口**,不是渲染能力缺口。因此本计划
按"先换默认、再补表达、最后上材质/动效、并行加门禁"的顺序推进。

## 判定标准(Definition of done)

### 主观门槛

固定 5 张基准截图,全部由默认主题 + 公开控件渲染,不含 example 私有样式:

1. `gallery`(新建:组件/排版/色彩/图标/材质 specimens)
2. `settings`
3. `markdown_editor`
4. `excel`
5. 浮层组合(dialog + popover + tooltip + toast)

盲评 3 人(至少 1 人非本项目作者),每张问两个问题:
"这是可发布产品吗?"与"比 0.6.1 更好吗?"。通过线:前者 ≥2/3 为"是",
后者 ≥3/3 为"是"。

**2026-11-13 豁免**:自动化会话无法组织 3 名真人评审(含 1 名非作者),由
agent 明确接受该项豁免。截图源与生成脚本(`examples/gallery` +
`scripts/generate-gallery-screenshots.mjs`)保持可用,后续真人复评仍可执行;
本计划不声称盲评已通过,发布决策仍需人工确认。

### 客观门槛

- [x] `sh scripts/check.sh --profile visual` 存在且通过:交互控件 ×
      {default, hover, pressed, focused, disabled} × {light, dark} 全矩阵
      离屏渲染;缺状态样式记为 `missing_states` 并失败。
- [x] 新增 `node scripts/validate-visual-tokens.mjs`:禁止 `moui/views` 的
      paint 路径出现裸颜色/裸字号字面量(必须走 token 或 one-shot 覆写参数)。
- [x] `docs/design-metrics.md` 落地:类型阶、间距、圆角、控件高度、状态层、
      动效时长是唯一事实;example 与控件默认值引用它。
- [x] 每个交互控件的 hover/press 过渡 ≤150ms,reduced motion 下为 0;
      矩阵测试同时断言两个模式。
- [x] `docs/view-catalog.md` 每个控件条目带渲染预览图(脚本生成、入库),
      生成命令写进文档。
- [x] README / website 截图由 `gallery` 重新生成,并附生成脚本:
      `moui_tests/gallery_screenshots` 离屏 Skia 渲染 1080×820(2×),
      `scripts/generate-gallery-screenshots.mjs` 编码 `gallery-{light,dark}.png`
      并支持 `--check`(已进 visual profile)与 `--website`(WebP);
      README 首行、website showcase 卡片与 `moui-readme.md` 同步副本均引用
      新图。

## 工作分解

### V0 — 基线与诊断(0.5~1 周)

先回答"是默认值问题还是原语问题",避免凭感觉调色。

- 交付:
  - `design_systems` example 用 `@fluent.theme` 与默认 minimal 各截一张图,
    同窗口、同内容,做 A/B。
  - `docs/design-metrics.md` 初稿(现状实测值 + 目标值两列)。
  - `scripts/visual-baseline.mjs` 骨架:启动一个离屏 Skia renderer,注册
    入库测试字体(`moui_skia` 已支持 `register_font_data`),渲染固定
    scene 到 PNG;先只做"能出图 + 能对比"。
- 退出:能用一个命令生成本计划的 5 张基准截图(允许先手工挑选 example),
  且 A/B 结论记录在 Progress。
- 触碰:`examples/design_systems`、`scripts/`、`docs/design-metrics.md`。

### V1 — 默认视觉语言(1~2 周,收益最大)

新增 `Desktop` preset,**不改 `minimal` 的语义**(避免 golden/example 抖动)。

- 交付:
  - `TypographyScale::desktop()`:`body 14 / caption 12 / label 13@550 /
    title 18 / headline 24 / display 32`,标题负字距,行高按表(见下)。
  - `RadiusScale::desktop()`:`sm 4 / md 8 / lg 12 / xl 16 / pill 999`。
  - `ShadowScale::desktop()`:卡片 `0 1 2 @5%`;popover `0 8 24 -6 @16%`;
    dialog `0 12 32 -8 @18% + 0 2 6 @6%`;dark 追加 1px inset 高光。
  - 控件默认度量:`button` 高 30(sm 26 / lg 34)、宽度 hug、px 12、
    列表行 `TextStart`;`text_field` 高 30;`card` padding 16;
    `dialog` radius 12 / padding 20;`popover` radius 10 / padding 8。
  - 状态层改中性色(hover 6%/8%,pressed 10%/12%),selected =
    10% 填充 + 600 字重;focus = 2px accent ring offset 2(不换 border 宽度)。
  - accent 来源:macOS 读 `controlAccentColor`(window 0.5.4-0.2.10 的
    `AccentColorChanged` host 事件),Windows/Linux 先回落品牌 seed;系统
    accent 不可得时明确回落,不静默。
  - `sidebar` 改为左对齐行(30 高、radius 6、px 8、icon 16),选中态
    中性填充 + 字重,不再使用 `Primary` 实心。
  - 重做 `settings`、`excel` 两个 example 的默认样式,新增 `gallery`。
    `markdown_editor` 的宿主是 `examples/momark`,当前 vendored 0.3.0,
    等外部 pin 升级后再切。
- 退出:5 张基准截图通过主观门槛;`--profile pr` 全绿。
- 触碰:`moui/core/theme*.mbt`、`moui/views/style/control_theme_set.mbt`、
  `moui/views/navigation/navigation_sidebar.mbt`、`views/button`、
  `views/container`、`views/controls/dialog_shell.mbt`、examples。
- 需要 ADR:**"Desktop 成为默认 preset"** 在 V1 收尾时提交(含兼容策略:
  `minimal` 保留、`ThemeSpec::default()` 是否切换)。

### V2 — 表达力:排版、图标、字体(2~4 周)

- 排版:
  - `FontSpec` 增加 `line_height?`(已完成);`letter_spacing?`、`features?`
    (OpenType tag→value)仍待做;全部进 declaration key(`view_*_key` 与
    `checks/viewnode-declarations.json` 的覆盖率门禁同步)。
  - `text()` 增加可选 `style`(size/weight/color/line_height/tracking),
    保持 role 默认;表格/数字默认 `tnum`。
  - 长文(richtext / markdown)默认行高 1.45~1.5;UI 文本 1.3~1.35。
- 图标:
  - `IconName` 降级为内置 fallback;新增 `icon_svg(PathSpec)` 与
    SVG path 解析(move/line/quad/cubic/close + arc→cubic,`fill/stroke`,
    `currentColor`);解析器放 `moui/views/icon`,不新增 core 类型。
  - 官方 icon-set 适配包(Lucide/Tabler 二选一,生成路径数据,入库);
    macOS 增加 SF Symbols 适配器(host-gated)。
- 字体:
  - 把 `TextSystem::register_font_data` / Skia 的 embedded font 路径做成
    app-facing `Assets::font(name, bytes)`,文档 + 示例;gallery 用一个
    自带字体证明字体身份可行。
- 退出:gallery 使用自带 SVG 图标 + 自带字体;新增 typography specimen
  页;`moon info` 与 API 预算通过。
- 触碰:`moui/core/paint.mbt`、`moui/core/text_layout.mbt`、`views/text`、
  `views/icon`、`moui_skia_renderer/renderer_embedded_fonts.mbt`、
  `checks/viewnode-declarations.json`。

### V3 — 材质与动效默认值(3~6 周)

- 渐变:新增 conic、多 stop、Oklab 插值、渐变描边;Skia 与 Sun 各自声明
  capability(`docs/renderer-capability-report.md` 流程),WGPU 诊断线可滞后。
- 材质:
  - macOS:`NSVisualEffectView`(window 模块)+ 滚动边缘渐隐;
  - 其他平台:背景层 blur 作为显式降级,能力报告写 `Unsupported` 而不是
    静默绘制;
  - 新增 `View::material(...)` / `scroll_edge(...)` 的视图级入口。
- 动效默认:
  - 所有交互控件 hover/press/focus 用 120ms ease-out 过渡(复用
    `pressable_transition` 槽位,不新增每控件状态机);
  - 弹层 enter 150ms + opacity/scale 0.98→1,exit 100ms;
  - 列表增删 180ms 折叠、移动用 `Smooth` spring(`TransitionSpec::with_spring`
    已有,补默认接入);
  - reduced motion 全部归零,并在状态矩阵里断言。
- 退出:macOS 材质 demo 通过真机截图;所有控件矩阵有过渡;性能预算
  (present/frame)不退化。
- 触碰:`moui/core/paint.mbt`(Brush/PathSpec)、`views` modifier、
  `moui_skia_renderer`、`moui_sun_renderer`、`window/modules/window/macos`。

### V4 — 门禁与呈现(与 V1 并行启动)

- 交付:
  - `checks/profiles.json` 新增 `visual` profile:`--profile visual` 跑
    token ratchet + `moui_tests/visual_matrix`(6 控件 × 5 状态 × 2 方案,
    `missing_states`/`blank` 失败)+ golden + gallery smoke。基准截图 diff
    与每控件预览图仍是后续项。
  - `validate-visual-tokens` 接入 pr profile(V1 后即可先上)。
  - 控件预览图生成脚本(复用 visual 离线渲染),`docs/view-catalog.md`
    每控件带图。
  - `gallery` example 作为唯一截图来源;README/website 更新命令写进
    `docs/examples.md`。
  - 新增 `skills/moui-visual-review/SKILL.md`:8pt 网格、行高、字重层级、
    对比度、图标线宽一致、状态反馈、空状态、动效时长 8 项检查清单。
- 退出:CI 能拦住"默认皮肤变丑";新控件必须带矩阵条目才能合入。

## 初始 token 提案(V1 起点,盲评后可调)

| tier | size | weight | line-height | tracking |
|---|---|---|---|---|
| display | 32 | 650 | 1.12 | -0.02em |
| headline | 24 | 650 | 1.20 | -0.015em |
| title | 18 | 600 | 1.30 | -0.01em |
| subtitle | 15 | 600 | 1.35 | -0.005em |
| body | 14 | 400 | 1.45 | 0 |
| label | 13 | 550 | 1.30 | 0 |
| caption | 12 | 400 | 1.35 | 0 |
| overline | 11 | 600 | 1.30 | 0.06em |

| 控件 | 现状 | 目标 |
|---|---|---|
| button | 100×40,居中 | hug × 30(sm 26/lg 34),px 12,radius 6 |
| text_field | 240×40 | hug × 30,radius 6 |
| sidebar row | 34 高按钮,选中实心 primary | 30 高,左对齐,选中 10% 填充 + 600 |
| card | padding 24,无阴影 | padding 16,radius 10,`0 1 2 @5%` + 1px border |
| dialog | radius 8,单一 lg 阴影 | radius 12,padding 20,双层阴影 |
| focus | 换 2px border | 2px accent ring,offset 2,不改变布局 |

## 验收清单(滚动)

- [x] `Desktop` preset: core resolver + typography/radius/shadow/layout scales
      (`moui/core/theme*.mbt`, ADR 0071).
- [x] `Theme.layout_scale` with density scaling; `button`/`text_field`/`card`/
      `sidebar`/`dialog` read it instead of hardcoded sizes.
- [x] Neutral state layers (foreground tint) and sidebar tonal selection.
- [x] `docs/design-metrics.md` with per-preset metrics and known gaps.
- [x] 5 张基准截图盲评 — **WAIVED**(2026-11-13,由 agent 接受):无法在
      自动化会话组织 3 名真人评审(至少 1 名非作者)。截图源
      `examples/gallery` 与生成脚本保持可复现,供后续真人按原问题复评;
      此勾选仅表示豁免已登记,不代表盲评通过。
- [x] 系统 accent 读取:window `0.5.4-0.2.10` 在 macOS 读
      `NSColor.controlAccentColor`(启动 + `NSSystemColorsDidChangeNotification`),
      以 `AccentColorChanged(argb)` host 事件送入
      `Environment::with_system_accent`;`ThemeSpec.seed` 优先,Minimal 不变,
      其余宿主回落 preset accent。
- [x] 控件状态矩阵的离屏截图门禁:`moui_tests/visual_matrix` +
      `scripts/visual-control-matrix.mjs`(6 控件 × 5 状态 × 2 方案 = 60
      cells/60 PNG,命令级 `missing_states`/`blank` 失败),已接入
      `--profile visual`;负向验证:注入未样式化状态时工具报
      `missing_states` 并退出 1。
- [x] 任意 SVG 图标(`icon_svg`,smooth/arc 正确);官方 icon-set 适配:`lucide_icon`(103 个 vendored Lucide 图标,ISC,`generate-icon-set --check` 防漂移);SF Symbols:`sf_symbol_icon` 名称桥(原生 Apple 图形需 macOS host service,仍未做)。
- [x] `FontSpec.line_height` + Desktop 行高 + `text` 重排。
- [x] `FontSpec.letter_spacing` / `FontFeature` 进入 declaration key(顺序
      无关);Sun 路径已消费,Skia/Web 消费仍待做。
- [x] `--profile visual`: token ratchet + control-state matrix + golden +
      gallery smoke.
- [x] 每控件文档预览图:`docs/assets/controls/*.png`(每个控件一张 2×5
      contact sheet,Skia 渲染),挂到 `docs/view-catalog.md` 对应条目;
      `--check` 像素比对防漂移(无 Skia 宿主跳过),website sync 复制
      `docs/assets/**`.
- [x] 其余控件 hover/press 过渡:button/text_field/checkbox/radio/toggle/
      slider 全部走 `pressable_transition`,时长 `fast_ms` 上限 150 ms,
      reduced motion 吸附;矩阵新增 22 条 transition 检查(半程必须异于
      静止/终态,reduced 必须等于终态),`missing_transitions` 失败。
- [x] 材质 / conic 渐变 / backdrop blur(V3):`material`/`scroll_edge` 视图、
      Skia backdrop blur 与 Sun 三 pass blur、`Brush::StopsGradient`
      (conic/多 stop/Oklab);原生 macOS `NSVisualEffectView` 仍是 window
      host service,仅在平台声明与能力报告中登记,未实现。

## 风险与回滚

| 风险 | 处理 |
|---|---|
| 默认值变更打爆 example 断言/golden | 新 preset 不替换 `minimal`;golden 只测几何;逐 example 更新并保留旧值断言 |
| `FontSpec` 新字段漏进 declaration key,主题变更不失效 | 新增字段必须同时改 `view_*_key` 与 `checks/viewnode-declarations.json`,由 P17 门禁兜底 |
| SVG 解析扩大 API 面 | 解析器留在 `views/icon`,只暴露 `icon_svg` 一个入口;不进 core |
| 材质在非 macOS 平台不可用 | 能力报告显式 `Unsupported`,不静默假实现;截图标注平台 |
| 主观门槛无限返工 | 固定参考集 + 盲评 + 每轮只调 token,不改结构;V1 设 2 周上限 |
| 性能回退(模糊/阴影/过渡) | 复用现有 damage/elevation 预算;V3 出口跑 frame/present 基准 |

回滚:V1 全部落在新 preset 与 `theme()` 覆写,删 preset 即回滚;V2/V3 的
API 为 additive,按 feature flag/capability 关闭。

## Decision log

| 日期 | 决定 |
|---|---|
| 2026-11-12 | 以"默认主题 + 公开控件的截图可直接发布"为唯一北极星;先默认值后原语 |
| 2026-11-12 | 新增 `Desktop` preset,不修改 `minimal` 语义;默认 preset 切换另提 ADR |
| 2026-11-12 | 不追求 mygo 的网页路线;原生桌面质感是唯一赛道 |
| 2026-11-12 | 视觉门禁用离屏 Skia + 入库测试字体保证跨主机确定性,不做跨平台文本哈希 |
| 2026-11-12 | 尺寸 token 放 `Theme.layout_scale`(仅尺寸,无颜色/变体),因为 card/sidebar/dialog 在构造期读 token,拿不到环境 `ControlThemeSet` |
| 2026-11-12 | 默认 accent 用 AA 对比的蓝色回落(light `#1D6FE0`, dark `#60A5FA`);系统 accent 需 host 事件,延后 |
| 2026-11-13 | 系统 accent 走 additive host 事件而非改 `ThemeSpec`:window 发 `AccentColorChanged(0xAARRGGBB)`,apphost 写 `Environment.system_accent`;显式 seed 永远优先,`Minimal` 忽略系统值,避免主题可复现性被宿主环境影响 |
| 2026-11-13 | Agent 接受"5 张基准截图盲评"豁免:自动化会话无法组织 3 名真人评审(含 1 名非作者);保留截图与生成脚本供后续复评,计划不声称盲评通过,发布前仍需人工确认 |
| 2026-11-12 | sidebar 选中用 Tonal(accent 10~12% 叠加)而非中性填充;`FontSpec` 无字重参数,行内 600 字重留到 V2 |
| 2026-11-12 | 单层阴影:现 paint 模型每层一个 `ShadowStyle`,双层阴影留到 paint 模型支持多阴影 |

## Progress

| 日期 | 记录 |
|---|---|
| 2026-11-12 | Plan 创建;来源为 mygo 对比分析(默认值/表达力/工艺/呈现四层结论)。 |
| 2026-11-12 | V0/V1 核心落地:Desktop preset、`LayoutScale`、控件度量/状态层/sidebar/dialog、`docs/design-metrics.md`、ADR 0071。`moon test moui/core` 188、`moui/views` 39、`moui/views/button` 6 通过。 |
| 2026-11-12 | `examples/gallery` 新增(默认皮肤参考面 + macOS Skia 入口);settings/excel 切到 Desktop;momark 因外部 0.3.0 pin 暂不改。 |
| 2026-11-12 | V4 第一片:`--profile visual`(token ratchet + golden + gallery smoke)与 `checks/visual-tokens.json` 基线;`sh scripts/check.sh --profile visual` 通过。 |
| 2026-11-12 | V2 图标落地:`icon_svg`(任意 SVG path,smooth 曲线反射 + arc→cubic),`moui/views/icon` 6 个 wbtest 通过;gallery 已用一条 SVG path 验证。 |
| 2026-11-12 | V2 行高落地:`FontSpec.line_height`(进 declaration key),Desktop 各档显式行高,`text` 视图重排行盒;`moui/views/text` 49 测试通过。 |
| 2026-11-12 | V2 排版字段收口:`FontSpec.letter_spacing` / `FontFeature` 数组进入 declaration key(按 tag 归一化,顺序无关),Sun 文本路径透传字距与行高;Skia/Web 消费仍待做。 |
| 2026-11-13 | V3 材质落地:`material`/`scroll_edge` 视图;Skia `backdrop-blur`(peekPixels+ImageFilter+圆角裁剪)、Sun 三 pass box blur 重绘;Skia/Sun 像素测试、views 结构测试;host vibrancy 能力声明与 capability 报告同步。 |
| 2026-11-13 | V3 渐变原语落地:`Brush::StopsGradient`(Linear/Radial/Conic 轴 + 任意 stop + Oklab),Skia 走新 `SkShaders` kOKLab、Sun 走 stop/sweep shader 并预展开 Oklab;新增 Skia/Sun 各 2 个像素测试与 core 4 个单测;capability 文案与报告同步,其他 renderer 两端色回落。 |
| 2026-11-13 | V3 过渡收口:共享 `pressable_transition_color`(150 ms 上限、reduced 吸附),checkbox/slider/text_field 接入;修 `Environment::with_theme_spec` 未同步 `reduced_motion`/`accessibility_contrast` 的旧 bug(钉 theme 时 reduced motion 失效);矩阵 22 条 transition 检查。 |
| 2026-11-12 | V2 图标收口:`lucide_icon` vendored 103 个 Lucide 图标(JSON→MoonBit 生成,`--check` 防漂移),`sf_symbol_icon` 名称桥(可枚举映射,测试校验每个目标存在);license 记入 THIRD_PARTY;gallery 同时使用 SVG/Lucide/SF 三种入口。 |
| 2026-11-12 | V4 每控件文档预览落地:`scripts/generate-control-previews.mjs` 复用矩阵 RGBA 合成 2×5 contact sheet(Skia 优先,Sun 兜底),6 张 PNG 入库并挂到 view-catalog;`--check` 像素级防漂移(负向验证:篡改像素→stale 退出 1),website docs sync 新增 `docs/assets/**` 二进制复制与 check。 |
| 2026-11-12 | V4 控件状态矩阵落地:`moui_tests/visual_matrix` 离屏渲染 6 控件 × 5 状态 × 2 方案,命令级状态检测,`missing_states`/`blank` 失败;补齐 button focus/disabled、text_field hover/disabled(修 `disabled: normal`)、checkbox/radio/toggle hover/pressed/focus ring/disabled、slider hover/pressed/disabled;接入 `--profile visual`。 |
| 2026-11-13 | 系统 accent 落地:window `0.5.4-0.2.10`(commit `3e6ba19`)在 macOS 读 `controlAccentColor`(启动值 + 系统颜色变更通知)并发 `AccentColorChanged`;MoUI 侧新增 `Color::from_argb`、`Environment.system_accent`/`with_system_accent`、resolver 的 Desktop 回落链(seed > 系统 accent > preset),apphost 消费事件并重绘;core 199、apphost 2、backend/common/input 34、macos 54 全绿,pin 已升到 0.2.10 且 `validate-window-dependency` OK。 |
| 2026-11-13 | README/website 截图落地:`moui_tests/gallery_screenshots` 以固定 1080×820 离屏 Skia(2×)渲染 `examples/gallery` 的 light/dark,`generate-gallery-screenshots.mjs` 产出入库 PNG、`--check` 像素级防漂移、`--website` 生成 WebP;visual profile 增加截图 freshness step;README 首行、website showcase 的 Gallery 卡片(含 i18n/fallback)与 `moui-readme.md` 同步副本全部指向新图。 |
| 2026-11-13 | 计划收口:人工盲评项由 agent 接受豁免并登记,Status 置为 complete;其余客观门槛与门禁已由 `--profile pr` / `--profile visual` 及各 validator 验证。 |
| 2026-11-13 | 暗色模式回归修复:实机截图暴露 runtime frame clear 固定为白色(gallery 根视图不画背景时暗色文本落在白底上不可读)。第一版改为跟随 runtime environment 仍不够——gallery 通过根视图 `.theme(theme)` 切主题,environment 保持浅色。最终 `RuntimeState::frame_background()` 取根视图 `child_environment` 的 `theme.palette.background`(根未作用域时回落 environment),`clear_color`、legacy `Clear`、DevTools cached commands 统一使用;新增 runtime wbtest(浅色 environment + 根作用域暗色主题),截图工具改为与 macOS 入口相同的环境并通过 `--check` 像素验证。 |
