///|
/// MoUI Studio 编辑器壳主题：石墨工程面板 + IDE 蓝唯一强调色（IDEA/VSCode
/// 口径——成熟 IDE 的强调色都是一套低饱和中性底 + 单一蓝交互色）。
/// from_seed 从蓝主色派生完整角色盘；scheme 钉深色（Dark），让 IDE 更像
/// 工程终端而不是课堂幻灯片：暗底、发丝分隔线、等宽信息密度。
/// Deep-dark 基底是刻意选的中间层（不是纯黑），既有终端观感又保留
/// 面板/画布/卡片三级层次。
///
/// **字阶按 IDE 密度单独给**（`studio_typography`）：core 的默认字阶是
/// 移动端/通用水准（body 16 / title 21），放进 24pt 的树行里就是「字比行
/// 还高」——面板头、树行、状态栏全部顶着字，读起来又挤又土。IDEA/VSCode
/// 的界面字阶在 11–13pt 区间，本仓的行高常量（顶栏 40 / 面板头 30 /
/// 树行 24 / 状态栏 22）本来就是照那个密度定的，字阶必须跟上，
/// 否则「行是 IDE 的行、字是移动端的字」，两边互相打架。
/// **只改编辑器壳**：舞台控件走 `studio_product_theme`，导出应用的字阶
/// 不变（产品 UI 的观感不因编辑器密度调整而漂移）。
pub fn studio_theme() -> @core.Theme {
  @views.theme(
    scheme=Dark,
    palette=@core.ColorPalette::from_seed(
      primary=ide_accent(),
      Dark,
      foreground=@core.Color::rgba(r=0.90, g=0.91, b=0.93),
      background=@core.Color::rgba(r=0.086, g=0.094, b=0.110),
      surface=@core.Color::rgba(r=0.121, g=0.133, b=0.153),
      surface_variant=@core.Color::rgba(r=0.161, g=0.176, b=0.200),
      outline=@core.Color::rgba(r=0.235, g=0.255, b=0.290),
      muted=@core.Color::rgba(r=0.553, g=0.580, b=0.620),
    ),
    radius_scale=@core.RadiusScale::{ sm: 2.0, md: 4.0, lg: 6.0, pill: 999.0, },
    typography=studio_typography(),
  )
}

///|
/// 编辑器壳字阶（IDEA/VSCode 密度：界面 11–13pt，代码 13pt 等宽）。
///
/// 与壳的行高常量配套：24pt 树行装 13pt 正文（上下各 ~5.5pt 呼吸），
/// 30pt 面板头装 13pt 标题，40pt 顶栏装 13pt 芯片字。
///
/// `display/headline/title` 保留较大的档位（空舞台 hero、对话框标题要用），
/// 但都比 core 默认收一档——默认 38/27/21 在 IDE 里是「海报字号」。
pub fn studio_typography() -> @core.TypographyScale {
  let label = @core.FontSpec::new(size=13.0, weight=600)
  {
    display: @core.FontSpec::new(size=24.0, weight=600),
    headline: @core.FontSpec::new(size=18.0, weight=600),
    title: @core.FontSpec::new(size=15.0, weight=600),
    subtitle: @core.FontSpec::new(size=13.0, weight=600),
    body: @core.FontSpec::new(size=13.0, weight=400),
    label,
    caption: @core.FontSpec::new(size=12.0, weight=400),
    overline: @core.FontSpec::new(size=10.0, weight=600),
    // `control` 是 `label` 的历史别名（按钮/页签的强调字），保持同一档。
    control: label,
  }
}

///|
/// 产品主题：导出应用（真实运行态）的外观——浅色 + IDE 蓝强调。
/// 设计/运行舞台的控件套这个主题渲染，设计所见即真实所得；
/// runner 模板（tools/export_runner_template/runner.mbt 的 runner_theme）
/// 内联同一组值——跨 bundle 不能 import，改动必须两处同步。
pub fn studio_product_theme() -> @core.Theme {
  @views.theme(
    palette=@core.ColorPalette::from_seed(primary=ide_accent(), Light),
  )
}

///|
/// 设计/运行舞台底：暗色画布 + 细网格（技术风画板，不再是白纸）。
/// 控件自身颜色仍由 IR 携带（设计结果是产品数据，不随 Studio 主题变化）。
pub fn studio_stage_background() -> @core.Color {
  @core.Color::rgba(r=0.957, g=0.957, b=0.965)
}

///|
/// 拟真窗口标题条底：比内容区略深一档的浅灰（设计稿 #e9e9ec）。
pub fn studio_stage_title_bar() -> @core.Color {
  @core.Color::rgba(r=0.914, g=0.914, b=0.925)
}

///|
/// 窗口根底色：与 studio_theme 的 palette.background 同源。宿主窗口不铺
/// 主题底色（macOS 浅色系统给白底），根容器必须显式铺满，否则暗色文字
/// 落在透出的白底上（2026-09-29 白字白底事故的窗口侧修复）。
pub fn studio_window_background() -> @core.Color {
  @core.Color::rgba(r=0.086, g=0.094, b=0.110)
}

///|
/// 画布网格线：比舞台底略亮一档的发丝线（1px 网格，不抢控件视觉）。
pub fn studio_grid_line() -> @core.Color {
  @core.Color::rgba(r=0.208, g=0.227, b=0.259)
}

///|
/// 画布边界线：主轴框线，比网格线更明确但仍克制。
pub fn studio_stage_outline() -> @core.Color {
  @core.Color::rgba(r=0.310, g=0.337, b=0.380)
}

///|
/// 终端式控制台卡底：比 surface 再暗一档，和面板区分出「日志区」。
pub fn studio_console_background() -> @core.Color {
  @core.Color::rgba(r=0.078, g=0.086, b=0.102)
}

///|
/// 积木分类底色：技术风暗色块——每个语义族一个低饱和深色 tint
/// （存值蓝 / 分支橙 / 循环绿 / 跳出红 / 调用紫），亮色文字保证对比度；
/// 选中态用 IDE 蓝描边（唯一强调色）。
pub fn block_fill(kind : @blocks.BlockKind) -> @graphics.Color {
  match kind {
    @blocks.BkDeclare | @blocks.BkAssign | @blocks.BkSetIndex =>
      @graphics.Color::rgba(r=0.157, g=0.208, b=0.318)
    @blocks.BkIf | @blocks.BkElseIf | @blocks.BkElse | @blocks.BkEnd =>
      @graphics.Color::rgba(r=0.298, g=0.235, b=0.145)
    @blocks.BkMatch | @blocks.BkCase =>
      @graphics.Color::rgba(r=0.298, g=0.235, b=0.145)
    // 声明块：数据族的存值蓝（更深一档，与普通变量行区分）
    @blocks.BkEnumDecl | @blocks.BkStructDecl =>
      @graphics.Color::rgba(r=0.106, g=0.157, b=0.255)
    @blocks.BkCountLoop | @blocks.BkForEach | @blocks.BkWhile | @blocks.BkReturn =>
      @graphics.Color::rgba(r=0.145, g=0.271, b=0.196)
    @blocks.BkBreak => @graphics.Color::rgba(r=0.318, g=0.165, b=0.157)
    @blocks.BkCall => @graphics.Color::rgba(r=0.243, g=0.192, b=0.333)
  }
}

///|
/// 积木块圆角半径：变量族（声明/赋值/元素赋值）用大圆角「胶囊」，
/// 控制流/命令保持小圆角矩形——形状本身参与语义编码（切片 E）。
pub fn block_corner_radius(kind : @blocks.BlockKind) -> Double {
  match kind {
    @blocks.BkDeclare | @blocks.BkAssign | @blocks.BkSetIndex => 14.0
    // 声明块也是数据族：胶囊圆角
    @blocks.BkEnumDecl | @blocks.BkStructDecl => 14.0
    _ => 6.0
  }
}

///|
/// 条件徽标色：比块体亮一档的暖白半透明——「这里是一个取值判断」。
pub fn block_badge_color(_kind : @blocks.BlockKind) -> @graphics.Color {
  @graphics.Color::rgba(r=0.95, g=0.95, b=0.92, a=0.32)
}

///|
/// 单轮廓描边色（M7②）：低透明度暗色——块体边缘一点点「咬合」的
/// 立体感，不与选中描边（强调色）竞争。
pub fn block_outline_stroke() -> @graphics.Color {
  @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.35)
}

///|
/// 积木块上的文字：暗色块配亮灰文字（等宽语义由字体层决定）。
pub fn block_text_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.902, g=0.914, b=0.933)
}

///|
/// 积木凹槽切口色：与积木画布底板同色，形成“咬合”视觉。
pub fn block_notch_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.098, g=0.106, b=0.125)
}

///|
/// 积木画布底板：比页面背景略暗一档的工程网格底。
///
/// **必须显式钉在画布容器上。** 早先 `blocks_canvas` 的容器没写
/// background，回落到环境 Base → `palette.surface`，于是画布底与相邻的
/// AI 保留带**完全同色**（实测同为 `#22262C`），两段之间的边界整个消失。
/// 落回主题色是「看起来对、其实没画」的典型：只要邻居也走回落，两块就糊成
/// 一片。画布底板与壳面板是两套配色纪律（前者属于积木域），所以这里
/// 不并入 `ide_*` 系列，由积木画布自己钉。

///|
/// 插槽（reporter slot）底色：**有内容**时用比块体略暗的一档，读作
/// 「这里坐着一块东西」（内容块自己会画在洞上面）。

///|
/// 脚本说明横幅的底色：比画布略亮的一档浅底，读作「这是注释不是代码」。
pub fn blocks_note_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.145, g=0.157, b=0.180, a=1.0)
}

///|
/// 脚本说明的文字色：比积木文本弱一档（注释不该与代码抢注意力）。
pub fn blocks_note_text() -> @graphics.Color {
  @graphics.Color::rgba(r=0.639, g=0.667, b=0.710, a=1.0)
}

///|
pub fn blocks_slot_filled() -> @graphics.Color {
  @graphics.Color::rgba(r=0.118, g=0.129, b=0.153, a=1.0)
}

///|
/// 空插槽底色：比 `blocks_slot_filled` 再暗一档（内凹），读作「这里等着
/// 塞一块」。两者都刻意**不与块体同色**——同色会让洞看不出来，而洞是
/// 「这里可以放东西」的唯一视觉线索。
pub fn blocks_slot_empty() -> @graphics.Color {
  @graphics.Color::rgba(r=0.078, g=0.086, b=0.106, a=1.0)
}

///|
pub fn blocks_canvas_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.098, g=0.106, b=0.125)
}

// ============================================================================
// IDE 壳调色板（v4 设计稿，JetBrains New UI 石墨档）
//
// 设计稿的 CSS 变量表是一套「编辑器壳」的独立角色盘：编辑器底 / 面板 /
// 面板二档 / 抬起面 / 悬停 / 选中 / 边框，以及代码语法 6 色。它们**不是**
// M3 语义角色（primary/on_surface…），所以不进 ColorPalette 派生——派生
// 只会把它们压成近似色，丢掉设计稿刻意拉开的四档明度。这里按角色平铺成
// 函数，与 blocks/stage 取色同一纪律：主题只管 Studio 自己的壳，控件外观
// 仍由 IR 携带。
// ============================================================================

///|
/// 编辑器底：代码区 / 积木画布 / 舞台背板的最底一档。
pub fn ide_editor_background() -> @core.Color {
  @core.Color::rgba(r=0.118, g=0.122, b=0.133)
}

///|
/// 面板：顶栏 / 图标栏 / 左栏 / 右栏 / 底部横条 / 状态栏。
pub fn ide_panel() -> @core.Color {
  @core.Color::rgba(r=0.169, g=0.176, b=0.188)
}

///|
/// 面板二档：按钮底 / 分段控件底 / 芯片底。
pub fn ide_panel_alt() -> @core.Color {
  @core.Color::rgba(r=0.200, g=0.212, b=0.227)
}

///|
/// 抬起面：输入框 / 卡片 / 内联卡（比面板再亮一档）。
///
/// **与 `ide_border`/`ide_hover` 是三件事，不是一件事。** 这三个函数一度
/// 返回同一个 rgba，后果是「面 = 线 = 悬停」：卡片描边与卡片填充同色，
/// 悬停也和静止同色，悬停反馈整个失效。原注释说「flat solid surfaces,
/// layer separation comes from border tone」——那句话要求**线比面亮**，
/// 抄成同值就把设计意图抹掉了。下面按 面 < 悬停 < 线 排开。
pub fn ide_elevated() -> @core.Color {
  @core.Color::rgba(r=0.224, g=0.231, b=0.251)
}

///|
/// 悬停底：行/按钮 hover（比抬起面亮一档，实测 1.09:1）。
///
/// 悬停是**瞬态状态**，必须在静止面上看得出来。与 `ide_elevated` 同值时，
/// 抬起面上的行悬停完全无反馈。
pub fn ide_hover() -> @core.Color {
  @core.Color::rgba(r=0.244, g=0.252, b=0.272)
}

///|
/// 悬停二档：抬起面之上的 hover（保留原值，仍是最高一档）。
pub fn ide_hover_strong() -> @core.Color {
  @core.Color::rgba(r=0.259, g=0.271, b=0.290)
}

///|
/// 选中底：树行/列表行选中（低饱和蓝灰，不与强调色抢）。
pub fn ide_selection() -> @core.Color {
  @core.Color::rgba(r=0.184, g=0.271, b=0.329)
}

///|
/// 边框：发丝分隔线（面板之间、行之间）。
///
/// 比 `ide_elevated` 亮一档（1.17:1）——发丝线要能在它分隔的**两块面**
/// 上都读出来，所以必须高于两侧的面，不能等于面。
pub fn ide_border() -> @core.Color {
  @core.Color::rgba(r=0.262, g=0.272, b=0.294)
}

///|
/// 边框弱档：面板内部行分隔（比 ide_border 更淡）。
pub fn ide_border_soft() -> @core.Color {
  @core.Color::rgba(r=0.200, g=0.208, b=0.220)
}

///|
/// 一级文字：正文/标题。
pub fn ide_text() -> @core.Color {
  @core.Color::rgba(r=0.875, g=0.882, b=0.898)
}

///|
/// 二级文字：次要说明 / 未选中标签。
pub fn ide_text_muted() -> @core.Color {
  @core.Color::rgba(r=0.616, g=0.627, b=0.659)
}

///|
/// 三级文字：元信息 / 计数 / 行号。
pub fn ide_text_faint() -> @core.Color {
  @core.Color::rgba(r=0.447, g=0.459, b=0.478)
}

///|
/// 强调色：IDE 蓝（IDEA/VSCode 口径的单一交互强调色）。
pub fn ide_accent() -> @core.Color {
  @core.Color::rgba(r=0.208, g=0.455, b=0.941)
}

///|
/// 强调色弱底：选中/上下文芯片底。
pub fn ide_accent_soft() -> @core.Color {
  @core.Color::rgba(r=0.208, g=0.455, b=0.941, a=0.22)
}

///|
/// 语义绿：运行正常 / 通过 / 已应用。
pub fn ide_success() -> @core.Color {
  @core.Color::rgba(r=0.361, g=0.710, b=0.384)
}

///|
/// 语义绿弱底（徽标）。
pub fn ide_success_soft() -> @core.Color {
  @core.Color::rgba(r=0.361, g=0.710, b=0.384, a=0.13)
}

///|
/// 语义黄：待审计 / 警告 / 脏标。
pub fn ide_warning() -> @core.Color {
  @core.Color::rgba(r=0.902, g=0.651, b=0.267)
}

///|
/// 语义黄弱底（徽标）。
pub fn ide_warning_soft() -> @core.Color {
  @core.Color::rgba(r=0.851, g=0.604, b=0.239, a=0.18)
}

///|
/// 语义红：错误 / 危险操作。
pub fn ide_danger() -> @core.Color {
  @core.Color::rgba(r=0.925, g=0.357, b=0.337)
}

///|
/// 语义红弱底（徽标 / 危险键悬停）。
pub fn ide_danger_soft() -> @core.Color {
  @core.Color::rgba(r=0.290, g=0.149, b=0.145)
}

///|
/// 代码语法色：关键字。
pub fn code_keyword_color() -> @core.Color {
  @core.Color::rgba(r=0.812, g=0.557, b=0.427)
}

///|
/// 代码语法色：字符串。
pub fn code_string_color() -> @core.Color {
  @core.Color::rgba(r=0.416, g=0.671, b=0.451)
}

///|
/// 代码语法色：数字。
pub fn code_number_color() -> @core.Color {
  @core.Color::rgba(r=0.165, g=0.675, b=0.722)
}

///|
/// 代码语法色：函数/内建命令。
pub fn code_function_color() -> @core.Color {
  @core.Color::rgba(r=0.337, g=0.659, b=0.961)
}

///|
/// 代码语法色：注释。
pub fn code_comment_color() -> @core.Color {
  @core.Color::rgba(r=0.478, g=0.494, b=0.522)
}

///|
/// 代码语法色：类型/控制关键字之外的高亮档。
pub fn code_type_color() -> @core.Color {
  @core.Color::rgba(r=0.780, g=0.490, b=0.733)
}

///|
/// 代码正文色：非高亮的普通 token。
pub fn code_plain_color() -> @core.Color {
  @core.Color::rgba(r=0.820, g=0.831, b=0.851)
}

///|
/// IR 行映射高亮色：设计稿的暖黄（与选中蓝区分——映射是提示，
/// 选中是状态）。
pub fn ide_ir_highlight() -> @core.Color {
  @core.Color::rgba(r=0.941, g=0.776, b=0.353)
}

///|
/// 诊断行的行内底色：淡红半透明（richtext run background），
/// 与错误条/行号红点同色系。
pub fn code_error_line_tint() -> @core.Color {
  @core.Color::rgba(r=0.937, g=0.325, b=0.313, a=0.16)
}

///|
/// IR 行映射**悬停**色：同一暖黄的半透明版。竖尺成为映射交互的
/// 唯一载体后，悬停（瞬态预览）与点击（驻留选择）必须有可区分的
/// 视觉——驻留用全亮暖黄，悬停用半透明。
pub fn ide_ir_hover() -> @core.Color {
  @core.Color::rgba(r=0.941, g=0.776, b=0.353, a=0.38)
}

///|
/// 积木分类色板：按 domain 的 5 个语义族取色——domain 保持语言与颜色
/// 中立，取色是渲染层的事（设计稿 8 类收敛到 IR 的 5 族）。
pub fn block_category_fill(category : @blocks.BlockCategory) -> @graphics.Color {
  match category {
    @blocks.CatEvent => @graphics.Color::rgba(r=0.784, g=0.627, b=0.196)
    @blocks.CatVariable => @graphics.Color::rgba(r=0.769, g=0.478, b=0.290)
    @blocks.CatFlow => @graphics.Color::rgba(r=0.322, g=0.627, b=0.424)
    @blocks.CatCommand => @graphics.Color::rgba(r=0.294, g=0.612, b=0.784)
    @blocks.CatExpression => @graphics.Color::rgba(r=0.494, g=0.408, b=0.788)
  }
}

///|
/// 积木块文字：分类色底都是中高明度，用近黑文字保证对比（设计稿口径）。
pub fn block_category_text() -> @graphics.Color {
  @graphics.Color::rgba(r=0.078, g=0.086, b=0.094)
}
