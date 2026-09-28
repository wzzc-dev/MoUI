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
  @core.Color::rgba(r=0.145, g=0.157, b=0.180)
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
