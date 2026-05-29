///|
pub struct ShowcaseApp {
  unit : Unit
}

///|
pub(all) struct ShowcaseModel {
  dark : Bool
  active : Bool
  dialog_visible : Bool
  sheet_visible : Bool
  feature_enabled : Bool
  secondary_enabled : Bool
  draft : String
  tab : String
  selected_section : String
  filter : String
  slider_value : Double
  picker_value : String
  date_value : @core.DateValue
  sidebar_scroll_offset : @core.Point
  list_scroll : @core.ScrollState
  grid_scroll : @core.ScrollState
  counter_count : Int
  todo_items : Array[ShowcaseTodoItem]
  todo_next_id : Int
  todo_draft : String
  last_drop_label : String
  gesture_label : String
}

///|
pub(all) struct ShowcaseTodoItem {
  id : Int
  text : String
  completed : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ShowcaseMsg {
  ToggleScheme
  ToggleActive
  ShowDialog
  HideDialog
  ShowSheet
  HideSheet
  SelectSection(String)
  TabSelected(String)
  ClearFilter
  FilterChanged(String)
  DraftChanged(String)
  SliderChanged(Double)
  PickerSelected(String)
  DateSelected(@core.DateValue)
  FeatureEnabledChanged(Bool)
  SecondaryEnabledChanged(Bool)
  CounterIncrement
  TodoDraftChanged(String)
  TodoSubmitDraft
  TodoToggled(Int, Bool)
  TodoRemove(Int)
  RecordFileDrop(Array[String])
  RecordGesture(String)
  ResizePanel(Double)
  SidebarScrollTo(Double)
}

///|
priv struct ShowcaseSection {
  route : String
  title : String
  summary : String
  group : String
}

///|
priv struct ShowcaseMetrics {
  viewport : @core.Size
  shell_width : Double
  sidebar_width : Double
  detail_width : Double
  panel_width : Double
  panel_height : Double
  body_width : Double
  body_height : Double
  action_width : Double
  compact : Bool
}

///|
pub fn ShowcaseApp::new() -> ShowcaseApp {
  { unit: () }
}

///|
pub fn ShowcaseModel::new() -> ShowcaseModel {
  {
    dark: false,
    active: false,
    dialog_visible: false,
    sheet_visible: false,
    feature_enabled: true,
    secondary_enabled: false,
    draft: "Visual polish",
    tab: "form",
    selected_section: "overview",
    filter: "",
    slider_value: 0.64,
    picker_value: "native",
    date_value: @core.DateValue::new(year=2026, month=5, day=21),
    sidebar_scroll_offset: @core.Point::new(x=0.0, y=0.0),
    list_scroll: @core.ScrollState::new(),
    grid_scroll: @core.ScrollState::new(),
    counter_count: 0,
    todo_items: [
      ShowcaseTodoItem::new(id=0, text="Reuse Todo state"),
      ShowcaseTodoItem::new(id=1, text="Render inside Showcase"),
    ],
    todo_next_id: 2,
    todo_draft: "",
    last_drop_label: "No files dropped",
    gesture_label: "No gesture yet",
  }
}

///|
pub fn ShowcaseTodoItem::new(id~ : Int, text~ : String) -> ShowcaseTodoItem {
  { id, text, completed: false }
}

///|
pub fn ShowcaseModel::todo_count(self : ShowcaseModel) -> Int {
  self.todo_items.length()
}

///|
fn ShowcaseModel::with_todo_added(
  self : ShowcaseModel,
  text : String,
) -> ShowcaseModel {
  let items = self.todo_items.copy()
  items.push(ShowcaseTodoItem::new(id=self.todo_next_id, text~))
  { ..self, todo_items: items, todo_next_id: self.todo_next_id + 1 }
}

///|
pub fn ShowcaseModel::update(
  self : ShowcaseModel,
  message : ShowcaseMsg,
) -> ShowcaseModel {
  match message {
    ToggleScheme => { ..self, dark: !self.dark }
    ToggleActive => { ..self, active: !self.active }
    ShowDialog => { ..self, dialog_visible: true }
    HideDialog => { ..self, dialog_visible: false }
    ShowSheet => { ..self, sheet_visible: true }
    HideSheet => { ..self, sheet_visible: false }
    SelectSection(route) => { ..self, selected_section: route }
    TabSelected(route) => { ..self, tab: route }
    ClearFilter => { ..self, filter: "" }
    FilterChanged(value) => { ..self, filter: value }
    DraftChanged(value) => { ..self, draft: value }
    SliderChanged(value) => { ..self, slider_value: value }
    PickerSelected(value) => { ..self, picker_value: value }
    DateSelected(value) => { ..self, date_value: value }
    FeatureEnabledChanged(value) => { ..self, feature_enabled: value }
    SecondaryEnabledChanged(value) => { ..self, secondary_enabled: value }
    CounterIncrement => { ..self, counter_count: self.counter_count + 1 }
    TodoDraftChanged(value) => { ..self, todo_draft: value }
    TodoSubmitDraft =>
      if self.todo_draft == "" {
        self
      } else {
        { ..self.with_todo_added(self.todo_draft), todo_draft: "" }
      }
    TodoToggled(id, completed) => {
      let items = self.todo_items.map(item => {
        if item.id == id {
          { ..item, completed, }
        } else {
          item
        }
      })
      { ..self, todo_items: items }
    }
    TodoRemove(id) =>
      { ..self, todo_items: self.todo_items.filter(item => item.id != id) }
    RecordFileDrop(paths) =>
      { ..self, last_drop_label: "Dropped \{paths.length()} file(s)" }
    RecordGesture(label) => { ..self, gesture_label: label }
    ResizePanel(size) => { ..self, slider_value: size / 520.0 }
    SidebarScrollTo(y) =>
      { ..self, sidebar_scroll_offset: @core.Point::new(x=0.0, y~) }
  }
}

///|
pub fn ShowcaseModel::view(
  self : ShowcaseModel,
  env : @core.ViewEnvironment,
) -> @core.View[ShowcaseMsg] {
  let theme = if self.dark { @views.dark_theme() } else { @views.light_theme() }
  let metrics = showcase_metrics(env.viewport_size(), theme)
  let offset = if self.active { 18.0 } else { 0.0 }
  let opacity = if self.active { 1.0 } else { 0.68 }
  let shell = surface(
    column(
      [
        self.header(theme, metrics),
        self.catalog_shell(theme, metrics, offset, opacity),
      ],
      spacing=theme.spacing_scale.lg,
      align=@views.CrossAlign::Stretch,
    ),
    width=metrics.viewport.width,
    height=metrics.viewport.height,
    variant=@views.SurfaceVariant::Base,
    theme~,
  )
  let sheeted = @views.sheet_host(
    child=shell,
    sheet=Some(self.sheet(theme)),
    presented=self.sheet_visible,
    presentation_mode=@core.SheetPresentationMode::BottomSheet,
    on_dismiss=Some(HideSheet),
  )
  @views.dialog_host(
    sheeted,
    dialog=Some(self.dialog(theme)),
    presented=self.dialog_visible,
  )
}

///|
pub fn ShowcaseApp::runtime(
  self : ShowcaseApp,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @core.AppRuntime {
  ignore(self)
  ShowcaseModel::new().runtime(width~, height~)
}

///|
pub fn ShowcaseModel::runtime(
  self : ShowcaseModel,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::simple_with_environment(
      init=self,
      update=(model, message) => model.update(message),
      view=(model, env) => model.view(env),
    ),
    size=@core.Size::new(width~, height~),
  )
}
