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
  // 舞台固定为设计坐标系尺寸（640×480）；父级 tight 帧与本征测量都得到
  // 同一尺寸，绘制/命中/语义帧三者天然一致。
  let size = ctx.constraints.constrain(
    @core.Size::new(width=design_width, height=design_height),
  )
  let frames : Array[@core.Rect] = []
  for rect in self.rects {
    frames.push(
      @core.Rect::new(
        x=rect.origin.x,
        y=rect.origin.y,
        width=rect.size.width,
        height=rect.size.height,
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
  children : Array[@core.View[Msg]],
  rects : Array[@geometry.Rect],
) -> @core.View[Msg] {
  @core.View::from_node(StageLayout::{ rects, }, children=_node => children)
}
