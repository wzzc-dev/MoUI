///|
pub fn[Msg] padding_layout(
  child~ : @core.View[Msg],
  insets~ : @core.Insets,
  kind? : String = "Padding",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(PaddingLayout::{ insets, kind, key }, children=_node => {
    [child]
  })
}

///|
priv struct PaddingLayout {
  insets : @core.Insets
  kind : String
  key : String?
}

///|
impl @core.ViewNode for PaddingLayout with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for PaddingLayout with fn declaration(self) {
  @common.view_layout_declaration(@common.view_insets_key(self.insets))
}

///|
impl @core.ViewNode for PaddingLayout with fn child_constraints(
  self,
  constraints,
) {
  constraints.deflate(self.insets)
}

///|
impl @core.ViewNode for PaddingLayout with fn layout(self, ctx) {
  let child_size = first_child_size(ctx.child_sizes)
  let size = ctx.constraints.constrain(child_size.inflate(self.insets))
  // Clamp the child frame to the deflated available area so a greedy child
  // (e.g. web_view reporting max constraints) cannot overflow this node's
  // own frame in the place pass.
  let available = ctx.constraints.deflate(self.insets)
  @core.ViewLayoutResult::new(size~, child_frames=[
    @core.Rect::new(
      x=self.insets.left,
      y=self.insets.top,
      width=@common.view_min_double(
        @common.view_max_double(0.0, available.max.width),
        child_size.width,
      ),
      height=@common.view_min_double(
        @common.view_max_double(0.0, available.max.height),
        child_size.height,
      ),
    ),
  ])
}

///|
impl @core.ViewNode for PaddingLayout with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
pub fn[Msg] frame_layout(
  child~ : @core.View[Msg],
  width~ : Double?,
  height~ : Double?,
  min_width~ : Double?,
  min_height~ : Double?,
  max_width~ : Double?,
  max_height~ : Double?,
  kind? : String = "Frame",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    FrameLayout::{
      width,
      height,
      min_width,
      min_height,
      max_width,
      max_height,
      kind,
      key,
    },
    children=_node => [child],
  )
}

///|
priv struct FrameLayout {
  width : Double?
  height : Double?
  min_width : Double?
  min_height : Double?
  max_width : Double?
  max_height : Double?
  kind : String
  key : String?
}

///|
impl @core.ViewNode for FrameLayout with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for FrameLayout with fn declaration(self) {
  @common.view_layout_declaration(
    @common.view_record_key("FrameLayout", [
      ("width", @common.view_double_option_key(self.width)),
      ("height", @common.view_double_option_key(self.height)),
      ("min_width", @common.view_double_option_key(self.min_width)),
      ("min_height", @common.view_double_option_key(self.min_height)),
      ("max_width", @common.view_double_option_key(self.max_width)),
      ("max_height", @common.view_double_option_key(self.max_height)),
    ]),
  )
}

///|
impl @core.ViewNode for FrameLayout with fn child_constraints(self, constraints) {
  frame_constraints_for_measure(
    constraints,
    width=self.width,
    height=self.height,
  )
}

///|
impl @core.ViewNode for FrameLayout with fn layout(self, ctx) {
  let size = ctx.constraints.constrain(
    resolve_frame_size(
      first_child_size(ctx.child_sizes),
      width=self.width,
      height=self.height,
      min_width=self.min_width,
      min_height=self.min_height,
      max_width=self.max_width,
      max_height=self.max_height,
    ),
  )
  @core.ViewLayoutResult::new(size~, child_frames=[
    @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
  ])
}

///|
impl @core.ViewNode for FrameLayout with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
pub fn[Msg] container_box(
  child? : @core.View[Msg]? = None,
  size? : @core.Size? = None,
  background? : @core.Brush? = None,
  border? : @core.BorderStyle? = None,
  corner_radius? : Double = 0.0,
  shadow? : @core.ShadowStyle? = None,
  kind? : String = "Container",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    ContainerBox::{ size, background, border, corner_radius, shadow, kind, key },
    children=_node => {
      match child {
        Some(value) => [value]
        None => []
      }
    },
  )
}

///|
priv struct ContainerBox {
  size : @core.Size?
  background : @core.Brush?
  border : @core.BorderStyle?
  corner_radius : Double
  shadow : @core.ShadowStyle?
  kind : String
  key : String?
}

///|
impl @core.ViewNode for ContainerBox with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for ContainerBox with fn declaration(self) {
  @common.view_declaration(
    layout=@common.view_exact_channel(@common.view_size_option_key(self.size)),
    paint=@common.view_exact_channel(
      @common.view_record_key("ContainerBox.paint", [
        ("background", @common.view_brush_option_key(self.background)),
        ("border", @common.view_border_option_key(self.border)),
        ("corner_radius", @core.DeclarationKey::double(self.corner_radius)),
        ("shadow", @common.view_shadow_option_key(self.shadow)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for ContainerBox with fn layout(self, ctx) {
  let measured = match self.size {
    Some(value) => value
    None => first_child_size(ctx.child_sizes)
  }
  let measured = ctx.constraints.constrain(measured)
  let frames = if ctx.child_sizes.length() > 0 {
    let child_size = ctx.child_sizes[0]
    let x = @common.view_max_double(
      0.0,
      (measured.width - child_size.width) / 2.0,
    )
    let y = @common.view_max_double(
      0.0,
      (measured.height - child_size.height) / 2.0,
    )
    [@core.Rect::new(x~, y~, width=child_size.width, height=child_size.height)]
  } else {
    []
  }
  @core.ViewLayoutResult::new(size=measured, child_frames=frames)
}

///|
impl @core.ViewNode for ContainerBox with fn paint(self, ctx) {
  container_paint(
    ctx.frame,
    background=self.background,
    border=self.border,
    corner_radius=self.corner_radius,
    shadow=self.shadow,
    scheme=ctx.environment.color_scheme(),
  )
}

///|
impl @core.ViewNode for ContainerBox with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
pub fn[Msg] grid_layout(
  children~ : Array[@core.View[Msg]],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
  kind? : String = "Grid",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    GridLayout::{ columns, row_spacing, column_spacing, kind, key },
    children=_node => children,
  )
}

///|
priv struct GridLayout {
  columns : Int
  row_spacing : Double
  column_spacing : Double
  kind : String
  key : String?
}

///|
impl @core.ViewNode for GridLayout with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for GridLayout with fn declaration(self) {
  @common.view_layout_declaration(
    @common.view_record_key("GridLayout", [
      ("columns", @core.DeclarationKey::int(self.columns)),
      ("row_spacing", @core.DeclarationKey::double(self.row_spacing)),
      ("column_spacing", @core.DeclarationKey::double(self.column_spacing)),
    ]),
  )
}

///|
impl @core.ViewNode for GridLayout with fn layout(self, ctx) {
  let columns = @common.view_max_int(1, self.columns)
  let count = ctx.child_sizes.length()
  let rows = grid_row_count(count, columns)
  let mut cell_width = 0.0
  let mut cell_height = 0.0
  for size in ctx.child_sizes {
    cell_width = @common.view_max_double(cell_width, size.width)
    cell_height = @common.view_max_double(cell_height, size.height)
  }
  let measured = ctx.constraints.constrain(
    @core.Size::new(
      width=cell_width * columns.to_double() +
        self.column_spacing * @common.view_max_int(0, columns - 1).to_double(),
      height=cell_height * rows.to_double() +
        self.row_spacing * @common.view_max_int(0, rows - 1).to_double(),
    ),
  )
  let frames : Array[@core.Rect] = []
  for index, _size in ctx.child_sizes {
    let row = index / columns
    let column = index % columns
    frames.push(
      @core.Rect::new(
        x=column.to_double() * (cell_width + self.column_spacing),
        y=row.to_double() * (cell_height + self.row_spacing),
        width=cell_width,
        height=cell_height,
      ),
    )
  }
  @core.ViewLayoutResult::new(size=measured, child_frames=frames)
}

///|
impl @core.ViewNode for GridLayout with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
pub fn[Msg] list_layout(
  children~ : Array[@core.View[Msg]],
  spacing? : Double = 0.0,
  kind? : String = "List",
  key? : String? = None,
) -> @core.View[Msg] {
  let child_views : (ListLayout) -> Array[@core.View[Msg]] = _node => {
    let captured_children = children
    captured_children
  }
  @core.View::from_node(
    ListLayout::{ spacing, kind, key },
    children=child_views,
  )
}

///|
priv struct ListLayout {
  spacing : Double
  kind : String
  key : String?
}

///|
impl @core.ViewNode for ListLayout with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for ListLayout with fn declaration(self) {
  @common.view_layout_declaration(@core.DeclarationKey::double(self.spacing))
}

///|
impl @core.ViewNode for ListLayout with fn layout(self, ctx) {
  let mut width = 0.0
  let mut height = 0.0
  let frames : Array[@core.Rect] = []
  for index, size in ctx.child_sizes {
    if index > 0 {
      height = height + self.spacing
    }
    frames.push(
      @core.Rect::new(x=0.0, y=height, width=size.width, height=size.height),
    )
    width = @common.view_max_double(width, size.width)
    height = height + size.height
  }
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
    child_frames=frames,
  )
}

///|
impl @core.ViewNode for ListLayout with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
fn first_child_size(sizes : Array[@core.Size]) -> @core.Size {
  match sizes {
    [size, ..] => size
    [] => @core.Size::new(width=0.0, height=0.0)
  }
}

///|
fn frame_constraints_for_measure(
  constraints : @core.Constraints,
  width~ : Double?,
  height~ : Double?,
) -> @core.Constraints {
  match (width, height) {
    (Some(width), Some(height)) => constraints.tighten(width~, height~).loosen()
    (Some(width), None) => constraints.tighten(width~).loosen()
    (None, Some(height)) => constraints.tighten(height~).loosen()
    (None, None) => constraints.loosen()
  }
}

///|
fn resolve_frame_size(
  child : @core.Size,
  width~ : Double?,
  height~ : Double?,
  min_width~ : Double?,
  min_height~ : Double?,
  max_width~ : Double?,
  max_height~ : Double?,
) -> @core.Size {
  let width = width.unwrap_or(child.width)
  let height = height.unwrap_or(child.height)
  let min_width = min_width.unwrap_or(0.0)
  let min_height = min_height.unwrap_or(0.0)
  let max_width = max_width.unwrap_or(width)
  let max_height = max_height.unwrap_or(height)
  @core.Size::new(width~, height~).clamp({
    min: @core.Size::new(width=min_width, height=min_height),
    max: @core.Size::new(
      width=@common.view_max_double(min_width, max_width),
      height=@common.view_max_double(min_height, max_height),
    ),
  })
}

///|
fn container_paint(
  frame : @core.Rect,
  background~ : @core.Brush?,
  border~ : @core.BorderStyle?,
  corner_radius~ : Double,
  shadow~ : @core.ShadowStyle?,
  scheme~ : @core.ColorScheme,
) -> @core.ViewPaintPlan {
  let commands : Array[@core.DrawCommand] = []
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  @common.emit_elevation_shadow(commands, rounded, shadow, scheme)
  match background {
    Some(brush) =>
      commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, brush))
    None => ()
  }
  match border {
    Some(style) =>
      if style.width > 0.0 {
        commands.push(
          @core.DrawCommand::StrokeRoundedRectBrush(
            rounded,
            style.brush,
            style.width,
          ),
        )
      }
    None => ()
  }
  @core.ViewPaintPlan::commands(commands)
}

///|
fn grid_row_count(count : Int, columns : Int) -> Int {
  if count == 0 {
    0
  } else {
    (count + columns - 1) / columns
  }
}
