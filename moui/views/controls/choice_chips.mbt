///|
pub fn[Msg] chip(
  label : String,
  selected? : Bool = false,
  on_click? : Msg? = None,
  variant? : @style.ChipVariant = @style.ChipVariant::Soft,
  theme? : @core.Theme,
  width? : Double = 112.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let child = @text.text(
    label,
    role=@style.TextRole::Control,
    theme=resolved_theme,
    width=width - 18.0,
    height=height - 8.0,
  ).foreground(chip_foreground(selected, resolved_theme))
  let surfaced = @container.container(
    child,
    width~,
    height~,
    background=chip_background(selected, variant, resolved_theme),
    corner_radius=height / 2.0,
    padding=4.0,
  )
  let bordered = match chip_border(selected, variant, resolved_theme) {
    Some(border) => surfaced.border(border)
    None => surfaced
  }
  let base = bordered
    .semantics_role(@core.SemanticsRole::Button)
    .semantics_selected(selected~)
  match on_click {
    Some(message) => base.on_tap(message)
    None => base
  }
}

///|
pub fn[Msg] tag(
  label : String,
  theme? : @core.Theme,
  width? : Double = 96.0,
  height? : Double = 28.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  chip(
    label,
    selected=false,
    variant=@style.ChipVariant::Outline,
    theme=resolved_theme,
    width~,
    height~,
  ).semantics_role(@core.SemanticsRole::Text)
}

///|
pub fn[Msg] filter_chip(
  label : String,
  selected~ : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme,
  width? : Double = 120.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  chip(
    label,
    selected~,
    on_click=Some(on_change(!selected)),
    variant=@style.ChipVariant::Soft,
    theme=resolved_theme,
    width~,
    height~,
  )
}

///|
pub fn[Msg] choice_chip(
  label : String,
  selected~ : Bool,
  on_select~ : Msg,
  theme? : @core.Theme,
  width? : Double = 120.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  chip(
    label,
    selected~,
    on_click=Some(on_select),
    variant=@style.ChipVariant::Filled,
    theme=resolved_theme,
    width~,
    height~,
  )
}

///|
fn chip_foreground(selected : Bool, theme : @core.Theme) -> @core.Color {
  if selected {
    theme.palette.on_primary
  } else {
    theme.palette.foreground
  }
}

///|
fn chip_background(
  selected : Bool,
  variant : @style.ChipVariant,
  theme : @core.Theme,
) -> @core.Color {
  if selected {
    theme.palette.primary
  } else {
    match variant {
      @style.ChipVariant::Filled => theme.palette.surface_variant
      @style.ChipVariant::Outline => theme.palette.surface.multiply_alpha(0.1)
      @style.ChipVariant::Soft =>
        theme.palette.surface_variant.multiply_alpha(0.62)
    }
  }
}

///|
fn chip_border(
  selected : Bool,
  variant : @style.ChipVariant,
  theme : @core.Theme,
) -> @core.BorderStyle? {
  if selected || variant == @style.ChipVariant::Outline {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(
          if selected {
            theme.palette.primary
          } else {
            theme.palette.outline
          },
        ),
        width=1.0,
      ),
    )
  } else {
    None
  }
}
