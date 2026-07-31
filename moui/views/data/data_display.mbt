///|
pub fn[Msg] description_list(
  items : Array[DescriptionItem],
  theme? : @core.Theme,
  width? : Double = 360.0,
  term_width? : Double = 112.0,
  row_height? : Double = 30.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      row(
        [
          @text.text(
            item.term,
            role=@style.TextRole::Caption,
            theme=resolved_theme,
            width=term_width,
            height=row_height,
          ),
          @text.text(
            item.detail,
            role=@style.TextRole::Body,
            theme=resolved_theme,
            width=@common.view_max_double(
              80.0,
              width - term_width - resolved_theme.spacing_scale.sm,
            ),
            height=row_height,
          ),
        ],
        spacing=resolved_theme.spacing_scale.sm,
        align=@style.CrossAlign::Center,
      ),
    )
  }
  column(
    rows,
    spacing=resolved_theme.spacing_scale.xs,
    align=@style.CrossAlign::Start,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] detail_panel(
  title : String,
  items : Array[DescriptionItem],
  subtitle? : String = "",
  action? : @controls.StateViewAction[Msg]? = None,
  empty? : @core.View[Msg]? = None,
  theme? : @core.Theme,
  width? : Double = 280.0,
  height? : Double = 180.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let inner_width = @common.view_max_double(
    96.0,
    width - resolved_theme.spacing_scale.md * 2.0,
  )
  let rows : Array[@core.View[Msg]] = [
    @text.text(
      title,
      role=@style.TextRole::Control,
      theme=resolved_theme,
      width=inner_width,
      height=26.0,
    ),
  ]
  if subtitle != "" {
    rows.push(
      @text.text(
        subtitle,
        role=@style.TextRole::Caption,
        theme=resolved_theme,
        width=inner_width,
        height=22.0,
      ),
    )
  }
  if items.length() == 0 {
    match empty {
      Some(view) => rows.push(view)
      None =>
        rows.push(
          @text.text(
            "No detail selected",
            role=@style.TextRole::Caption,
            theme=resolved_theme,
            width=inner_width,
            height=28.0,
          ),
        )
    }
  } else {
    rows.push(
      description_list(
        items,
        theme=resolved_theme,
        width=inner_width,
        term_width=@common.view_min_double(104.0, inner_width * 0.42),
        row_height=28.0,
      ),
    )
  }
  match action {
    Some(action) =>
      rows.push(
        @button.button(
          action.label,
          on_click=action.message,
          variant=@style.ButtonVariant::Tonal,
          theme=resolved_theme,
          width=@common.view_min_double(148.0, inner_width),
          height=36.0,
        ),
      )
    None => ()
  }
  @container.container(
    column(
      rows,
      spacing=resolved_theme.spacing_scale.xs,
      align=@style.CrossAlign::Start,
    ),
    width~,
    height~,
    variant=@style.ContainerVariant::Raised,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label(title)
}
