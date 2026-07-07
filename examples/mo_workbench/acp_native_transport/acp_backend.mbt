///|
pub struct AcpNativeTransportConfig {
  command : String
  args : Array[String]
  process_cwd : String
  workspace : String
}

///|
pub fn AcpNativeTransportConfig::new(
  command~ : String,
  args? : Array[String] = [],
  process_cwd? : String = "",
  workspace? : String = ".",
) -> AcpNativeTransportConfig {
  { command, args, process_cwd, workspace }
}

///|
pub struct AcpBackendOwner {
  config : AcpNativeTransportConfig
  queue : @async.Queue[AcpWork]
}

///|
enum AcpWork {
  RunCommands(Array[@app.AgentCommand], (@app.AgentEvent) -> Unit)
}

///|
pub struct AcpBackendBundle {
  runtime : @app.AgentBackendRuntime
  owner : AcpBackendOwner
}

///|
pub fn acp_backend_bundle(
  config : AcpNativeTransportConfig,
) -> AcpBackendBundle {
  let owner = { config, queue: @async.Queue(kind=Unbounded) }
  { runtime: acp_backend_runtime(owner), owner }
}

///|
pub fn acp_backend_bundle_from_settings(
  file : @app.MoWorkbenchSettingsFile,
) -> AcpBackendBundle? {
  if file.agent_backend != Some("acp") {
    return None
  }
  let command = match file.acp_command {
    Some(value) => value.trim().to_owned()
    None => ""
  }
  if command.is_empty() {
    return None
  }
  let args = match file.acp_args {
    Some(value) => acp_helper_args(value)
    None => []
  }
  let process_cwd = match file.acp_process_cwd {
    Some(value) => value.trim().to_owned()
    None => ""
  }
  Some(
    acp_backend_bundle(
      AcpNativeTransportConfig::new(
        command~,
        args~,
        process_cwd~,
        workspace=file.mo_workbench_workspace,
      ),
    ),
  )
}

///|
fn acp_backend_runtime(owner : AcpBackendOwner) -> @app.AgentBackendRuntime {
  @app.agent_backend_runtime(run=(commands, emit) => {
    ignore(
      owner.queue.try_put(AcpWork::RunCommands(commands, emit)) catch {
        _ => false
      },
    )
  })
}
