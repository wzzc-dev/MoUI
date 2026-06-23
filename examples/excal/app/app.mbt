///|
using @views {
  button,
  column,
  container,
  divider,
  row,
  scroll_view,
  table,
  table_column,
  tab_view,
  text,
  text_field,
  type TabItem,
}

///|
pub(all) struct ExcalApp {
  unit : Unit
}

///|
pub(all) struct ExcalModel {
  workbook : @xlsx.Workbook
  sheet_names : Array[String]
  active_sheet : Int
  headers : Array[String]
  rows : Array[Array[String]]
  selected_cell : Option[(Int, Int)]
  editing : Bool
  edit_value : String
  file_name : String
  status : String
}

///|
pub(all) enum ExcalMsg {
  SheetSelected(Int)
  CellSelected(Int, Int)
  CellEditStarted
  CellValueChanged(String)
  CellEditCommitted
  CellEditCancelled
  NewWorkbook
  LoadDemo
}

///|
pub fn ExcalApp::new() -> ExcalApp {
  { unit: () }
}

///|
pub fn ExcalModel::new() -> ExcalModel {
  let wb = @mbtexcel.new_file()
  let names = sheet_names_of(wb)
  let data = load_sheet_data(wb, names[0])
  {
    workbook: wb,
    sheet_names: names,
    active_sheet: 0,
    headers: data.0,
    rows: data.1,
    selected_cell: None,
    editing: false,
    edit_value: "",
    file_name: "Untitled",
    status: "Ready",
  }
}

///|
pub fn sheet_names_of(wb : @xlsx.Workbook) -> Array[String] {
  wb.get_sheet_list()
}

///|
pub fn load_sheet_data(
  wb : @xlsx.Workbook,
  name : String,
) -> (Array[String], Array[Array[String]]) {
  match wb.sheet(name) {
    None => ([], [])
    Some(sheet) =>
      {
        let all_rows = sheet.get_rows()
        if all_rows.is_empty() {
          ([], [])
        } else {
          let headers = all_rows[0]
          let data_rows : Array[Array[String]] = []
          for i = 1; i < all_rows.length(); i = i + 1 {
            data_rows.push(all_rows[i])
          }
          (headers, data_rows)
        }
      }
  }
}

///|
pub fn ExcalModel::with_demo_data() -> ExcalModel {
  let wb = @mbtexcel.new_workbook()
  ignore(try! wb.add_sheet("Sales"))
  // Row 0: headers
  try! wb.set_cell("Sales", "A1", "Product")
  try! wb.set_cell("Sales", "B1", "Q1")
  try! wb.set_cell("Sales", "C1", "Q2")
  try! wb.set_cell("Sales", "D1", "Q3")
  try! wb.set_cell("Sales", "E1", "Q4")
  try! wb.set_cell("Sales", "F1", "Total")
  // Row 1-5: data
  try! wb.set_cell("Sales", "A2", "Widget A")
  try! wb.set_cell("Sales", "B2", "1200")
  try! wb.set_cell("Sales", "C2", "1350")
  try! wb.set_cell("Sales", "D2", "1420")
  try! wb.set_cell("Sales", "E2", "1580")
  try! wb.set_cell("Sales", "F2", "5550")
  try! wb.set_cell("Sales", "A3", "Widget B")
  try! wb.set_cell("Sales", "B3", "800")
  try! wb.set_cell("Sales", "C3", "920")
  try! wb.set_cell("Sales", "D3", "1100")
  try! wb.set_cell("Sales", "E3", "980")
  try! wb.set_cell("Sales", "F3", "3800")
  try! wb.set_cell("Sales", "A4", "Gadget X")
  try! wb.set_cell("Sales", "B4", "2500")
  try! wb.set_cell("Sales", "C4", "2800")
  try! wb.set_cell("Sales", "D4", "3100")
  try! wb.set_cell("Sales", "E4", "2900")
  try! wb.set_cell("Sales", "F4", "11300")
  try! wb.set_cell("Sales", "A5", "Gadget Y")
  try! wb.set_cell("Sales", "B5", "600")
  try! wb.set_cell("Sales", "C5", "750")
  try! wb.set_cell("Sales", "D5", "810")
  try! wb.set_cell("Sales", "E5", "920")
  try! wb.set_cell("Sales", "F5", "3080")
  try! wb.set_cell("Sales", "A6", "Module Z")
  try! wb.set_cell("Sales", "B6", "1800")
  try! wb.set_cell("Sales", "C6", "1650")
  try! wb.set_cell("Sales", "D6", "1900")
  try! wb.set_cell("Sales", "E6", "2100")
  try! wb.set_cell("Sales", "F6", "7450")

  ignore(try! wb.add_sheet("Inventory"))
  try! wb.set_cell("Inventory", "A1", "Product")
  try! wb.set_cell("Inventory", "B1", "Stock")
  try! wb.set_cell("Inventory", "C1", "Warehouse")
  try! wb.set_cell("Inventory", "D1", "Status")
  try! wb.set_cell("Inventory", "A2", "Widget A")
  try! wb.set_cell("Inventory", "B2", "500")
  try! wb.set_cell("Inventory", "C2", "A1")
  try! wb.set_cell("Inventory", "D2", "OK")
  try! wb.set_cell("Inventory", "A3", "Widget B")
  try! wb.set_cell("Inventory", "B3", "120")
  try! wb.set_cell("Inventory", "C3", "A2")
  try! wb.set_cell("Inventory", "D3", "Low")
  try! wb.set_cell("Inventory", "A4", "Gadget X")
  try! wb.set_cell("Inventory", "B4", "800")
  try! wb.set_cell("Inventory", "C4", "B1")
  try! wb.set_cell("Inventory", "D4", "OK")
  try! wb.set_cell("Inventory", "A5", "Gadget Y")
  try! wb.set_cell("Inventory", "B5", "30")
  try! wb.set_cell("Inventory", "C5", "B2")
  try! wb.set_cell("Inventory", "D5", "Critical")
  try! wb.set_cell("Inventory", "A6", "Module Z")
  try! wb.set_cell("Inventory", "B6", "200")
  try! wb.set_cell("Inventory", "C6", "C1")
  try! wb.set_cell("Inventory", "D6", "OK")

  let names = sheet_names_of(wb)
  let data = load_sheet_data(wb, names[0])
  {
    workbook: wb,
    sheet_names: names,
    active_sheet: 0,
    headers: data.0,
    rows: data.1,
    selected_cell: None,
    editing: false,
    edit_value: "",
    file_name: "Demo.xlsx",
    status: "Demo data loaded (2 sheets, 6 rows each)",
  }
}

///|
pub fn ExcalModel::switch_sheet(
  self : ExcalModel,
  index : Int,
) -> ExcalModel {
  if index < 0 || index >= self.sheet_names.length() {
    self
  } else {
    let data = load_sheet_data(self.workbook, self.sheet_names[index])
    {
      ..self,
      active_sheet: index,
      headers: data.0,
      rows: data.1,
      selected_cell: None,
      editing: false,
      edit_value: "",
      status: "Switched to sheet: " + self.sheet_names[index],
    }
  }
}

///|
pub fn ExcalModel::select_cell(
  self : ExcalModel,
  row : Int,
  col : Int,
) -> ExcalModel {
  let cell_ref = try! @mbtexcel.coordinates_to_cell_name(col + 1, row + 1)
  let value = if row < self.rows.length() && col < self.rows[row].length() {
    self.rows[row][col]
  } else {
    ""
  }
  {
    ..self,
    selected_cell: Some((row, col)),
    editing: false,
    edit_value: value,
    status: "Selected \{cell_ref}: \{value}",
  }
}

///|
pub fn ExcalModel::start_editing(self : ExcalModel) -> ExcalModel {
  match self.selected_cell {
    None => self
    Some(_) =>
      {
        ..self,
        editing: true,
        status: "Editing...",
      }
  }
}

///|
pub fn ExcalModel::commit_edit(self : ExcalModel) -> ExcalModel {
  match self.selected_cell {
    None => self
    Some((row, col)) =>
      {
        let sheet_name = self.sheet_names[self.active_sheet]
        let _ = try! apply_cell_edit_impl(
          self.workbook,
          sheet_name,
          row,
          col,
          self.edit_value,
        )
        let new_rows = self.rows.copy()
        if row < new_rows.length() && col < new_rows[row].length() {
          new_rows[row][col] = self.edit_value
        }
        let cell_ref = try! @mbtexcel.coordinates_to_cell_name(col + 1, row + 1)
        {
          ..self,
          rows: new_rows,
          editing: false,
          status: "Committed \{cell_ref} = \{self.edit_value}",
        }
      }
  }
}

///|
pub fn apply_cell_edit_impl(
  wb : @xlsx.Workbook,
  sheet_name : String,
  row : Int,
  col : Int,
  value : String,
) -> Unit raise @xlsx.XlsxError {
  wb.set_cell_rc(sheet_name, row + 1, col + 1, value)
}

///|
pub fn ExcalModel::cancel_edit(self : ExcalModel) -> ExcalModel {
  {
    ..self,
    editing: false,
    status: "Edit cancelled",
  }
}

///|
pub fn update(model : ExcalModel, msg : ExcalMsg) -> ExcalModel {
  match msg {
    SheetSelected(index) => model.switch_sheet(index)
    CellSelected(row, col) => model.select_cell(row, col)
    CellEditStarted => model.start_editing()
    CellValueChanged(value) => { ..model, edit_value: value }
    CellEditCommitted => model.commit_edit()
    CellEditCancelled => model.cancel_edit()
    NewWorkbook => ExcalModel::new()
    LoadDemo => ExcalModel::with_demo_data()
  }
}

///|
pub fn view(model : ExcalModel) -> @moui.View[ExcalMsg] {
  let theme = @views.light_theme()
  let sheet_tabs = build_sheet_tabs(model, theme)
  let data_grid = build_data_grid(model, theme)
  let status_bar_view = build_status_bar(model, theme)
  let shell = column(
    [
      toolbar(model, theme),
      divider(theme=theme),
      sheet_tabs,
      divider(theme=theme),
      data_grid,
      divider(theme=theme),
      status_bar_view,
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
  container(
    shell,
    width=1000.0,
    height=700.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=0.0,
  )
}

///|
fn toolbar(model : ExcalModel, theme : @moui.Theme) -> @moui.View[ExcalMsg] {
  container(
    row(
      [
        text(
          "Excal - " + model.file_name,
          role=@views.TextRole::Title,
          theme~,
          width=300.0,
          height=32.0,
        ),
        @views.spacer(min_length=8.0, weight=1.0),
        button(
          "New",
          on_click=NewWorkbook,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=72.0,
          height=32.0,
        ),
        button(
          "Load Demo",
          on_click=LoadDemo,
          variant=@views.ButtonVariant::Primary,
          theme~,
          width=100.0,
          height=32.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn build_sheet_tabs(
  model : ExcalModel,
  theme : @moui.Theme,
) -> @moui.View[ExcalMsg] {
  if model.sheet_names.length() <= 1 {
    container(
      text(
        model.sheet_names[0],
        role=@views.TextRole::Label,
        theme~,
        width=120.0,
        height=28.0,
      ),
      variant=@views.ContainerVariant::Base,
      theme~,
      padding=theme.spacing_scale.xs,
    )
  } else {
    let tabs : Array[TabItem[ExcalMsg]] = []
    for i, name in model.sheet_names {
      tabs.push(
        @views.tab_item(
          route=i.to_string(),
          label=name,
          view=@views.empty(),
        ),
      )
    }
    tab_view(
      model.active_sheet.to_string(),
      tabs,
      spacing=theme.spacing_scale.xs,
      on_select=fn(route) { SheetSelected(parse_int_or_zero(route)) },
    )
  }
}

///|
fn parse_int_or_zero(s : String) -> Int {
  // Simple digit-by-digit parse for sheet index strings "0", "1", etc.
  if s == "0" { 0 }
  else if s == "1" { 1 }
  else if s == "2" { 2 }
  else if s == "3" { 3 }
  else if s == "4" { 4 }
  else if s == "5" { 5 }
  else if s == "6" { 6 }
  else if s == "7" { 7 }
  else if s == "8" { 8 }
  else if s == "9" { 9 }
  else { 0 }
}

///|
fn build_data_grid(
  model : ExcalModel,
  theme : @moui.Theme,
) -> @moui.View[ExcalMsg] {
  if model.headers.is_empty() {
    container(
      column(
        [
          text(
            "No data",
            role=@views.TextRole::Subtitle,
            theme~,
            width=200.0,
            height=28.0,
          ),
          text(
            "Load a demo or create a new workbook",
            role=@views.TextRole::Caption,
            theme~,
            width=300.0,
            height=24.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      ),
      width=1000.0,
      height=500.0,
      variant=@views.ContainerVariant::Raised,
      theme~,
      padding=theme.spacing_scale.lg,
    )
  } else {
    let columns = model.headers.map(fn(label) {
      table_column(id=label, label=label, width=120.0)
    })
    let selected_row = match model.selected_cell {
      Some((row, _)) => Some(row)
      None => None
    }
    container(
      scroll_view(
        table(
          columns,
          model.rows,
          selected_row~,
          on_row_select=Some(fn(row) { CellSelected(row, 0) }),
          cell=Some(fn(
            row_index : Int,
            col : @views.TableColumn,
            value : String,
          ) -> @moui.View[ExcalMsg] {
            render_cell(model, row_index, col, value, theme)
          }),
          theme~,
          row_height=34.0,
        ),
        width=980.0,
        height=500.0,
      ),
      width=1000.0,
      height=520.0,
      variant=@views.ContainerVariant::Base,
      theme~,
      padding=theme.spacing_scale.xs,
    )
  }
}

///|
fn render_cell(
  model : ExcalModel,
  row_index : Int,
  col : @views.TableColumn,
  value : String,
  theme : @moui.Theme,
) -> @moui.View[ExcalMsg] {
  let col_index = find_column_index(model.headers, col.label)
  let is_selected = match model.selected_cell {
    Some((r, c)) => r == row_index && c == col_index
    None => false
  }
  if is_selected && model.editing {
    text_field(
      model.edit_value,
      on_input=fn(v) { CellValueChanged(v) },
      on_submit=Some(CellEditCommitted),
      variant=@views.TextFieldVariant::Plain,
      theme~,
      width=col.width,
      height=30.0,
    )
  } else {
    let cell_view = text(
      value,
      role=@views.TextRole::Body,
      theme~,
      width=col.width,
      height=30.0,
    )
    if is_selected {
      cell_view
        .background(
          @moui.Color::rgba(r=0.89, g=0.95, b=0.99),
        )
        .on_tap(CellSelected(row_index, col_index))
        .on_double_tap(CellEditStarted)
    } else {
      cell_view
        .on_tap(CellSelected(row_index, col_index))
        .on_double_tap(CellEditStarted)
    }
  }
}

///|
fn find_column_index(headers : Array[String], label : String) -> Int {
  for i, h in headers {
    if h == label {
      return i
    }
  }
  0
}

///|
fn build_status_bar(
  model : ExcalModel,
  theme : @moui.Theme,
) -> @moui.View[ExcalMsg] {
  let cell_info = match model.selected_cell {
    Some((row, col)) =>
      {
        let cell_ref = try! @mbtexcel.coordinates_to_cell_name(col + 1, row + 1)
        "Cell: \{cell_ref}"
      }
    None => "No cell selected"
  }
  let sheet_info = "Sheet: \{model.sheet_names[model.active_sheet]}"
  let row_count = "\{model.rows.length()} rows"
  let col_count = "\{model.headers.length()} columns"
  let status_text = "\{cell_info}  |  \{sheet_info}  |  \{row_count}  |  \{col_count}  |  \{model.status}"
  container(
    text(
      status_text,
      role=@views.TextRole::Caption,
      theme~,
      width=980.0,
      height=24.0,
    ),
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
pub fn ExcalApp::program(
  self : ExcalApp,
) -> @moui.Program[ExcalModel, ExcalMsg] {
  ignore(self)
  program()
}

///|
pub fn program() -> @moui.Program[ExcalModel, ExcalMsg] {
  ExcalModel::with_demo_data().program()
}

///|
pub fn ExcalModel::program(
  self : ExcalModel,
) -> @moui.Program[ExcalModel, ExcalMsg] {
  @moui.Program::simple(init=self, update~, view~)
}
