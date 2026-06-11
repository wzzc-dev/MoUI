///|
fn transcript_items_from_messages(
  values : Array[Json],
) -> Array[TranscriptItem] {
  let items : Array[TranscriptItem] = []
  for index, value in values {
    for item in transcript_items_from_json(index, value) {
      items.push(item)
    }
  }
  items
}

///|
fn pi_command_infos_from_values(values : Array[Json]) -> Array[PiCommandInfo] {
  let commands : Array[PiCommandInfo] = []
  for index, value in values {
    commands.push(pi_command_info_from_json(index, value))
  }
  commands
}

///|
fn pi_model_infos_from_values(values : Array[Json]) -> Array[PiModelInfo] {
  let models : Array[PiModelInfo] = []
  for index, value in values {
    models.push(pi_model_info_from_json(index, value))
  }
  models
}

///|
fn pi_fork_messages_from_values(values : Array[Json]) -> Array[PiForkMessage] {
  let messages : Array[PiForkMessage] = []
  for index, value in values {
    messages.push(pi_fork_message_from_json(index, value))
  }
  messages
}

///|
fn pi_session_stats_from_data(
  data : Map[String, Json],
) -> PiSessionStatsSnapshot {
  let tokens = json_object(data, "tokens").unwrap_or({})
  let context = json_object(data, "contextUsage").unwrap_or({})
  PiSessionStatsSnapshot::new(
    session_file=json_string(data, "sessionFile").unwrap_or(""),
    session_id=json_string(data, "sessionId").unwrap_or(""),
    user_messages=json_int(data, "userMessages").unwrap_or(0),
    assistant_messages=json_int(data, "assistantMessages").unwrap_or(0),
    tool_calls=json_int(data, "toolCalls").unwrap_or(0),
    tool_results=json_int(data, "toolResults").unwrap_or(0),
    total_messages=json_int(data, "totalMessages").unwrap_or(0),
    token_input=json_int(tokens, "input").unwrap_or(0),
    token_output=json_int(tokens, "output").unwrap_or(0),
    token_cache_read=json_int(tokens, "cacheRead").unwrap_or(0),
    token_cache_write=json_int(tokens, "cacheWrite").unwrap_or(0),
    token_total=json_int(tokens, "total").unwrap_or(0),
    cost=json_number(data, "cost").unwrap_or(0.0),
    context_tokens=json_int(context, "tokens"),
    context_window=json_int(context, "contextWindow").unwrap_or(0),
    context_percent=json_number(context, "percent"),
  )
}

///|
fn pi_command_info_from_json(index : Int, value : Json) -> PiCommandInfo {
  match value {
    Object(fields) => {
      let source_info = json_object(fields, "sourceInfo").unwrap_or({})
      PiCommandInfo::new(
        name=json_string(fields, "name").unwrap_or(
          "command-" + index.to_string(),
        ),
        source=json_string(fields, "source").unwrap_or("unknown"),
        description=json_string(fields, "description").unwrap_or(""),
        source_scope=json_string(source_info, "scope").unwrap_or(""),
        source_path=json_string(source_info, "path").unwrap_or(""),
      )
    }
    _ =>
      PiCommandInfo::new(
        name="command-" + index.to_string(),
        source="unknown",
        description=value.stringify(),
        source_scope="",
        source_path="",
      )
  }
}

///|
fn pi_model_info_from_json(index : Int, value : Json) -> PiModelInfo {
  match value {
    Object(fields) => {
      let provider = json_string(fields, "provider").unwrap_or("")
      let id = json_string(fields, "id").unwrap_or(
        json_string(fields, "model").unwrap_or(
          json_string(fields, "name").unwrap_or("model-" + index.to_string()),
        ),
      )
      let name = json_string(fields, "name").unwrap_or("")
      PiModelInfo::new(provider~, id~, name~)
    }
    _ =>
      PiModelInfo::new(
        provider="",
        id="model-" + index.to_string(),
        name=value.stringify(),
      )
  }
}

///|
fn pi_fork_message_from_json(index : Int, value : Json) -> PiForkMessage {
  match value {
    Object(fields) =>
      PiForkMessage::new(
        entry_id=json_string(fields, "entryId").unwrap_or(
          "entry-" + index.to_string(),
        ),
        text=json_string(fields, "text").unwrap_or(""),
      )
    _ =>
      PiForkMessage::new(
        entry_id="entry-" + index.to_string(),
        text=value.stringify(),
      )
  }
}

///|
fn transcript_items_from_json(
  index : Int,
  value : Json,
) -> Array[TranscriptItem] {
  match value {
    Object(fields) => {
      let role = json_string(fields, "role").unwrap_or("message")
      let id = json_string(fields, "entryId").unwrap_or(
        json_string(fields, "id").unwrap_or(role + "-" + index.to_string()),
      )
      if role == "assistant" {
        assistant_transcript_items_from_fields(id, fields)
      } else {
        [
          TranscriptItem::new(
            id~,
            role~,
            summary=transcript_summary(role, fields),
            detail=transcript_detail(role, fields),
            tone=transcript_tone(role),
          ),
        ]
      }
    }
    _ =>
      [
        TranscriptItem::new(
          id="message-" + index.to_string(),
          role="message",
          summary="Pi message",
          detail=value.stringify(),
          tone="neutral",
        ),
      ]
  }
}

///|
fn assistant_transcript_items_from_fields(
  id : String,
  fields : Map[String, Json],
) -> Array[TranscriptItem] {
  let items : Array[TranscriptItem] = []
  let visible = json_message_visible_content_summary(fields).trim().to_owned()
  let process = json_message_process_content_summary(fields).trim().to_owned()
  if visible != "" {
    items.push(
      TranscriptItem::new(
        id~,
        role="assistant",
        summary=visible,
        detail=visible,
        tone=transcript_tone("assistant"),
      ),
    )
  }
  if process != "" {
    items.push(
      TranscriptItem::new(
        id=id + "-process",
        role="assistantProcess",
        summary=assistant_process_summary_label(process),
        detail=process,
        tone=transcript_tone("assistantProcess"),
      ),
    )
  }
  if items.is_empty() {
    items.push(
      TranscriptItem::new(
        id~,
        role="assistant",
        summary="Assistant message",
        detail="Assistant message",
        tone=transcript_tone("assistant"),
      ),
    )
  }
  items
}

///|
fn assistant_process_summary_label(process : String) -> String {
  let clean = process.trim().to_owned()
  if clean == "" {
    "Assistant process"
  } else {
    clean
  }
}

///|
fn transcript_summary(role : String, fields : Map[String, Json]) -> String {
  match role {
    "user" => non_empty(json_message_content_summary(fields), "User message")
    "assistant" =>
      non_empty(
        json_message_visible_content_summary(fields),
        "Assistant message",
      )
    "assistantProcess" => "Assistant process"
    "toolResult" =>
      "Tool result: " + json_string(fields, "toolName").unwrap_or("tool")
    "bashExecution" =>
      non_empty(json_string(fields, "command").unwrap_or(""), "Bash execution")
    "branchSummary" => "Branch summary"
    "compactionSummary" => "Compaction summary"
    "custom" =>
      "Custom: " + json_string(fields, "customType").unwrap_or("message")
    _ => non_empty(json_message_content_summary(fields), role)
  }
}

///|
fn transcript_detail(role : String, fields : Map[String, Json]) -> String {
  match role {
    "bashExecution" => {
      let exit_code = json_int(fields, "exitCode")
      let output = json_string(fields, "output").unwrap_or("")
      let output_suffix = if output == "" { "" } else { " - " + output }
      "exit code " + bash_exit_code_label(exit_code) + output_suffix
    }
    "branchSummary" =>
      non_empty(json_string(fields, "summary").unwrap_or(""), "summary")
    "compactionSummary" =>
      non_empty(json_string(fields, "summary").unwrap_or(""), "summary")
    _ => non_empty(json_message_content_summary(fields), "message")
  }
}

///|
fn transcript_tone(role : String) -> String {
  match role {
    "assistant" => "success"
    "assistantProcess" | "toolResult" | "bashExecution" => "warning"
    "user" => "info"
    _ => "neutral"
  }
}

///|
fn non_empty(value : String, fallback : String) -> String {
  if value == "" {
    fallback
  } else {
    value
  }
}

///|
fn plan_steps_from_values(values : Array[Json]) -> Array[PlanStep] {
  let steps : Array[PlanStep] = []
  let mut index = 0
  for value in values {
    match value {
      Object(fields) => {
        let title = json_string(fields, "title").unwrap_or(
          json_string(fields, "text").unwrap_or(
            "Step " + (index + 1).to_string(),
          ),
        )
        steps.push(
          PlanStep::new(
            id=json_string(fields, "id").unwrap_or("step-" + index.to_string()),
            title~,
            status=json_string(fields, "status").unwrap_or("pending"),
            owner=json_string(fields, "owner").unwrap_or("pi"),
            detail=json_string(fields, "detail").unwrap_or(
              json_string(fields, "summary").unwrap_or(""),
            ),
          ),
        )
      }
      String(title) =>
        steps.push(
          PlanStep::new(
            id="step-" + index.to_string(),
            title~,
            status="pending",
            owner="pi",
            detail="",
          ),
        )
      _ => ()
    }
    index = index + 1
  }
  steps
}

///|
fn current_plan_step(steps : Array[PlanStep]) -> PlanStep? {
  for step in steps {
    if plan_step_is_active(step) {
      return Some(step)
    }
  }
  for step in steps {
    if plan_step_is_open(step) {
      return Some(step)
    }
  }
  None
}

///|
fn plan_has_running_step(steps : Array[PlanStep]) -> Bool {
  steps.any(step => plan_step_is_active(step))
}

///|
fn plan_has_blocked_step(steps : Array[PlanStep]) -> Bool {
  steps.any(step => step.status == "blocked")
}

///|
fn plan_open_count(steps : Array[PlanStep]) -> Int {
  let mut count = 0
  for step in steps {
    if plan_step_is_open(step) {
      count = count + 1
    }
  }
  count
}

///|
fn plan_step_is_open(step : PlanStep) -> Bool {
  step.status != "done" &&
  step.status != "completed" &&
  step.status != "cancelled" &&
  step.status != "skipped"
}

///|
fn plan_step_is_active(step : PlanStep) -> Bool {
  step.status == "in_progress" ||
  step.status == "running" ||
  step.status == "active" ||
  step.status == "blocked"
}

///|
fn plan_summary(steps : Array[PlanStep]) -> String {
  let done = steps.length() - plan_open_count(steps)
  done.to_string() + "/" + steps.length().to_string() + " plan steps complete"
}

///|
fn agent_intervention_source_label(event_type : String) -> String {
  match event_type {
    "approval_required" => "Agent approval"
    "permission_required" => "Agent permission"
    "input_required" => "Agent input"
    _ => "Agent intervention"
  }
}

///|
fn agent_intervention_kind_label(event_type : String) -> String {
  match event_type {
    "approval_required" => "approval"
    "permission_required" => "permission"
    "input_required" => "input"
    _ => "intervention"
  }
}

///|
fn agent_intervention_task_label(event_type : String) -> String {
  match event_type {
    "approval_required" => "等待用户批准"
    "permission_required" => "等待权限确认"
    "input_required" => "等待用户输入"
    _ => "等待用户处理"
  }
}

///|
fn agent_intervention_event_title(event_type : String) -> String {
  match event_type {
    "approval_required" => "Pi approval required"
    "permission_required" => "Pi permission required"
    "input_required" => "Pi input required"
    _ => "Pi intervention required"
  }
}

///|
fn agent_intervention_first_string(
  fields : Map[String, Json],
  data : Map[String, Json]?,
  keys : Array[String],
) -> String {
  for key in keys {
    match agent_intervention_string(fields, data, key) {
      Some(value) => return value
      None => ()
    }
  }
  ""
}

///|
fn agent_intervention_string(
  fields : Map[String, Json],
  data : Map[String, Json]?,
  key : String,
) -> String? {
  match json_string(fields, key) {
    Some(value) => {
      let clean = value.trim().to_owned()
      if clean != "" {
        return Some(clean)
      }
    }
    None => ()
  }
  match data {
    Some(data_fields) =>
      match json_string(data_fields, key) {
        Some(value) => {
          let clean = value.trim().to_owned()
          if clean == "" {
            None
          } else {
            Some(clean)
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn agent_intervention_message(
  kind_label : String,
  detail : String,
  target : String,
) -> String {
  if detail == "" && target == "" {
    kind_label + " required"
  } else if detail == "" {
    kind_label + " required: " + target
  } else if target == "" || detail.contains(target) {
    detail
  } else {
    detail + " · " + target
  }
}

///|
fn json_string(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_int(fields : Map[String, Json], key : String) -> Int? {
  match fields.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn json_number(fields : Map[String, Json], key : String) -> Double? {
  match fields.get(key) {
    Some(Number(value, ..)) => Some(value)
    _ => None
  }
}

///|
fn json_bool(fields : Map[String, Json], key : String) -> Bool? {
  match fields.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn json_object(fields : Map[String, Json], key : String) -> Map[String, Json]? {
  match fields.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn json_array(fields : Map[String, Json], key : String) -> Array[Json]? {
  match fields.get(key) {
    Some(Array(value)) => Some(value)
    _ => None
  }
}

///|
fn json_array_count(fields : Map[String, Json], key : String) -> Int {
  match json_array(fields, key) {
    Some(value) => value.length()
    None => 0
  }
}

///|
fn json_message_role(fields : Map[String, Json]) -> String {
  match json_object(fields, "message") {
    Some(message) => json_string(message, "role").unwrap_or("message")
    None => "message"
  }
}

///|
fn json_message_preview(fields : Map[String, Json]) -> String {
  match json_object(fields, "message") {
    Some(message) => json_message_content_summary(message)
    None => ""
  }
}

///|
fn json_message_content_summary(message : Map[String, Json]) -> String {
  match message.get("content") {
    Some(String(value)) => value
    Some(Array(values)) => json_content_array_summary(values)
    _ =>
      json_string(message, "display").unwrap_or(
        json_string(message, "errorMessage").unwrap_or(""),
      )
  }
}

///|
fn json_message_visible_content_summary(message : Map[String, Json]) -> String {
  match message.get("content") {
    Some(String(value)) => value
    Some(Array(values)) => json_content_array_visible_summary(values)
    _ =>
      json_string(message, "display").unwrap_or(
        json_string(message, "errorMessage").unwrap_or(""),
      )
  }
}

///|
fn json_message_process_content_summary(message : Map[String, Json]) -> String {
  match message.get("content") {
    Some(Array(values)) => json_content_array_process_summary(values)
    _ => ""
  }
}

///|
fn json_content_array_summary(values : Array[Json]) -> String {
  let segments : Array[String] = []
  for value in values {
    let segment = json_content_block_summary(value)
    if segment != "" {
      segments.push(segment)
    }
  }
  segments.join("")
}

///|
fn json_content_array_visible_summary(values : Array[Json]) -> String {
  let segments : Array[String] = []
  for value in values {
    let segment = json_content_block_visible_summary(value)
    if segment != "" {
      segments.push(segment)
    }
  }
  segments.join("")
}

///|
fn json_content_array_process_summary(values : Array[Json]) -> String {
  let segments : Array[String] = []
  for value in values {
    let segment = json_content_block_process_summary(value)
    if segment != "" {
      segments.push(segment)
    }
  }
  segments.join(" · ")
}

///|
fn json_content_block_summary(value : Json) -> String {
  match value {
    String(text) => text
    Object(fields) =>
      match json_string(fields, "type") {
        Some("text") => json_string(fields, "text").unwrap_or("")
        Some("thinking") => "thinking"
        Some("toolCall") =>
          "tool call: " + json_string(fields, "name").unwrap_or("tool")
        Some("image") => "[image]"
        _ => json_string(fields, "text").unwrap_or("")
      }
    _ => ""
  }
}

///|
fn json_content_block_visible_summary(value : Json) -> String {
  match value {
    String(text) => text
    Object(fields) =>
      match json_string(fields, "type") {
        Some("text") => json_string(fields, "text").unwrap_or("")
        Some("image") => "[image]"
        _ => ""
      }
    _ => ""
  }
}

///|
fn json_content_block_process_summary(value : Json) -> String {
  match value {
    Object(fields) =>
      match json_string(fields, "type") {
        Some("thinking") => "thinking"
        Some("toolCall") =>
          "tool call: " + json_string(fields, "name").unwrap_or("tool")
        _ => ""
      }
    _ => ""
  }
}

///|
fn message_event_detail(session_id : String, detail : String) -> String {
  if detail == "" {
    session_id
  } else {
    session_id + ": " + detail
  }
}

///|
fn assistant_update_detail(
  fields : Map[String, Json],
  fallback : String,
) -> String {
  match json_object(fields, "assistantMessageEvent") {
    Some(event) => {
      let event_type = json_string(event, "type").unwrap_or("update")
      let value = json_string(event, "delta").unwrap_or(
        json_string(event, "content").unwrap_or(fallback),
      )
      if value == "" {
        event_type
      } else {
        event_type + ": " + value
      }
    }
    None => if fallback == "" { "assistant message update" } else { fallback }
  }
}

///|
fn tool_command_summary(tool_name : String, args : Json?) -> String {
  match args {
    Some(Object(fields)) => {
      let command = json_string(fields, "command").unwrap_or(
        json_string(fields, "cmd").unwrap_or(""),
      )
      if command != "" {
        command
      } else {
        let path = json_string(fields, "path").unwrap_or(
          json_string(fields, "filePath").unwrap_or(
            json_string(fields, "file_path").unwrap_or(""),
          ),
        )
        if path == "" {
          tool_name
        } else {
          tool_name + ": " + path
        }
      }
    }
    Some(String(value)) => tool_name + ": " + value
    Some(value) => tool_name + ": " + value.stringify()
    None => tool_name
  }
}

///|
fn tool_command_cwd(default_cwd : String, args : Json?) -> String {
  match args {
    Some(Object(fields)) => json_string(fields, "cwd").unwrap_or(default_cwd)
    _ => default_cwd
  }
}

///|
fn tool_result_exit_code(result : Json?) -> Int? {
  match result {
    Some(Object(fields)) =>
      match json_int(fields, "exitCode") {
        Some(code) => Some(code)
        None =>
          match json_int(fields, "exit_code") {
            Some(code) => Some(code)
            None =>
              match json_int(fields, "code") {
                Some(code) => Some(code)
                None =>
                  match json_object(fields, "details") {
                    Some(details) => json_int(details, "exitCode")
                    None => None
                  }
              }
          }
      }
    _ => None
  }
}

///|
fn tool_result_summary(result : Json?) -> String? {
  match result {
    Some(Object(fields)) =>
      match json_string(fields, "output") {
        Some(output) => Some(output)
        None =>
          match json_array(fields, "content") {
            Some(content) => Some(json_content_array_summary(content))
            None =>
              match json_object(fields, "details") {
                Some(details) => json_string(details, "output")
                None => None
              }
          }
      }
    Some(String(value)) => Some(value)
    Some(value) => Some(value.stringify())
    None => None
  }
}

///|
fn tool_result_output_path(result : Json?) -> String {
  match result {
    Some(Object(fields)) =>
      match json_string(fields, "fullOutputPath") {
        Some(path) => path
        None =>
          match json_string(fields, "outputPath") {
            Some(path) => path
            None =>
              match json_string(fields, "output_path") {
                Some(path) => path
                None =>
                  match json_object(fields, "details") {
                    Some(details) =>
                      tool_result_output_path_from_fields(details)
                    None => ""
                  }
              }
          }
      }
    _ => ""
  }
}

///|
fn tool_result_output_path_from_fields(fields : Map[String, Json]) -> String {
  match json_string(fields, "fullOutputPath") {
    Some(path) => path
    None =>
      match json_string(fields, "outputPath") {
        Some(path) => path
        None => json_string(fields, "output_path").unwrap_or("")
      }
  }
}

///|
fn tool_result_truncated(result : Json?) -> Bool {
  match result {
    Some(Object(fields)) =>
      match json_bool(fields, "truncated") {
        Some(value) => value
        None =>
          match json_object(fields, "details") {
            Some(details) => json_bool(details, "truncated").unwrap_or(false)
            None => false
          }
      }
    _ => false
  }
}

///|
fn json_model_label(fields : Map[String, Json]) -> String {
  match fields.get("model") {
    Some(Object(model)) => {
      let provider = json_string(model, "provider").unwrap_or("")
      let id = json_string(model, "id").unwrap_or(
        json_string(model, "name").unwrap_or(""),
      )
      if provider == "" {
        id
      } else if id == "" {
        provider
      } else {
        provider + "/" + id
      }
    }
    _ => {
      let provider = json_string(fields, "provider").unwrap_or("")
      let id = json_string(fields, "id").unwrap_or(
        json_string(fields, "name").unwrap_or(""),
      )
      let name = json_string(fields, "name").unwrap_or("")
      if provider == "" && id == "" && name == "" {
        ""
      } else {
        agent_model_label(provider, id, name)
      }
    }
  }
}

///|
fn diagnostic_tone(severity : String) -> String {
  match severity {
    "error" | "failed" => "danger"
    "warning" | "warn" => "warning"
    _ => "info"
  }
}
