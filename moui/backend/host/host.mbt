///|
pub(all) struct HostSurfaceMetrics {
  logical_size : @core.Size
  physical_size : @core.Size
  scale_factor : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostCoordinateSpace {
  LogicalPixels
  PhysicalPixels
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostCoordinatePolicy {
  input_space : HostCoordinateSpace
  surface_space : HostCoordinateSpace
  scale_factor_applied : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostBackendKind {
  Native
  Web
  Test
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostAppInfo {
  backend : HostBackendKind
  uses_shared_event_model : Bool
  uses_shared_surface_model : Bool
  uses_shared_input_model : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostInputCapabilities {
  pointer : Bool
  scroll : Bool
  keyboard : Bool
  focus : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  drag_drop : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostServiceCapabilities {
  clipboard : Bool
  menus : Bool
  file_dialogs : Bool
  open_url : Bool
  system_theme : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostClipboardRequest {
  ReadText
  WriteText(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostFileDialogKind {
  OpenFile
  SaveFile
  PickDirectory
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostFileDialogOptions {
  kind : HostFileDialogKind
  title : String
  filters : Array[String]
  default_name : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceRequest {
  Clipboard(HostClipboardRequest)
  ShowMenu(Array[@core.ActionCommand])
  FileDialog(HostFileDialogOptions)
  OpenUrl(String)
  QuerySystemTheme
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceResponse {
  Unavailable(String)
  Pending(HostServiceRequestId)
  ClipboardText(String)
  ClipboardWritten
  MenuCommand(@core.CommandIntent)
  FileDialogSelection(Array[String])
  UrlOpened
  SystemTheme(@core.ColorScheme)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceKind {
  ClipboardService
  MenuService
  FileDialogService
  OpenUrlService
  SystemThemeService
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostServiceHandler {
  kind : HostServiceKind
  handle : (HostServiceRequest) -> HostServiceResponse
}

///|
pub(all) struct PlatformChannelRequest {
  channel : String
  operation : String
  payload : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum PlatformChannelResponse {
  Ok(String)
  Unavailable(String)
  Error(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PlatformChannelHandler {
  channel : String
  handle : (PlatformChannelRequest) -> PlatformChannelResponse
}

///|
pub(all) struct PlatformChannelRegistry {
  mut handlers : Array[PlatformChannelHandler]
}

///|
pub(all) struct HostServiceBridge {
  capabilities : HostServiceCapabilities
  handle : (HostServiceRequest) -> HostServiceResponse
  mut services : Array[HostServiceHandler]
  channels : PlatformChannelRegistry
}

///|
pub(all) enum NativeAccessibilityBridgeKind {
  AppKit
  UIAutomation
  ATSPI
  TestBridge
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NativeAccessibilityNode {
  element_id : @core.ElementId
  role : @core.SemanticsRole
  native_role : String
  label : String
  value : String
  frame : @core.Rect
  focused : Bool
  disabled : Bool
  selected : Bool
  checked : Bool
  actions : Array[@core.SemanticsAction]
  children : Array[NativeAccessibilityNode]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NativeAccessibilityActionRequest {
  element_id : @core.ElementId
  action : @core.SemanticsAction
  value : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum NativeAccessibilityActionResult {
  Handled
  Unsupported(String)
  ElementNotFound(@core.ElementId)
  BridgeUnavailable(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NativeAccessibilityBridge {
  kind : NativeAccessibilityBridgeKind
  available : Bool
  snapshot : (@core.SemanticsNode) -> @accesskit.TreeUpdate
  perform : (NativeAccessibilityActionRequest) -> NativeAccessibilityActionResult
}

///|
pub(all) struct HostInputContract {
  capabilities : HostInputCapabilities
  coordinates : HostCoordinatePolicy
} derive(Eq, Debug, ToJson)

///|
pub(all) struct InputHostState {
  mut focused : Bool
  mut modifiers : @core.KeyModifiers
  contract : HostInputContract
}

///|
pub(all) struct SurfaceHostState {
  mut metrics : HostSurfaceMetrics
  owns_surface : Bool
  can_reconfigure : Bool
}

///|
pub(all) enum HostScrollPhase {
  Started
  Moved
  Ended
  Cancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostScrollDelta {
  Lines(@core.Point)
  Pixels(@core.Point)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostScrollEvent {
  position : @core.Point
  delta : HostScrollDelta
  phase : HostScrollPhase
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostFocusEvent {
  focused : Bool
  pointer_cancel_position : @core.Point?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostEvent {
  Resized(HostSurfaceMetrics)
  Pointer(@core.PointerEvent)
  Scroll(HostScrollEvent)
  Focus(HostFocusEvent)
  Keyboard(@core.KeyboardEvent)
  TextInput(@core.TextInputEvent)
  DragDrop(@core.DragDropEvent)
  ThemeChanged(@core.ColorScheme)
  Command(@core.CommandIntent)
  RedrawRequested
  CloseRequested
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostEventResult {
  needs_rebuild : Bool
  needs_redraw : Bool
  redraw_requested : Bool
  close_requested : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RedrawScheduler {
  mut redraw_requested : Bool
  mut schedule : () -> Unit
}

///|
pub(all) struct HostRuntimeDriver {
  runtime : @core.AppRuntime
  scheduler : RedrawScheduler
  mut close_requested : Bool
}

///|
pub fn HostSurfaceMetrics::new(
  logical_size~ : @core.Size,
  physical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> HostSurfaceMetrics {
  { logical_size, physical_size, scale_factor }
}

///|
pub fn HostSurfaceMetrics::from_logical(
  size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> HostSurfaceMetrics {
  {
    logical_size: size,
    physical_size: @core.Size::new(
      width=size.width * scale_factor,
      height=size.height * scale_factor,
    ),
    scale_factor,
  }
}

///|
pub fn HostCoordinatePolicy::logical(
  description? : String = "Host input and surface metrics use logical pixels after DPR scaling.",
) -> HostCoordinatePolicy {
  {
    input_space: HostCoordinateSpace::LogicalPixels,
    surface_space: HostCoordinateSpace::LogicalPixels,
    scale_factor_applied: true,
    description,
  }
}

///|
pub fn HostCoordinatePolicy::physical(
  description? : String = "Host input and surface metrics use physical pixels.",
) -> HostCoordinatePolicy {
  {
    input_space: HostCoordinateSpace::PhysicalPixels,
    surface_space: HostCoordinateSpace::PhysicalPixels,
    scale_factor_applied: false,
    description,
  }
}

///|
pub fn HostAppInfo::new(
  backend~ : HostBackendKind,
  description? : String = "",
  uses_shared_event_model? : Bool = true,
  uses_shared_surface_model? : Bool = true,
  uses_shared_input_model? : Bool = true,
) -> HostAppInfo {
  {
    backend,
    uses_shared_event_model,
    uses_shared_surface_model,
    uses_shared_input_model,
    description,
  }
}

///|
pub fn HostInputCapabilities::new(
  pointer? : Bool = true,
  scroll? : Bool = true,
  keyboard? : Bool = true,
  focus? : Bool = true,
  text_input? : Bool = true,
  ime? : Bool = false,
  clipboard? : Bool = false,
  drag_drop? : Bool = false,
) -> HostInputCapabilities {
  { pointer, scroll, keyboard, focus, text_input, ime, clipboard, drag_drop }
}

///|
pub fn HostInputCapabilities::none() -> HostInputCapabilities {
  {
    pointer: false,
    scroll: false,
    keyboard: false,
    focus: false,
    text_input: false,
    ime: false,
    clipboard: false,
    drag_drop: false,
  }
}

///|
pub fn HostServiceCapabilities::none() -> HostServiceCapabilities {
  {
    clipboard: false,
    menus: false,
    file_dialogs: false,
    open_url: false,
    system_theme: false,
  }
}

///|
pub fn HostServiceCapabilities::new(
  clipboard? : Bool = false,
  menus? : Bool = false,
  file_dialogs? : Bool = false,
  open_url? : Bool = false,
  system_theme? : Bool = false,
) -> HostServiceCapabilities {
  { clipboard, menus, file_dialogs, open_url, system_theme }
}

///|
pub fn HostFileDialogOptions::new(
  kind~ : HostFileDialogKind,
  title? : String = "",
  filters? : Array[String] = [],
  default_name? : String? = None,
) -> HostFileDialogOptions {
  { kind, title, filters, default_name }
}

///|
pub fn HostServiceBridge::new(
  capabilities~ : HostServiceCapabilities,
  handle~ : (HostServiceRequest) -> HostServiceResponse,
) -> HostServiceBridge {
  {
    capabilities,
    handle,
    services: [],
    channels: PlatformChannelRegistry::new(),
  }
}

///|
pub fn HostServiceBridge::unavailable() -> HostServiceBridge {
  HostServiceBridge::new(capabilities=HostServiceCapabilities::none(), handle=request => {
    HostServiceResponse::Unavailable(request.unavailable_message())
  })
}

///|
pub fn HostServiceBridge::dispatch(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> HostServiceResponse {
  if self.can_handle(request) {
    match self.dispatch_registered_service(request) {
      Some(response) => response
      None => (self.handle)(request)
    }
  } else {
    HostServiceResponse::Unavailable(request.unavailable_message())
  }
}

///|
pub fn HostServiceBridge::query_system_theme(
  self : HostServiceBridge,
) -> @core.ColorScheme? {
  match self.dispatch(HostServiceRequest::QuerySystemTheme) {
    HostServiceResponse::SystemTheme(scheme) => Some(scheme)
    _ => None
  }
}

///|
pub fn HostServiceBridge::environment_with_system_theme(
  self : HostServiceBridge,
  environment : @core.Environment,
) -> @core.Environment {
  match self.query_system_theme() {
    Some(scheme) => environment.with_color_scheme(scheme)
    None => environment
  }
}

///|
pub fn HostServiceBridge::can_handle(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> Bool {
  match request {
    Clipboard(_) => self.capabilities.clipboard
    ShowMenu(_) => self.capabilities.menus
    FileDialog(_) => self.capabilities.file_dialogs
    OpenUrl(_) => self.capabilities.open_url
    QuerySystemTheme => self.capabilities.system_theme
  }
}

///|
pub fn HostServiceRequest::unavailable_message(
  self : HostServiceRequest,
) -> String {
  match self {
    Clipboard(_) => "clipboard service is unavailable"
    ShowMenu(_) => "menu service is unavailable"
    FileDialog(_) => "file dialog service is unavailable"
    OpenUrl(_) => "open URL service is unavailable"
    QuerySystemTheme => "system theme service is unavailable"
  }
}

///|
pub fn HostServiceRequest::kind(self : HostServiceRequest) -> HostServiceKind {
  match self {
    Clipboard(_) => ClipboardService
    ShowMenu(_) => MenuService
    FileDialog(_) => FileDialogService
    OpenUrl(_) => OpenUrlService
    QuerySystemTheme => SystemThemeService
  }
}

///|
pub fn HostServiceHandler::new(
  kind~ : HostServiceKind,
  handle~ : (HostServiceRequest) -> HostServiceResponse,
) -> HostServiceHandler {
  { kind, handle }
}

///|
pub fn HostServiceBridge::register_service(
  self : HostServiceBridge,
  handler : HostServiceHandler,
) -> Unit {
  self.services = self.services.filter(existing => existing.kind != handler.kind)
  self.services.push(handler)
}

///|
pub fn HostServiceBridge::dispatch_registered_service(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> HostServiceResponse? {
  let kind = request.kind()
  for handler in self.services {
    if handler.kind == kind {
      return Some((handler.handle)(request))
    }
  }
  None
}

///|
pub fn PlatformChannelRequest::new(
  channel~ : String,
  operation~ : String,
  payload? : String = "",
) -> PlatformChannelRequest {
  { channel, operation, payload }
}

///|
pub fn PlatformChannelHandler::new(
  channel~ : String,
  handle~ : (PlatformChannelRequest) -> PlatformChannelResponse,
) -> PlatformChannelHandler {
  { channel, handle }
}

///|
pub fn PlatformChannelRegistry::new() -> PlatformChannelRegistry {
  { handlers: [] }
}

///|
pub fn PlatformChannelRegistry::register(
  self : PlatformChannelRegistry,
  handler : PlatformChannelHandler,
) -> Unit {
  self.handlers = self.handlers.filter(existing => {
    existing.channel != handler.channel
  })
  self.handlers.push(handler)
}

///|
pub fn PlatformChannelRegistry::can_dispatch(
  self : PlatformChannelRegistry,
  channel : String,
) -> Bool {
  self.handlers.any(handler => handler.channel == channel)
}

///|
pub fn PlatformChannelRegistry::dispatch(
  self : PlatformChannelRegistry,
  request : PlatformChannelRequest,
) -> PlatformChannelResponse {
  for handler in self.handlers {
    if handler.channel == request.channel {
      return (handler.handle)(request)
    }
  }
  PlatformChannelResponse::Unavailable(
    "platform channel is unavailable: " + request.channel,
  )
}

///|
pub fn HostServiceBridge::register_channel(
  self : HostServiceBridge,
  handler : PlatformChannelHandler,
) -> Unit {
  self.channels.register(handler)
}

///|
pub fn HostServiceBridge::dispatch_channel(
  self : HostServiceBridge,
  request : PlatformChannelRequest,
) -> PlatformChannelResponse {
  self.channels.dispatch(request)
}

///|
pub fn NativeAccessibilityBridgeKind::label(
  self : NativeAccessibilityBridgeKind,
) -> String {
  match self {
    AppKit => "appkit"
    UIAutomation => "uiautomation"
    ATSPI => "at-spi"
    TestBridge => "test"
  }
}

///|
pub fn NativeAccessibilityNode::from_semantics(
  node : @core.SemanticsNode,
  native_role? : String = native_accessibility_role(node.role),
) -> NativeAccessibilityNode {
  {
    element_id: node.element_id,
    role: node.role,
    native_role,
    label: node.label,
    value: node.value,
    frame: node.frame,
    focused: node.state.focused,
    disabled: node.state.disabled,
    selected: node.state.selected,
    checked: node.state.checked,
    actions: node.actions,
    children: node.children.map(child => {
      NativeAccessibilityNode::from_semantics(child)
    }),
  }
}

///|
pub fn accesskit_node_id_for_element(
  element_id : @core.ElementId,
) -> @accesskit.NodeId {
  @accesskit.NodeId::from_u64(element_id.value.to_uint64())
}

///|
pub fn accesskit_rect_from_core(rect : @core.Rect) -> @accesskit.Rect {
  @accesskit.Rect::new(
    rect.origin.x,
    rect.origin.y,
    rect.origin.x + rect.size.width,
    rect.origin.y + rect.size.height,
  )
}

///|
pub fn accesskit_role_from_semantics(
  role : @core.SemanticsRole,
) -> @accesskit.Role {
  match role {
    @core.SemanticsRole::None => @accesskit.Role::GenericContainer
    @core.SemanticsRole::Text => @accesskit.Role::TextRun
    @core.SemanticsRole::Button => @accesskit.Role::Button
    @core.SemanticsRole::Checkbox => @accesskit.Role::CheckBox
    @core.SemanticsRole::TextField => @accesskit.Role::TextInput
    @core.SemanticsRole::List => @accesskit.Role::List
    @core.SemanticsRole::ListItem => @accesskit.Role::ListItem
    @core.SemanticsRole::Grid => @accesskit.Role::Grid
    @core.SemanticsRole::ScrollView => @accesskit.Role::ScrollView
    @core.SemanticsRole::Switch => @accesskit.Role::Switch
    @core.SemanticsRole::Radio => @accesskit.Role::RadioButton
    @core.SemanticsRole::Slider => @accesskit.Role::Slider
    @core.SemanticsRole::Progress => @accesskit.Role::ProgressIndicator
    @core.SemanticsRole::Tab => @accesskit.Role::Tab
    @core.SemanticsRole::Dialog => @accesskit.Role::Dialog
    @core.SemanticsRole::Tooltip => @accesskit.Role::Tooltip
    @core.SemanticsRole::Menu => @accesskit.Role::Menu
    @core.SemanticsRole::ButtonGroup => @accesskit.Role::Group
    @core.SemanticsRole::Form => @accesskit.Role::Form
    @core.SemanticsRole::FormField => @accesskit.Role::GenericContainer
    @core.SemanticsRole::Tree => @accesskit.Role::Tree
    @core.SemanticsRole::TreeItem => @accesskit.Role::TreeItem
    @core.SemanticsRole::Group => @accesskit.Role::Group
  }
}

///|
pub fn accesskit_action_from_semantics(
  action : @core.SemanticsAction,
) -> @accesskit.Action {
  match action {
    @core.SemanticsAction::Activate => @accesskit.Action::Click
    @core.SemanticsAction::Focus => @accesskit.Action::Focus
    @core.SemanticsAction::SetText => @accesskit.Action::SetValue
    @core.SemanticsAction::Submit => @accesskit.Action::Click
    @core.SemanticsAction::Scroll => @accesskit.Action::ScrollIntoView
    @core.SemanticsAction::Select => @accesskit.Action::Click
    @core.SemanticsAction::Expand => @accesskit.Action::Expand
    @core.SemanticsAction::Collapse => @accesskit.Action::Collapse
    @core.SemanticsAction::Dismiss => @accesskit.Action::HideTooltip
  }
}

///|
pub fn accesskit_node_from_semantics(
  node : @core.SemanticsNode,
) -> @accesskit.Node {
  let access_node = @accesskit.Node::new(
    accesskit_role_from_semantics(node.role),
  )
  access_node.set_bounds(accesskit_rect_from_core(node.frame))
  if node.label != "" {
    access_node.set_label(node.label)
  }
  if node.value != "" {
    access_node.set_value(node.value)
  }
  if node.description != "" {
    access_node.set_description(node.description)
  }
  if node.state.disabled {
    access_node.set_disabled()
  }
  if node.state.selected {
    access_node.set_selected(true)
  }
  if node.state.checked {
    access_node.set_toggled(@accesskit.Toggled::True)
  }
  if node.state.expanded {
    access_node.set_expanded(true)
  }
  if node.state.invalid {
    access_node.set_invalid(@accesskit.Invalid::True)
  }
  if node.state.required {
    access_node.set_required()
  }
  for action in node.actions {
    access_node.add_action(accesskit_action_from_semantics(action))
  }
  access_node.set_children(
    node.children.map(child => accesskit_node_id_for_element(child.element_id)),
  )
  access_node
}

///|
pub fn accesskit_tree_update_from_semantics(
  node : @core.SemanticsNode,
) -> @accesskit.TreeUpdate {
  let root_id = accesskit_node_id_for_element(node.element_id)
  let update = @accesskit.TreeUpdate::new(@accesskit.TreeId::root(), root_id)
  update.set_tree(@accesskit.Tree::new(root_id))
  push_accesskit_semantics_node(update, node)
  update
}

///|
fn push_accesskit_semantics_node(
  update : @accesskit.TreeUpdate,
  node : @core.SemanticsNode,
) -> Unit {
  update.push_node(
    accesskit_node_id_for_element(node.element_id),
    accesskit_node_from_semantics(node),
  )
  for child in node.children {
    push_accesskit_semantics_node(update, child)
  }
}

///|
pub fn NativeAccessibilityNode::from_accesskit(
  update : @accesskit.TreeUpdate,
  element_id : @core.ElementId,
  role : @core.SemanticsRole,
) -> NativeAccessibilityNode {
  let id = accesskit_node_id_for_element(element_id)
  for node_update in update.nodes() {
    if node_update.id() == id {
      let node = node_update.node()
      return {
        element_id,
        role,
        native_role: node.role().to_string(),
        label: node.label().unwrap_or(""),
        value: node.value().unwrap_or(""),
        frame: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
        focused: false,
        disabled: node.is_disabled(),
        selected: node.is_selected().unwrap_or(false),
        checked: node.toggled() == Some(@accesskit.Toggled::True),
        actions: [],
        children: [],
      }
    }
  }
  NativeAccessibilityNode::from_semantics(@core.SemanticsNode::{
    element_id,
    role,
    label: "",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    children: [],
  })
}

///|
pub fn NativeAccessibilityActionRequest::new(
  element_id~ : @core.ElementId,
  action~ : @core.SemanticsAction,
  value? : String? = None,
) -> NativeAccessibilityActionRequest {
  { element_id, action, value }
}

///|
pub fn NativeAccessibilityBridge::new(
  kind~ : NativeAccessibilityBridgeKind,
  available? : Bool = true,
  snapshot? : (@core.SemanticsNode) -> @accesskit.TreeUpdate = node => {
    accesskit_tree_update_from_semantics(node)
  },
  perform? : (NativeAccessibilityActionRequest) -> NativeAccessibilityActionResult = request => {
    NativeAccessibilityActionResult::Unsupported(
      "native accessibility action is not handled: " +
      semantics_action_label(request.action),
    )
  },
) -> NativeAccessibilityBridge {
  { kind, available, snapshot, perform }
}

///|
pub fn NativeAccessibilityBridge::unavailable(
  kind~ : NativeAccessibilityBridgeKind,
  reason? : String = "native accessibility bridge is unavailable",
) -> NativeAccessibilityBridge {
  NativeAccessibilityBridge::new(kind~, available=false, perform=_request => {
    NativeAccessibilityActionResult::BridgeUnavailable(reason)
  })
}

///|
pub fn NativeAccessibilityBridge::snapshot_semantics(
  self : NativeAccessibilityBridge,
  node : @core.SemanticsNode,
) -> @accesskit.TreeUpdate? {
  if self.available {
    Some((self.snapshot)(node))
  } else {
    None
  }
}

///|
pub fn NativeAccessibilityBridge::snapshot_legacy_node(
  self : NativeAccessibilityBridge,
  node : @core.SemanticsNode,
) -> NativeAccessibilityNode? {
  if self.available {
    Some(NativeAccessibilityNode::from_semantics(node))
  } else {
    None
  }
}

///|
pub fn NativeAccessibilityBridge::perform_action(
  self : NativeAccessibilityBridge,
  request : NativeAccessibilityActionRequest,
) -> NativeAccessibilityActionResult {
  if self.available {
    (self.perform)(request)
  } else {
    NativeAccessibilityActionResult::BridgeUnavailable(
      "native accessibility bridge is unavailable: " + self.kind.label(),
    )
  }
}

///|
pub fn NativeAccessibilityBridge::semantics_action_bridge(
  kind~ : NativeAccessibilityBridgeKind,
  root~ : @core.SemanticsNode,
  dispatch~ : (@core.ElementId, @core.SemanticsAction, String?) -> Bool,
) -> NativeAccessibilityBridge {
  NativeAccessibilityBridge::new(
    kind~,
    snapshot=node => accesskit_tree_update_from_semantics(node),
    perform=request => {
      match find_semantics_node(root, request.element_id) {
        Some(node) =>
          if node.actions.any(action => action == request.action) {
            if dispatch(request.element_id, request.action, request.value) {
              NativeAccessibilityActionResult::Handled
            } else {
              NativeAccessibilityActionResult::Unsupported(
                "native accessibility action dispatch returned false: " +
                semantics_action_label(request.action),
              )
            }
          } else {
            NativeAccessibilityActionResult::Unsupported(
              "semantics node does not expose action: " +
              semantics_action_label(request.action),
            )
          }
        None =>
          NativeAccessibilityActionResult::ElementNotFound(request.element_id)
      }
    },
  )
}

///|
pub fn semantics_action_label(action : @core.SemanticsAction) -> String {
  match action {
    @core.SemanticsAction::Activate => "activate"
    @core.SemanticsAction::Focus => "focus"
    @core.SemanticsAction::SetText => "set-text"
    @core.SemanticsAction::Submit => "submit"
    @core.SemanticsAction::Scroll => "scroll"
    @core.SemanticsAction::Select => "select"
    @core.SemanticsAction::Expand => "expand"
    @core.SemanticsAction::Collapse => "collapse"
    @core.SemanticsAction::Dismiss => "dismiss"
  }
}

///|
pub fn find_semantics_node(
  node : @core.SemanticsNode,
  element_id : @core.ElementId,
) -> @core.SemanticsNode? {
  if node.element_id == element_id {
    Some(node)
  } else {
    for child in node.children {
      match find_semantics_node(child, element_id) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}

///|
fn native_accessibility_role(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "ignored"
    @core.SemanticsRole::Text => "staticText"
    @core.SemanticsRole::Button => "button"
    @core.SemanticsRole::Checkbox => "checkbox"
    @core.SemanticsRole::TextField => "textField"
    @core.SemanticsRole::List => "list"
    @core.SemanticsRole::ListItem => "listItem"
    @core.SemanticsRole::Grid => "grid"
    @core.SemanticsRole::ScrollView => "scrollArea"
    @core.SemanticsRole::Switch => "switch"
    @core.SemanticsRole::Radio => "radioButton"
    @core.SemanticsRole::Slider => "slider"
    @core.SemanticsRole::Progress => "progressIndicator"
    @core.SemanticsRole::Tab => "tab"
    @core.SemanticsRole::Dialog => "dialog"
    @core.SemanticsRole::Tooltip => "tooltip"
    @core.SemanticsRole::Menu => "menu"
    @core.SemanticsRole::ButtonGroup => "buttonGroup"
    @core.SemanticsRole::Form => "form"
    @core.SemanticsRole::FormField => "formField"
    @core.SemanticsRole::Tree => "tree"
    @core.SemanticsRole::TreeItem => "treeItem"
    @core.SemanticsRole::Group => "group"
  }
}

///|
pub fn HostInputContract::new(
  capabilities? : HostInputCapabilities = HostInputCapabilities::new(),
  coordinates? : HostCoordinatePolicy = HostCoordinatePolicy::logical(),
) -> HostInputContract {
  { capabilities, coordinates }
}

///|
pub fn InputHostState::new(
  focused? : Bool = false,
  modifiers? : @core.KeyModifiers = @core.KeyModifiers::none(),
  contract? : HostInputContract = HostInputContract::new(),
) -> InputHostState {
  { focused, modifiers, contract }
}

///|
pub fn InputHostState::focus(self : InputHostState) -> Unit {
  self.focused = true
}

///|
pub fn InputHostState::blur(self : InputHostState) -> Unit {
  self.focused = false
}

///|
pub fn InputHostState::set_modifiers(
  self : InputHostState,
  modifiers : @core.KeyModifiers,
) -> Unit {
  self.modifiers = modifiers
}

///|
pub fn InputHostState::capabilities(
  self : InputHostState,
) -> HostInputCapabilities {
  self.contract.capabilities
}

///|
pub fn InputHostState::coordinate_policy(
  self : InputHostState,
) -> HostCoordinatePolicy {
  self.contract.coordinates
}

///|
pub fn InputHostState::focus_event(
  self : InputHostState,
  focused~ : Bool,
  pointer_cancel_position? : @core.Point? = None,
) -> HostEvent? {
  if self.contract.capabilities.focus {
    self.focused = focused
    Some(
      HostEvent::Focus(HostFocusEvent::new(focused~, pointer_cancel_position~)),
    )
  } else {
    None
  }
}

///|
pub fn InputHostState::keyboard_event(
  self : InputHostState,
  key~ : String,
  text? : String? = None,
  pressed? : Bool = true,
  repeat? : Bool = false,
) -> HostEvent? {
  if self.contract.capabilities.keyboard {
    Some(
      HostEvent::Keyboard(
        @core.KeyboardEvent::new(
          key~,
          text~,
          pressed~,
          repeat~,
          modifiers=self.modifiers,
        ),
      ),
    )
  } else {
    None
  }
}

///|
pub fn InputHostState::text_event(
  self : InputHostState,
  event : @core.TextInputEvent,
) -> HostEvent? {
  if self.focused && self.contract.capabilities.text_input {
    Some(HostEvent::TextInput(event))
  } else {
    None
  }
}

///|
pub fn InputHostState::insert_text(
  self : InputHostState,
  text : String,
) -> HostEvent? {
  self.text_event(@core.TextInputEvent::InsertText(text))
}

///|
pub fn SurfaceHostState::new(
  metrics~ : HostSurfaceMetrics,
  owns_surface? : Bool = false,
  can_reconfigure? : Bool = true,
) -> SurfaceHostState {
  { metrics, owns_surface, can_reconfigure }
}

///|
pub fn SurfaceHostState::resize(
  self : SurfaceHostState,
  metrics : HostSurfaceMetrics,
) -> HostEvent {
  self.metrics = metrics
  HostEvent::Resized(metrics)
}

///|
pub fn HostScrollEvent::new(
  position~ : @core.Point,
  delta~ : HostScrollDelta,
  phase? : HostScrollPhase = HostScrollPhase::Moved,
) -> HostScrollEvent {
  { position, delta, phase }
}

///|
pub fn HostScrollDelta::to_logical_pixels(
  self : HostScrollDelta,
  line_extent? : Double = 40.0,
) -> @core.Point {
  match self {
    Pixels(delta) => delta
    Lines(delta) =>
      @core.Point::new(x=delta.x * line_extent, y=delta.y * line_extent)
  }
}

///|
pub fn HostScrollEvent::to_pointer_event(
  self : HostScrollEvent,
) -> @core.PointerEvent {
  @core.PointerEvent::new(
    position=self.position,
    phase=@core.PointerPhase::Move,
    wheel_delta=self.delta.to_logical_pixels(),
  )
}

///|
pub fn HostFocusEvent::new(
  focused~ : Bool,
  pointer_cancel_position? : @core.Point? = None,
) -> HostFocusEvent {
  { focused, pointer_cancel_position }
}

///|
pub fn HostFocusEvent::to_core(self : HostFocusEvent) -> @core.AppEvent? {
  match (self.focused, self.pointer_cancel_position) {
    (false, Some(position)) =>
      Some(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(position~, phase=@core.PointerPhase::Cancel),
        ),
      )
    _ => None
  }
}

///|
pub fn SurfaceHostState::logical_size(self : SurfaceHostState) -> @core.Size {
  self.metrics.logical_size
}

///|
pub fn RedrawScheduler::new(schedule~ : () -> Unit) -> RedrawScheduler {
  { redraw_requested: false, schedule }
}

///|
pub fn RedrawScheduler::request(self : RedrawScheduler) -> Unit {
  if !self.redraw_requested {
    self.redraw_requested = true
    (self.schedule)()
  }
}

///|
pub fn RedrawScheduler::begin_redraw(self : RedrawScheduler) -> Unit {
  self.redraw_requested = false
}

///|
pub fn RedrawScheduler::set_schedule(
  self : RedrawScheduler,
  schedule : () -> Unit,
) -> Unit {
  self.schedule = schedule
}

///|
pub fn RedrawScheduler::is_redraw_requested(self : RedrawScheduler) -> Bool {
  self.redraw_requested
}

///|
pub fn HostRuntimeDriver::new(
  runtime~ : @core.AppRuntime,
  schedule_redraw~ : () -> Unit,
) -> HostRuntimeDriver {
  let driver = {
    runtime,
    scheduler: RedrawScheduler::new(schedule=schedule_redraw),
    close_requested: false,
  }
  runtime.set_redraw_callback(() => driver.request_redraw())
  driver
}

///|
pub fn HostRuntimeDriver::dispatch(
  self : HostRuntimeDriver,
  event : HostEvent,
) -> HostEventResult {
  match event {
    Resized(metrics) => {
      self.runtime.dispatch_event(@core.AppEvent::Resize(metrics.logical_size))
      self.request_redraw()
    }
    Pointer(event) => {
      self.runtime.dispatch_event(@core.AppEvent::Pointer(event))
      self.request_redraw_if_needed()
    }
    Scroll(event) => {
      self.runtime.dispatch_event(
        @core.AppEvent::Pointer(event.to_pointer_event()),
      )
      self.request_redraw_if_needed()
    }
    Focus(event) =>
      match event.to_core() {
        Some(core_event) => {
          self.runtime.dispatch_event(core_event)
          self.request_redraw_if_needed()
        }
        None => ()
      }
    Keyboard(event) => {
      self.runtime.dispatch_event(@core.AppEvent::Keyboard(event))
      self.request_redraw_if_needed()
    }
    TextInput(event) => {
      self.runtime.dispatch_event(@core.AppEvent::TextInput(event))
      self.request_redraw_if_needed()
    }
    DragDrop(event) => {
      self.runtime.dispatch_event(@core.AppEvent::DragDrop(event))
      self.request_redraw_if_needed()
    }
    ThemeChanged(scheme) => {
      self.runtime.set_environment(
        self.runtime.environment().with_color_scheme(scheme),
      )
      self.request_redraw_if_needed()
    }
    Command(intent) =>
      if self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
    RedrawRequested => {
      self.begin_redraw()
      self.finish_redraw()
    }
    CloseRequested => {
      self.close_requested = true
      self.runtime.dispatch_event(@core.AppEvent::CloseRequested)
    }
  }
  self.event_result()
}

///|
pub fn HostRuntimeDriver::dispatch_command_with_services(
  self : HostRuntimeDriver,
  intent : @core.CommandIntent,
  services : HostServiceBridge,
) -> HostEventResult {
  match intent {
    @core.CommandIntent::Copy | @core.CommandIntent::Cut => {
      let result = self.runtime.dispatch_focused_text_command(intent)
      if result.handled {
        match result.clipboard_text {
          Some(text) =>
            ignore(
              services.dispatch(
                HostServiceRequest::Clipboard(
                  HostClipboardRequest::WriteText(text),
                ),
              ),
            )
          None => ()
        }
        self.request_redraw_if_needed()
      } else if self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
    }
    @core.CommandIntent::Paste => {
      let mut handled = false
      match
        services.dispatch(
          HostServiceRequest::Clipboard(HostClipboardRequest::ReadText),
        ) {
        HostServiceResponse::ClipboardText(text) => {
          let result = self.runtime.dispatch_focused_text_command(
            intent,
            paste_text=Some(text),
          )
          if result.handled {
            handled = true
          }
          self.request_redraw_if_needed()
        }
        HostServiceResponse::Pending(_) => handled = true
        _ => ()
      }
      if !handled && self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
    }
    _ =>
      if self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
  }
  self.event_result()
}

///|
pub fn HostRuntimeDriver::dispatch_keyboard_with_services(
  self : HostRuntimeDriver,
  event : @core.KeyboardEvent,
  services : HostServiceBridge,
) -> HostEventResult {
  match keyboard_service_command_intent(event) {
    Some(intent) => self.dispatch_command_with_services(intent, services)
    None => self.dispatch(HostEvent::Keyboard(event))
  }
}

///|
pub fn HostRuntimeDriver::show_context_menu(
  self : HostRuntimeDriver,
  services : HostServiceBridge,
) -> HostEventResult {
  match
    services.dispatch(
      HostServiceRequest::ShowMenu(self.context_menu_commands()),
    ) {
    HostServiceResponse::MenuCommand(intent) =>
      ignore(self.dispatch_command_with_services(intent, services))
    _ => ()
  }
  self.event_result()
}

///|
fn HostRuntimeDriver::context_menu_commands(
  self : HostRuntimeDriver,
) -> Array[@core.ActionCommand] {
  let commands = self.runtime.action_commands()
  if self.runtime.focused_text_input().focused {
    merge_context_menu_commands(@core.default_text_commands(), commands)
  } else {
    commands
  }
}

///|
fn merge_context_menu_commands(
  primary : Array[@core.ActionCommand],
  secondary : Array[@core.ActionCommand],
) -> Array[@core.ActionCommand] {
  let commands : Array[@core.ActionCommand] = []
  for command in primary {
    commands.push(command)
  }
  for command in secondary {
    if !commands.any(existing => existing.intent == command.intent) {
      commands.push(command)
    }
  }
  commands
}

///|
fn keyboard_service_command_intent(
  event : @core.KeyboardEvent,
) -> @core.CommandIntent? {
  if !event.pressed ||
    event.repeat ||
    event.modifiers.alt ||
    event.modifiers.shift ||
    !(event.modifiers.meta || event.modifiers.control) {
    None
  } else if event.key == "c" || event.key == "C" {
    Some(@core.CommandIntent::Copy)
  } else if event.key == "x" || event.key == "X" {
    Some(@core.CommandIntent::Cut)
  } else if event.key == "v" || event.key == "V" {
    Some(@core.CommandIntent::Paste)
  } else {
    None
  }
}

///|
pub fn HostRuntimeDriver::request_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.request()
}

///|
pub fn HostRuntimeDriver::set_redraw_scheduler(
  self : HostRuntimeDriver,
  schedule_redraw : () -> Unit,
) -> Unit {
  self.scheduler.set_schedule(schedule_redraw)
}

///|
pub fn HostRuntimeDriver::request_redraw_if_needed(
  self : HostRuntimeDriver,
) -> Unit {
  if self.runtime.needs_redraw() {
    self.request_redraw()
  }
}

///|
pub fn HostRuntimeDriver::begin_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.begin_redraw()
}

///|
pub fn HostRuntimeDriver::finish_redraw(self : HostRuntimeDriver) -> Unit {
  self.runtime.dispatch_event(
    @core.AppEvent::Redraw(@core.RedrawReason::Explicit),
  )
}

///|
pub fn HostRuntimeDriver::draw_commands(
  self : HostRuntimeDriver,
) -> Array[@core.DrawCommand] {
  self.runtime.draw_commands()
}

///|
pub fn HostRuntimeDriver::environment(
  self : HostRuntimeDriver,
) -> @core.Environment {
  self.runtime.environment()
}

///|
pub fn HostRuntimeDriver::set_environment(
  self : HostRuntimeDriver,
  environment : @core.Environment,
) -> Unit {
  self.runtime.set_environment(environment)
}

///|
pub fn HostRuntimeDriver::set_text_system(
  self : HostRuntimeDriver,
  text_system : @core.TextSystem,
) -> Unit {
  self.runtime.set_text_system(text_system)
}

///|
pub fn HostRuntimeDriver::focused_text_input(
  self : HostRuntimeDriver,
) -> @core.TextInputState {
  self.runtime.focused_text_input()
}

///|
pub fn HostRuntimeDriver::size(self : HostRuntimeDriver) -> @core.Size {
  self.runtime.size()
}

///|
pub fn HostRuntimeDriver::event_result(
  self : HostRuntimeDriver,
) -> HostEventResult {
  {
    needs_rebuild: self.runtime.needs_rebuild(),
    needs_redraw: self.runtime.needs_redraw(),
    redraw_requested: self.scheduler.is_redraw_requested(),
    close_requested: self.close_requested,
  }
}

///|
pub fn HostEvent::to_core(self : HostEvent) -> @core.AppEvent? {
  match self {
    Resized(metrics) => Some(@core.AppEvent::Resize(metrics.logical_size))
    Pointer(event) => Some(@core.AppEvent::Pointer(event))
    Scroll(event) => Some(@core.AppEvent::Pointer(event.to_pointer_event()))
    Focus(event) => event.to_core()
    Keyboard(event) => Some(@core.AppEvent::Keyboard(event))
    TextInput(event) => Some(@core.AppEvent::TextInput(event))
    DragDrop(event) => Some(@core.AppEvent::DragDrop(event))
    ThemeChanged(_) => None
    Command(_) => None
    RedrawRequested =>
      Some(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
    CloseRequested => Some(@core.AppEvent::CloseRequested)
  }
}
