///|
pub struct LinuxATSPIBinding {
  priv published_nodes : Map[@core.SemanticsNodeId, Unit]
  priv dispatch : (@runtime.PerformSemanticsActionRequest) -> @accesskit_bridge.AccessKitActionResult
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
  dispatch~ : (@runtime.PerformSemanticsActionRequest) -> @accesskit_bridge.AccessKitActionResult,
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
  ignore(@accesskit_bridge.accesskit_update_from_semantics_read(read))
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
  request : @runtime.PerformSemanticsActionRequest,
) -> @accesskit_bridge.AccessKitActionResult {
  if self.disposed {
    return @accesskit_bridge.AccessKitActionResult::BridgeUnavailable(
      "Linux AT-SPI binding is disposed",
    )
  }
  let result = (self.dispatch)(request)
  match result {
    @accesskit_bridge.AccessKitActionResult::Handled(_) =>
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
    // This binding currently mirrors committed nodes in memory only. It does
    // not become native until the objects are exported through AT-SPI D-Bus.
    native_binding_ready: false,
    published_node_count: self.published_nodes.length(),
    action_dispatch_count: self.action_dispatch_count,
    disposed: self.disposed,
  }
}
