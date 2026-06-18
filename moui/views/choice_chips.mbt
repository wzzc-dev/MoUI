///|
pub fn[Msg] chip(
  label : String,
  selected? : Bool = false,
  on_click? : Msg? = None,
  variant? : ChipVariant = ChipVariant::Soft,
  theme? : @core.Theme = default_theme(),
  width? : Double = 112.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let child = text(
    label,
    role=TextRole::Control,
    theme~,
    width=width - 18.0,
    height=height - 8.0,
  ).foreground(chip_foreground(selected, theme))
  let surfaced = container(
    child,
    width~,
    height~,
    background=chip_background(selected, variant, theme),
    corner_radius=height / 2.0,
    padding=4.0,
  )
  let bordered = match chip_border(selected, variant, theme) {
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
  theme? : @core.Theme = default_theme(),
  width? : Double = 96.0,
  height? : Double = 28.0,
) -> @core.View[Msg] {
  chip(
    label,
    selected=false,
    variant=ChipVariant::Outline,
    theme~,
    width~,
    height~,
  ).semantics_role(@core.SemanticsRole::Text)
}

///|
pub fn[Msg] filter_chip(
  label : String,
  selected~ : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = default_theme(),
  width? : Double = 120.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  chip(
    label,
    selected~,
    on_click=Some(on_change(!selected)),
    variant=ChipVariant::Soft,
    theme~,
    width~,
    height~,
  )
}

///|
pub fn[Msg] choice_chip(
  label : String,
  selected~ : Bool,
  on_select~ : Msg,
  theme? : @core.Theme = default_theme(),
  width? : Double = 120.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  chip(
    label,
    selected~,
    on_click=Some(on_select),
    variant=ChipVariant::Filled,
    theme~,
    width~,
    height~,
  )
}

///|
fn chip_foreground(selected : Bool, theme : @core.Theme) -> @core.Color {
  if selected {
    theme.palette.primary_foreground
  } else {
    theme.palette.foreground
  }
}

///|
fn chip_background(
  selected : Bool,
  variant : ChipVariant,
  theme : @core.Theme,
) -> @core.Color {
  if selected {
    theme.palette.primary
  } else {
    match variant {
      Filled => theme.palette.surface_variant
      Outline => theme.palette.surface.multiply_alpha(0.1)
      Soft => theme.palette.surface_variant.multiply_alpha(0.62)
    }
  }
}

///|
fn chip_border(
  selected : Bool,
  variant : ChipVariant,
  theme : @core.Theme,
) -> @core.BorderStyle? {
  if selected || variant == ChipVariant::Outline {
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
