///|
/// Stable semantic control surface for an Agent transport.
///
/// The trait deliberately contains no coordinate input, global commands,
/// runtime counters, frame capture, activation state, or subscriptions.
pub(open) trait AgentHost {
  fn read_semantics(Self, since : @core.SemanticsGeneration?) -> Result[
    AgentSemanticsRead,
    AgentReadError,
  ]
  fn perform_action(Self, request : AgentActionRequest) -> Result[
    AgentActionReceipt,
    AgentActionError,
  ]
}

///|
/// Opt-in diagnostics surface. It does not inherit from `AgentHost` and is not
/// exposed by the default MCP registry.
pub(open) trait AgentDiagnosticsHost {
  fn runtime_state(Self) -> Result[RuntimeStateSnapshot, AgentDiagnosticsError]
  fn paint_summary(Self) -> Result[PaintSummary, AgentDiagnosticsError]
  fn dispatch_event(Self, event : @core.AppEvent) -> Result[
    DiagnosticsDispatchResult,
    AgentDiagnosticsError,
  ]
  fn dispatch_command(Self, intent : @core.CommandIntent) -> Result[
    DiagnosticsDispatchResult,
    AgentDiagnosticsError,
  ]
}
