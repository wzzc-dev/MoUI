///|
pub struct ShowcaseApp {
  unit : Unit
}

///|
pub(all) struct ShowcaseModel {
  scheme : @state.ColorScheme
  active : Bool
  dialog_visible : Bool
  sheet_visible : Bool
  feature_enabled : Bool
  secondary_enabled : Bool
  draft : String
  tab : String
  selected_section : String
  route_history : @views.RouteHistoryState
  filter : String
  data_filter_query : String
  data_filter_active : Bool
  data_filter_review : Bool
  data_sort_column : String
  data_sort_ascending : Bool
  data_page : Int
  data_visible_columns : Array[String]
  feedback_dismissed_toasts : Array[String]
  slider_value : Double
  picker_value : String
  date_value : @views.DateValue
  counter_count : Int
  todo_items : Array[ShowcaseTodoItem]
  todo_next_id : Int
  todo_draft : String
  last_drop_label : String
  gesture_label : String
  diagnostics_input : ShowcaseDiagnosticsInput
  diagnostics_panel_scroll : @geometry.Point
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
  HostRouteChanged(@services.RouteEvent)
  TabSelected(String)
  ClearFilter
  FilterChanged(String)
  DataFilterQueryChanged(String)
  DataActiveFilterChanged(Bool)
  DataReviewFilterChanged(Bool)
  ClearDataFilters
  DataSortChanged(String)
  DataPreviousPage
  DataNextPage
  DataColumnVisibilityChanged(String, Bool)
  FeedbackToastDismissed(String)
  DraftChanged(String)
  SliderChanged(Double)
  PickerSelected(String)
  DateSelected(@views.DateValue)
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
  DiagnosticsPanelScrolled(@geometry.Point)
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
  route_source : @services.RouteSource
  dispatch_command : (ShowcaseRouteHistoryCommand) -> Unit
}

///|
priv struct ShowcaseMetrics {
  panel_width : Double
  panel_height : Double
  body_width : Double
  body_height : Double
  compact : Bool
}

///|
pub fn ShowcaseApp::new() -> ShowcaseApp {
  { unit: () }
}

///|
pub fn ShowcaseModel::new() -> ShowcaseModel {
  {
    scheme: @state.ColorScheme::Light,
    active: false,
    dialog_visible: false,
    sheet_visible: false,
    feature_enabled: true,
    secondary_enabled: false,
    draft: "Visual polish",
    tab: "form",
    selected_section: "overview",
    route_history: @views.RouteHistoryState::new(
      initial=@views.RouteLocation::new(path="overview"),
      title="Overview",
      source="showcase",
    ),
    filter: "",
    data_filter_query: "atlas",
    data_filter_active: true,
    data_filter_review: false,
    data_sort_column: "status",
    data_sort_ascending: false,
    data_page: 1,
    data_visible_columns: ["name", "status"],
    feedback_dismissed_toasts: [],
    slider_value: 0.64,
    picker_value: "native",
    date_value: @views.DateValue::new(year=2026, month=5, day=21),
    counter_count: 0,
    todo_items: [
      ShowcaseTodoItem::new(id=0, text="Reuse Todo state"),
      ShowcaseTodoItem::new(id=1, text="Render inside Showcase"),
    ],
    todo_next_id: 2,
    todo_draft: "",
    last_drop_label: "No files dropped",
    gesture_label: "No gesture yet",
    diagnostics_input: ShowcaseDiagnosticsInput::fallback(),
    diagnostics_panel_scroll: @geometry.Point::new(x=0.0, y=0.0),
  }
}

///|
pub fn ShowcaseModel::with_diagnostics_input(
  self : ShowcaseModel,
  diagnostics_input : ShowcaseDiagnosticsInput,
) -> ShowcaseModel {
  { ..self, diagnostics_input, }
}

///|
/// Open a diagnostics section id (no workspace prefix). Used by the Showcase
/// root composition shell; this package is a diagnostics exception and is not
/// an ordinary app dependency example.
pub fn ShowcaseModel::open(
  self : ShowcaseModel,
  route : String,
) -> ShowcaseModel {
  self.update(SelectSection(normalize_diagnostics_route(route)))
}

///|
pub fn ShowcaseModel::route(self : ShowcaseModel) -> String {
  self.selected_section
}

///|
/// `theme-renderer` alias normalization lives on the shell (`workspace.mbt`
/// `legacy_showcase_route`), so by the time a route reaches Diagnostics it is
/// already canonical. This helper only enforces the Diagnostics-private
/// whitelist (including the hidden `theme` helper section) and falls back to
/// the Inspector entry otherwise.
pub fn normalize_diagnostics_route(route : String) -> String {
  if route == "theme" || diagnostics_routes().contains(route) {
    route
  } else {
    "diagnostics"
  }
}

///|
pub fn diagnostics_routes() -> Array[String] {
  [
    "diagnostics", "runtime-renderer", "advanced-rendering", "text-diagnostics",
    "interaction-lab",
  ]
}

///|
/// Package-local subscriptions. Host route bridging lives on the Showcase root.
pub fn subscriptions(_model : ShowcaseModel) -> @moui.Subscription[ShowcaseMsg] {
  @moui.Subscription::none()
}

///|
pub fn ShowcaseTodoItem::new(id~ : Int, text~ : String) -> ShowcaseTodoItem {
  { id, text, completed: false }
}

///|
pub fn ShowcaseRouteHost::new(
  route_source~ : @services.RouteSource,
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
    ToggleScheme => { ..self, scheme: toggle_color_scheme(self.scheme) }
    ToggleActive => { ..self, active: !self.active }
    ShowDialog => { ..self, dialog_visible: true }
    HideDialog => { ..self, dialog_visible: false }
    ShowSheet => { ..self, dialog_visible: false, sheet_visible: true }
    HideSheet => { ..self, sheet_visible: false }
    SelectSection(route) => self.with_route_pushed(route)
    RouteBack => self.with_route_history(self.route_history.back())
    RouteForward => self.with_route_history(self.route_history.forward())
    OpenRouteLink(route) =>
      self.with_route_history(
        self.route_history.push(
          @views.RouteLocation::parse(route),
          title=showcase_route_title(@views.RouteLocation::parse(route).path),
          source="deep-link",
        ),
      )
    HostRouteChanged(event) => self.with_host_route_event(event)
    TabSelected(route) => { ..self, tab: route }
    ClearFilter => { ..self, filter: "" }
    FilterChanged(value) => { ..self, filter: value }
    DataFilterQueryChanged(value) =>
      { ..self, data_filter_query: value, data_page: 0 }
    DataActiveFilterChanged(value) =>
      { ..self, data_filter_active: value, data_page: 0 }
    DataReviewFilterChanged(value) =>
      { ..self, data_filter_review: value, data_page: 0 }
    ClearDataFilters =>
      {
        ..self,
        data_filter_query: "",
        data_filter_active: false,
        data_filter_review: false,
        data_page: 0,
      }
    DataSortChanged(column) => {
      let sort = @views.DataSortState::new(
        column=self.data_sort_column,
        ascending=self.data_sort_ascending,
      ).toggle(column)
      {
        ..self,
        data_sort_column: sort.column(),
        data_sort_ascending: sort.ascending(),
      }
    }
    DataPreviousPage => {
      let page = @views.PaginationState::new(
          page=self.data_page,
          page_size=3,
          total_count=10,
        )
        .previous()
        .page()
      { ..self, data_page: page }
    }
    DataNextPage => {
      let page = @views.PaginationState::new(
          page=self.data_page,
          page_size=3,
          total_count=10,
        )
        .next()
        .page()
      { ..self, data_page: page }
    }
    DataColumnVisibilityChanged(id, visible) =>
      if id == "name" {
        self
      } else {
        {
          ..self,
          data_visible_columns: showcase_string_array_set(
            self.data_visible_columns,
            id,
            visible,
          ),
        }
      }
    FeedbackToastDismissed(id) =>
      {
        ..self,
        feedback_dismissed_toasts: showcase_string_array_set(
          self.feedback_dismissed_toasts,
          id,
          true,
        ),
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
    DiagnosticsPanelScrolled(point) =>
      { ..self, diagnostics_panel_scroll: point }
  }
}

///|
fn ShowcaseModel::update_with_route_host(
  self : ShowcaseModel,
  message : ShowcaseMsg,
  route_host : ShowcaseRouteHost?,
) -> (ShowcaseModel, @moui.Effect[ShowcaseMsg]) {
  let next = self.update(message)
  let effect = match message {
    SelectSection(route) => {
      let location = @views.RouteLocation::parse(route)
      let command = if self.route_history.current_route() == location.to_route() {
        ReplaceRoute(location.to_route())
      } else {
        PushRoute(location.to_route())
      }
      command.effect(route_host)
    }
    OpenRouteLink(route) =>
      PushRoute(@views.RouteLocation::parse(route).to_route()).effect(
        route_host,
      )
    RouteBack => BackRoute.effect(route_host)
    RouteForward => ForwardRoute.effect(route_host)
    _ => @moui.Effect::none()
  }
  (next, effect)
}

///|
fn ShowcaseRouteHistoryCommand::effect(
  self : ShowcaseRouteHistoryCommand,
  route_host : ShowcaseRouteHost?,
) -> @moui.Effect[ShowcaseMsg] {
  match route_host {
    Some(host) =>
      @moui.Effect::run(
        key="showcase:route-history",
        kind="host-service",
        label=self.label(),
        run=_dispatch => (host.dispatch_command)(self),
      )
    None => @moui.Effect::none()
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
  let location = @views.RouteLocation::parse(route)
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
  event : @services.RouteEvent,
) -> ShowcaseModel {
  let route = event.location.to_route()
  let location = @views.RouteLocation::parse(route)
  let history = if self.route_history.current_route() == route {
    self.route_history.replace(
      location,
      title=showcase_route_title(location.path),
      source=event.source,
    )
  } else {
    match showcase_route_history_cursor_for_route(self.route_history, route) {
      Some(cursor) =>
        @views.RouteHistoryState::from_routes(
          routes=self.route_history.entries().map(entry => entry.route()),
          cursor~,
        )
      None =>
        self.route_history.push(
          location,
          title=showcase_route_title(location.path),
          source=event.source,
        )
    }
  }
  self.with_route_history(history)
}

///|
fn showcase_route_history_cursor_for_route(
  history : @views.RouteHistoryState,
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
  route_history : @views.RouteHistoryState,
) -> ShowcaseModel {
  { ..self, route_history, selected_section: route_history.current().path }
}

///|
/// Title for a diagnostics route, sourced from the catalog item so the
/// sidebar label and the history entry agree without a second hand-maintained
/// lookup table. Falls back to the raw route for the hidden `theme` helper
/// section which is intentionally not a catalog item.
fn showcase_route_title(route : String) -> String {
  for item in catalog_items() {
    if item.id == route {
      return item.title
    }
  }
  match route {
    "theme" => "Theme"
    _ => route
  }
}

///|
/// Hosted body for the unified Showcase shell — detail panel only.
/// The outer shell (app/view.mbt) renders the global left rail; feature
/// packages must not add a second sidebar here.
pub fn ShowcaseModel::view_body(
  self : ShowcaseModel,
  env : @moui.ViewEnvironment,
  width? : Double = 0.0,
) -> @moui.View[ShowcaseMsg] {
  let theme = match self.scheme {
    @state.ColorScheme::Light => @views.light_theme()
    @state.ColorScheme::Dark => @views.dark_theme()
  }
  let metrics = if width > 0.0 {
    let panel_width = width.max(320.0)
    let panel_height = max_showcase_double(
      280.0,
      env.viewport_size().height.max(320.0) - 108.0,
    )
    let body_width = max_showcase_double(
      220.0,
      panel_width - theme.spacing_scale.md * 2.0,
    )
    let body_height = max_showcase_double(120.0, panel_height - 96.0)
    {
      panel_width,
      panel_height,
      body_width,
      body_height,
      compact: body_width < 620.0,
    }
  } else {
    let viewport = env.viewport_size()
    showcase_metrics(viewport, theme)
  }
  let offset = if self.active { 18.0 } else { 0.0 }
  let opacity = if self.active { 1.0 } else { 0.68 }
  let content = self.current_destination(theme, metrics, offset, opacity)
  if self.dialog_visible {
    @views.overlay_host(content, [
      @views.PresentationSpec::new(
        id="showcase-dialog",
        kind=@views.PresentationKind::Dialog,
        content=@views.dialog(
          "Showcase dialog",
          content=text("Custom modal content here", width=300.0, height=48.0),
          primary_action=Some(
            @views.StateViewAction::new(label="Close", message=HideDialog),
          ),
          theme~,
        ),
        modality=@views.PresentationModality::Modal,
        presented=true,
      ),
    ])
  } else {
    content
  }
}

///|
fn toggle_color_scheme(scheme : @state.ColorScheme) -> @state.ColorScheme {
  match scheme {
    @state.ColorScheme::Light => @state.ColorScheme::Dark
    @state.ColorScheme::Dark => @state.ColorScheme::Light
  }
}

///|
pub fn ShowcaseApp::program(
  self : ShowcaseApp,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new().program()
}

///|
pub fn ShowcaseApp::program_with_diagnostics(
  self : ShowcaseApp,
  diagnostics_input : ShowcaseDiagnosticsInput,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new().with_diagnostics_input(diagnostics_input).program()
}

///|
pub fn ShowcaseModel::program(
  self : ShowcaseModel,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  self.program_with_optional_route_host(None)
}

///|
pub fn ShowcaseModel::program_with_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  self.program_with_optional_route_host(Some(route_host))
}

///|
fn ShowcaseModel::program_with_optional_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost?,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => model.update_with_route_host(message, route_host),
    view=(model, env) => model.view_body(env),
    subscriptions=_model => showcase_route_subscription(route_host),
  )
}

///|
fn showcase_route_subscription(
  route_host : ShowcaseRouteHost?,
) -> @moui.Subscription[ShowcaseMsg] {
  match route_host {
    Some(host) =>
      host.route_source.subscription(
        key="showcase:host-route",
        label="Showcase host route",
        map=event => Some(HostRouteChanged(event)),
      )
    None => @moui.Subscription::none()
  }
}
