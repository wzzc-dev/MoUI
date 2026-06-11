///|
fn WorkbenchModel::append_ingested_event(
  self : WorkbenchModel,
  event : AgentEvent,
  status~ : String,
) -> WorkbenchModel {
  let events = self.events.copy()
  events.push(event)
  { ..self, events, last_status: status }.scroll_main_to_latest()
}

///|
fn WorkbenchModel::update_active_session_for_pi(
  self : WorkbenchModel,
  status~ : String,
  active_task~ : String,
  unread_events? : Int? = None,
  summary? : String? = None,
) -> WorkbenchModel {
  let sessions = self.sessions.map(session => {
    if session.id == self.selected_session_id {
      {
        ..session,
        status,
        active_task,
        unread_events: unread_events.unwrap_or(session.unread_events),
        summary: summary.unwrap_or(session.summary),
      }
    } else {
      session
    }
  })
  { ..self, sessions, }
}

///|
fn WorkbenchModel::next_command_id(self : WorkbenchModel) -> Int {
  let mut next = self.commands.length() + 1
  for command in self.commands {
    if command.id >= next {
      next = command.id + 1
    }
  }
  next
}

///|
fn WorkbenchModel::command_id_for_tool_call(
  self : WorkbenchModel,
  tool_call_id : String,
) -> Int? {
  if tool_call_id == "" {
    None
  } else {
    for command in self.commands {
      if command.tool_call_id == tool_call_id {
        return Some(command.id)
      }
    }
    None
  }
}

///|
fn WorkbenchModel::mark_tool_command_complete(
  self : WorkbenchModel,
  tool_call_id : String,
  tool_name : String,
  exit_code : Int,
  is_error : Bool,
  output : String,
  output_path : String,
  output_truncated : Bool,
) -> WorkbenchModel {
  let status = if is_error || exit_code != 0 { "failed" } else { "passed" }
  let mut found = false
  let commands = self.commands.map(command => {
    if tool_call_id != "" && command.tool_call_id == tool_call_id {
      found = true
      {
        ..command,
        status,
        exit_code: Some(exit_code),
        output,
        output_path,
        output_truncated,
      }
    } else {
      command
    }
  })
  if found {
    { ..self, commands, }
  } else {
    let next = commands.copy()
    next.push(
      CommandRun::new(
        id=self.next_command_id(),
        command=tool_name,
        cwd=self.active_session().project_path,
        status~,
        exit_code=Some(exit_code),
        tool_call_id~,
        output~,
        output_path~,
        output_truncated~,
      ),
    )
    { ..self, commands: next }
  }
}

///|
fn WorkbenchModel::mark_next_shell_command_complete(
  self : WorkbenchModel,
  session_id : String,
  exit_code : Int?,
  cancelled : Bool,
  output_path : String,
  output : String,
  output_truncated : Bool,
) -> WorkbenchModel {
  let session = self.session_for_id(session_id)
  let status = shell_command_status(exit_code, cancelled)
  let mut target_id : Int? = None
  for command in self.commands {
    if target_id is None && command.is_active_shell_for_session(session) {
      target_id = Some(command.id)
    }
  }
  match target_id {
    Some(id) => {
      let commands = self.commands.map(command => {
        if command.id == id {
          {
            ..command,
            status,
            exit_code,
            output_path,
            output,
            output_truncated,
          }
        } else {
          command
        }
      })
      { ..self, commands, }
    }
    None =>
      self.upsert_command(
        CommandRun::new(
          id=self.next_command_id(),
          command="Pi RPC bash",
          cwd=session.project_path,
          status~,
          exit_code~,
          output_path~,
          output~,
          output_truncated~,
        ),
      )
  }
}

///|
fn WorkbenchModel::append_bash_diagnostics(
  self : WorkbenchModel,
  exit_code : Int?,
  cancelled : Bool,
  truncated : Bool,
  full_output_path : String,
) -> WorkbenchModel {
  let diagnostics = self.diagnostics.copy()
  if cancelled {
    diagnostics.push(
      DiagnosticItem::new(
        source="Pi bash",
        severity="warning",
        message="bash command was cancelled",
      ),
    )
  } else {
    match exit_code {
      Some(0) => ()
      Some(code) =>
        diagnostics.push(
          DiagnosticItem::new(
            source="Pi bash",
            severity="error",
            message="bash exited with code " + code.to_string(),
          ),
        )
      None =>
        diagnostics.push(
          DiagnosticItem::new(
            source="Pi bash",
            severity="error",
            message="bash response did not include an exit code",
          ),
        )
    }
  }
  if truncated {
    diagnostics.push(
      DiagnosticItem::new(
        source="Pi bash",
        severity="warning",
        message=if full_output_path == "" {
          "bash output was truncated"
        } else {
          "bash output was truncated: " + full_output_path
        },
      ),
    )
  }
  { ..self, diagnostics, }
}

///|
fn shell_command_status(exit_code : Int?, cancelled : Bool) -> String {
  if cancelled {
    "cancelled"
  } else {
    match exit_code {
      Some(0) => "passed"
      _ => "failed"
    }
  }
}

///|
fn bash_response_detail(
  session_id : String,
  exit_code : Int?,
  cancelled : Bool,
  truncated : Bool,
  full_output_path : String,
  output : String,
) -> String {
  let state = if cancelled {
    "cancelled"
  } else {
    "exit code " + bash_exit_code_label(exit_code)
  }
  let truncated_suffix = if truncated && full_output_path != "" {
    " - truncated output at " + full_output_path
  } else if truncated {
    " - output truncated"
  } else {
    ""
  }
  let output_suffix = if output == "" { "" } else { " - " + output }
  session_id + ": " + state + truncated_suffix + output_suffix
}

///|
fn bash_exit_code_label(exit_code : Int?) -> String {
  match exit_code {
    Some(code) => code.to_string()
    None => "unknown"
  }
}
