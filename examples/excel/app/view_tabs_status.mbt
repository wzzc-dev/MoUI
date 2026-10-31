///|
fn build_sheet_tabs(model : ExcelModel) -> @moui.View[ExcelMsg] {
  let tabs : Array[@moui.View[ExcelMsg]] = []
  for i, name in model.sheet_names() {
    let active = i == model.workbook.active_sheet
    tabs.push(
      @views.container(
        @views.row(
          [
            @views.text(name, role=Label, width=112.0, height=28.0),
            if model.workbook.sheets.length() > 1 {
              @views.button(
                "x",
                on_click=ExcelMsg::DeleteSheet(i),
                variant=Ghost,
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
        padding=3.0,
      ).on_tap(SheetSelected(i)),
    )
  }
  tabs.push(
    @views.button(
      "+",
      on_click=AddSheet,
      variant=Ghost,
      width=38.0,
      height=32.0,
    ),
  )
  @views.container(
    @views.row(tabs, spacing=0.0, align=Center),
    width=shell_width,
    height=40.0,
    variant=Base,
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
    @views.text(text, role=Caption, width=grid_width, height=24.0),
    width=shell_width,
    height=32.0,
    variant=Base,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn build_more_menu_overlay() -> @moui.View[ExcelMsg] {
  @views.container(
    @views.column(
      [
        context_menu_item("Cut", Cut),
        context_menu_item("Copy", Copy),
        context_menu_item("Paste", Paste),
        @views.divider(),
        context_menu_item("Delete", Delete),
        @views.divider(),
        context_menu_item("Insert Row Above", InsertRowAbove),
        context_menu_item("Insert Row Below", InsertRowBelow),
        context_menu_item("Delete Row", DeleteRow),
        context_menu_item("Insert Column Left", InsertColumnLeft),
        context_menu_item("Insert Column Right", InsertColumnRight),
        context_menu_item("Delete Column", DeleteColumn),
        @views.divider(),
        context_menu_item("Sort A to Z", SortAscending),
        context_menu_item("Sort Z to A", SortDescending),
        @views.divider(),
        context_menu_item("Clear Contents", ClearContents),
      ],
      spacing=0.0,
      align=Stretch,
    ),
    width=190.0,
    variant=Overlay,
    padding=4.0,
  )
}

///|
fn context_menu_item(
  label : String,
  action : ContextMenuAction,
) -> @moui.View[ExcelMsg] {
  @views.button(
    label,
    on_click=ContextMenuAction(action),
    variant=Tonal,
    width=182.0,
    height=34.0,
  )
}
