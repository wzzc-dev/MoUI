///|
pub struct ShowcaseApp {
  dark : @core.State[Bool]
  active : @core.State[Bool]
  dialog_visible : @core.State[Bool]
  sheet_visible : @core.State[Bool]
  feature_enabled : @core.State[Bool]
  secondary_enabled : @core.State[Bool]
  draft : @core.State[String]
  tab : @core.State[String]
  selected_section : @core.State[String]
  filter : @core.State[String]
  slider_value : @core.State[Double]
  picker_value : @core.State[String]
  date_value : @core.State[@core.DateValue]
  navigation : @core.NavigationState
  sidebar_scroll : @core.ScrollState
  list_scroll : @core.ScrollState
  grid_scroll : @core.ScrollState
  counter_count : @core.State[Int]
  todo_items : @core.State[Array[ShowcaseTodoItem]]
  todo_next_id : @core.State[Int]
  todo_draft : @core.State[String]
  last_drop_label : @core.State[String]
}

///|
pub(all) struct ShowcaseTodoItem {
  id : Int
  text : String
  completed : Bool
} derive(Eq, Debug, ToJson)

///|
enum ShowcaseMsg {
  ToggleScheme
  ToggleActive
  ShowDialog
  HideDialog
  ShowSheet
  HideSheet
  SelectSection(String)
  SelectTab(String)
  ClearFilter
  CounterIncrement
  TodoSubmitDraft
  TodoRemove(Int)
  RecordFileDrop(Array[String])
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
  {
    dark: @core.State::new(false),
    active: @core.State::new(false),
    dialog_visible: @core.State::new(false),
    sheet_visible: @core.State::new(false),
    feature_enabled: @core.State::new(true),
    secondary_enabled: @core.State::new(false),
    draft: @core.State::new("Visual polish"),
    tab: @core.State::new("form"),
    selected_section: @core.State::new("overview"),
    filter: @core.State::new(""),
    slider_value: @core.State::new(0.64),
    picker_value: @core.State::new("native"),
    date_value: @core.State::new(
      @core.DateValue::new(year=2026, month=5, day=21),
    ),
    navigation: @core.NavigationState::new(initial="overview"),
    sidebar_scroll: @core.ScrollState::new(),
    list_scroll: @core.ScrollState::new(),
    grid_scroll: @core.ScrollState::new(),
    counter_count: @core.State::new(0),
    todo_items: @core.State::new([
      ShowcaseTodoItem::new(id=0, text="Reuse Todo state"),
      ShowcaseTodoItem::new(id=1, text="Render inside Showcase"),
    ]),
    todo_next_id: @core.State::new(2),
    todo_draft: @core.State::new(""),
    last_drop_label: @core.State::new("No files dropped"),
  }
}

///|
pub fn ShowcaseTodoItem::new(id~ : Int, text~ : String) -> ShowcaseTodoItem {
  { id, text, completed: false }
}

///|
pub fn ShowcaseApp::counter_increment(self : ShowcaseApp) -> Unit {
  self.counter_count.update(value => value + 1)
}

///|
pub fn ShowcaseApp::todo_items(self : ShowcaseApp) -> Array[ShowcaseTodoItem] {
  self.todo_items.get()
}

///|
pub fn ShowcaseApp::todo_count(self : ShowcaseApp) -> Int {
  self.todo_items.get().length()
}

///|
pub fn ShowcaseApp::todo_add(self : ShowcaseApp, text : String) -> Unit {
  let id = self.todo_next_id.get()
  self.todo_next_id.set(id + 1)
  let items = self.todo_items.get().copy()
  items.push(ShowcaseTodoItem::new(id~, text~))
  self.todo_items.set(items)
}

///|
pub fn ShowcaseApp::todo_set_draft(self : ShowcaseApp, text : String) -> Unit {
  self.todo_draft.set(text)
}

///|
pub fn ShowcaseApp::todo_submit_draft(self : ShowcaseApp) -> Unit {
  let text = self.todo_draft.get()
  if text != "" {
    self.todo_add(text)
    self.todo_draft.set("")
  }
}

///|
pub fn ShowcaseApp::todo_toggle(self : ShowcaseApp, id : Int) -> Unit {
  self.todo_items.update(items => {
    items.map(item => {
      if item.id == id {
        { ..item, completed: !item.completed }
      } else {
        item
      }
    })
  })
}

///|
pub fn ShowcaseApp::todo_remove(self : ShowcaseApp, id : Int) -> Unit {
  self.todo_items.update(items => items.filter(item => item.id != id))
}

///|
pub fn ShowcaseApp::record_file_drop(
  self : ShowcaseApp,
  paths : Array[String],
) -> Unit {
  self.last_drop_label.set("Dropped \{paths.length()} file(s)")
}

///|
pub fn ShowcaseApp::todo_completed_binding(
  self : ShowcaseApp,
  id : Int,
) -> @core.Binding[Bool] {
  @core.Binding::new(
    get=() => {
      for item in self.todo_items.get() {
        if item.id == id {
          return item.completed
        }
      }
      false
    },
    set=completed => {
      self.todo_items.update(items => {
        items.map(item => {
          if item.id == id {
            { ..item, completed, }
          } else {
            item
          }
        })
      })
    },
  )
}

///|
pub fn ShowcaseApp::toggle_scheme(self : ShowcaseApp) -> Unit {
  self.dark.update(value => !value)
}

///|
pub fn ShowcaseApp::toggle_active(self : ShowcaseApp) -> Unit {
  self.active.update(value => !value)
}

///|
pub fn ShowcaseApp::show_dialog(self : ShowcaseApp) -> Unit {
  self.dialog_visible.set(true)
}

///|
pub fn ShowcaseApp::hide_dialog(self : ShowcaseApp) -> Unit {
  self.dialog_visible.set(false)
}

///|
pub fn ShowcaseApp::show_sheet(self : ShowcaseApp) -> Unit {
  self.sheet_visible.set(true)
}

///|
pub fn ShowcaseApp::hide_sheet(self : ShowcaseApp) -> Unit {
  self.sheet_visible.set(false)
}

///|
pub fn ShowcaseApp::select_section(self : ShowcaseApp, route : String) -> Unit {
  self.selected_section.set(route)
  self.navigation.replace(route)
}

///|
fn ShowcaseApp::update(self : ShowcaseApp, message : ShowcaseMsg) -> Unit {
  match message {
    ToggleScheme => self.toggle_scheme()
    ToggleActive => self.toggle_active()
    ShowDialog => self.show_dialog()
    HideDialog => self.hide_dialog()
    ShowSheet => self.show_sheet()
    HideSheet => self.hide_sheet()
    SelectSection(route) => self.select_section(route)
    SelectTab(route) => self.tab.set(route)
    ClearFilter => self.filter.set("")
    CounterIncrement => self.counter_increment()
    TodoSubmitDraft => self.todo_submit_draft()
    TodoRemove(id) => self.todo_remove(id)
    RecordFileDrop(paths) => self.record_file_drop(paths)
    SidebarScrollTo(y) => self.sidebar_scroll.scroll_to(x=0.0, y~)
  }
}

///|
pub fn ShowcaseApp::root(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
) -> @core.View[ShowcaseMsg] {
  let dark = ctx.watch(self.dark)
  let active = ctx.watch(self.active)
  let dialog_visible = ctx.watch(self.dialog_visible)
  let sheet_visible = ctx.watch(self.sheet_visible)
  let selected_section = ctx.watch(self.selected_section)
  let filter = ctx.binding(self.filter)
  let draft = ctx.binding(self.draft)
  let tab = ctx.binding(self.tab)
  let slider = ctx.binding(self.slider_value)
  let enabled = ctx.binding(self.feature_enabled)
  let secondary = ctx.binding(self.secondary_enabled)
  let picker = ctx.binding(self.picker_value)
  let date = ctx.binding(self.date_value)
  ignore(ctx.watch_navigation(self.navigation))
  ignore(ctx.watch_scroll(self.list_scroll))
  ignore(ctx.watch_scroll(self.grid_scroll))
  let theme = if dark { @views.dark_theme() } else { @views.light_theme() }
  let metrics = showcase_metrics(ctx.viewport_size(), theme)
  let offset = if active { 18.0 } else { 0.0 }
  let opacity = if active { 1.0 } else { 0.68 }
  let shell = surface(
    column(
      [
        self.header(theme, metrics, dark, active, selected_section),
        self.catalog_shell(
          ctx, theme, metrics, selected_section, filter, draft, tab, slider, enabled,
          secondary, picker, date, active, offset, opacity,
        ),
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
    presented=sheet_visible,
    presentation_mode=@core.SheetPresentationMode::BottomSheet,
    on_dismiss=Some(HideSheet),
  )
  @views.dialog_host(
    sheeted,
    dialog=Some(self.dialog(theme)),
    presented=dialog_visible,
  )
}

///|
pub fn ShowcaseApp::runtime(
  self : ShowcaseApp,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_component_view(
    root=ctx => self.root(ctx),
    size=@core.Size::new(width~, height~),
    on_message=Some(message => self.update(message)),
  )
}
