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
  route_history : @core.RouteHistoryState
  filter : String
  data_filter_query : String
  data_filter_active : Bool
  data_filter_review : Bool
  slider_value : Double
  picker_value : String
  date_value : @core.DateValue
  detail_scroll_offset : @core.Point
  sidebar_scroll_offset : @core.Point
  list_scroll : @core.ScrollState
  grid_scroll : @core.ScrollState
  counter_count : Int
  todo_items : Array[ShowcaseTodoItem]
  todo_next_id : Int
  todo_draft : String
  last_drop_label : String
  gesture_label : String
  host_summary : @host.HostCapabilitySummary
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
  RouteBack
  RouteForward
  OpenRouteLink(String)
  HostRouteChanged(@host.HostRouteEvent)
  TabSelected(String)
  ClearFilter
  FilterChanged(String)
  DataFilterQueryChanged(String)
  DataActiveFilterChanged(Bool)
  DataReviewFilterChanged(Bool)
  ClearDataFilters
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
  DetailScrollTo(Double)
  SidebarScrollTo(Double)
}

///|
pub(all) enum ShowcaseRouteHistoryCommand {
  PushRoute(String)
  ReplaceRoute(String)
  BackRoute
  ForwardRoute
} derive(Eq, Debug, ToJson)

///|
pub struct ShowcaseRouteHost {
  route_source : @host.HostRouteSource
  dispatch_command : (ShowcaseRouteHistoryCommand) -> Unit
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
    route_history: @core.RouteHistoryState::new(
      initial=@core.RouteLocation::new(path="overview"),
      title="Overview",
      source="showcase",
    ),
    filter: "",
    data_filter_query: "atlas",
    data_filter_active: true,
    data_filter_review: false,
    slider_value: 0.64,
    picker_value: "native",
    date_value: @core.DateValue::new(year=2026, month=5, day=21),
    detail_scroll_offset: @core.Point::new(x=0.0, y=0.0),
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
    host_summary: @host.HostCapabilitySummary::test_host(
      label="Showcase test host",
    ),
  }
}

///|
pub fn ShowcaseModel::with_host_summary(
  self : ShowcaseModel,
  host_summary : @host.HostCapabilitySummary,
) -> ShowcaseModel {
  { ..self, host_summary, }
}

///|
pub fn ShowcaseTodoItem::new(id~ : Int, text~ : String) -> ShowcaseTodoItem {
  { id, text, completed: false }
}

///|
pub fn ShowcaseRouteHost::new(
  route_source~ : @host.HostRouteSource,
  dispatch_command~ : (ShowcaseRouteHistoryCommand) -> Unit,
) -> ShowcaseRouteHost {
  { route_source, dispatch_command }
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
    ShowSheet => { ..self, dialog_visible: false, sheet_visible: true }
    HideSheet => { ..self, sheet_visible: false }
    SelectSection(route) =>
      self.with_route_pushed(route).with_detail_scroll_reset()
    RouteBack =>
      self
      .with_route_history(self.route_history.back())
      .with_detail_scroll_reset()
    RouteForward =>
      self
      .with_route_history(self.route_history.forward())
      .with_detail_scroll_reset()
    OpenRouteLink(route) =>
      self
      .with_route_history(
        self.route_history.push(
          @core.RouteLocation::parse(route),
          title=showcase_route_title(@core.RouteLocation::parse(route).path),
          source="deep-link",
        ),
      )
      .with_detail_scroll_reset()
    HostRouteChanged(event) =>
      self.with_host_route_event(event).with_detail_scroll_reset()
    TabSelected(route) => { ..self, tab: route }
    ClearFilter => { ..self, filter: "" }
    FilterChanged(value) => { ..self, filter: value }
    DataFilterQueryChanged(value) => { ..self, data_filter_query: value }
    DataActiveFilterChanged(value) => { ..self, data_filter_active: value }
    DataReviewFilterChanged(value) => { ..self, data_filter_review: value }
    ClearDataFilters =>
      {
        ..self,
        data_filter_query: "",
        data_filter_active: false,
        data_filter_review: false,
      }
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
    DetailScrollTo(y) =>
      {
        ..self,
        detail_scroll_offset: @core.Point::new(
          x=0.0,
          y=max_showcase_double(0.0, y),
        ),
      }
    SidebarScrollTo(y) =>
      { ..self, sidebar_scroll_offset: @core.Point::new(x=0.0, y~) }
  }
}

///|
fn ShowcaseModel::update_with_route_host(
  self : ShowcaseModel,
  message : ShowcaseMsg,
  route_host : ShowcaseRouteHost?,
) -> (ShowcaseModel, @core.Effect[ShowcaseMsg]) {
  let next = self.update(message)
  let effect = match message {
    SelectSection(route) => {
      let location = @core.RouteLocation::parse(route)
      let command = if self.route_history.current_route() == location.to_route() {
        ReplaceRoute(location.to_route())
      } else {
        PushRoute(location.to_route())
      }
      command.effect(route_host)
    }
    OpenRouteLink(route) =>
      PushRoute(@core.RouteLocation::parse(route).to_route()).effect(route_host)
    RouteBack => BackRoute.effect(route_host)
    RouteForward => ForwardRoute.effect(route_host)
    _ => @core.Effect::none()
  }
  (next, effect)
}

///|
fn ShowcaseRouteHistoryCommand::effect(
  self : ShowcaseRouteHistoryCommand,
  route_host : ShowcaseRouteHost?,
) -> @core.Effect[ShowcaseMsg] {
  match route_host {
    Some(host) =>
      @core.Effect::host_service(
        key="showcase:route-history",
        label=self.label(),
        run=_dispatch => (host.dispatch_command)(self),
      )
    None => @core.Effect::none()
  }
}

///|
fn ShowcaseRouteHistoryCommand::label(
  self : ShowcaseRouteHistoryCommand,
) -> String {
  match self {
    PushRoute(route) => "Push route " + route
    ReplaceRoute(route) => "Replace route " + route
    BackRoute => "Back route"
    ForwardRoute => "Forward route"
  }
}

///|
fn ShowcaseModel::with_route_pushed(
  self : ShowcaseModel,
  route : String,
) -> ShowcaseModel {
  let location = @core.RouteLocation::parse(route)
  let history = if self.route_history.current_route() == location.to_route() {
    self.route_history.replace(
      location,
      title=showcase_route_title(location.path),
      source="showcase",
    )
  } else {
    self.route_history.push(
      location,
      title=showcase_route_title(location.path),
      source="showcase",
    )
  }
  self.with_route_history(history)
}

///|
fn ShowcaseModel::with_host_route_event(
  self : ShowcaseModel,
  event : @host.HostRouteEvent,
) -> ShowcaseModel {
  let route = event.location.to_route()
  let history = if self.route_history.current_route() == route {
    self.route_history.replace(
      event.location,
      title=showcase_route_title(event.location.path),
      source=event.source,
    )
  } else {
    match showcase_route_history_cursor_for_route(self.route_history, route) {
      Some(cursor) => { ..self.route_history, cursor, }
      None =>
        self.route_history.push(
          event.location,
          title=showcase_route_title(event.location.path),
          source=event.source,
        )
    }
  }
  self.with_route_history(history)
}

///|
fn showcase_route_history_cursor_for_route(
  history : @core.RouteHistoryState,
  route : String,
) -> Int? {
  for index, entry in history.entries {
    if entry.route == route {
      return Some(index)
    }
  }
  None
}

///|
fn ShowcaseModel::with_route_history(
  self : ShowcaseModel,
  route_history : @core.RouteHistoryState,
) -> ShowcaseModel {
  { ..self, route_history, selected_section: route_history.current().path }
}

///|
fn ShowcaseModel::with_detail_scroll_reset(
  self : ShowcaseModel,
) -> ShowcaseModel {
  { ..self, detail_scroll_offset: @core.Point::new(x=0.0, y=0.0) }
}

///|
fn showcase_route_title(route : String) -> String {
  for section in showcase_sections() {
    if section.route == route {
      return section.title
    }
  }
  route
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
pub fn ShowcaseApp::runtime_with_host_summary(
  self : ShowcaseApp,
  host_summary : @host.HostCapabilitySummary,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @core.AppRuntime {
  ignore(self)
  ShowcaseModel::new().with_host_summary(host_summary).runtime(width~, height~)
}

///|
pub fn ShowcaseModel::runtime(
  self : ShowcaseModel,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @core.AppRuntime {
  self.runtime_with_optional_route_host(None, width~, height~)
}

///|
pub fn ShowcaseModel::runtime_with_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @core.AppRuntime {
  self.runtime_with_optional_route_host(Some(route_host), width~, height~)
}

///|
fn ShowcaseModel::runtime_with_optional_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost?,
  width~ : Double,
  height~ : Double,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::new_with_environment(
      init=() => (self, @core.Effect::none()),
      update=(model, message) => {
        model.update_with_route_host(message, route_host)
      },
      view=(model, env) => model.view(env),
      subscriptions=_model => showcase_route_subscription(route_host),
    ),
    size=@core.Size::new(width~, height~),
  )
}

///|
fn showcase_route_subscription(
  route_host : ShowcaseRouteHost?,
) -> @core.Subscription[ShowcaseMsg] {
  match route_host {
    Some(host) =>
      host.route_source.subscription(
        key="showcase:host-route",
        label="Showcase host route",
        map=event => Some(HostRouteChanged(event)),
      )
    None => @core.Subscription::none()
  }
}
