///|
pub struct LinuxATSPIBinding {
  priv published_nodes : Map[@core.SemanticsNodeId, Unit]
  priv dispatch : (@host.NativeAccessibilityActionRequest) -> @host.NativeAccessibilityActionResult
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
  dispatch~ : (@host.NativeAccessibilityActionRequest) -> @host.NativeAccessibilityActionResult,
) -> LinuxATSPIBinding {
  {
    published_nodes: Map([]),
    dispatch,
    action_dispatch_count: 0,
    disposed: false,
  }
}

///|
pub fn LinuxATSPIBinding::publish_semantics(
  self : LinuxATSPIBinding,
  read : @runtime.SemanticsRead,
) -> LinuxATSPIBindingDiagnostics {
  if self.disposed {
    return self.diagnostics()
  }
  ignore(@host.accesskit_update_from_semantics_read(read))
  match read {
    @runtime.SemanticsRead::Full(snapshot) => {
      self.published_nodes.clear()
      for node in snapshot.nodes() {
        self.published_nodes[node.node_id] = ()
      }
    }
    @runtime.SemanticsRead::Delta(delta) => {
      for node_id in delta.removed() {
        self.published_nodes.remove(node_id)
      }
      for node in delta.upserted() {
        self.published_nodes[node.node_id] = ()
      }
    }
    @runtime.SemanticsRead::Unchanged(_) => ()
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
  let result = (self.dispatch)(request)
  match result {
    @host.NativeAccessibilityActionResult::Handled(_) =>
      self.action_dispatch_count = self.action_dispatch_count + 1
    _ => ()
  }
  result
}

///|
pub fn LinuxATSPIBinding::dispose(
  self : LinuxATSPIBinding,
) -> LinuxATSPIBindingDiagnostics {
  self.published_nodes.clear()
  self.disposed = true
  self.diagnostics()
}

///|
pub fn LinuxATSPIBinding::diagnostics(
  self : LinuxATSPIBinding,
) -> LinuxATSPIBindingDiagnostics {
  {
    native_binding_ready: true,
    published_node_count: self.published_nodes.length(),
    action_dispatch_count: self.action_dispatch_count,
    disposed: self.disposed,
  }
}
