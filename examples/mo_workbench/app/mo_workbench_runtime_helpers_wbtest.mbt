///|
fn runtime(
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @runtime.AppRuntime {
  WorkbenchModel::new().runtime(width~, height~)
}

///|
fn WorkbenchModel::runtime(
  self : WorkbenchModel,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @runtime.AppRuntime {
  self.runtime_with_transport(
    PiTransportRuntime::unavailable(),
    width~,
    height~,
  )
}

///|
fn WorkbenchModel::runtime_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @runtime.AppRuntime {
  self.runtime_with_agent_connectors(transport_runtime, [], width~, height~)
}

///|
fn WorkbenchModel::runtime_with_agent_connectors(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
  connector_runtimes : Array[AgentConnectorRuntime],
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=self.program_with_agent_connectors(
      transport_runtime, connector_runtimes,
    ),
    width~,
    height~,
  )
}
