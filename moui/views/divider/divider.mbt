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
priv struct Divider {
  axis : @core.Axis
  thickness : Double
  color : @core.Color?
  inset : Double
}

///|
impl @core.ViewNode for Divider with fn identity(_self) {
  @core.ViewIdentity::new(kind="Divider")
}

///|
impl @core.ViewNode for Divider with fn declaration(self) {
  let axis = @core.DeclarationKey::int(
    match self.axis {
      Horizontal => 0
      Vertical => 1
    },
  )
  @common.view_declaration(
    layout=@common.view_exact_channel(
      @common.view_record_key("Divider.layout", [
        ("axis", axis),
        ("thickness", @core.DeclarationKey::double(self.thickness)),
      ]),
    ),
    paint=@common.view_exact_channel(
      @common.view_record_key("Divider.paint", [
        ("axis", axis),
        (
          "color",
          match self.color {
            Some(value) => @common.view_color_key(value)
            None => @core.DeclarationKey::string("ambient")
          },
        ),
        ("inset", @core.DeclarationKey::double(self.inset)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for Divider with fn layout(self, ctx) {
  let line_thickness = @common.max_view_double(1.0, self.thickness)
  let size = match self.axis {
    Horizontal =>
      @core.Size::new(
        width=if ctx.constraints.max.width < 1.0e8 {
          ctx.constraints.max.width
        } else {
          line_thickness
        },
        height=line_thickness,
      )
    Vertical =>
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
impl @core.ViewNode for Divider with fn paint(self, ctx) {
  // 未显式钉色的分隔线在 paint 期取环境主题的 outline_variant,
  // 与 button/text 同约定:`.theme()` 子树即时生效。
  let line_color = self.color.unwrap_or(
    ctx.environment.theme.palette.outline_variant,
  )
  let frame = ctx.frame
  let rect = if self.inset > 0.0 {
    match self.axis {
      Horizontal =>
        @core.Rect::new(
          x=frame.origin.x + self.inset,
          y=frame.origin.y,
          width=@common.max_view_double(
            0.0,
            frame.size.width - self.inset * 2.0,
          ),
          height=frame.size.height,
        )
      Vertical =>
        @core.Rect::new(
          x=frame.origin.x,
          y=frame.origin.y + self.inset,
          width=frame.size.width,
          height=@common.max_view_double(
            0.0,
            frame.size.height - self.inset * 2.0,
          ),
        )
    }
  } else {
    frame
  }
  @core.ViewPaintPlan::commands([FillRect(rect, line_color)])
}

///|
impl @core.ViewNode for Divider with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(composition=Boundary, role=Separator)
}

///|
pub fn[Msg] divider(
  axis? : @core.Axis = Horizontal,
  theme? : @core.Theme,
  thickness? : Double = 1.0,
  color? : @core.Color,
  inset? : Double = 0.0,
) -> @core.View[Msg] {
  // 显式 color/theme 钉死取色;两者都缺省时保持 None,绘制期从
  // 环境主题解析 outline_variant(`.theme()` 子树即时生效)。
  let line_color : @core.Color? = match (color, theme) {
    (Some(value), _) => Some(value)
    (None, Some(t)) => Some(t.palette.outline_variant)
    (None, None) => None
  }
  @core.View::from_node(Divider::{ axis, thickness, color: line_color, inset, })
}
