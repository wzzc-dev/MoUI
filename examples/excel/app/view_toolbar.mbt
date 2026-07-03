///|
using @moui {type Theme}

///|
fn build_toolbar(model : ExcelModel, theme : Theme) -> @moui.View[ExcelMsg] {
  let format = model.selected_format()
  let align_id = align_id(format.align)
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.text(
              "Excel - " + model.file_name,
              role=@views.TextRole::Title,
              theme~,
              width=220.0,
              height=30.0,
            ),
            @views.spacer(min_length=8.0, weight=1.0),
            tool_button(
              "New",
              ExcelMsg::NewWorkbook,
              theme,
              icon=Some(@views.IconName::FileNew),
              width=78.0,
            ),
            tool_button(
              "Open",
              ExcelMsg::FileOpenRequested,
              theme,
              icon=Some(@views.IconName::FolderOpen),
              width=84.0,
            ),
            tool_button(
              "Save",
              ExcelMsg::FileSaveRequested,
              theme,
              icon=Some(@views.IconName::Save),
              width=78.0,
            ),
            tool_button(
              "Demo",
              ExcelMsg::LoadDemo,
              theme,
              icon=Some(@views.IconName::Table),
              variant=@views.ButtonVariant::Primary,
              width=82.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        @views.row(
          [
            group_label("Edit", theme),
            tool_button("Cut", ExcelMsg::CutCells, theme, width=52.0),
            tool_button(
              "Copy",
              ExcelMsg::CopyCells,
              theme,
              icon=Some(@views.IconName::Clipboard),
              width=68.0,
            ),
            tool_button("Paste", ExcelMsg::PasteCells, theme, width=64.0),
            tool_button("Undo", ExcelMsg::Undo, theme, width=58.0),
            tool_button("Redo", ExcelMsg::Redo, theme, width=58.0),
            @views.divider(theme~),
            group_label("Format", theme),
            format_button(
              "B",
              ExcelMsg::ToggleBold,
              format.bold,
              theme,
              icon=Some(@views.IconName::Bold),
            ),
            format_button(
              "I",
              ExcelMsg::ToggleItalic,
              format.italic,
              theme,
              icon=Some(@views.IconName::Italic),
            ),
            format_button(
              "U",
              ExcelMsg::ToggleUnderline,
              format.underline,
              theme,
            ),
            @views.segmented_control(
              [
                @views.choice_item("left", "L"),
                @views.choice_item("center", "C"),
                @views.choice_item("right", "R"),
              ],
              selected=align_id,
              on_select=id => ExcelMsg::SetCellAlign(align_from_id(id)),
              size=@views.SegmentedControlSize::Compact,
              theme~,
              width=102.0,
            ),
            @views.divider(theme~),
            group_label("Number", theme),
            @views.picker(
              [
                @views.picker_item("general", "General"),
                @views.picker_item("currency", "Currency"),
                @views.picker_item("percent", "Percent"),
                @views.picker_item("fixed", "Fixed"),
              ],
              selected=number_format_id(format.num_format),
              on_select=id => ExcelMsg::SetCellFormat(number_format_from_id(id)),
              theme~,
            ),
            @views.divider(theme~),
            group_label("Color", theme),
            color_swatch("", ExcelMsg::SetCellBgColor(""), theme),
            color_swatch("dbeafe", ExcelMsg::SetCellBgColor("dbeafe"), theme),
            color_swatch("dcfce7", ExcelMsg::SetCellBgColor("dcfce7"), theme),
            color_swatch("fef3c7", ExcelMsg::SetCellBgColor("fef3c7"), theme),
            color_swatch("fde2e2", ExcelMsg::SetCellBgColor("fde2e2"), theme),
            @views.divider(theme~),
            @views.toggle(
              "Heat",
              model.heat_map,
              on_change=fn(_) { ExcelMsg::ToggleHeatMap },
              theme~,
            ),
            tool_button(
              "Clear",
              ExcelMsg::ClearCell,
              theme,
              icon=Some(@views.IconName::Trash),
              width=72.0,
            ),
            @views.menu_button(
              "More",
              on_click=ExcelMsg::ToggleContextMenu,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=64.0,
              height=32.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Stretch,
    ),
    width=shell_width,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn group_label(label : String, theme : Theme) -> @moui.View[ExcelMsg] {
  @views.text(
    label,
    role=@views.TextRole::Caption,
    theme~,
    width=48.0,
    height=24.0,
  ).foreground(theme.palette.muted)
}

///|
fn tool_button(
  label : String,
  msg : ExcelMsg,
  theme : Theme,
  icon? : @views.IconName? = None,
  variant? : @views.ButtonVariant = @views.ButtonVariant::Ghost,
  width? : Double = 64.0,
) -> @moui.View[ExcelMsg] {
  @views.tooltip(
    @views.button(
      label,
      on_click=msg,
      variant~,
      theme~,
      icon~,
      width~,
      height=32.0,
    ),
    label,
  )
}

///|
fn format_button(
  label : String,
  msg : ExcelMsg,
  active : Bool,
  theme : Theme,
  icon? : @views.IconName? = None,
) -> @moui.View[ExcelMsg] {
  @views.tooltip(
    @views.button(
      label,
      on_click=msg,
      variant=if active {
        @views.ButtonVariant::Tonal
      } else {
        @views.ButtonVariant::Ghost
      },
      theme~,
      icon~,
      width=34.0,
      height=32.0,
    ),
    label,
  )
}

///|
fn color_swatch(
  hex : String,
  msg : ExcelMsg,
  theme : Theme,
) -> @moui.View[ExcelMsg] {
  let bg = if hex.is_empty() {
    theme.palette.surface
  } else {
    parse_hex_color(hex).unwrap_or(theme.palette.surface_variant)
  }
  @views.container(
    @views.empty(),
    width=24.0,
    height=24.0,
    background=bg,
    corner_radius=4.0,
    theme~,
    padding=0.0,
  )
  .border(
    @moui.BorderStyle::new(
      brush=@moui.Brush::solid(theme.palette.outline),
      width=1.0,
    ),
  )
  .on_tap(msg)
}

///|
fn align_id(align : @cell.CellAlign) -> String {
  match align {
    @cell.CellAlign::Left => "left"
    @cell.CellAlign::Center => "center"
    @cell.CellAlign::Right => "right"
    @cell.CellAlign::Auto => "left"
  }
}

///|
fn align_from_id(id : String) -> @cell.CellAlign {
  match id {
    "center" => @cell.CellAlign::Center
    "right" => @cell.CellAlign::Right
    _ => @cell.CellAlign::Left
  }
}

///|
fn number_format_id(format : @cell.NumFormat) -> String {
  match format {
    @cell.NumFormat::Currency => "currency"
    @cell.NumFormat::Percent => "percent"
    @cell.NumFormat::Fixed => "fixed"
    @cell.NumFormat::General => "general"
  }
}

///|
fn number_format_from_id(id : String) -> @cell.NumFormat {
  match id {
    "currency" => @cell.NumFormat::Currency
    "percent" => @cell.NumFormat::Percent
    "fixed" => @cell.NumFormat::Fixed
    _ => @cell.NumFormat::General
  }
}
