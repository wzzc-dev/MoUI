///|
/// Concrete view node for the `divider` control.
///
/// A thin hairline rule used to separate sections of content. Horizontal
/// dividers fill the available width and are `thickness` tall; vertical
/// dividers fill the available height and are `thickness` wide. The color
/// tracks the theme outline so dividers stay calm against the surfaces and
/// respect dark mode.
///
/// Dividers use `outline_variant` (Fluent 2 colorNeutralStroke2, the subtle
/// divider tier) rather than the stronger `outline` (colorNeutralStroke1) so
/// hairlines stay calm against the surfaces.
priv struct DividerViewNode {
  axis : @core.Axis
  thickness : Double
  color : @core.Color
  inset : Double
}

///|
impl @core.ViewNode for DividerViewNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Divider")
}

///|
impl @core.ViewNode for DividerViewNode with fn revision(self) {
  // Capture every paint-affecting field (axis, thickness, color, inset) so
  // the runtime reconcile path does not reuse a stale RenderNode when only
  // the color or the inset changed.
  // `Axis` and `Color` do not implement `Show`; emit stable fingerprint
  // tokens (axis label + rounded RGBA) so reconcile detects axis/color
  // changes without relying on a Show instance.
  let axis_token = match self.axis {
    @core.Axis::Horizontal => "h"
    @core.Axis::Vertical => "v"
  }
  let color_token = "\{round4(self.color.r)},\{round4(self.color.g)},\{round4(self.color.b)},\{round4(self.color.a)}"
  "divider:\{axis_token}:\{self.thickness}:\{color_token}:\{self.inset}"
}

///|
impl @core.ViewNode for DividerViewNode with fn layout(self, ctx) {
  let line_thickness = max_view_double(1.0, self.thickness)
  let size = match self.axis {
    @core.Axis::Horizontal =>
      @core.Size::new(
        width=if ctx.constraints.max.width < 1.0e8 {
          ctx.constraints.max.width
        } else {
          line_thickness
        },
        height=line_thickness,
      )
    @core.Axis::Vertical =>
      @core.Size::new(
        width=line_thickness,
        height=if ctx.constraints.max.height < 1.0e8 {
          ctx.constraints.max.height
        } else {
          line_thickness
        },
      )
  }
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
}

///|
impl @core.ViewNode for DividerViewNode with fn paint(self, ctx) {
  let frame = ctx.frame
  let rect = if self.inset > 0.0 {
    match self.axis {
      @core.Axis::Horizontal =>
        @core.Rect::new(
          x=frame.origin.x + self.inset,
          y=frame.origin.y,
          width=max_view_double(0.0, frame.size.width - self.inset * 2.0),
          height=frame.size.height,
        )
      @core.Axis::Vertical =>
        @core.Rect::new(
          x=frame.origin.x,
          y=frame.origin.y + self.inset,
          width=frame.size.width,
          height=max_view_double(0.0, frame.size.height - self.inset * 2.0),
        )
    }
  } else {
    frame
  }
  @core.ViewPaintPlan::commands([
    @core.DrawCommand::FillRect(rect, self.color),
  ])
}

///|
impl @core.ViewNode for DividerViewNode with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::Group,
    label="Divider",
  )
}

///|
pub fn[Msg] divider(
  axis? : @core.Axis = @core.Axis::Horizontal,
  theme? : @core.Theme,
  thickness? : Double = 1.0,
  color? : @core.Color,
  inset? : Double = 0.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let line_color = match color {
    Some(value) => value
    None => resolved_theme.palette.outline_variant
  }
  @core.View::from_node(
    DividerViewNode::{ axis, thickness, color: line_color, inset },
  )
}
