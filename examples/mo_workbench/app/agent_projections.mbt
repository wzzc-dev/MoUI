///|
enum AgentRequestKind {
  ApprovalRequest
  PermissionRequest
  InputRequest
  InterventionRequest
} derive(Eq, Debug)

///|
enum AgentActivityQueueKind {
  ProviderRecovery
  RuntimeActivity
  QueuedOperation
  ActiveTool
  PlanProgress
  PendingRequest
} derive(Eq, Debug)

///|
enum AgentCatalogItemKind {
  ModelCatalogItem
  CommandCatalogItem
} derive(Eq, Debug)

///|
struct AgentRequestSummary {
  backend_id : String
  kind : AgentRequestKind
  source : String
  severity : String
  message : String
  title : String
  detail : String
  action_label : String
  badge_label : String
  tone : String
} derive(Eq, Debug)

///|
struct AgentActivityQueueItem {
  backend_id : String
  kind : AgentActivityQueueKind
  badge_label : String
  tone : String
  title : String
  detail : String
  primary_label : String
  primary_message : WorkbenchMsg?
  secondary_label : String
  secondary_message : WorkbenchMsg?
} derive(Eq, Debug)

///|
struct AgentRunOverview {
  backend_id : String
  title : String
  detail : String
  focus_label : String
  focus_title : String
  focus_detail : String
  activity_count : Int
  request_count : Int
  operator_action_count : Int
  shortcut_count : Int
  tone : String
  active : Bool
  primary_label : String
  primary_message : WorkbenchMsg?
  secondary_label : String
  secondary_message : WorkbenchMsg?
} derive(Eq, Debug)

///|
struct AgentProviderRegistryItem {
  backend_id : String
  label : String
  transport_label : String
  capability_label : String
  status_label : String
  detail : String
  badge_label : String
  tone : String
  active : Bool
  action_label : String
  action_message : WorkbenchMsg?
} derive(Eq, Debug)

///|
struct AgentProviderSwitchSummary {
  backend_id : String
  label : String
  transport_label : String
  capability_label : String
  status_label : String
  detail : String
  switch_count : Int
  tone : String
} derive(Eq, Debug)

///|
struct AgentComposerRouteSummary {
  backend_id : String
  label : String
  session_label : String
  model_label : String
  context_label : String
  focus_label : String
  input_label : String
  detail : String
  tone : String
  visible : Bool
  slash_mode : Bool
} derive(Eq, Debug)

///|
struct AgentComposerRequestSummary {
  backend_id : String
  badge_label : String
  title : String
  detail : String
  action_label : String
  action_message : WorkbenchMsg?
  secondary_label : String
  secondary_message : WorkbenchMsg?
  tone : String
  visible : Bool
} derive(Eq, Debug)

///|
struct AgentStatusBarSummary {
  backend_id : String
  status_label : String
  context_label : String
  queue_label : String
  diagnostic_label : String
  activity_label : String
  tone : String
} derive(Eq, Debug)

///|
struct AgentTimelineItem {
  backend_id : String
  source_kind : String
  badge_label : String
  title : String
  detail : String
  tone : String
  process : Bool
  visible : Bool
} derive(Eq, Debug)

///|
fn AgentRequestSummary::new(
  backend_id~ : String,
  source~ : String,
  kind? : AgentRequestKind = agent_request_kind_for_source(source),
  severity? : String = "warning",
  message? : String = "",
  title? : String = "",
  detail? : String = "",
  action_label? : String = "",
  badge_label? : String = "",
  tone? : String = "",
) -> AgentRequestSummary {
  {
    backend_id,
    kind,
    source,
    severity,
    message,
    title: if title == "" {
      kind.default_title_label()
    } else {
      title
    },
    detail: if detail == "" {
      agent_request_detail_label(source, message)
    } else {
      detail
    },
    action_label: if action_label == "" {
      kind.default_action_label()
    } else {
      action_label
    },
    badge_label: if badge_label == "" {
      kind.default_badge_label()
    } else {
      badge_label
    },
    tone: if tone == "" {
      kind.default_tone_label()
    } else {
      tone
    },
  }
}

///|
fn AgentRequestSummary::has_visible_request(
  self : AgentRequestSummary,
) -> Bool {
  self.source != "" || self.message != ""
}

///|
fn AgentActivityQueueItem::new(
  backend_id~ : String,
  kind~ : AgentActivityQueueKind,
  badge_label? : String = "",
  tone? : String = "neutral",
  title? : String = "",
  detail? : String = "",
  primary_label? : String = "",
  primary_message? : WorkbenchMsg? = None,
  secondary_label? : String = "",
  secondary_message? : WorkbenchMsg? = None,
) -> AgentActivityQueueItem {
  {
    backend_id,
    kind,
    badge_label,
    tone,
    title,
    detail,
    primary_label,
    primary_message,
    secondary_label,
    secondary_message,
  }
}

///|
fn AgentActivityQueueItem::has_primary_action(
  self : AgentActivityQueueItem,
) -> Bool {
  self.primary_message is Some(_)
}

///|
fn AgentActivityQueueItem::has_secondary_action(
  self : AgentActivityQueueItem,
) -> Bool {
  self.secondary_message is Some(_)
}

///|
fn AgentRunOverview::new(
  backend_id~ : String,
  title? : String = "",
  detail? : String = "",
  focus_label? : String = "",
  focus_title? : String = "",
  focus_detail? : String = "",
  activity_count? : Int = 0,
  request_count? : Int = 0,
  operator_action_count? : Int = 0,
  shortcut_count? : Int = 0,
  tone? : String = "neutral",
  active? : Bool = false,
  primary_label? : String = "",
  primary_message? : WorkbenchMsg? = None,
  secondary_label? : String = "",
  secondary_message? : WorkbenchMsg? = None,
) -> AgentRunOverview {
  {
    backend_id,
    title,
    detail,
    focus_label,
    focus_title,
    focus_detail,
    activity_count,
    request_count,
    operator_action_count,
    shortcut_count,
    tone,
    active,
    primary_label,
    primary_message,
    secondary_label,
    secondary_message,
  }
}

///|
fn AgentRunOverview::has_visible_overview(self : AgentRunOverview) -> Bool {
  self.title != "" ||
  self.detail != "" ||
  self.activity_count > 0 ||
  self.request_count > 0 ||
  self.focus_title != ""
}

///|
fn AgentProviderRegistryItem::new(
  backend_id~ : String,
  label~ : String,
  transport_label~ : String,
  capability_label~ : String,
  detail~ : String,
  status_label? : String = "",
  badge_label? : String = "",
  tone? : String = "neutral",
  active? : Bool = false,
  action_label? : String = "",
  action_message? : WorkbenchMsg? = None,
) -> AgentProviderRegistryItem {
  {
    backend_id,
    label,
    transport_label,
    capability_label,
    status_label,
    detail,
    badge_label,
    tone,
    active,
    action_label,
    action_message,
  }
}

///|
fn AgentProviderRegistryItem::has_action(
  self : AgentProviderRegistryItem,
) -> Bool {
  self.action_message is Some(_)
}

///|
fn AgentProviderSwitchSummary::new(
  backend_id~ : String,
  label~ : String,
  transport_label~ : String,
  capability_label~ : String,
  status_label? : String = "",
  detail? : String = "",
  switch_count? : Int = 0,
  tone? : String = "neutral",
) -> AgentProviderSwitchSummary {
  {
    backend_id,
    label,
    transport_label,
    capability_label,
    status_label,
    detail,
    switch_count,
    tone,
  }
}

///|
fn AgentProviderSwitchSummary::has_switch_targets(
  self : AgentProviderSwitchSummary,
) -> Bool {
  self.switch_count > 1
}

///|
fn AgentComposerRouteSummary::new(
  backend_id~ : String,
  label~ : String,
  session_label? : String = "",
  model_label? : String = "",
  context_label? : String = "",
  focus_label? : String = "",
  input_label? : String = "",
  detail? : String = "",
  tone? : String = "neutral",
  visible? : Bool = false,
  slash_mode? : Bool = false,
) -> AgentComposerRouteSummary {
  {
    backend_id,
    label,
    session_label,
    model_label,
    context_label,
    focus_label,
    input_label,
    detail,
    tone,
    visible,
    slash_mode,
  }
}

///|
fn AgentComposerRouteSummary::has_visible_route(
  self : AgentComposerRouteSummary,
) -> Bool {
  self.visible
}

///|
fn AgentComposerRequestSummary::new(
  backend_id~ : String,
  badge_label? : String = "",
  title? : String = "",
  detail? : String = "",
  action_label? : String = "",
  action_message? : WorkbenchMsg? = None,
  secondary_label? : String = "",
  secondary_message? : WorkbenchMsg? = None,
  tone? : String = "neutral",
  visible? : Bool = false,
) -> AgentComposerRequestSummary {
  {
    backend_id,
    badge_label,
    title,
    detail,
    action_label,
    action_message,
    secondary_label,
    secondary_message,
    tone,
    visible,
  }
}

///|
fn AgentComposerRequestSummary::has_visible_request(
  self : AgentComposerRequestSummary,
) -> Bool {
  self.visible
}

///|
fn AgentStatusBarSummary::new(
  backend_id~ : String,
  status_label? : String = "",
  context_label? : String = "",
  queue_label? : String = "",
  diagnostic_label? : String = "",
  activity_label? : String = "",
  tone? : String = "neutral",
) -> AgentStatusBarSummary {
  {
    backend_id,
    status_label,
    context_label,
    queue_label,
    diagnostic_label,
    activity_label,
    tone,
  }
}

///|
fn AgentStatusBarSummary::has_visible_metrics(
  self : AgentStatusBarSummary,
) -> Bool {
  self.status_label != "" ||
  self.queue_label != "" ||
  self.diagnostic_label != "" ||
  self.activity_label != ""
}

///|
fn AgentTimelineItem::new(
  backend_id~ : String,
  source_kind~ : String,
  badge_label~ : String,
  title~ : String,
  detail? : String = "",
  tone? : String = "neutral",
  process? : Bool = false,
  visible? : Bool = true,
) -> AgentTimelineItem {
  {
    backend_id,
    source_kind,
    badge_label,
    title,
    detail,
    tone,
    process,
    visible,
  }
}

///|
fn AgentTimelineItem::has_visible_timeline_item(
  self : AgentTimelineItem,
) -> Bool {
  self.visible && (self.title != "" || self.detail != "")
}

///|
fn WorkbenchModel::agent_request_summaries(
  self : WorkbenchModel,
) -> Array[AgentRequestSummary] {
  let backend = self.active_agent_backend_profile()
  let requests : Array[AgentRequestSummary] = []
  for diagnostic in self.diagnostics {
    if diagnostic_source_is_agent_intervention(diagnostic.source) {
      requests.push(
        AgentRequestSummary::new(
          backend_id=backend.id,
          source=diagnostic.source,
          severity=diagnostic.severity,
          message=diagnostic.message,
        ),
      )
    }
  }
  requests
}

///|
fn WorkbenchModel::latest_agent_request_summary(
  self : WorkbenchModel,
) -> AgentRequestSummary? {
  let requests = self.agent_request_summaries()
  if requests.is_empty() {
    None
  } else {
    Some(requests[requests.length() - 1])
  }
}

///|
fn WorkbenchModel::agent_activity_queue(
  self : WorkbenchModel,
) -> Array[AgentActivityQueueItem] {
  let backend = self.active_agent_backend_profile()
  let items : Array[AgentActivityQueueItem] = []
  for request in self.agent_request_summaries() {
    items.push(
      AgentActivityQueueItem::new(
        backend_id=backend.id,
        kind=PendingRequest,
        badge_label=request.badge_label,
        tone=request.tone,
        title=request.title,
        detail=request.detail,
        primary_label=request.action_label,
        primary_message=Some(
          FixDiagnostic(request.source, request.severity, request.message),
        ),
        secondary_label="忽略",
      ),
    )
  }
  if self.pending_transport_count() > 0 {
    items.push(
      AgentActivityQueueItem::new(
        backend_id=backend.id,
        kind=QueuedOperation,
        badge_label="队列",
        tone="info",
        title="Provider operations queued",
        detail=self.pending_transport_count().to_string() + " pending",
      ),
    )
  }
  let signal = self.active_agent_runtime_signal()
  if signal.has_visible_signal() {
    items.push(
      AgentActivityQueueItem::new(
        backend_id=backend.id,
        kind=RuntimeActivity,
        badge_label="运行",
        tone=if signal.has_active_signal() { "accent" } else { "neutral" },
        title=signal.status_label,
        detail=signal.message_preview,
        primary_label=if signal.has_active_signal() { "取消" } else { "" },
        primary_message=if signal.has_active_signal() {
          Some(CancelRun)
        } else {
          None
        },
      ),
    )
  }
  for command in self.commands {
    if command.status == "failed" || command.status == "running" {
      items.push(
        AgentActivityQueueItem::new(
          backend_id=backend.id,
          kind=ActiveTool,
          badge_label=command.status,
          tone=if command.status == "failed" { "danger" } else { "accent" },
          title=command.command,
          detail=command.cwd,
          primary_label=if command.status == "failed" {
            "修复"
          } else {
            "查看"
          },
          primary_message=Some(command_primary_action_message(command)),
        ),
      )
    }
  }
  items
}

///|
fn WorkbenchModel::agent_run_overview(
  self : WorkbenchModel,
) -> AgentRunOverview {
  let backend = self.active_agent_backend_profile()
  let queue = self.agent_activity_queue()
  let requests = self.agent_request_summaries()
  let signal = self.active_agent_runtime_signal()
  let title = if signal.message_preview != "" {
    signal.message_preview
  } else if signal.status_label != "" {
    signal.status_label
  } else {
    self.active_session().summary
  }
  AgentRunOverview::new(
    backend_id=backend.id,
    title~,
    detail=backend.label + " · " + backend.transport_kind.label(),
    focus_label=self.selected_agent_id,
    focus_title=self.active_session().title,
    focus_detail=self.active_session().project_path,
    activity_count=queue.length(),
    request_count=requests.length(),
    operator_action_count=agent_operator_action_count(self),
    shortcut_count=self.active_agent_command_catalog().length(),
    tone=if requests.length() > 0 { "warning" } else { "neutral" },
    active=signal.has_active_signal(),
  )
}

///|
fn WorkbenchModel::agent_provider_registry_items(
  self : WorkbenchModel,
) -> Array[AgentProviderRegistryItem] {
  let active = self.active_agent_backend_profile()
  let items : Array[AgentProviderRegistryItem] = []
  for profile in agent_backend_profiles() {
    let status = if profile.id == active.id {
      self.active_agent_backend_status().status_label
    } else {
      ""
    }
    items.push(
      AgentProviderRegistryItem::new(
        backend_id=profile.id,
        label=profile.label,
        transport_label=profile.transport_kind.label(),
        capability_label=agent_capability_label(profile.capabilities),
        status_label=status,
        detail=profile.description,
        badge_label=if profile.id == active.id { "当前" } else { "可选" },
        tone=if profile.id == active.id { "accent" } else { "neutral" },
        active=profile.id == active.id,
        action_label=if profile.id == active.id { "" } else { "切换" },
        action_message=if profile.id == active.id {
          None
        } else {
          Some(SwitchAgentBackend(profile.id))
        },
      ),
    )
  }
  items
}

///|
fn WorkbenchModel::agent_provider_switch_summary(
  self : WorkbenchModel,
) -> AgentProviderSwitchSummary {
  let backend = self.active_agent_backend_profile()
  AgentProviderSwitchSummary::new(
    backend_id=backend.id,
    label=backend.label,
    transport_label=backend.transport_kind.label(),
    capability_label=agent_capability_label(backend.capabilities),
    status_label=self.active_agent_backend_status().status_label,
    detail=backend.description,
    switch_count=agent_backend_profiles().length(),
    tone=if self.active_agent_backend_status().failed {
      "danger"
    } else {
      "neutral"
    },
  )
}

///|
fn WorkbenchModel::agent_composer_route_summary(
  self : WorkbenchModel,
) -> AgentComposerRouteSummary {
  let backend = self.active_agent_backend_profile()
  let slash_mode = self.composer_slash_query() is Some(_)
  if !self.has_composer_prompt() || slash_mode {
    return AgentComposerRouteSummary::new(
      backend_id=backend.id,
      label=backend.label,
      tone=agent_backend_tone(backend),
      slash_mode~,
    )
  }
  let binding = self.active_agent_session_binding()
  let session_label = agent_binding_session_label(binding)
  let model_label = if binding.model == "" {
    ""
  } else {
    "模型 " + binding.model
  }
  let context_label = agent_composer_context_display_label(self)
  let focus_label = self.selected_agent_id
  let parts : Array[String] = [backend.label]
  if session_label != "" {
    parts.push(session_label)
  }
  if model_label != "" {
    parts.push(model_label)
  }
  if context_label != "" {
    parts.push(context_label)
  }
  AgentComposerRouteSummary::new(
    backend_id=backend.id,
    label=backend.label,
    session_label~,
    model_label~,
    context_label~,
    focus_label~,
    detail=parts.join(" · "),
    tone=agent_backend_tone(backend),
    visible=true,
    slash_mode~,
  )
}

///|
fn WorkbenchModel::agent_composer_request_summary(
  self : WorkbenchModel,
) -> AgentComposerRequestSummary {
  let backend = self.active_agent_backend_profile()
  match self.latest_agent_request_summary() {
    Some(request) =>
      AgentComposerRequestSummary::new(
        backend_id=backend.id,
        badge_label=request.badge_label,
        title=request.title,
        detail=request.detail,
        action_label=request.action_label,
        action_message=Some(
          FixDiagnostic(request.source, request.severity, request.message),
        ),
        secondary_label="忽略",
        tone=request.tone,
        visible=true,
      )
    None => AgentComposerRequestSummary::new(backend_id=backend.id)
  }
}

///|
fn WorkbenchModel::agent_status_bar_summary(
  self : WorkbenchModel,
) -> AgentStatusBarSummary {
  let backend = self.active_agent_backend_profile()
  AgentStatusBarSummary::new(
    backend_id=backend.id,
    status_label=self.status_bar_status_label(),
    context_label=self.status_bar_context_label(),
    queue_label=self.status_bar_queue_label(),
    diagnostic_label=self.status_bar_diagnostic_label(),
    activity_label=self.status_bar_activity_label(),
    tone=agent_backend_tone(backend),
  )
}

///|
fn WorkbenchModel::agent_timeline_items(
  self : WorkbenchModel,
) -> Array[AgentTimelineItem] {
  let backend = self.active_agent_backend_profile()
  let items : Array[AgentTimelineItem] = []
  for event in self.events {
    items.push(
      AgentTimelineItem::new(
        backend_id=backend.id,
        source_kind=event.phase,
        badge_label=event.phase,
        title=event.title,
        detail=event.detail,
        tone=event.tone,
        process=event.phase == "agent" ||
          event.phase == "assistant" ||
          event.phase == "connector",
        visible=!event.title.contains("JSONL sent"),
      ),
    )
  }
  items
}

///|
fn AgentRequestKind::default_title_label(self : AgentRequestKind) -> String {
  match self {
    ApprovalRequest => "等待批准"
    PermissionRequest => "等待权限"
    InputRequest => "等待输入"
    InterventionRequest => "等待处理"
  }
}

///|
fn AgentRequestKind::default_action_label(self : AgentRequestKind) -> String {
  match self {
    ApprovalRequest => "处理批准"
    PermissionRequest => "处理权限"
    InputRequest => "回复"
    InterventionRequest => "处理"
  }
}

///|
fn AgentRequestKind::default_badge_label(self : AgentRequestKind) -> String {
  match self {
    ApprovalRequest => "批准"
    PermissionRequest => "权限"
    InputRequest => "输入"
    InterventionRequest => "请求"
  }
}

///|
fn AgentRequestKind::default_tone_label(self : AgentRequestKind) -> String {
  match self {
    ApprovalRequest | PermissionRequest | InputRequest => "warning"
    InterventionRequest => "neutral"
  }
}

///|
fn agent_request_kind_for_source(source : String) -> AgentRequestKind {
  match source {
    "Agent approval" => ApprovalRequest
    "Agent permission" => PermissionRequest
    "Agent input" => InputRequest
    _ => InterventionRequest
  }
}

///|
fn agent_request_detail_label(source : String, message : String) -> String {
  if source == "" {
    message
  } else if message == "" {
    source
  } else {
    source + " · " + message
  }
}

///|
fn agent_capability_label(capabilities : AgentBackendCapabilities) -> String {
  let labels : Array[String] = []
  if capabilities.supports_session_refresh || capabilities.supports_new_session {
    labels.push("session")
  }
  if capabilities.supports_command_catalog {
    labels.push("commands")
  }
  if capabilities.supports_model_catalog {
    labels.push("models")
  }
  if capabilities.supports_shell_commands {
    labels.push("shell")
  }
  if labels.is_empty() {
    "local"
  } else {
    labels.join(" · ")
  }
}

///|
fn agent_backend_tone(backend : AgentBackendProfile) -> String {
  match backend.transport_kind {
    PiJsonlRpcTransport => "accent"
    AcpConnectorTransport => "accent"
    FixtureTransport | NoAgentTransport => "neutral"
  }
}

///|
fn agent_operator_action_count(model : WorkbenchModel) -> Int {
  let capabilities = model.active_agent_backend_capabilities()
  let mut count = 0
  if capabilities.supports_session_refresh {
    count += 1
  }
  if capabilities.supports_new_session {
    count += 1
  }
  if capabilities.supports_shell_commands {
    count += 1
  }
  if model.has_cancel_target() {
    count += 1
  }
  count
}

///|
fn agent_binding_session_label(binding : AgentSessionBinding) -> String {
  if binding.session_name != "" {
    "会话 " + binding.session_name
  } else if binding.provider_session_id != "" {
    "会话 " + binding.provider_session_id
  } else {
    ""
  }
}

///|
fn agent_composer_context_display_label(model : WorkbenchModel) -> String {
  let labels : Array[String] = []
  for id in ["repo", "examples", "evidence", "session"] {
    if model.context_is_selected(id) {
      labels.push(agent_context_display_label(id))
    }
  }
  for id in model.expanded_context {
    if !known_context_id(id) {
      labels.push(id)
    }
  }
  if labels.is_empty() {
    "无上下文"
  } else {
    labels.join("、")
  }
}

///|
fn agent_context_display_label(id : String) -> String {
  match id {
    "repo" => "仓库"
    "examples" => "示例"
    "evidence" => "证据"
    "session" => "会话"
    _ => id
  }
}
