///|
/// MoUI Studio 品牌主题：石墨工程面板 + 印泥朱砂唯一强调色。
/// 「卯」取木工榫卯的朱印意象——from_seed 从朱砂主色派生完整角色盘；
/// scheme 钉深色（Dark），让 IDE 更像工程终端而不是课堂幻灯片：
/// 暗底、发丝分隔线、等宽信息密度。Deep-dark 基底是刻意选的中间层
/// （不是纯黑），既有终端观感又保留面板/画布/卡片三级层次。
pub fn studio_theme() -> @core.Theme {
  @views.theme(
    scheme=Dark,
    palette=@core.ColorPalette::from_seed(
      primary=@core.Color::rgba(r=0.86, g=0.32, b=0.24),
      Dark,
      foreground=@core.Color::rgba(r=0.90, g=0.91, b=0.93),
      background=@core.Color::rgba(r=0.086, g=0.094, b=0.110),
      surface=@core.Color::rgba(r=0.121, g=0.133, b=0.153),
      surface_variant=@core.Color::rgba(r=0.161, g=0.176, b=0.200),
      outline=@core.Color::rgba(r=0.235, g=0.255, b=0.290),
      muted=@core.Color::rgba(r=0.553, g=0.580, b=0.620),
    ),
    radius_scale=@core.RadiusScale::{ sm: 2.0, md: 4.0, lg: 6.0, pill: 999.0, },
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
/// 选中态用朱砂描边（唯一强调色）。
pub fn block_fill(kind : @blocks.BlockKind) -> @graphics.Color {
  match kind {
    @blocks.BkDeclare | @blocks.BkAssign =>
      @graphics.Color::rgba(r=0.157, g=0.208, b=0.318)
    @blocks.BkIf | @blocks.BkElseIf | @blocks.BkElse | @blocks.BkEnd =>
      @graphics.Color::rgba(r=0.298, g=0.235, b=0.145)
    @blocks.BkCountLoop | @blocks.BkWhile =>
      @graphics.Color::rgba(r=0.145, g=0.271, b=0.196)
    @blocks.BkBreak => @graphics.Color::rgba(r=0.318, g=0.165, b=0.157)
    @blocks.BkCall => @graphics.Color::rgba(r=0.243, g=0.192, b=0.333)
  }
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
pub fn ide_elevated() -> @core.Color {
  @core.Color::rgba(r=0.224, g=0.231, b=0.251)
}

///|
/// 悬停底：行/按钮 hover。
pub fn ide_hover() -> @core.Color {
  @core.Color::rgba(r=0.224, g=0.231, b=0.251)
}

///|
/// 悬停二档：抬起面之上的 hover。
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
pub fn ide_border() -> @core.Color {
  @core.Color::rgba(r=0.224, g=0.231, b=0.251)
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
/// 强调色：设计稿的 IDE 蓝（与朱砂品牌色并存——朱砂是品牌，蓝是交互）。
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
