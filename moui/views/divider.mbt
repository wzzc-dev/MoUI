///|
/// A thin hairline rule used to separate sections of content. Horizontal
/// dividers fill the available width and are `thickness` tall; vertical
/// dividers fill the available height and are `thickness` wide. The color
/// tracks the theme outline so dividers stay calm against the surfaces and
/// respect dark mode.
pub fn[Msg] divider(
  axis? : @core.Axis = @core.Axis::Horizontal,
  theme? : @core.Theme = default_theme(),
  thickness? : Double = 1.0,
  color? : @core.Color,
  inset? : Double = 0.0,
) -> @core.View[Msg] {
  let line_color = match color {
    Some(value) => value
    None =>
      match theme.scheme {
        @core.ColorScheme::Light => theme.palette.outline.multiply_alpha(0.6)
        @core.ColorScheme::Dark => theme.palette.outline.multiply_alpha(0.5)
      }
  }
  let line_thickness = max_view_double(1.0, thickness)
  custom_layout(
    measure=constraints => {
     match axis {
       @core.Axis::Horizontal =>
         constraints.constrain(
           @core.Size::new(
              width=if constraints.max.width < 1.0e8 {
               constraints.max.width
             } else {
               line_thickness
             },
             height=line_thickness,
           ),
         )
       @core.Axis::Vertical =>
         constraints.constrain(
           @core.Size::new(
             width=line_thickness,
              height=if constraints.max.height < 1.0e8 {
               constraints.max.height
             } else {
               line_thickness
             },
           ),
         )
     }
    },
    paint=frame => {
      let rect = if inset > 0.0 {
        match axis {
          @core.Axis::Horizontal =>
            @core.Rect::new(
              x=frame.origin.x + inset,
              y=frame.origin.y,
              width=max_view_double(0.0, frame.size.width - inset * 2.0),
              height=frame.size.height,
            )
          @core.Axis::Vertical =>
            @core.Rect::new(
              x=frame.origin.x,
              y=frame.origin.y + inset,
              width=frame.size.width,
              height=max_view_double(0.0, frame.size.height - inset * 2.0),
            )
        }
      } else {
        frame
      }
      [@core.DrawCommand::FillRect(rect, line_color)]
    },
    semantics_role=@core.SemanticsRole::Group,
    semantics_label="Divider",
  )
}
