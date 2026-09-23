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
              role=Title,
              theme~,
              width=220.0,
              height=30.0,
            ),
            @views.spacer(min_length=8.0, weight=1.0),
            tool_button(
              "New",
              NewWorkbook,
              theme,
              icon=Some(FileNew),
              width=78.0,
            ),
            tool_button(
              "Open",
              FileOpenRequested,
              theme,
              icon=Some(FolderOpen),
              width=84.0,
            ),
            tool_button(
              "Save",
              FileSaveRequested,
              theme,
              icon=Some(Save),
              width=78.0,
            ),
            tool_button(
              "Demo",
              LoadDemo,
              theme,
              icon=Some(Table),
              variant=Primary,
              width=82.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=Center,
        ),
        @views.row(
          [
            group_label("Edit", theme),
            tool_button("Cut", CutCells, theme, width=52.0),
            tool_button(
              "Copy",
              CopyCells,
              theme,
              icon=Some(Clipboard),
              width=68.0,
            ),
            tool_button("Paste", PasteCells, theme, width=64.0),
            tool_button("Undo", Undo, theme, width=58.0),
            tool_button("Redo", Redo, theme, width=58.0),
            @views.divider(theme~),
            group_label("Format", theme),
            format_button("B", ToggleBold, format.bold, theme, icon=Some(Bold)),
            format_button(
              "I",
              ToggleItalic,
              format.italic,
              theme,
              icon=Some(Italic),
            ),
            format_button("U", ToggleUnderline, format.underline, theme),
            @views.segmented_control(
              [
                @views.choice_item("left", "L"),
                @views.choice_item("center", "C"),
                @views.choice_item("right", "R"),
              ],
              selected=align_id,
              on_select=id => SetCellAlign(align_from_id(id)),
              size=Compact,
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
              on_select=id => SetCellFormat(number_format_from_id(id)),
              theme~,
            ),
            @views.divider(theme~),
            group_label("Color", theme),
            color_swatch("", SetCellBgColor(""), theme),
            color_swatch("dbeafe", SetCellBgColor("dbeafe"), theme),
            color_swatch("dcfce7", SetCellBgColor("dcfce7"), theme),
            color_swatch("fef3c7", SetCellBgColor("fef3c7"), theme),
            color_swatch("fde2e2", SetCellBgColor("fde2e2"), theme),
            @views.divider(theme~),
            group_label("Sort", theme),
            tool_button("A→Z", SortAscending, theme, width=56.0),
            tool_button("Z→A", SortDescending, theme, width=56.0),
            @views.divider(theme~),
            @views.toggle(
              "Heat",
              model.heat_map,
              on_change=fn(_) { ToggleHeatMap },
              theme~,
            ),
            tool_button("Clear", ClearCell, theme, icon=Some(Trash), width=72.0),
            @views.menu_button(
              "More",
              on_click=ToggleContextMenu,
              variant=Ghost,
              theme~,
              width=64.0,
              height=32.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=Center,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=Stretch,
    ),
    width=shell_width,
    variant=Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn group_label(label : String, theme : Theme) -> @moui.View[ExcelMsg] {
  @views.text(label, role=Caption, theme~, width=48.0, height=24.0).foreground(
    theme.palette.muted,
  )
}

///|
fn tool_button(
  label : String,
  msg : ExcelMsg,
  theme : Theme,
  icon? : @views.IconName? = None,
  variant? : @views.ButtonVariant = Ghost,
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
      variant=if active { Tonal } else { Ghost },
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
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
      width=1.0,
    ),
  )
  .on_tap(msg)
}

///|
fn align_id(align : @cell.CellAlign) -> String {
  match align {
    Left => "left"
    Center => "center"
    Right => "right"
    Auto => "left"
  }
}

///|
fn align_from_id(id : String) -> @cell.CellAlign {
  match id {
    "center" => Center
    "right" => Right
    _ => Left
  }
}

///|
fn number_format_id(format : @cell.NumFormat) -> String {
  match format {
    Currency => "currency"
    Percent => "percent"
    Fixed => "fixed"
    General => "general"
  }
}

///|
fn number_format_from_id(id : String) -> @cell.NumFormat {
  match id {
    "currency" => Currency
    "percent" => Percent
    "fixed" => Fixed
    _ => General
  }
}
