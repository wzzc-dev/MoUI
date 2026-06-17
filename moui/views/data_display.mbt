///|
pub fn[Msg] description_list(
  items : Array[DescriptionItem],
  theme? : @core.Theme = default_theme(),
  width? : Double = 360.0,
  term_width? : Double = 112.0,
  row_height? : Double = 30.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      row(
        [
          text(
            item.term,
            role=TextRole::Caption,
            theme~,
            width=term_width,
            height=row_height,
          ),
          text(
            item.detail,
            role=TextRole::Body,
            theme~,
            width=views_max_double(
              80.0,
              width - term_width - theme.spacing_scale.sm,
            ),
            height=row_height,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=CrossAlign::Center,
      ),
    )
  }
  column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn[Msg] detail_panel(
  title : String,
  items : Array[DescriptionItem],
  subtitle? : String = "",
  action? : StateViewAction[Msg]? = None,
  empty? : @core.View[Msg]? = None,
  theme? : @core.Theme = default_theme(),
  width? : Double = 280.0,
  height? : Double = 180.0,
) -> @core.View[Msg] {
  let inner_width = views_max_double(96.0, width - theme.spacing_scale.md * 2.0)
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=inner_width, height=26.0),
  ]
  if subtitle != "" {
    rows.push(
      text(
        subtitle,
        role=TextRole::Caption,
        theme~,
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
          text(
            "No detail selected",
            role=TextRole::Caption,
            theme~,
            width=inner_width,
            height=28.0,
          ),
        )
    }
  } else {
    rows.push(
      description_list(
        items,
        theme~,
        width=inner_width,
        term_width=views_min_double(104.0, inner_width * 0.42),
        row_height=28.0,
      ),
    )
  }
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Tonal,
          theme~,
          width=views_min_double(148.0, inner_width),
          height=36.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label(title)
}

///|
fn views_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}
