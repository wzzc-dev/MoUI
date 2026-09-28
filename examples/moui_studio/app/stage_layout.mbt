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
  // 缩放从帧约束现算：min(帧宽/640, 帧高/480)。运行舞台（640×480 容器）
  // 得 1.0；设计舞台「适应窗口」随画布列等比、固定档位得 zoom——与
  // 背景/覆盖层画布的绘制比例同源，三层永不失配。无界约束（本征测量）
  // 退回 1.0。放置管线以帧 tight 约束重排子树，子控件精确等于缩放后的
  // 设计尺寸。
  let by_width = ctx.constraints.min.width / design_width
  let by_height = ctx.constraints.min.height / design_height
  let scale = if by_width > 0.0 &&
    by_width < 1.0e8 &&
    by_height > 0.0 &&
    by_height < 1.0e8 {
    by_width.min(by_height)
  } else {
    1.0
  }
  let size = ctx.constraints.constrain(
    @core.Size::new(
      width=design_width * scale,
      height=design_height * scale,
    ),
  )
  let frames : Array[@core.Rect] = []
  for rect in self.rects {
    frames.push(
      @core.Rect::new(
        x=rect.origin.x * scale,
        y=rect.origin.y * scale,
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
  @core.View::from_node(StageLayout::{ rects, }, children=_node => children)
}
