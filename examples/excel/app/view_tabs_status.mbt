///|
fn build_sheet_tabs(
  model : ExcelModel,
  theme : @core.Theme,
) -> @moui.View[ExcelMsg] {
  let tabs : Array[@moui.View[ExcelMsg]] = []
  for i, name in model.sheet_names() {
    let active = i == model.workbook.active_sheet
    tabs.push(
      @views.container(
        @views.row(
          [
            @views.text(
              name,
              role=@views.TextRole::Label,
              theme~,
              width=112.0,
              height=28.0,
            ),
            if model.workbook.sheets.length() > 1 {
              @views.button(
                "x",
                on_click=ExcelMsg::DeleteSheet(i),
                variant=@views.ButtonVariant::Ghost,
                theme~,
                width=24.0,
                height=24.0,
              )
            } else {
              @views.empty()
            },
          ],
          spacing=0.0,
          align=@views.CrossAlign::Center,
        ),
        width=148.0,
        height=34.0,
        variant=if active {
          @views.ContainerVariant::Raised
        } else {
          @views.ContainerVariant::Base
        },
        theme~,
        padding=3.0,
      ).on_tap(ExcelMsg::SheetSelected(i)),
    )
  }
  tabs.push(
    @views.button(
      "+",
      on_click=ExcelMsg::AddSheet,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width=38.0,
      height=32.0,
    ),
  )
  @views.container(
    @views.row(tabs, spacing=0.0, align=@views.CrossAlign::Center),
    width=shell_width,
    height=40.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=3.0,
  )
}

///|
fn build_status_bar(
  model : ExcelModel,
  theme : @core.Theme,
) -> @moui.View[ExcelMsg] {
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
    @views.text(
      text,
      role=@views.TextRole::Caption,
      theme~,
      width=grid_width,
      height=24.0,
    ),
    width=shell_width,
    height=32.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn build_more_menu_overlay(theme : @core.Theme) -> @moui.View[ExcelMsg] {
  @views.container(
    @views.column(
      [
        context_menu_item("Cut", ContextMenuAction::Cut, theme),
        context_menu_item("Copy", ContextMenuAction::Copy, theme),
        context_menu_item("Paste", ContextMenuAction::Paste, theme),
        @views.divider(theme~),
        context_menu_item("Delete", ContextMenuAction::Delete, theme),
        @views.divider(theme~),
        context_menu_item(
          "Insert Row Above",
          ContextMenuAction::InsertRowAbove,
          theme,
        ),
        context_menu_item(
          "Insert Row Below",
          ContextMenuAction::InsertRowBelow,
          theme,
        ),
        context_menu_item(
          "Insert Column Left",
          ContextMenuAction::InsertColumnLeft,
          theme,
        ),
        context_menu_item(
          "Insert Column Right",
          ContextMenuAction::InsertColumnRight,
          theme,
        ),
        @views.divider(theme~),
        context_menu_item(
          "Clear Contents",
          ContextMenuAction::ClearContents,
          theme,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=190.0,
    variant=@views.ContainerVariant::Overlay,
    theme~,
    padding=4.0,
  )
}

///|
fn context_menu_item(
  label : String,
  action : ContextMenuAction,
  theme : @core.Theme,
) -> @moui.View[ExcelMsg] {
  @views.button(
    label,
    on_click=ExcelMsg::ContextMenuAction(action),
    variant=@views.ButtonVariant::Tonal,
    theme~,
    width=182.0,
    height=34.0,
  )
}
