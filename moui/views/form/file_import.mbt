///|
pub fn[Msg] drop_zone(
  title? : String = "Drop files here",
  message? : String = "",
  on_drop~ : (Array[String]) -> Msg,
  theme? : @core.Theme,
  width? : Double = 320.0,
  height? : Double = 104.0,
  enabled? : Bool = true,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let title_height = 28.0
  let message_height = if message == "" { 0.0 } else { 26.0 }
  let rows : Array[@core.View[Msg]] = [
    @text.text(
      title,
      role=@style.TextRole::Control,
      theme=resolved_theme,
      width=width - 32.0,
      height=title_height,
    ),
  ]
  if message != "" {
    rows.push(
      @text.text(
        message,
        role=@style.TextRole::Caption,
        theme=resolved_theme,
        width=width - 32.0,
        height=message_height,
      ),
    )
  }
  let zone = @container.container(
      @layout.column(
        rows,
        spacing=resolved_theme.spacing_scale.xs,
        align=@style.CrossAlign::Center,
      ),
      width~,
      height~,
      background=if enabled {
        resolved_theme.palette.surface_variant.multiply_alpha(0.54)
      } else {
        resolved_theme.palette.surface_variant.multiply_alpha(0.28)
      },
      corner_radius=resolved_theme.radius_scale.md,
      theme=resolved_theme,
      padding=resolved_theme.spacing_scale.md,
    )
    .border(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(
          if enabled {
            resolved_theme.palette.primary.multiply_alpha(0.58)
          } else {
            resolved_theme.palette.outline.multiply_alpha(0.46)
          },
        ),
        width=1.0,
      ),
    )
    .semantics_role(@core.SemanticsRole::Button)
    .semantics_description("File drop target")
    .disabled(disabled=!enabled)
  if enabled {
    zone.on_file_drop((paths, _point) => on_drop(paths))
  } else {
    zone
  }
}

///|
pub fn[Msg] file_import_panel(
  selection~ : FileSelection,
  on_drop~ : (Array[String]) -> Msg,
  on_browse? : Msg? = None,
  availability? : FileImportAvailability = FileImportAvailability::Available,
  title? : String = "Import files",
  drop_title? : String = "Drop files here",
  empty_message? : String = "No files selected",
  theme? : @core.Theme,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let enabled = availability is FileImportAvailability::Available
  let rows : Array[@core.View[Msg]] = [
    @text.text(
      title,
      role=@style.TextRole::Control,
      theme=resolved_theme,
      width=width - 32.0,
      height=28.0,
    ),
    drop_zone(
      title=drop_title,
      message=file_import_status_text(selection, availability, empty_message),
      on_drop~,
      theme=resolved_theme,
      width=width - 32.0,
      enabled~,
    ),
  ]
  match on_browse {
    Some(message) =>
      rows.push(
        @button.button(
          "Browse",
          on_click=message,
          variant=if enabled {
            @style.ButtonVariant::Primary
          } else {
            @style.ButtonVariant::Tonal
          },
          theme=resolved_theme,
          width=112.0,
          height=36.0,
        ).disabled(disabled=!enabled),
      )
    None => ()
  }
  let list = file_selection_list(
    selection,
    theme=resolved_theme,
    width=width - 32.0,
    empty_message~,
  )
  rows.push(list)
  @container.container(
    @layout.column(
      rows,
      spacing=resolved_theme.spacing_scale.sm,
      align=@style.CrossAlign::Start,
    ),
    width~,
    height=file_import_panel_height(selection, on_browse is Some(_)),
    variant=@style.ContainerVariant::Base,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_description("File import panel")
}

///|
fn file_import_status_text(
  selection : FileSelection,
  availability : FileImportAvailability,
  empty_message : String,
) -> String {
  match availability {
    Available => selection.summary(empty=empty_message)
    Pending => "Waiting for file picker"
    Unavailable(reason) => reason
  }
}

///|
fn[Msg] file_selection_list(
  selection : FileSelection,
  theme~ : @core.Theme,
  width~ : Double,
  empty_message~ : String,
) -> @core.View[Msg] {
  if selection.is_empty() {
    @text.text(
      empty_message,
      role=@style.TextRole::Caption,
      theme~,
      width~,
      height=24.0,
    )
  } else {
    let rows : Array[@core.View[Msg]] = []
    for path in selection.paths {
      rows.push(
        @text.text(
          path,
          role=@style.TextRole::Caption,
          theme~,
          width~,
          height=24.0,
        ),
      )
    }
    @layout.column(
      rows,
      spacing=theme.spacing_scale.xs,
      align=@style.CrossAlign::Start,
    )
  }
}

///|
fn file_import_panel_height(
  selection : FileSelection,
  has_browse : Bool,
) -> Double {
  let list_rows = if selection.is_empty() {
    1
  } else {
    selection.paths.length()
  }
  180.0 + (if has_browse { 44.0 } else { 0.0 }) + list_rows.to_double() * 28.0
}
