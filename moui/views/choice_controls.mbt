///|
pub fn choice_item(id : String, label : String) -> ChoiceItem {
  { id, label }
}

///|
pub fn[Msg] radio_group(
  items : Array[ChoiceItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  spacing? : Double = @core.Theme::default().spacing_scale.sm,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      radio(
        item.label,
        item.id == selected,
        on_change=_value => on_select(item.id),
        foreground=theme.palette.foreground,
        check_color=theme.palette.primary,
      ),
    )
  }
  column(rows, spacing~, align=CrossAlign::Start).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] checkbox_group(
  items : Array[ChoiceItem],
  selected~ : Array[String],
  on_change~ : (String, Bool) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  spacing? : Double = @core.Theme::default().spacing_scale.sm,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    let checked = string_array_contains(selected, item.id)
    rows.push(
      checkbox(
        item.label,
        checked~,
        on_change=value => on_change(item.id, value),
        foreground=theme.palette.foreground,
        check_color=theme.palette.primary,
      ),
    )
  }
  column(rows, spacing~, align=CrossAlign::Start).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] segmented_control(
  items : Array[ChoiceItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  size? : SegmentedControlSize = SegmentedControlSize::Regular,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let height = match size {
    Compact => 32.0
    Regular => 40.0
  }
  let item_width = if items.length() == 0 {
    width
  } else {
    width / items.length().to_double()
  }
  let segments : Array[@core.View[Msg]] = []
  for item in items {
    let active = item.id == selected
    segments.push(
      button(
        item.label,
        on_click=on_select(item.id),
        variant=if active { ButtonVariant::Primary } else { ButtonVariant::Ghost },
        theme~,
        width=item_width,
        height~,
      ).semantics_role(@core.SemanticsRole::Tab),
    )
  }
  surface(
    row(segments, spacing=0.0, align=CrossAlign::Center),
    width~,
    height~,
    background=theme.palette.surface_variant.multiply_alpha(0.55),
    corner_radius=theme.radius_scale.md,
    padding=2.0,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] chip(
  label : String,
  selected? : Bool = false,
  on_click? : Msg? = None,
  variant? : ChipVariant = ChipVariant::Soft,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 112.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let child = text(label, role=TextRole::Control, theme~, width=width - 18.0, height=height - 8.0)
    .foreground(chip_foreground(selected, theme))
  let surfaced = surface(
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
  let base = bordered.semantics_role(@core.SemanticsRole::Button)
  match on_click {
    Some(message) => base.on_tap(message)
    None => base
  }
}

///|
pub fn[Msg] tag(
  label : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 96.0,
  height? : Double = 28.0,
) -> @core.View[Msg] {
  chip(label, selected=false, variant=ChipVariant::Outline, theme~, width~, height~)
  .semantics_role(@core.SemanticsRole::Text)
}

///|
pub fn[Msg] filter_chip(
  label : String,
  selected~ : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
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
  theme? : @core.Theme = @core.Theme::default(),
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
fn string_array_contains(items : Array[String], id : String) -> Bool {
  items.any(item => item == id)
}

///|
fn chip_foreground(selected : Bool, theme : @core.Theme) -> @core.Color {
  if selected { theme.palette.primary_foreground } else { theme.palette.foreground }
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
          if selected { theme.palette.primary } else { theme.palette.outline },
        ),
        width=1.0,
      ),
    )
  } else {
    None
  }
}
