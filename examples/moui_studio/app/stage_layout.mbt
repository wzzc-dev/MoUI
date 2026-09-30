///|
/// 运行舞台的绝对布局节点：按 IR 控件矩形给每个子控件分配帧。
///
/// MoUI 的放置管线会用「帧的 tight 约束」重排子树，所以只要这里把帧
/// 分配成设计矩形，子控件就精确等于设计的尺寸与位置——这是 stack+offset
/// 做不到的（stack 给每个子整帧，tight 重排会把单个控件拉伸成整帧）。
/// 子帧用 child_frames_tight 声明，子树按最终帧重新测量换行。
priv struct StageLayout {
  // 与 children 一一对应的设计坐标矩形（来自 IR 控件的 x/y/width/height）
  rects : Array[@geometry.Rect]
}

///|
impl @core.ViewNode for StageLayout with fn identity(_self) {
  @core.ViewIdentity::new(kind="StageLayout")
}

///|
impl @core.ViewNode for StageLayout with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for StageLayout with fn layout(self, ctx) {
  // 满幅画布映射（canvas.mbt 的 stage_mapping 同一公式）：舞台按 fit_scale
  // （[0.5,1] 钳制）缩放后**居中**在窗格里，控件层节点本身铺满窗格。
  // 三层（背景/控件/覆盖）与指针换算共用同一映射，任何一层各算一份就会
  // 失配（实测 w=900 时底板按比例缩小、控件层却按 1.0 摆放，按钮文字被
  // 压成 0 宽）。放置管线以帧 tight 约束重排子树（此时 min == max == 帧），
  // 重排后比例不变，子控件精确等于缩放后的设计尺寸。
  let avail_w = ctx.constraints.max.width
  let avail_h = ctx.constraints.max.height
  let scale = fit_scale(avail_w, avail_h, design_width, design_total_height)
  let ox = (avail_w - design_width * scale) / 2.0
  let oy = (avail_h - design_total_height * scale) / 2.0
  let size = ctx.constraints.constrain(
    @core.Size::new(width=avail_w, height=avail_h),
  )
  let frames : Array[@core.Rect] = []
  for rect in self.rects {
    // 内容区从标题条之下开始：控件 y 要整体下移一条标题条。
    frames.push(
      @core.Rect::new(
        x=ox + rect.origin.x * scale,
        y=oy + (title_bar_height + rect.origin.y) * scale,
        width=rect.size.width * scale,
        height=rect.size.height * scale,
      ),
    )
  }
  @core.ViewLayoutResult::new(
    size~,
    child_frames=frames,
    child_frames_tight=true,
  )
}

///|
impl @core.ViewNode for StageLayout with fn semantics(_self) {
  // 透明组合：子控件的语义（按钮/输入框/勾选框…）直接对外暴露，
  // Agent/MCP 读到的就是舞台上的真实控件帧。
  @core.ViewSemanticsInfo::new(composition=Transparent)
}

///|
pub fn[Msg] stage_layout(
  children : Array[@moui.View[Msg]],
  rects : Array[@geometry.Rect],
) -> @moui.View[Msg] {
  // 控件套**产品主题**（导出应用的真实外观，浅色）：设计/运行舞台共用
  // 这一个构造点，所以「设计所见 = 运行所见 = 导出应用所见」由构造保证。
  // 舞台外的 IDE 覆盖层（选中描边/参考线/手柄）不受影响——它们是 IDE 的
  // chrome，不是产品 UI。
  @core.View::from_node(StageLayout::{ rects, }, children=_node => children).theme(
    studio_product_theme(),
  )
}

///|
/// 「适应窗口」比例：min(可用宽/设计宽, 可用高/设计高)，钳在 [0.5, 1]。
/// 上限 1 是不放大——设计稿 640×480 在宽窗格里保持原尺寸（放大只会让
/// 像素发虚）；下限 0.5 保证再窄也还能看清内容。
pub fn fit_scale(
  avail_width : Double,
  avail_height : Double,
  design_w : Double,
  design_h : Double,
) -> Double {
  if avail_width <= 0.0 ||
    avail_height <= 0.0 ||
    design_w <= 0.0 ||
    design_h <= 0.0 {
    1.0
  } else {
    (avail_width / design_w).min(avail_height / design_h).max(0.5).min(1.0)
  }
}
