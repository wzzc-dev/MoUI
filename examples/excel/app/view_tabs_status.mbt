///|
fn build_sheet_tabs(model : ExcelModel, theme : Theme) -> @moui.View[ExcelMsg] {
  let tabs : Array[@moui.View[ExcelMsg]] = []
  for i, name in model.sheet_names() {
    let active = i == model.workbook.active_sheet
    tabs.push(
      @views.container(
        @views.row(
          [
            @views.text(name, role=Label, theme~, width=112.0, height=28.0),
            if model.workbook.sheets.length() > 1 {
              @views.button(
                "x",
                on_click=ExcelMsg::DeleteSheet(i),
                variant=Ghost,
                theme~,
                width=24.0,
                height=24.0,
              )
            } else {
              @views.empty()
            },
          ],
          spacing=0.0,
          align=Center,
        ),
        width=148.0,
        height=34.0,
        variant=if active { Raised } else { Base },
        theme~,
        padding=3.0,
      ).on_tap(SheetSelected(i)),
    )
  }
  tabs.push(
    @views.button(
      "+",
      on_click=AddSheet,
      variant=Ghost,
      theme~,
      width=38.0,
      height=32.0,
    ),
  )
  @views.container(
    @views.row(tabs, spacing=0.0, align=Center),
    width=shell_width,
    height=40.0,
    variant=Base,
    theme~,
    padding=3.0,
  )
}

///|
fn build_status_bar(model : ExcelModel, theme : Theme) -> @moui.View[ExcelMsg] {
  let sheet = model.active_sheet()
  let selected = if model.selected_ref().is_empty() {
    "No cell"
  } else {
    model.selected_ref()
  }
  let value = model.selected_cell().display()
  let text = sheet.name +
    " | " +
    selected +
    ": " +
    value +
    " | " +
    sheet.used_cell_count().to_string() +
    " cells | " +
    sheet.col_count.to_string() +
    " x " +
    sheet.row_count.to_string() +
    " grid | " +
    model.status
  @views.container(
    @views.text(text, role=Caption, theme~, width=grid_width, height=24.0),
    width=shell_width,
    height=32.0,
    variant=Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn build_more_menu_overlay(theme : Theme) -> @moui.View[ExcelMsg] {
  @views.container(
    @views.column(
      [
        context_menu_item("Cut", Cut, theme),
        context_menu_item("Copy", Copy, theme),
        context_menu_item("Paste", Paste, theme),
        @views.divider(theme~),
        context_menu_item("Delete", Delete, theme),
        @views.divider(theme~),
        context_menu_item("Insert Row Above", InsertRowAbove, theme),
        context_menu_item("Insert Row Below", InsertRowBelow, theme),
        context_menu_item("Delete Row", DeleteRow, theme),
        context_menu_item("Insert Column Left", InsertColumnLeft, theme),
        context_menu_item("Insert Column Right", InsertColumnRight, theme),
        context_menu_item("Delete Column", DeleteColumn, theme),
        @views.divider(theme~),
        context_menu_item("Sort A to Z", SortAscending, theme),
        context_menu_item("Sort Z to A", SortDescending, theme),
        @views.divider(theme~),
        context_menu_item("Clear Contents", ClearContents, theme),
      ],
      spacing=0.0,
      align=Stretch,
    ),
    width=190.0,
    variant=Overlay,
    theme~,
    padding=4.0,
  )
}

///|
fn context_menu_item(
  label : String,
  action : ContextMenuAction,
  theme : Theme,
) -> @moui.View[ExcelMsg] {
  @views.button(
    label,
    on_click=ContextMenuAction(action),
    variant=Tonal,
    theme~,
    width=182.0,
    height=34.0,
  )
}
