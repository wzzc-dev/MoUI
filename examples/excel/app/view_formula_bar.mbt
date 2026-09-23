///|
fn build_formula_bar(
  model : ExcelModel,
  theme : @moui.Theme,
) -> @moui.View[ExcelMsg] {
  let suggestions = build_autocomplete(model, theme)
  let preview = formula_preview(model)
  @views.container(
    @views.row(
      [
        @views.text_field(
          model.cell_ref_input,
          on_input=fn(v) { ExcelMsg::CellRefChanged(v) },
          on_submit=Some(GoToCell(model.cell_ref_input)),
          variant=Plain,
          theme~,
          width=72.0,
          height=32.0,
        ).key("excel-cell-ref-input"),
        @views.text("fx", role=Label, theme~, width=24.0, height=32.0).foreground(
          theme.palette.muted,
        ),
        @views.column(
          [
            @views.text_field(
              model.edit_value,
              on_input=fn(v) { ExcelMsg::CellValueChanged(v) },
              on_submit=Some(CellEditCommittedAndNavigate(1, 0)),
              variant=Filled,
              theme~,
              width=760.0,
              height=32.0,
            ).key("excel-formula-input"),
            suggestions,
          ],
          spacing=0.0,
          align=Start,
        ),
        @views.text(preview, role=Mono, theme~, width=190.0, height=32.0).foreground(
          theme.palette.primary,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=Start,
    ),
    width=shell_width,
    variant=Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn build_autocomplete(
  model : ExcelModel,
  theme : @moui.Theme,
) -> @moui.View[ExcelMsg] {
  if model.autocomplete_suggestions.is_empty() {
    @views.empty()
  } else {
    let items : Array[@moui.View[ExcelMsg]] = []
    for i, suggestion in model.autocomplete_suggestions {
      let selected = i == model.autocomplete_index
      items.push(
        @views.container(
          @views.text(suggestion, role=Mono, theme~, width=220.0, height=26.0),
          width=236.0,
          height=28.0,
          variant=if selected { Raised } else { Base },
          theme~,
          padding=4.0,
        ).on_tap(AutocompleteSelect(i)),
      )
    }
    @views.container(
      @views.column(items, spacing=0.0, align=Start),
      width=236.0,
      variant=Overlay,
      theme~,
      padding=2.0,
    )
  }
}

///|
fn formula_preview(model : ExcelModel) -> String {
  if model.editing &&
    model.edit_value.length() > 0 &&
    model.edit_value[0] == '=' {
    let sheet = model.active_sheet()
    let value = @formula.evaluate(model.edit_value, ref_str => {
      match @cell.parse_ref(ref_str) {
        Some(addr) => sheet.get_cell(addr.row, addr.col).value
        None => Empty
      }
    })
    "= " + value.format_with(model.selected_format().num_format)
  } else {
    model.selected_cell().display()
  }
}
