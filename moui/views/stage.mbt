///|
/// 坐标布局原语(M4):绝对定位舞台——`stage(width, height, [place(...)])`。
///
/// 模式来自 Studio 的 StageLayout(app 私有,此处为**公共化**版本):
/// MoUI 的放置管线会用「帧的 tight 约束」重排子树,所以只要把每个子视图
/// 的帧分配成设计矩形(乘 fit 缩放、居中),子控件就精确等于设计的尺寸
/// 与位置——这是 stack+offset 做不到的(stack 给每个子整帧,tight 重排会
/// 把单个控件拉伸成整帧)。子帧用 child_frames_tight 声明,子树按最终帧
/// 重新测量换行。
///
/// 用法:
/// ```moonbit
/// stage(640.0, 480.0, [
///   place(@views.button("确定"), x=280.0, y=180.0, width=80.0, height=36.0),
///   place(@views.text("标题"), x=40.0, y=20.0, width=200.0, height=24.0),
/// ])
/// ```
/// 设计者语义:x/y/width/height 是**坐标布局代码的字面量**,设计器据此
/// 做 span 补丁回写(拖拽 = 改字面量)。

///|
/// 一个被放置的子视图:视图 + 设计坐标矩形。
pub(all) struct Placed[Msg] {
  view : @core.View[Msg]
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
/// 把子视图放到设计坐标 (x, y),尺寸 (width, height)。
pub fn[Msg] place(
  view : @core.View[Msg],
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
) -> Placed[Msg] {
  { view, x, y, width, height, }
}

///|
/// 坐标舞台节点:按 fit 缩放 + 居中,给每个 place 分配最终帧。
priv struct StageNode {
  design_width : Double
  design_height : Double
  rects : Array[@core.Rect]
}

///|
impl @core.ViewNode for StageNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Stage")
}

///|
/// Layout cache key: `layout()` derives every child frame from the design size
/// and the placed rectangles, so all three fields participate in the layout
/// channel. The node itself paints nothing (children paint), so paint,
/// semantics and platform stay constant for a reused identity.
fn stage_layout_key(
  design_width : Double,
  design_height : Double,
  rects : Array[@core.Rect],
) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag="Stage.layout", fields=[
    ("design_width", @core.DeclarationKey::double(design_width)),
    ("design_height", @core.DeclarationKey::double(design_height)),
    (
      "rects",
      @core.DeclarationKey::array(
        rects.map(rect => {
          @core.DeclarationKey::record(type_tag="Rect", fields=[
            ("x", @core.DeclarationKey::double(rect.origin.x)),
            ("y", @core.DeclarationKey::double(rect.origin.y)),
            ("width", @core.DeclarationKey::double(rect.size.width)),
            ("height", @core.DeclarationKey::double(rect.size.height)),
          ])
        }),
      ),
    ),
  ])
}

///|
impl @core.ViewNode for StageNode with fn declaration(self) {
  @core.ViewDeclaration::channels(
    layout=Exact(
      stage_layout_key(self.design_width, self.design_height, self.rects),
    ),
    paint=Constant,
    semantics=Constant,
    platform=Constant,
  )
}

///|
impl @core.ViewNode for StageNode with fn layout(self, ctx) {
  let avail_w = ctx.constraints.max.width
  let avail_h = ctx.constraints.max.height
  // 适应比例:不放大(上限 1,放大只会让像素发虚);下限 0.5 保证窄窗格
  // 仍可读。与 Studio 设计舞台同一钳制口径。
  let scale = if avail_w <= 0.0 ||
    avail_h <= 0.0 ||
    self.design_width <= 0.0 ||
    self.design_height <= 0.0 {
    1.0
  } else {
    let sx = avail_w / self.design_width
    let sy = avail_h / self.design_height
    (if sx < sy { sx } else { sy }).clamp(min=0.5, max=1.0)
  }
  let ox = (avail_w - self.design_width * scale) / 2.0
  let oy = (avail_h - self.design_height * scale) / 2.0
  let size = ctx.constraints.constrain(
    @core.Size::new(width=avail_w, height=avail_h),
  )
  let frames : Array[@core.Rect] = []
  for rect in self.rects {
    frames.push(
      @core.Rect::new(
        x=ox + rect.origin.x * scale,
        y=oy + rect.origin.y * scale,
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
impl @core.ViewNode for StageNode with fn semantics(_self) {
  // 透明组合:子控件的语义(按钮/输入框/文本…)直接对外暴露——
  // 预览点选层读到的就是舞台上的真实控件帧。
  @core.ViewSemanticsInfo::new(composition=Transparent)
}

///|
/// 坐标舞台:place 数组 → 绝对定位视图。
pub fn[Msg] stage(
  width~ : Double,
  height~ : Double,
  placed : Array[Placed[Msg]],
) -> @core.View[Msg] {
  let rects : Array[@core.Rect] = []
  let children : Array[@core.View[Msg]] = []
  for item in placed {
    rects.push(
      @core.Rect::new(x=item.x, y=item.y, width=item.width, height=item.height),
    )
    children.push(item.view)
  }
  @core.View::from_node(
    StageNode::{ design_width: width, design_height: height, rects, },
    children=_node => children,
  )
}
