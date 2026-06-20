///|
pub fn[Msg] avatar(
  label : String,
  image? : String? = None,
  theme? : @core.Theme,
  size? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  match image {
    Some(source) =>
      @core.View::node(
        identity=() => @core.ViewIdentity::new(kind="Image"),
        revision=() => "avatar-image:\{source}:\{size}",
        layout=ctx => {
          @core.ViewLayoutResult::new(
            size=ctx.constraints.constrain(
              @core.Size::new(width=size, height=size),
            ),
          )
        },
        paint=ctx => {
          @core.ViewPaintPlan::commands([
            @core.DrawCommand::DrawImage({
              source,
              frame: ctx.frame,
              opacity: 1.0,
              fit: @core.ImageFit::Contain,
            }),
          ])
        },
        semantics=() => {
          @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
        },
      )
      .corner_radius(size / 2.0)
      .clip()
      .accessibility_label(label)
    None =>
      container(
        text(
          avatar_initials(label),
          role=TextRole::Control,
          theme=resolved_theme,
          width=size - 10.0,
          height=size - 10.0,
        ).foreground(resolved_theme.palette.on_primary),
        width=size,
        height=size,
        background=resolved_theme.palette.primary,
        corner_radius=size / 2.0,
        padding=5.0,
      ).accessibility_label(label)
  }
}

///|
pub fn[Msg] avatar_group(
  labels : Array[String],
  theme? : @core.Theme,
  size? : Double = 36.0,
  max_visible? : Int = 4,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let visible = views_min_int(labels.length(), views_max_int(0, max_visible))
  let children : Array[@core.View[Msg]] = []
  for index in 0..<visible {
    children.push(
      avatar(labels[index], theme=resolved_theme, size~).key(
        "avatar-" + labels[index],
      ),
    )
  }
  let remaining = labels.length() - visible
  if remaining > 0 {
    children.push(
      container(
        text(
          "+\{remaining}",
          role=TextRole::Caption,
          theme=resolved_theme,
          width=size - 10.0,
          height=size - 10.0,
        ).foreground(resolved_theme.palette.foreground),
        width=size,
        height=size,
        background=resolved_theme.palette.surface_variant,
        corner_radius=size / 2.0,
        padding=5.0,
      ),
    )
  }
  row(children, spacing=0.0, align=CrossAlign::Center)
}

///|
fn avatar_initials(label : String) -> String {
  let chars = label.to_array()
  if chars.length() == 0 {
    "?"
  } else {
    chars[0].to_string()
  }
}
