# 设计度量

> 默认控件与表面度量的唯一事实来源。这里的数字即契约:
> `moui/core/theme_desktop_test.mbt`、
> `moui/views/style/control_theme_set_test.mbt` 与
> `moui/views/button/button_test.mbt` 会断言它们,gallery 截图也按它们评审。
> 改动数字必须同时改测试,并在 ADR 中记录。

相关:[visual-theme-system.md](visual-theme-system.md)、
[button-styling-guide.md](button-styling-guide.md)、
[../plans/done/visual-quality.md](../plans/done/visual-quality.md)、
ADR 0071(Desktop preset)。

## 度量归属

| 层 | 归属 | 内容 |
|---|---|---|
| `Theme.palette` / `typography` / `radius_scale` / `shadow_scale` / `motion` / **`layout_scale`** | `moui/core` | 中立、仅尺寸的 token。`layout_scale` 承载控件高度、行高与容器内边距——不含颜色与变体词汇。 |
| `ControlThemeSet` | `moui/views` | 由主题解析的每控件样式 token(颜色、边框、圆角)。阴影与表面内边距读取主题 scale,因此 preset 不需要第二套 token。 |
| 构造函数默认值 | `moui/views` | 仅限调用方可以合理覆盖的尺寸(`width`、显式 `height`、card `padding`)。零值/省略表示"使用 `layout_scale`"。 |

密度(`ThemeSpec.density`)会同时缩放间距与布局度量:
`Compact` ×0.82,`Standard` ×1.0,`Comfortable` ×1.18。

## 字阶

`Minimal`(既有默认,保持 0.6.x 不变)与 `Desktop`(新的可选 preset)。
每一档都是 `FontSpec`(尺寸 / 字重 / 行高);`FontSpec` 还携带可选的
`letter_spacing` 与 OpenType `features`(tag → value)。Desktop 档当前只设置
行高;字距要等 Skia 文本路径支持后再进默认档(见[已知缺口](#已知缺口))。

| 角色 | Minimal | Desktop | 用途 |
|---|---|---|---|
| display | 38 / 600 | 32 / 650 | 页面主视觉数字、空状态插画文字 |
| headline | 27 / 600 | 24 / 650 | 页面/区块标题 |
| title | 21 / 600 | 18 / 600 | 卡片/面板标题 |
| subtitle | 18 / 600 | 15 / 600 | 次级标题 |
| body | 16 / 400 | 14 / 400 | 默认正文 |
| label | 16 / 600 | 13 / 550 | 按钮、页签、表单标签 |
| control | = label | = label | 控件文字 |
| caption | 13 / 400 | 12 / 400 | 元数据、状态栏 |
| overline | 11 / 600 | 11 / 600 | eyebrow、表头 |

Desktop 行高:display 35.8、headline 28.8、title 23.4、subtitle/body 20.3
(正文 1.45×)、label 16.9、caption 16.2、overline 14.3。`FontSpec` 携带可选
`line_height`;只读 `text` 视图会按它重排行盒(未设置时仍用 provider 自然
行距),因此正文拿到 1.45× 而无需改文本 provider。

## 圆角

| Token | Minimal | Desktop |
|---|---|---|
| sm | 4 | 4 |
| md | 6 | 8 |
| lg | 8 | 12 |
| pill | 999 | 999 |

`md` 用于控件与输入框;`lg` 用于卡片、popover 与 dialog。

## 布局度量(`Theme.layout_scale`)

| 字段 | Minimal | Desktop | 消费方 |
|---|---|---|---|
| `control_height` | 40 | 32 | `button`、`text_field`(未显式给高度时) |
| `control_padding_x` | 16 | 12 | `button` 水平内边距与图标间距 |
| `row_height` | 34 | 30 | `sidebar` 行 |
| `card_padding` | 24 | 16 | `card` / raised `container` |
| `overlay_padding` | 12 | 8 | popover/menu 面板内边距、sidebar 内缩 |
| `dialog_padding` | 16 | 20 | `dialog` 面板内边距 |

按钮宽度按内容 hug;旧的固定 100×40 默认已移除。显式 `width`/`height`
仍然优先。

## 层级(`Theme.shadow_scale`)

| Tier | Minimal | Desktop(light) |
|---|---|---|
| sm | 0 0 0 @3% | 0 1 2 @5% |
| md | 0 2 8 @6% | 0 8 24 −6 @10% |
| lg | 0 2 16 @8.4% | 0 12 32 −8 @18% |

Desktop dark 使用 28/38/52% alpha。卡片取 `sm`,popover 取 `md`,dialog
取 `lg`。当前 paint 模型每层只有一个阴影,所以每个 tier 是一个调好的
单层阴影;叠加阴影是后续工作。

## 状态层

`ControlThemeSet.button.state_layer` 用 `palette.foreground` 着色,而不是
品牌色,因此 ghost 按钮与列表行的 hover/pressed 保持中性。选中态仍通过
更重的 alpha 与控件自身 token 表达。

| 状态 | 浅色 alpha | 深色 alpha |
|---|---|---|
| hover | 0.06 | 近白前景 0.06 |
| focus | 0.10 | 0.10 |
| pressed | 0.10 | 0.10 |
| dragged | 0.14 | 0.14 |
| selected | 0.10 | 0.10 |
| disabled | 0.38 | 0.38 |

今天 focus 是一个可见状态层;不改变边框宽度的 2px accent ring 是 V2
工作项(需要 paint 侧的内描边)。

## 强调色

Desktop 调色板用品牌 accent 取代 Minimal 的单色主色。回落值按 13px 控件
文字的 AA 对比度选择:

| 方案 | Accent | On-accent | 对比度 |
|---|---|---|---|
| Light | `#1D6FE0` | white | 4.77:1 |
| Dark | `#60A5FA` | near-black | 6.38:1 |

macOS 上宿主会把系统 accent(`NSColor.controlAccentColor`)作为
`AccentColorChanged(0xAARRGGBB)` 上报:启动时一次,之后
`NSSystemColorsDidChangeNotification` 触发时再次上报。`HostRuntimeDriver`
把它存进 `Environment.system_accent`,resolver 按以下顺序选调色板:

1. `ThemeSpec.seed` — 应用显式钉住的 accent 永远优先;
2. `Desktop` preset 下的 `Environment.system_accent` — 系统 accent 驱动
   调色板(accent、tonal 行、focus ring);
3. 上表的 Desktop 回落值;
4. Minimal 两者都忽略,保持单色。

没有 accent 服务的宿主(Windows、Linux、Web)留空 `system_accent`,落到
回落值,行为不变。该值作为 environment 输入而非写进 `ThemeSpec`,既让主题
spec 保持可复现,也让应用钉住的 spec 不受宿主影响。

## 帧背景

runtime 每帧清屏使用根视图作用域内的主题背景(`theme.palette.background`);
根视图没有作用域主题时回落到 runtime environment 的主题。因此根视图即使不画
背景也会落在主题底色上:根上的 `.theme(dark_theme())` 不会在暗色下露出白底,
离屏 gallery 截图也可以直接渲染 runtime 命令。平台视图独占 surface 时保持
透明。

## 动效

`Theme.motion` 携带 `fast 120 / normal 180 / slow 280 ms`,缓动
`EaseInOut`。reduced motion 会把三者归零。

状态矩阵中的每个交互控件都通过共享 `pressable_transition` 槽位做 hover/press
过渡:button 背景、text_field 边框、checkbox/radio/toggle 行叠加层、slider
halo。时长为 `fast_ms` 且**上限 150 ms**,reduced motion 直接吸附到终态。
即使控件钉了 theme,也会读 `environment.reduced_motion`——因为
`Environment::with_theme_spec` 现在会同步 `reduced_motion` /
`accessibility_contrast`。

## 校验

```sh
moon test moui/core --target native
moon test moui/views --target native
node scripts/visual-control-matrix.mjs
node scripts/generate-control-previews.mjs --check
node scripts/generate-gallery-screenshots.mjs --check
node scripts/generate-icon-set.mjs --check
```

- `moui/core/theme_desktop_test.mbt` — preset 数值、密度、seed、对比度、
  reduced motion、accent on-color,以及系统 accent 优先于 Desktop 回落值
  (Minimal 忽略系统值)。
- `moui/apphost/host_runtime_driver_test.mbt` — 派发
  `Event::AccentColorChanged` 会重建 `Environment.system_accent`。
- `moui/views/style/control_theme_set_test.mbt` — 控件 token 派生自主题;
  Minimal 度量保持不变。
- `moui/views/button/button_test.mbt` — 控件高度跟随 `layout_scale`;显式
  高度优先;默认按内容 hug。
- `moui_tests/visual_matrix` + `scripts/visual-control-matrix.mjs` — 每个
  交互控件在 default/hover/pressed/focused/disabled × 明暗两套下渲染;预期
  状态与静止状态绘制相同则记为 `missing_states` 并失败。
- `scripts/generate-control-previews.mjs --check` — 入库的 Skia 渲染
  `docs/assets/controls/*.png` 仍与矩阵像素一致(无 Skia 的宿主跳过该比对)。
- `scripts/generate-gallery-screenshots.mjs --check` — 入库的 README/首页
  `gallery-{light,dark}.png` 仍与 `examples/gallery` 的 1080×820 离屏渲染一致
  (无 Skia 的宿主跳过)。

## 已知缺口

1. **字距 / OpenType feature** — token 与 declaration key 已就位
   (`FontSpec.letter_spacing`、`FontSpec.features`)。Sun CPU 文本路径已支持
   字距与行高;主线 Skia 文本路径与 Web 渲染器目前忽略这两个字段,因此
   Desktop preset 暂不设置 tracking。feature tag 已记录,但还没有 provider
   消费。
2. **叠加阴影** — `ShadowStyle` 只有一层;dialog/card 的叠加阴影等待 paint
   模型或第二个 `ShadowStyle`。
3. **其他宿主上的系统 accent** — macOS 已读 `controlAccentColor`;Windows
   (DWM accent)与 Linux(portal `accent-color`)对应项尚未接入,落到 preset
   回落值。
4. **其余控件状态过渡** — 只有 `button` 动画 hover/press。
5. **图标** — 内置 24×24 图标集、`icon_svg`(任意 SVG path),以及
   `lucide_icon`(vendored 103 个 Lucide 图标,`resource/icons/lucide.json`,
   ISC)。`sf_symbol_icon` 把 SF Symbols 名称桥接到该集合;原生 Apple 图形
   (经 AppKit 的按字重 SF Symbols)需要 macOS host service,仍未做。
