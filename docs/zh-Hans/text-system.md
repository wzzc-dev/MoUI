# 文本系统

MoUI 将文本测量保留在平台中立的运行时中，同时允许原生和 Web 宿主安装与各自渲染器匹配的
渲染器支撑文本系统。公共边界是 `@core.TextSystem`；仅测量的旧形状不再属于框架契约。
原生 Skia 是推荐的原生渲染器/文本路线，Web 使用浏览器 WebGPU 加浏览器文本集成，
下面的原生 WGPU provider 栈仍是用于比较 provider 行为的显式诊断路线。
Sun CPU 栅格后端现在通过 `moui_sun/text` 暴露一个渲染器支撑的 `TextSystem`，
包含字体注册、fallback-face 解析、适配到 core 字素稳定 caret 数组的单行测量，
以及由同一个 Sun fallback 行计划驱动的段落几何，同时保留共享 core 段落结果契约。
Sun 先解析请求的字体族，然后将剩余已注册 face 追加为 fallback 链，因此在存在已注册字体覆盖时，
拉丁文字加 emoji 等混合文本可以在测量和绘制时避免 missing-glyph 诊断。
`SunRasterRenderer::text_maturity_diagnostic()` 暴露渲染器拥有的字体状态的结构化诊断摘要：
注册字体数量、段落行度量、选择矩形、hit testing、轻量 bidi 视觉顺序元数据，以及原生段落和
彩色 emoji 就绪性的显式 pending 标志。
`SunRasterRenderer::text_selection_geometry_diagnostic()` 为字素规范化的选择矩形和 hit-test
审计映射同一个段落契约，并暴露来自 Sun 段落元数据的视觉顺序观察字段。
`SunRasterRenderer::text_visual_order_diagnostic()` 通过报告逻辑/视觉文本、cluster 数量、
segment 数量、glyph 数量、宽度，以及来自 Sun 段落元数据的 bidi 就绪性，为 Sun 映射
Skia 专用的视觉顺序诊断形状。
`SunRasterRenderer::emoji_font_fallback_diagnostic()` 审计 emoji-hint 文本的已注册字体
fallback 链：它报告请求的 family、已注册字体和解析后 face 数量、fallback span、覆盖/缺失的
scalar 数量、missing-glyph 恢复就绪性、字素 cluster 数量、代表性 fallback 字符、
source/shaper 标签、测量出的 glyph extents、解析后的 missing-glyph 数量、emoji 与非 ASCII
代表文本的 fallback 语言/脚本标签、fallback-request 就绪性、解析出的 fallback face 索引和稳定链标签、
稳定的 coverage-mask glyph key，以及 `glyph_format=coverage-mask`，同时将确定性彩色 emoji
明确保持为 pending。
当没有已注册字体 face 覆盖某次绘制时，Sun 仍会回退到渲染器本地 placeholder glyph。
Bidi、高级 shaping 和彩色 emoji 声明由共享一致性与真实 Skia 证明矩阵覆盖，而不是单独的
text-system blocker 状态。

## 运行时边界

- `core/text_layout.mbt` 定义 `TextSystem`、`TextSystem::fallback()`、
  `TextSystem::layout_paragraph()` 和字体数据注册。确定性兜底会为稳定几何保留逐字符
  caret 数组，同时 UAX #29 风格的 `TextGraphemeBoundaries` 扫描器会把 cluster 内部折回到
  cluster 起点。它覆盖 CRLF/control 断点、Hangul L/V/T 序列、Extend/ZWJ/SpacingMark、
  Prepend、regional-indicator 成对、emoji ZWJ 序列、emoji tags、作为 Extend 边界的 ZWNJ，
  以及 Indic virama/linker 结合，同时不会吞掉后接拉丁文本或空白的 virama。段落契约返回
  行度量、caret 矩形、选择矩形、hit-test 结果和带有显式就绪标志的视觉顺序元数据，
  因此简化兜底或诊断渲染器布局可以暴露几何，而不声称原生 SkParagraph 或 bidi 等价。
  Core 文本编辑使用同一组 cluster 边界实现基本的左右 caret 移动和 shift-selection。
- `AppRuntime` 暴露 `text_system()` 和 `set_text_system()`，使宿主可以在产生布局、绘制、
  hit testing、选择和 IME anchor 几何之前安装平台文本系统。底层 `RuntimeState`
  将活动系统存储为引擎细节。
- `FontSpec` 携带结构化 family stack。默认栈是 `SystemUi`；除非应用代码请求命名 family，
  具体字体名由活动的原生或 Web provider 解析。
- `core/` 只拥有中立契约和确定性兜底。它不导入 `Milky2018/moon_cosmic`、
  `Milky2018/moon_swash`、CoreText、DirectWrite、fontconfig、HarfBuzz、FreeType
  或浏览器 API。

实时文本路径是：

```text
View[Msg] -> DrawCommand::DrawText(TextRun) -> active TextSystem measurement -> renderer glyph path
```

Caret 位置、选择几何、换行、裁剪和 IME 请求坐标都应使用布局所用的同一个活动
`TextSystem`。富文本 run 可以包含显式换行符；core 会把这些 run 拆分为行片段，用于绘制、
hit testing、caret 几何和文档高度，因此渲染器支撑的文本系统永远不需要在单个绘制命令中解释
嵌入换行。

## 富文本输入热路径

聚焦文本控件会在普通文本编辑之外被原生和 Web 宿主查询，包括焦点探测、IME 候选窗口 anchor
同步、surrounding-text 更新、上下文菜单状态和由重绘驱动的 composition 几何。这些查询在大文档上
必须保持低成本。

对于 Markdown 编辑，`moui_richtext` 将规范源保存在 `MarkdownDocumentSession` 内，并暴露
窗口化编辑器路径，而不是 formatter 回调。`controlled_markdown_session_editor` 会把完整 source
返回给宿主，但 caret 和选择几何来自当前 `ScrollState`、viewport 高度和 overscan 对应的
`MarkdownDocumentSession::rich_text_window`。普通 `focused_text_input()` 调用应使用缓存的
source 长度和 session selection，不应为整个文档构造 `TextGraphemeBoundaries`。

只有当操作实际改变或规范化文本时，才使用完整的字素边界扫描器：键盘移动、选择规范化、
delete-range 计算、paste/input 转换、composition 光标偏移，或向 IME 移交时的 raw/UTF-8
偏移转换。不要在绘制、焦点探测、滚动处理或普通宿主 IME polling 中放入整文档字素扫描、
完整 Markdown 解析、完整 `RichTextDocument` 构造或文档高度遍历。

预期的 Markdown Editor 滚动/输入管道是：

```text
ScrollState -> MarkdownDocumentSession height index -> visible block window
  -> active TextSystem caret/hit-test geometry -> TextInputState / DrawCommand
```

包测试可以证明结构契约，例如“滚动不会重新解析”和“滚动标记 paint dirty，而不是 layout dirty”。
关于原生 IME anchoring、候选窗口位置或可见滚动平滑度的声明仍需要下文描述的匹配宿主
smoke 证据。

## 原生 WGPU

`moui_wgpu_renderer` 拥有原生 provider 协议、provider 响应验证、fallback 组合、glyph atlas 上传
和渲染器侧 cache keys。它不依赖独立的 Cosmic provider 包。

Provider 包刻意保持分离：

- `moui_wgpu_renderer/cosmic_text/`：Moon Cosmic provider，由选择 `MoonCosmic` 的示例直接使用，
  也作为平台默认值的 fallback provider。
- `moui_wgpu_renderer/coretext/`：macOS CoreText/CoreGraphics provider。macOS 默认使用该 provider
  与 Cosmic fallback 组合。
- `moui_wgpu_renderer/directwrite/`：Windows DirectWrite scaffold。在真实 DirectWrite 引擎返回平台布局
  和栅格数据之前，Windows 默认使用该 scaffold 与 Cosmic fallback 组合。
- `moui_wgpu_renderer/fontconfig/`：Linux fontconfig/FreeType provider 边界。Linux 默认使用该 provider
  与 Cosmic fallback 组合。当 FreeType 和字体可用时，该 provider 可以为显式 emoji family run
  返回来自 Noto Color Emoji 的原生彩色 emoji glyph；更广泛的 shaping、测量和非 emoji 栅格数据
  在完整 fontconfig/HarfBuzz 路径实现前仍回退到 Cosmic。
- `moui_wgpu_renderer/text_protocol/`：用于 UTF-32 输入、版本化 `FontSpec` 编码、measure/run/raster
  信封和嵌入字体注册载荷的共享 native-stub 载荷协议。

原生 WGPU 文本引擎选择属于 WGPU renderer provider，而不属于平台 host cores。入口调用
`@wgpu_renderer.native(text_engine=...)` 并与平台 `entry()` 组合。平台默认引擎将原生 provider 与 Cosmic fallback
组合；`MoonCosmic` 直接选择 Cosmic provider。Showcase 也有显式的 `macos_wgpu`、
`windows_wgpu` 和 `linux_wgpu` 入口，用于比较这些路径。单独的 Showcase 和
Markdown Editor `*_skia` 入口选择 `moui_skia_renderer` provider，而不是 WGPU 文本 provider 变体。
默认情况下，Skia 基本文本测量和绘制会通过 `moui_skia` 的 `FontMgr` 和 `Font`
解析 MoUI `FontSpec` family stack、weight 和 style。系统 `FontMgr` 路径现在构造
`FontFallbackRequest`，其中包含代表性覆盖字符：优先 emoji hints，其次非 ASCII code point，
再其次第一个 code point，然后才回退到常规 family matching。它还为 emoji、CJK、kana、Hangul、
Hebrew、Arabic、Devanagari、Thai、Lao、Sinhala、Khmer、Myanmar 和 Latin/default 文本附加推断的
BCP47 脚本语言标签，使原生 `FontMgr` 的 `match_fallback_request` 可以在 family matching 前使用
语言感知 fallback 元数据。它的 `TextSystem` 返回 Skia 字体度量 baseline/height，以及基本输入几何的
caret 位置。当 `moui_skia/native` 与 SkShaper 支持链接时，Skia 文本系统会把 shaped-run source
clusters 映射回 MoUI 的逐字符 caret 数组；否则它会回退到 Skia 测量的 prefix carets。
两条 caret 路径都会应用代表性 combining-mark、Indic matra/virama、Arabic mark、Thai mark、
Lao mark、Sinhala mark、Khmer vowel/coeng、Myanmar mark、Hangul Jamo L/V/T clusters、keycap、
emoji-modifier、variation-selector、regional-indicator 成对、emoji tag-sequence flags、
Unicode prepend marks 和 ZWJ cluster 内部稳定化。对于系统 `FontMgr` 路线，单行 `TextRun`
渲染现在消费与测量、布局宽度和 caret mapping 相同的 shaped glyph 载荷。原生绘制先通过已检查的
`moui_skia/native` glyph-run 绘制契约重放该载荷；如果 SkShaper 或 glyph 载荷不可用，
则回退到 `draw_text_utf8`，使文本保持可见。混合 run fallback 分段器遵循同一个
Indic virama/linker 边界，包括 Indic 辅音前的 virama 加 Extend marks，因此逐 run 字体 fallback
不会拆开该编辑 cluster。Skia 分段和 fallback caret 稳定化现在直接通过 core
`TextGraphemeBoundaries` 路由，Skia white-box 测试将 cluster slices 和面向 IME 的
`nearest_boundary_utf8_offset` 转换与 core 扫描器比较，使渲染器文本 smoke、编辑器移动、
选择几何、hit testing 和宿主 IME 请求共享一个边界来源。
Linux Skia 在 Skia port 头文件可用时通过 fontconfig/FreeType 解析默认 `FontMgr`，并以常见系统字体目录上的
directory font manager 作为兜底。如果选定的 Skia 字体产生空白或不完整的 glyph run，
渲染器会重试测量和绘制；系统 `FontMgr` 路径会先为 emoji-hint 文本尝试平台 emoji 字体候选，
然后回退到 Skia 默认字体。完整 fallback run 会立即被接受，而部分 default-font fallback
只有在减少 missing glyph ids 或从空白 primary run 恢复可见文本时才被接受，因此启动 Showcase
文本保持可见，文本字段 caret 位置也与绘制的 glyph 对齐，同时不会把同样不完整的 fallback run
静默视为已恢复。Skia 绘制会把选中的 glyph run 对齐到 `TextRun.frame` 内，并在栅格化前将 canvas
裁剪到同一个 frame，因此有界文本控件会使用同一个平台中立 frame 进行测量、caret 几何和原生栅格输出。
`skia_text_system()` 也继承 core 段落布局契约。在 fallback-safe 构建中，它仍可以从既有 Skia
测量路径产生换行行度量、段落 caret 矩形、选择矩形和 hit-test 结果，同时保持
`native_paragraph_ready` 和 `bidi_visual_order_ready` 为 false。当 `skia_paragraph_available()` 为 true 时，
Skia 文本系统通过原生 `Paragraph` wrapper 路由段落布局，通过绑定消费 SkParagraph 行度量、
选择框和 hit-test offset，并且仅在行度量、caret 几何、选择矩形、hit testing 和混合方向视觉顺序元数据
都有效时设置就绪元数据。默认 selection-box 策略是 SkParagraph 等价的
`RectHeightStyle::kMax` 加 `RectWidthStyle::kTight`。无效或不可用的 SkParagraph 几何会回退到既有
core 段落结果，而不会提升这些就绪标志。原生绑定也暴露可选 SkParagraph paint，用于段落路线 smoke
覆盖；MoUI 的单行 `TextRun` 主路径仍使用 shaped glyph/TextBlob-equivalent glyph-run 路线，而不是
SkParagraph paint。macOS、Windows 和 Linux 的 Skia factory 默认使用系统 `FontMgr` 路径，因此普通原生
Skia 入口会覆盖平台字体查找、emoji retry 和可选 SkShaper（如果已链接）。渲染器包也直接暴露
`skia_text_system()`，使 Skia 测量路径可以纳入原生诊断文本一致性，而不需要平台窗口，也不把 provider
检查视为运行时观察。这些诊断断言混合 CJK、emoji、ZWJ emoji、Indic mark、Arabic mark、Thai mark、
Lao mark、Sinhala mark、Khmer vowel/coeng、Myanmar mark、Hangul Jamo 和 bidi 样本的单调 caret 覆盖
与 max-width clamping，并且现在将 `skia_text_system()` 注入公共 `AppRuntime` 文本字段，以证明
Skia 测量路径驱动聚焦文本输入 composition caret 几何和选择高亮绘制。Fallback-safe 诊断不声称原生平台
IME 运行时行为或原生 SkParagraph 运行时等价；文本成熟度 preflight 现在将 bidi 重排和段落断行标记为
ready，而只有匹配宿主的真实 Skia SkParagraph smoke 日志可以声称原生段落运行时观察。macOS 测试者拥有的
first-frame smoke 入口仍显式选择 `SkiaFontResolution::EmptyTypeface`；这让 CLI smoke 运行保持在更安全的
default-font retry 路径，而不改变普通应用默认值。Fallback-safe Skia 渲染器测试也通过内部 descriptor
preflight 消费新的 `moui_skia` `FontFallbackRequest`、`TextMeasurementDescriptor`、
`TextShapingDescriptor`、`ShapedTextRunDescriptor` 和 `ShapedGlyphRunDescriptor` 资源计划，
使字体 fallback 和 shaped-run cache keys 在不需要真实 Skia 链接的情况下保持可审计。`backend_info()`
也报告 fallback-safe 的 `text maturity audit ready` 或 `text maturity audit pending` 摘要：它统计已审计的
descriptor、fallback-request、代表性 shaped/fallback caret、emoji-hint 和 empty-typeface retry 边界、
missing-glyph 恢复规则，以及 Skia 混合 run fallback 分段路径，并结合 Unicode 17 字素、bidi、段落和
确定性彩色 emoji 就绪性。段落 API 现在已具备行度量和几何，且可选 SkParagraph 路线已通过原生绑定接线。
文本成熟度 preflight 现在将 bidi 重排和段落断行标记为 ready；匹配宿主的 macOS、Windows 和 Linux
Skia 主线 smoke 日志提供真实 SkParagraph 观察。确定性彩色 emoji 通过运行时 glyph format 元数据报告，
而未来的 Unicode 字素数据刷新和更广泛排版 benchmark 属于一致性维护。

渲染器文本/emoji smoke 现在有更强的审计边界：`colorEmojiPixels` 必须携带高饱和度 glyph/raster
观察以及 `font-metadata` 和 `glyph-metadata` 令牌。原生 Skia 文本/emoji smoke 通过
`skia_emoji_font_fallback_diagnostic()` 记录请求的 emoji family、Skia text-system id、shaper path、
RGBA glyph format、cluster count、pixel counts、stable glyph key、measured glyph size、
推断的 fallback script/language-tag 数量、fallback request character、resolved missing-glyph count，
以及 emoji-hint/fallback-request/missing-glyph-recovery 状态；它还通过
`skia_text_selection_geometry_diagnostic()` / `skia_text_visual_order_diagnostic()` 记录段落选择矩形、
line-range 几何、hit-test 诊断和视觉 bidi-order 诊断。通过原生 smoke 现在要求
`paragraphWrapping` 的 SkParagraph 标记 `engine=skparagraph native_paragraph_ready=true
line-metrics later-line-pixels`，`bidiLayout` 的
`engine=skparagraph bidi_visual_order_ready=true visual-order`，以及 `selectionRects` 的
`engine=skparagraph selection-rects line-range rect-geometry hit-test`；fallback 几何、caret-only 诊断和
启发式 visual-order 日志不足以满足 smoke marker。对于原生 Skia，`colorEmojiPixels` 还要求
`fallback-request`、`emoji-hint` 和 `stable-glyph-key` smoke token，使高饱和度像素绑定到
FontMgr fallback request 和 glyph 元数据路径，而不是泛泛的 raster-only 观察。Skia emoji/font fallback
诊断载荷还记录推断的 fallback 语言标签、primary script tag、request language count、fallback request
character，以及该请求使用的 missing-glyph recovery 审计字段。
WebGPU wasm 记录浏览器 canvas 字体栈以及 glyph atlas key 和 size 元数据。渲染器 smoke 也为
`selectionRects`、`graphemeEditing`、`imeCandidateAnchor` 和 `imeCompositionVisual` 保留单独的 marker key；
这些 key 必须由选择矩形、line-range、字素边界、edit-action、candidate-anchor、surrounding-text、
composition-range 和 preedit-pixel 观察支撑，之后才能在发布说明中提及文本或 IME 就绪性。
原生 Skia `imeCandidateAnchor` 还要求 `utf8-offsets` 观察，用于字素规范化的光标和 anchor 偏移；
原生 Skia `imeCompositionVisual` 还要求 `composition-cursor` 观察。原生 Skia 文本/emoji smoke
从共享 `TextGraphemeBoundaries`、宿主 IME 诊断（包括 UTF-8 cursor 和 anchor offsets 加 composition
cursor 几何）、Skia 文本系统几何以及捕获的文本字段 composition 像素记录 `graphemeEditing`、
`imeCandidateAnchor` 和 `imeCompositionVisual`。这些是渲染器/文本系统 smoke marker，不是匹配宿主的
原生 IME 运行时观察。平台运行时观察会进一步拆分原生 IME 就绪性：原生 `status=passed` 条目还必须从
匹配宿主 Showcase artifacts 记录 `imeSurroundingText`、`imeCommitDelete`、`imeCursorUpdate`、
`imeScrollAnchor`、`imeScaleDprAnchor` 和 `imeResizeAnchor` 观察。这些日志必须携带
matching-host runtime、native-app、`renderer=application`、匹配应用 marker、platform-protocol、
candidate-window、surrounding-text、composition-visual、commit/delete、cursor-update、scroll、
scale/DPR 和 resize markers，因此仅包级 composition 测试和粗粒度 `textInput` 观察不能单独提升原生
IME 就绪性。这些字段让 CI artifacts 更容易审计，但尚不保证精确的跨平台 typeface identity、
glyph-id 确定性、原生 IME 行为或完整 Unicode bidi 布局等价。

原生 provider 响应必须报告有效度量、覆盖输入文本的单调 caret 位置，以及 cache key 包含所有影响栅格输入
（例如 glyph identity、font size、style、weight 和 scale）的栅格 glyph 载荷。无效布局或栅格数据会在渲染器边界
被拒绝，并在提供 fallback 引擎时回退。Run-layout 响应可以省略 carets，但任何非空 caret 数组都必须单调并覆盖
输入文本，之后 glyph 才会被接受用于 atlas upload。

Cosmic provider 会在平台 emoji fallback 字体候选可用时加载它们。对于 provider-fragile emoji 诊断，
它会把代表性的 single-codepoint、variation-selector 和 ZWJ 样本安全映射到等长布局文本后再 shaping，
因此测量和原生 run-layout 响应可以保持单调 caret 覆盖，而不声称完整 emoji shaping 等价。

## Web Wasm-GC

Web 路径保持在 `wasm-gc + window/web + browser WebGPU host imports` 上。`backend/web` 安装一个由
浏览器 Canvas 支撑的 `TextSystem`，WebGPU 运行时通过 DPR-aware 的 canvas-rasterized glyph atlas
绘制文本。测量和绘制使用由 `FontSpec` 生成的同一个 CSS `system-ui` 栈。
Web 宿主还路由浏览器 IME composition 事件，并接受聚焦文本控件的 `TextInputSession` IME 请求，
包括 cursor 几何和 surrounding-text 更新。这覆盖了浏览器输入法 plumbing；更广泛的 shaping、bidi
和确定性浏览器 glyph 栅格化仍作为一致性主题跟踪，而不是 Web-host 能力声明。

浏览器运行时资产位于 `backend/web/*.js`；Web 示例包只应提供应用专用入口、wasm URL、canvas host
和 UI 回调。

## 嵌入字体

应用可以通过 `AppRuntime::register_font_data` 注册嵌入字体字节。原生 WGPU 会把这些字节转发给活动
provider，并在存在时转发给组合的 fallback provider。CoreText v1 会尝试以请求的 family alias
进行进程本地注册。未来 DirectWrite 和 fontconfig/HarfBuzz/FreeType 实现应使用同一个 hook 处理私有字体集合。

远程字体加载有意不包含在当前后端契约中。

## 当前保证

**证明状态**

文本 shaping 和 emoji 文本在 `renderer-capability-report.md` 中声明为 `supported`。其证明边界是：

- **L1 proof**：`pr-profile` job 覆盖字素断点、caret 稳定化、UAX#29 fixtures、emoji cluster 检测、
  确定性测量和运行时 glyph format 检查。
- **L2 proof**：`macos-real-skia` / `linux-real-skia` / `windows-real-skia` 在每个 PR 上运行
  `--run-text-emoji-smoke`，覆盖 SkShaper/SkParagraph smoke markers、bidi Arabic 和混合方向
  visual-order markers、keycap/regional-indicator/skin-tone-modifier fallback 诊断，以及确定性彩色
  glyph format 元数据。
- **维护**：未来 Unicode 字素数据刷新需要重新生成属性谓词和 fixtures。

**原生 SkParagraph / Bidi 就绪性**

当 `MOUI_SKIA_ENABLE_SKPARAGRAPH=1` 且 `skia_paragraph_available()` 为 true 时，原生 Skia 段落布局
和 bidi 视觉顺序提升使用 SkParagraph 实现路径。发布声明由 macOS、Windows 和 Linux 真实 Skia
smoke 日志支撑，日志包含 SkParagraph 行度量、later-line 像素、选择矩形、line ranges、hit tests
和混合方向 visual-order 观察。

文本成熟度 preflight 会针对 core 字素边界契约将 bidi 重排和段落断行标记为 ready；匹配宿主 smoke
日志提供所需的 SkParagraph markers。

**Core 字素边界契约**

Core 现在暴露 `TextGraphemeBoundaries`，作为单一 UAX 风格 cluster 边界契约，供 fallback caret
稳定化、左右 caret 移动、选择/range 规范化、surrounding delete ranges、composition cursor offsets、
富文本 hit testing、raw UTF-8 offset 转换，以及后续 IME 移交的 `nearest_boundary_utf8_offset` 转换使用。
这让确定性文本字段、选择和 IME-anchor 几何保持在同一路径上。

仓库现在有一个离线 `GraphemeBreakTest.txt` 风格 fixture 和 generator guard
（`scripts/generate-grapheme-break-fixtures.mjs --check`），覆盖策展样本，以及一个从
`moui/core/unicode/testdata/GraphemeBreakTest-17.0.0.txt` 生成的 vendored Unicode 17.0 默认字素断点 fixture。
`moon test moui/core --target native` 会运行策展 fixture、完整边界 fixture，以及一个完整编辑 fixture，
检查 `is_boundary`、floor/ceil/nearest boundary snapping、折叠和展开 range 规范化、surrounding delete ranges、
raw boundary 到 UTF-8 offset 转换，以及每个 Unicode 17 样本上 every-index
`nearest_boundary_utf8_offset` snapping。另一个完整布局 fixture 会检查 fallback 段落 caret 矩形、
折叠选择矩形和 hit-test offsets 是否 snap 到同一个 Unicode 17 边界。`moui_skia_renderer` 也从同一个文件
生成 Skia white-box fixture，因此 `moon test moui_skia_renderer --target native` 会针对 Unicode 17 默认断点样本
验证 `skia_grapheme_cluster_texts`，并检查 every-index `nearest_boundary_utf8_offset` snapping 是否匹配
Skia 生成的 cluster boundaries。

完整 Unicode fixtures 使用不同的生成 helper/test 名称，并通过原 fixture 生成章节中记录的命令进行检查
（确切生成器调用见文件历史）。

扫描器现在从生成的 Unicode 17.0 属性谓词驱动 core 字素断点类别，覆盖 CR/LF/control、Prepend、Extend、
SpacingMark、Regional_Indicator、ZWJ、Extended_Pictographic，以及 Indic_Conjunct_Break
Linker/Consonant/Extend。下载官方 Unicode 17.0.0 UCD URL 中固定的 Unicode 文件后，使用
`node scripts/generate-grapheme-property-data.mjs --grapheme-property <Unicode-17.0.0-GraphemeBreakProperty.txt> --emoji-data <Unicode-17.0.0-emoji-data.txt> --derived-core-properties <Unicode-17.0.0-DerivedCoreProperties.txt> --check`
重新生成这些谓词。它将 ZWNJ 视为 GB9 的 Extend code point，应用 Unicode 17
Indic_Conjunct_Break linker 规则而不是早先手写的 virama 捷径，并使删除和 IME offsets 与完整默认字素断点
fixture 保持一致。

**原生 IME 运行时就绪性**

原生 IME 运行时就绪性按平台划分：macOS 已记录匹配宿主 Markdown Editor/AppKit artifacts，覆盖候选 anchor、
surrounding text、composition visuals、commit/delete 行为、cursor updates、scroll anchors、
scale/DPR anchors、resize anchors 和 Markdown Editor IME dogfood，因此 macOS 平台观察条目可以将这些观察设为
`yes`。Linux IME 协议功能已于 2026-07-11 通过 WSL2（WSLg Wayland）验证：
`check_moui_linux_smoke.sh` IME probe 通过全部 8 个字段
（enabled/hint/surrounding/cursor/updated/updated_hint/updated_cursor/disabled 均为 `true`）。
完整交互输入证据（pointer/keyboard 和 destroy sequence）仍需要匹配 Wayland 桌面宿主（Ubuntu 24.04+）
Showcase 或 Markdown Editor 运行时日志。Windows 在其原生 IME 运行时路径可称为 ready 前，仍需要等价的匹配
MSVC 宿主运行时日志。

**原生 WGPU Provider 状态**

原生 WGPU 可以通过 provider 协议和 glyph atlas 路径保留 RGBA 彩色 glyph 载荷，并且有 Cosmic 平台 emoji
fallback 候选加载、Cosmic color swash 保留、provider-safe emoji 布局映射，以及由聚焦测试覆盖的 CoreText
AppleColorEmoji RGBA 路径。稳定与诊断测试会断言 caret 数量、单调性、clamping、编辑器选择行为、
IME anchor 几何、core fallback cluster 稳定化和移动、CRLF/control 分段、emoji ZWJ 限制、
regional-indicator 成对、Indic conjuncts，以及混合 bidi、CJK、single-codepoint emoji、
variation-selector emoji 和 ZWJ emoji 样本中的 provider fallback 安全；Cosmic run-layout 测试还通过
safe-mapped 布局路径断言 glyph 输出和 caret 覆盖。Skia 渲染器测试覆盖同样有代表性的 emoji caret 覆盖，
以及 combining-mark、Indic matra/virama、Arabic mark、Thai mark、Lao mark、Sinhala mark、
Khmer vowel/coeng、Myanmar mark、Hangul Jamo L/V/T clusters、emoji-modifier、variation-selector、
regional-indicator 成对、emoji tag-sequence flags、Unicode prepend marks 和 ZWJ cluster 内部的
shaped-run 与 fallback caret 稳定化，系统 FontMgr-only emoji 字体重试边界，以及文本测量和 shaping 的
fallback-safe descriptor 资源计划。原生诊断一致性还把 Skia 文本系统注入文本字段运行时，以验证
composition caret 几何和选择高亮绘制。

**平台文本 Provider 状态**

Linux 原生 Skia 是 Preview Ready 的文本/渲染路线，并继续使用上文描述的 Skia 文本系统。Linux 原生 WGPU
fontconfig/FreeType provider 仍为诊断路径，带有显式 FreeType 彩色 emoji 处理和组合 Cosmic fallback
处理通用文本。Windows DirectWrite 仍是带 Cosmic fallback 的诊断 provider 路线。

Web 可以暴露浏览器 emoji 和字体 fallback 行为，而稳定 Web adapter 测试保持宿主支撑的 `TextSystem`
契约确定。

**文档同步要求**

影响渲染器功能状态的文本变化必须更新 `render/capabilities.mbt`、`render/capabilities_test.mbt`
和 `docs/renderer-capability-report.md`。
- 聚焦文本输入通过宿主上下文菜单暴露 MoUI 默认的 copy、cut、paste、undo、redo 和 select-all 命令，
  因此键盘快捷键和原生菜单选择共享同一条选择、剪贴板和 Unicode paste 分发路径。
- Linux 原生 Skia 是 Preview Ready 的文本/渲染路线，并继续使用上文描述的 Skia 文本系统。Linux 原生 WGPU
  fontconfig/FreeType provider 仍为诊断路径，带有显式 FreeType 彩色 emoji 处理和组合 Cosmic fallback
  处理通用文本。Windows DirectWrite 仍是带 Cosmic fallback 的诊断 provider 路线。
- Web 可以暴露浏览器 emoji 和字体 fallback 行为，而稳定 Web adapter 测试保持宿主支撑的 `TextSystem`
  契约确定。
- 影响渲染器功能状态的文本变化必须更新
  `render/capabilities.mbt`、`render/capabilities_test.mbt` 和
  `docs/renderer-capability-report.md`。

## 验证

文本一致性分为两层：

- 稳定测试在普通包检查内运行，覆盖 `core`、`moui_wgpu_renderer`、`moui_wgpu_renderer/cosmic_text`、
  `moui_web_renderer` 和 `backend/web`。
- 诊断矩阵测试位于 `moui_tests/text_conformance/` 下，并且是 opt-in。它们会在当前宿主确实能覆盖时，
  比较 core fallback、Cosmic、platform-default 组合 fallback、malformed-provider fallback 和 Web 文本系统。
  严格失败仅限于契约不变量；除非契约另有规定，跨引擎 width/baseline 差异都属于诊断信息。

文本系统工作的聚焦检查：

```sh
sh scripts/check.sh --profile full
moon test moui_tests/text_conformance/native --target native
moon test moui/core --target native
moon test moui_wgpu_renderer --target native
moon test moui_wgpu_renderer/cosmic_text --target native
moon test moui_skia_renderer --target native
moon test moui_web_renderer --target wasm-gc
moon test moui/backend/web --target wasm-gc
```

平台文本 provider 变化还应运行受影响的 WGPU provider 包测试。公共 API 变化需要运行 `moon info`
并审查生成的 `pkg.generated.mbti` diff。
