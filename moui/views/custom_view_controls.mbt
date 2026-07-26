///|
fn[Msg] custom_control(
  kind? : String = "Custom",
  key? : String? = None,
  measure~ : (@core.ViewLayoutContext) -> @core.ViewLayoutResult,
  paint? : (@core.ViewPaintContext) -> @core.ViewPaintPlan = _ctx => {
    @core.ViewPaintPlan::empty()
  },
  event? : (@core.ViewEventContext) -> @core.ViewEventResult[Msg] = _ctx => {
    @core.ViewEventResult::ignored()
  },
  semantics? : () -> @core.ViewSemanticsInfo = () => {
    @core.ViewSemanticsInfo::new()
  },
  focusable? : Bool = false,
  revision? : () -> String = () => "",
) -> @core.View[Msg] {
  @core.View::from_node(
    CustomControlNode::{
      kind,
      key,
      measure,
      paint,
      semantics,
      focusable,
      revision,
    },
    event=(_node, ctx) => event(ctx),
  )
}

///|
priv struct CustomControlNode {
  kind : String
  key : String?
  measure : (@core.ViewLayoutContext) -> @core.ViewLayoutResult
  paint : (@core.ViewPaintContext) -> @core.ViewPaintPlan
  semantics : () -> @core.ViewSemanticsInfo
  focusable : Bool
  revision : () -> String
}

///|
impl @core.ViewNode for CustomControlNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for CustomControlNode with fn revision(self) {
  (self.revision)()
}

///|
impl @core.ViewNode for CustomControlNode with fn layout(self, context) {
  (self.measure)(context)
}

///|
impl @core.ViewNode for CustomControlNode with fn paint(self, context) {
  (self.paint)(context)
}

///|
impl @core.ViewNode for CustomControlNode with fn semantics(self) {
  (self.semantics)()
}

///|
impl @core.ViewNode for CustomControlNode with fn focusable(self) {
  self.focusable
}

///|
fn[Msg] custom_children_layout_control(
  children~ : Array[@core.View[Msg]],
  measure~ : (@core.CustomLayoutContext) -> @core.Size,
  place~ : (@core.CustomPlacementContext) -> Array[@core.Rect],
  paint~ : (PaintContext, @core.Rect) -> Unit,
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
  kind? : String = "CustomLayout",
  key? : String? = None,
) -> @core.View[Msg] {
  let cache = @core.CustomLayoutCache::new()
  @core.View::from_node(
    CustomChildrenLayoutNode::{
      measure,
      place,
      paint,
      semantics_role,
      semantics_label,
      kind,
      key,
      cache,
    },
    children=_node => children,
  )
}

///|
priv struct CustomChildrenLayoutNode {
  measure : (@core.CustomLayoutContext) -> @core.Size
  place : (@core.CustomPlacementContext) -> Array[@core.Rect]
  paint : (PaintContext, @core.Rect) -> Unit
  semantics_role : @core.SemanticsRole
  semantics_label : String
  kind : String
  key : String?
  cache : @core.CustomLayoutCache
}

///|
impl @core.ViewNode for CustomChildrenLayoutNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for CustomChildrenLayoutNode with fn layout(self, ctx) {
  let cache_key = custom_layout_cache_key(ctx.child_sizes)
  let child_baselines = custom_layout_default_baselines(ctx.child_sizes)
  let context = @core.CustomLayoutContext::{
    constraints: ctx.constraints,
    child_sizes: ctx.child_sizes,
    child_baselines,
    child_priorities: custom_layout_default_priorities(ctx.child_sizes),
    child_alignment_guides: custom_layout_alignment_guides(
      ctx.child_sizes,
      child_baselines,
    ),
    cache: self.cache,
    cache_key,
    layout_direction: @core.LayoutDirection::LeftToRight,
    safe_area: @core.Insets::symmetric(),
    viewport: None,
  }
  let size = (self.measure)(context)
  let absolute_frame = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=size.width,
    height=size.height,
  )
  let placement_context = @core.CustomPlacementContext::{
    frame: absolute_frame,
    measured_size: size,
    child_sizes: ctx.child_sizes,
    child_baselines,
    child_priorities: custom_layout_default_priorities(ctx.child_sizes),
    child_alignment_guides: custom_layout_alignment_guides(
      ctx.child_sizes,
      child_baselines,
    ),
    cache: self.cache,
    cache_key,
    layout_direction: @core.LayoutDirection::LeftToRight,
    safe_area: @core.Insets::symmetric(),
    viewport: Some(size),
  }
  @core.ViewLayoutResult::new(
    size~,
    child_frames=(self.place)(placement_context).map(frame => {
      @core.Rect::new(
        x=frame.origin.x - absolute_frame.origin.x,
        y=frame.origin.y - absolute_frame.origin.y,
        width=frame.size.width,
        height=frame.size.height,
      )
    }),
  )
}

///|
impl @core.ViewNode for CustomChildrenLayoutNode with fn paint(self, ctx) {
  let pctx = PaintContext::new()
  (self.paint)(pctx, ctx.frame)
  @core.ViewPaintPlan::commands(PaintContext::finish(pctx))
}

///|
impl @core.ViewNode for CustomChildrenLayoutNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=self.semantics_role,
    label=self.semantics_label,
    value=self.semantics_label,
  )
}

///|
fn custom_layout_cache_key(sizes : Array[@core.Size]) -> String {
  let mut key = "view-custom-layout"
  for size in sizes {
    key = "\{key};\{size.width}x\{size.height}"
  }
  key
}

///|
fn custom_layout_default_baselines(sizes : Array[@core.Size]) -> Array[Double?] {
  sizes.map(size => Some(size.height * 0.8))
}

///|
fn custom_layout_default_priorities(sizes : Array[@core.Size]) -> Array[Double] {
  sizes.map(_size => 0.0)
}

///|
fn custom_layout_alignment_guides(
  sizes : Array[@core.Size],
  baselines : Array[Double?],
) -> Array[@core.AlignmentGuideSet] {
  let guides : Array[@core.AlignmentGuideSet] = []
  for index, size in sizes {
    let baseline = if index < baselines.length() {
      baselines[index]
    } else {
      None
    }
    guides.push(
      @core.AlignmentGuideSet::from_size(size, first_baseline=baseline),
    )
  }
  guides
}
