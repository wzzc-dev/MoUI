///|
pub struct LinuxATSPIBinding {
  priv mut root : @core.SemanticsNode?
  priv dispatch : (@core.ElementId, @core.SemanticsAction, String?) -> Bool
  priv mut published_node_count : Int
  priv mut action_dispatch_count : Int
  priv mut disposed : Bool
}

///|
pub(all) struct LinuxATSPIBindingDiagnostics {
  native_binding_ready : Bool
  published_node_count : Int
  action_dispatch_count : Int
  disposed : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn LinuxATSPIBinding::new(
  root~ : @core.SemanticsNode,
  dispatch~ : (@core.ElementId, @core.SemanticsAction, String?) -> Bool,
) -> LinuxATSPIBinding {
  {
    root: Some(root),
    dispatch,
    published_node_count: 0,
    action_dispatch_count: 0,
    disposed: false,
  }
}

///|
pub fn LinuxATSPIBinding::publish_semantics(
  self : LinuxATSPIBinding,
  root : @core.SemanticsNode,
) -> LinuxATSPIBindingDiagnostics {
  if !self.disposed {
    self.root = Some(root)
    let _ = @host.accesskit_tree_update_from_semantics(root)
    self.published_node_count = linux_semantics_node_count(root)
  }
  self.diagnostics()
}

///|
pub fn LinuxATSPIBinding::perform_action(
  self : LinuxATSPIBinding,
  request : @host.NativeAccessibilityActionRequest,
) -> @host.NativeAccessibilityActionResult {
  if self.disposed {
    return @host.NativeAccessibilityActionResult::BridgeUnavailable(
      "Linux AT-SPI binding is disposed",
    )
  }
  match self.root {
    Some(root) =>
      match @host.find_semantics_node(root, request.element_id) {
        Some(node) =>
          if node.actions.any(action => action == request.action) {
            if (self.dispatch)(
              request.element_id,
              request.action,
              request.value,
            ) {
              self.action_dispatch_count = self.action_dispatch_count + 1
              @host.NativeAccessibilityActionResult::Handled
            } else {
              @host.NativeAccessibilityActionResult::Unsupported(
                "AT-SPI action dispatch returned false: " +
                @host.semantics_action_label(request.action),
              )
            }
          } else {
            @host.NativeAccessibilityActionResult::Unsupported(
              "AT-SPI semantics node does not expose action: " +
              @host.semantics_action_label(request.action),
            )
          }
        None =>
          @host.NativeAccessibilityActionResult::ElementNotFound(
            request.element_id,
          )
      }
    None =>
      @host.NativeAccessibilityActionResult::BridgeUnavailable(
        "Linux AT-SPI binding has no published semantics tree",
      )
  }
}

///|
pub fn LinuxATSPIBinding::dispose(
  self : LinuxATSPIBinding,
) -> LinuxATSPIBindingDiagnostics {
  self.root = None
  self.published_node_count = 0
  self.disposed = true
  self.diagnostics()
}

///|
pub fn LinuxATSPIBinding::diagnostics(
  self : LinuxATSPIBinding,
) -> LinuxATSPIBindingDiagnostics {
  {
    native_binding_ready: true,
    published_node_count: self.published_node_count,
    action_dispatch_count: self.action_dispatch_count,
    disposed: self.disposed,
  }
}

///|
fn linux_semantics_node_count(node : @core.SemanticsNode) -> Int {
  let mut count = 1
  for child in node.children {
    count = count + linux_semantics_node_count(child)
  }
  count
}
