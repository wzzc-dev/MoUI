///|
/// Agent host permanently bound to one `AppRuntime` lifetime.
pub struct RuntimeAgentHost {
  runtime : @runtime.AppRuntime
}

///|
pub fn RuntimeAgentHost::new(runtime : @runtime.AppRuntime) -> RuntimeAgentHost {
  { runtime, }
}

///|
pub impl AgentHost for RuntimeAgentHost with fn read_semantics(self, since) {
  let result = match since {
    Some(generation) => self.runtime.read_semantics(since=generation)
    None => self.runtime.read_semantics()
  }
  match result {
    Ok(read) => Ok(agent_semantics_read(read))
    Err(@runtime.SemanticsReadError::RuntimeClosed) =>
      Err(AgentReadError::HostClosed)
  }
}

///|
pub impl AgentHost for RuntimeAgentHost with fn perform_action(self, request) {
  match self.runtime.perform_semantics_action(runtime_action_request(request)) {
    Ok(receipt) => Ok(agent_action_receipt(receipt))
    Err(error) => Err(agent_action_error(error))
  }
}

///|
fn RuntimeAgentHost::diagnostics_open(
  self : RuntimeAgentHost,
) -> Result[Unit, AgentDiagnosticsError] {
  match self.runtime.read_semantics() {
    Ok(_) => Ok(())
    Err(@runtime.SemanticsReadError::RuntimeClosed) =>
      Err(AgentDiagnosticsError::HostClosed)
  }
}

///|
pub impl AgentDiagnosticsHost for RuntimeAgentHost with fn runtime_state(self) {
  match self.diagnostics_open() {
    Err(error) => Err(error)
    Ok(_) => {
      let snapshot = self.runtime.program_runtime_snapshot()
      Ok({
        dispatched_count: snapshot.dispatched_count(),
        update_count: snapshot.update_count(),
        pending_message_count: snapshot.pending_message_count(),
        active_subscription_count: snapshot.active_subscription_count(),
        active_effect_task_count: snapshot.active_effect_task_count(),
      })
    }
  }
}

///|
pub impl AgentDiagnosticsHost for RuntimeAgentHost with fn paint_summary(self) {
  match self.diagnostics_open() {
    Err(error) => Err(error)
    Ok(_) => {
      let commands = self.runtime.draw_commands()
      let texts : Array[String] = []
      for command in commands {
        match command {
          @core.DrawCommand::DrawText(run) => texts.push(run.text)
          _ => ()
        }
      }
      Ok({ texts, draw_command_count: commands.length() })
    }
  }
}

///|
pub impl AgentDiagnosticsHost for RuntimeAgentHost with fn dispatch_event(
  self,
  event,
) {
  match self.diagnostics_open() {
    Err(error) => Err(error)
    Ok(_) => {
      self.runtime.dispatch_event(event)
      Ok({ accepted: true, reason: None })
    }
  }
}

///|
pub impl AgentDiagnosticsHost for RuntimeAgentHost with fn dispatch_command(
  self,
  intent,
) {
  match self.diagnostics_open() {
    Err(error) => Err(error)
    Ok(_) => {
      let accepted = self.runtime.dispatch_command(intent)
      Ok({
        accepted,
        reason: if accepted {
          None
        } else {
          Some("runtime rejected command")
        },
      })
    }
  }
}
