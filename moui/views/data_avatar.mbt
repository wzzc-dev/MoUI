///|
pub fn[Msg] avatar(
  label : String,
  image? : String? = None,
  theme? : @core.Theme = @core.Theme::default(),
  size? : Double = 40.0,
) -> @core.View[Msg] {
  match image {
    Some(source) =>
      @core.View::primitive_image_view(
        source~,
        size=Some(@core.Size::new(width=size, height=size)),
      )
      .corner_radius(size / 2.0)
      .clip()
      .accessibility_label(label)
    None =>
      surface(
        text(
          avatar_initials(label),
          role=TextRole::Control,
          theme~,
          width=size - 10.0,
          height=size - 10.0,
        ).foreground(theme.palette.primary_foreground),
        width=size,
        height=size,
        background=theme.palette.primary,
        corner_radius=size / 2.0,
        padding=5.0,
      ).accessibility_label(label)
  }
}

///|
pub fn[Msg] avatar_group(
  labels : Array[String],
  theme? : @core.Theme = @core.Theme::default(),
  size? : Double = 36.0,
  max_visible? : Int = 4,
) -> @core.View[Msg] {
  let visible = views_min_int(labels.length(), views_max_int(0, max_visible))
  let children : Array[@core.View[Msg]] = []
  for index in 0..<visible {
    children.push(
      avatar(labels[index], theme~, size~).key("avatar-" + labels[index]),
    )
  }
  let remaining = labels.length() - visible
  if remaining > 0 {
    children.push(
      surface(
        text(
          "+\{remaining}",
          role=TextRole::Caption,
          theme~,
          width=size - 10.0,
          height=size - 10.0,
        ).foreground(theme.palette.foreground),
        width=size,
        height=size,
        background=theme.palette.surface_variant,
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
