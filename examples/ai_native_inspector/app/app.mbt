///|
using @views {
  badge,
  button,
  card,
  column,
  divider,
  row,
  scroll_view,
  status_badge,
  text,
  text_field,
}

///|
/// A bounded step in the local Agent demonstration.
pub(all) enum DemoStep {
  ReadSemantics
  Search
  OpenRecord
  SensitiveRead
  RequestTransitionConfirmation
  ApproveTransition
  RequestExportConfirmation
  ApproveExport
  Replay
  Audit
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DemoStatus {
  Idle
  Running
  WaitingConfirmation
  Completed
  Failed
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DemoCommand {
  RunAll
  NextStep
  Approve
  Reject
  Replay
  Audit
  ExportReport
  Reset
} derive(Eq, Debug, ToJson)

///| Business changes returned by a DemoDriver. A real composition root usually

///| changes the business model through a semantic action, while the local

///|
/// driver returns the equivalent patch for deterministic tests.
pub(all) enum DemoBusinessAction {
  None
  Reset
  Search(String)
  Open(Int)
  Transition(String)
  RevealSensitive
  Export
} derive(Eq, Debug, ToJson)

///|
/// Neutral input passed from the app to a composition-root driver.
pub(all) struct DemoContext {
  fixture_version : Int
  selected_record : Int?
  query : String
  selected_status : String
  snapshot : AgentConsoleSnapshot
} derive(Eq, Debug, ToJson)

///|
/// Neutral output returned by a local or host-backed driver.
pub(all) struct DemoResult {
  snapshot : AgentConsoleSnapshot
  event : String
  business : DemoBusinessAction
} derive(Eq, Debug, ToJson)

///|
/// Composition roots bind this callback to real Skills, policy and MCP.
pub struct DemoDriver {
  run_fn : (DemoCommand, DemoContext) -> DemoResult
}

///|
pub fn DemoDriver::new(
  run~ : (DemoCommand, DemoContext) -> DemoResult,
) -> DemoDriver {
  { run_fn: run }
}

///|
pub fn DemoDriver::run(
  self : DemoDriver,
  command : DemoCommand,
  context : DemoContext,
) -> DemoResult {
  (self.run_fn)(command, context)
}

///|
/// A readable row in the Agent trace timeline.
pub(all) struct TraceRow {
  step : String
  target : String
  action : String
  policy : String
  result : String
  before_generation : String
  after_generation : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PolicyRow {
  target : String
  decision : String
  reason : String
  confirmation : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct McpCallRow {
  tool : String
  request : String
  result : String
  error_code : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ReplaySummary {
  status : String
  completed : Int
  failed_step : String
  expected_target : String
  actual_target : String
  generation : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AuditSummary {
  status : String
  issue_count : Int
  issues : Array[String]
  passed : Array[String]
} derive(Eq, Debug, ToJson)

///|
/// Platform-neutral data shown by the Agent Console.
pub(all) struct AgentConsoleSnapshot {
  mode : String
  generation : String
  active_step : DemoStep
  demo_status : DemoStatus
  skills : Array[String]
  active_skill : String
  selected_target : String
  pending_confirmations : Int
  pending_confirmation : String?
  pending_confirmation_reason : String?
  trace_entries : Int
  trace : Array[TraceRow]
  policy : Array[PolicyRow]
  mcp : Array[McpCallRow]
  replay : ReplaySummary
  audit : AuditSummary
  replay_status : String
  audit_issues : Int
  mcp_status : String
  last_result : String
  report_text : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ConsoleWorkspace {
  Semantics
  Skills
  Actions
  Policy
  MCP
  Trace
  Replay
  Audit
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Record {
  id : Int
  name : String
  owner : String
  status : String
  amount : String
  sensitive_contact : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Model {
  query : String
  selected_status : String
  selected_record : Int?
  editor_value : String
  assigned_owner : String
  submitted : Bool
  exported : Bool
  sensitive_revealed : Bool
  fixture_version : Int
  console_workspace : ConsoleWorkspace
  console : AgentConsoleSnapshot
  last_event : String
  records : Array[Record]
}

///|
pub(all) enum Msg {
  QueryChanged(String)
  RunSearch
  StatusChanged(String)
  SelectRecord(Int)
  EditorChanged(String)
  Assign(String)
  Transition(String)
  Submit
  ConfirmSubmit
  Export
  RevealSensitive
  ToggleFixture
  RunDemo
  NextStep
  Approve
  Reject
  Replay
  Audit
  ExportReport
  ResetDemo
  ConsoleWorkspaceChanged(ConsoleWorkspace)
  AgentConsoleUpdated(AgentConsoleSnapshot)
  DemoResultReceived(DemoResult)
}

///|
fn default_records() -> Array[Record] {
  [
    {
      id: 101,
      name: "Northwind renewal",
      owner: "A. Chen",
      status: "Review",
      amount: "$42,000",
      sensitive_contact: "northwind-security@example.test",
    },
    {
      id: 102,
      name: "Contoso rollout",
      owner: "M. Li",
      status: "Approved",
      amount: "$18,500",
      sensitive_contact: "contoso-security@example.test",
    },
    {
      id: 103,
      name: "Fabrikam migration",
      owner: "S. Wang",
      status: "Draft",
      amount: "$76,200",
      sensitive_contact: "fabrikam-security@example.test",
    },
  ]
}

///|
fn default_replay() -> ReplaySummary {
  {
    status: "not run",
    completed: 0,
    failed_step: "-",
    expected_target: "-",
    actual_target: "-",
    generation: "-",
  }
}

///|
fn default_audit() -> AuditSummary {
  { status: "not run", issue_count: 0, issues: [], passed: [] }
}

///|
fn default_console() -> AgentConsoleSnapshot {
  {
    mode: "Local demo / Host-ready",
    generation: "1",
    active_step: DemoStep::ReadSemantics,
    demo_status: DemoStatus::Idle,
    skills: [
      "workbench.search", "workbench.open", "workbench.update", "workbench.transition",
      "workbench.assign", "workbench.export", "workbench.read_sensitive",
    ],
    active_skill: "-",
    selected_target: "workbench.record.101.open",
    pending_confirmations: 0,
    pending_confirmation: None,
    pending_confirmation_reason: None,
    trace_entries: 0,
    trace: [],
    policy: [],
    mcp: [],
    replay: default_replay(),
    audit: default_audit(),
    replay_status: "not run",
    audit_issues: 0,
    mcp_status: "default=2 tools; opt-in=Skills + Trace + Replay",
    last_result: "Ready: select Run demo or Next step",
    report_text: "",
  }
}

///|
pub fn Model::new() -> Model {
  {
    query: "Northwind",
    selected_status: "All",
    selected_record: Some(101),
    editor_value: "Northwind renewal",
    assigned_owner: "A. Chen",
    submitted: false,
    exported: false,
    sensitive_revealed: false,
    fixture_version: 1,
    console_workspace: ConsoleWorkspace::Semantics,
    console: default_console(),
    last_event: "Ready: Northwind renewal selected",
    records: default_records(),
  }
}

///|
fn context(model : Model) -> DemoContext {
  {
    fixture_version: model.fixture_version,
    selected_record: model.selected_record,
    query: model.query,
    selected_status: model.selected_status,
    snapshot: model.console,
  }
}

///|
fn driver_effect(
  model : Model,
  command : DemoCommand,
  driver : DemoDriver,
) -> (Model, @moui.Effect[Msg]) {
  let context = context(model)
  let next = {
    ..model,
    console: { ..model.console, demo_status: DemoStatus::Running },
  }
  (
    next,
    @moui.Effect::run(key="ai-native-demo", label="Run Agent demo command", run=_dispatch => {
      _dispatch(DemoResultReceived(driver.run(command, context)))
    }),
  )
}

///|
fn update_business(model : Model, action : DemoBusinessAction) -> Model {
  match action {
    DemoBusinessAction::None => model
    DemoBusinessAction::Reset => Model::new()
    DemoBusinessAction::Search(value) => { ..model, query: value }
    DemoBusinessAction::Open(id) => update(model, SelectRecord(id))
    DemoBusinessAction::Transition(status) => update(model, Transition(status))
    DemoBusinessAction::RevealSensitive => update(model, RevealSensitive)
    DemoBusinessAction::Export => update(model, Export)
  }
}

///|
fn apply_demo_result(model : Model, result : DemoResult) -> Model {
  let business = update_business(model, result.business)
  { ..business, console: result.snapshot, last_event: result.event }
}

///|
pub fn update_with_driver(
  model : Model,
  message : Msg,
  driver : DemoDriver,
) -> (Model, @moui.Effect[Msg]) {
  match message {
    QueryChanged(value) =>
      (
        { ..model, query: value, last_event: "Search query changed" },
        @moui.Effect::none(),
      )
    RunSearch =>
      (
        { ..model, last_event: "Search executed: " + model.query },
        @moui.Effect::none(),
      )
    StatusChanged(value) =>
      (
        { ..model, selected_status: value, last_event: "Filter changed" },
        @moui.Effect::none(),
      )
    SelectRecord(id) => {
      let mut editor_value = ""
      let mut assigned_owner = ""
      for record in model.records {
        if record.id == id {
          editor_value = record.name
          assigned_owner = record.owner
        }
      }
      (
        {
          ..model,
          selected_record: Some(id),
          editor_value,
          assigned_owner,
          sensitive_revealed: false,
          last_event: "Record opened: " + id.to_string(),
        },
        @moui.Effect::none(),
      )
    }
    EditorChanged(value) =>
      (
        { ..model, editor_value: value, last_event: "Draft edited" },
        @moui.Effect::none(),
      )
    Assign(owner) => {
      let records = model.records.copy()
      match model.selected_record {
        Some(id) =>
          for index in 0..<records.length() {
            if records[index].id == id {
              records[index] = { ..records[index], owner, }
            }
          }
        None => ()
      }
      (
        {
          ..model,
          records,
          assigned_owner: owner,
          last_event: "Assignment requires confirmation",
        },
        @moui.Effect::none(),
      )
    }
    Transition(status) => {
      let records = model.records.copy()
      match model.selected_record {
        Some(id) =>
          for index in 0..<records.length() {
            if records[index].id == id {
              records[index] = { ..records[index], status, }
            }
          }
        None => ()
      }
      (
        { ..model, records, last_event: "Status moved to " + status },
        @moui.Effect::none(),
      )
    }
    Submit =>
      (
        { ..model, last_event: "Confirmation required before submit" },
        @moui.Effect::none(),
      )
    ConfirmSubmit =>
      (
        { ..model, submitted: true, last_event: "Submitted after confirmation" },
        @moui.Effect::none(),
      )
    Export =>
      (
        { ..model, exported: true, last_event: "Export prepared" },
        @moui.Effect::none(),
      )
    RevealSensitive =>
      (
        {
          ..model,
          sensitive_revealed: true,
          last_event: "Sensitive field revealed with Scope",
        },
        @moui.Effect::none(),
      )
    ToggleFixture => {
      let next = if model.fixture_version == 1 { 2 } else { 1 }
      (
        {
          ..model,
          fixture_version: next,
          last_event: "Fixture switched to v" + next.to_string(),
        },
        @moui.Effect::none(),
      )
    }
    RunDemo => driver_effect(model, DemoCommand::RunAll, driver)
    NextStep => driver_effect(model, DemoCommand::NextStep, driver)
    Approve => driver_effect(model, DemoCommand::Approve, driver)
    Reject => driver_effect(model, DemoCommand::Reject, driver)
    Replay => driver_effect(model, DemoCommand::Replay, driver)
    Audit => driver_effect(model, DemoCommand::Audit, driver)
    ExportReport => driver_effect(model, DemoCommand::ExportReport, driver)
    ResetDemo => driver_effect(model, DemoCommand::Reset, driver)
    ConsoleWorkspaceChanged(workspace) =>
      ({ ..model, console_workspace: workspace }, @moui.Effect::none())
    AgentConsoleUpdated(snapshot) =>
      ({ ..model, console: snapshot }, @moui.Effect::none())
    DemoResultReceived(result) =>
      (apply_demo_result(model, result), @moui.Effect::none())
  }
}

///|
/// Compatibility helper for tests and simple hosts.
pub fn update(model : Model, message : Msg) -> Model {
  update_with_driver(model, message, DemoDriver::offline()).0
}

///|
fn semantic_id(model : Model, stable : String) -> @moui.SemanticId {
  let id = if model.fixture_version == 2 && stable == "workbench.export" {
    "workbench.export.v2"
  } else {
    stable
  }
  @moui.SemanticId::parse(id).unwrap()
}

///|
fn record_matches(model : Model, record : Record) -> Bool {
  let query = model.query.to_lower()
  (query == "" || record.name.to_lower().contains(query)) &&
  (model.selected_status == "All" || record.status == model.selected_status)
}

///|
fn filtered_records(model : Model) -> Array[Record] {
  model.records.filter(record => record_matches(model, record))
}

///|
fn selected_record(model : Model) -> Record? {
  match model.selected_record {
    None => None
    Some(id) => {
      for record in model.records {
        if record.id == id {
          return Some(record)
        }
      }
      None
    }
  }
}

///|
fn record_row(model : Model, record : Record) -> @moui.View[Msg] {
  let selected = model.selected_record == Some(record.id)
  row(
    [
      text(if selected { "> " + record.name } else { record.name }, width=178.0),
      text(record.owner, width=78.0),
      status_badge(record.status, width=76.0),
      text(record.amount, width=76.0),
      button("Open", on_click=SelectRecord(record.id)).semantic_id(
        semantic_id(
          model,
          "workbench.record." + record.id.to_string() + ".open",
        ),
      ),
    ],
    spacing=5.0,
  )
}

///|
fn workbench_view(model : Model) -> @moui.View[Msg] {
  let record = selected_record(model)
  let selected_label = match record {
    Some(value) => value.name + "  #" + value.id.to_string()
    None => "No record selected"
  }
  let sensitive = match (record, model.sensitive_revealed) {
    (Some(value), true) => value.sensitive_contact
    (Some(_), false) => "<hidden by Agent policy>"
    (None, _) => "Select a record to inspect"
  }
  let visible = filtered_records(model)
  let records_view = if visible.length() == 0 {
    text(
      "No records match the current query",
      role=@views.TextRole::Caption,
      width=540.0,
    )
  } else {
    column(visible.map(value => record_row(model, value)), spacing=7.0)
  }
  let status_label = match record {
    Some(value) => value.status
    None => "-"
  }
  let amount_label = match record {
    Some(value) => value.amount
    None => "-"
  }
  card(
    scroll_view(
      column(
        [
          text(
            "Secure Enterprise Operations Workbench",
            role=@views.TextRole::Title,
            width=550.0,
          ),
          row(
            [
              status_badge(
                "FIXTURE v" + model.fixture_version.to_string(),
                width=100.0,
              ),
              text(
                "semantic controls / typed actions / no screen capture",
                role=@views.TextRole::Caption,
                width=390.0,
              ),
            ],
            spacing=8.0,
          ),
          divider(),
          row(
            [
              text_field(
                model.query,
                on_input=value => QueryChanged(value),
                on_submit=Some(RunSearch),
                placeholder="Search records",
                width=220.0,
              ).semantic_id(
                @moui.SemanticId::parse("workbench.search.query").unwrap(),
              ),
              button("Search", on_click=RunSearch).semantic_id(
                @moui.SemanticId::parse("workbench.search.submit").unwrap(),
              ),
              button("Review", on_click=StatusChanged("Review")).semantic_id(
                @moui.SemanticId::parse("workbench.filter.review").unwrap(),
              ),
              button("All", on_click=StatusChanged("All")).semantic_id(
                @moui.SemanticId::parse("workbench.filter.all").unwrap(),
              ),
            ],
            spacing=5.0,
          ),
          row(
            [
              text(
                "Operational records",
                role=@views.TextRole::Headline,
                width=260.0,
              ),
              text(
                visible.length().to_string() + " visible",
                role=@views.TextRole::Caption,
                width=100.0,
              ),
            ],
            spacing=8.0,
          ),
          records_view,
          divider(),
          text(
            "Selected: " + selected_label,
            role=@views.TextRole::Headline,
            width=540.0,
          ),
          row(
            [
              text_field(
                model.editor_value,
                on_input=value => EditorChanged(value),
                placeholder="Edit selected record",
                width=210.0,
              ).semantic_id(
                @moui.SemanticId::parse("workbench.editor.name").unwrap(),
              ),
              button("Assign", on_click=Assign("M. Li")).semantic_id(
                @moui.SemanticId::parse("workbench.assign").unwrap(),
              ),
              button("Move to approved", on_click=Msg::Transition("Approved")).semantic_id(
                @moui.SemanticId::parse("workbench.transition").unwrap(),
              ),
            ],
            spacing=5.0,
          ),
          row(
            [
              text("Owner: " + model.assigned_owner, width=200.0),
              text("Status: " + status_label, width=170.0),
              text("Amount: " + amount_label, width=150.0),
            ],
            spacing=6.0,
          ),
          row(
            [
              button("Reveal sensitive", on_click=Msg::RevealSensitive).semantic_id(
                @moui.SemanticId::parse("workbench.sensitive.reveal").unwrap(),
              ),
              text("Contact: " + sensitive, width=330.0).semantic_id(
                @moui.SemanticId::parse("workbench.sensitive.contact").unwrap(),
              ),
            ],
            spacing=8.0,
          ),
          row(
            [
              button("Submit", on_click=Submit).semantic_id(
                @moui.SemanticId::parse("workbench.submit").unwrap(),
              ),
              button("Confirm", on_click=ConfirmSubmit).semantic_id(
                @moui.SemanticId::parse("workbench.submit.confirm").unwrap(),
              ),
              button("Export", on_click=Msg::Export).semantic_id(
                semantic_id(model, "workbench.export"),
              ),
            ],
            spacing=6.0,
          ),
          row(
            [
              button("Switch v1 / v2", on_click=ToggleFixture).semantic_id(
                @moui.SemanticId::parse("workbench.fixture.toggle").unwrap(),
              ),
              text(
                "Submitted=" +
                model.submitted.to_string() +
                "  Exported=" +
                model.exported.to_string(),
                role=@views.TextRole::Caption,
                width=320.0,
              ),
            ],
            spacing=8.0,
          ),
          text(
            "Latest event: " + model.last_event,
            role=@views.TextRole::Caption,
            width=540.0,
          ),
        ],
        spacing=10.0,
      ),
      width=590.0,
      height=744.0,
      shows_indicator=true,
    ),
    width=620.0,
    height=780.0,
    padding=18.0,
  )
}

///|
fn demo_step_label(step : DemoStep) -> String {
  match step {
    DemoStep::ReadSemantics => "1 Read semantics"
    DemoStep::Search => "2 Search"
    DemoStep::OpenRecord => "3 Open record"
    DemoStep::SensitiveRead => "4 Sensitive read"
    DemoStep::RequestTransitionConfirmation => "5 Transition confirmation"
    DemoStep::ApproveTransition => "6 Approve transition"
    DemoStep::RequestExportConfirmation => "7 Export confirmation"
    DemoStep::ApproveExport => "8 Approve export"
    DemoStep::Replay => "9 Replay"
    DemoStep::Audit => "10 Audit"
  }
}

///|
fn demo_status_label(status : DemoStatus) -> String {
  match status {
    DemoStatus::Idle => "IDLE"
    DemoStatus::Running => "RUNNING"
    DemoStatus::WaitingConfirmation => "WAITING"
    DemoStatus::Completed => "COMPLETE"
    DemoStatus::Failed => "FAILED"
  }
}

///|
fn console_button(
  label : String,
  workspace : ConsoleWorkspace,
) -> @moui.View[Msg] {
  button(label, on_click=ConsoleWorkspaceChanged(workspace)).semantic_id(
    @moui.SemanticId::parse(
      "agent.console." + label.to_lower().replace(old=" ", new="-"),
    ).unwrap(),
  )
}

///|
fn trace_view(model : Model) -> @moui.View[Msg] {
  if model.console.trace.length() == 0 {
    text(
      "No trace yet. Run the demo to create a redacted timeline.",
      role=@views.TextRole::Caption,
      width=550.0,
    )
  } else {
    column(
      model.console.trace.map(item => {
        card(
          column(
            [
              text(
                item.step + "  /  " + item.result,
                role=@views.TextRole::Control,
                width=520.0,
              ),
              text(item.target + "  " + item.action, width=520.0),
              text(
                item.policy +
                "  generation " +
                item.before_generation +
                " -> " +
                item.after_generation,
                role=@views.TextRole::Caption,
                width=520.0,
              ),
            ],
            spacing=4.0,
          ),
          width=550.0,
          padding=10.0,
        )
      }),
      spacing=7.0,
    )
  }
}

///|
fn console_detail(model : Model) -> @moui.View[Msg] {
  match model.console_workspace {
    ConsoleWorkspace::Semantics =>
      column(
        [
          text(
            "Committed semantics",
            role=@views.TextRole::Headline,
            width=550.0,
          ),
          text(
            "Generation " +
            model.console.generation +
            "  /  target " +
            model.console.selected_target,
            width=550.0,
          ),
          text(
            "Stable IDs: workbench.search.query, workbench.record.101.open, workbench.transition, workbench.export",
            role=@views.TextRole::Caption,
            width=550.0,
          ),
          text(
            "Sensitive contact: <redacted> until Scope records.sensitive.read is granted",
            width=550.0,
          ),
        ],
        spacing=8.0,
      )
    ConsoleWorkspace::Skills =>
      column(
        [
          text("Registered Skills", role=@views.TextRole::Headline, width=550.0),
          column(
            model.console.skills.map(id => {
              text(
                (if id == model.console.active_skill { "> " } else { "  " }) +
                id,
                width=540.0,
              )
            }),
            spacing=5.0,
          ),
          text(
            "Active: " + model.console.active_skill,
            role=@views.TextRole::Caption,
            width=550.0,
          ),
        ],
        spacing=8.0,
      )
    ConsoleWorkspace::Actions =>
      column(
        [
          text("Typed actions", role=@views.TextRole::Headline, width=550.0),
          text(
            "Focus   SetText   Activate   Submit   Scroll   SetSelection",
            width=550.0,
          ),
          text("Current target: " + model.console.selected_target, width=550.0),
          text(
            "No coordinates, OCR, simulated keyboard or screen capture",
            role=@views.TextRole::Caption,
            width=550.0,
          ),
        ],
        spacing=8.0,
      )
    ConsoleWorkspace::Policy =>
      column(
        [
          text("Policy decisions", role=@views.TextRole::Headline, width=550.0),
          match model.console.pending_confirmation {
            Some(request_id) =>
              card(
                column(
                  [
                    text(
                      "Pending confirmation: " + request_id,
                      role=@views.TextRole::Control,
                      width=520.0,
                    ),
                    text(
                      model.console.pending_confirmation_reason.unwrap_or(
                        "Human approval required",
                      ),
                      width=520.0,
                    ),
                    row(
                      [
                        button("Approve", on_click=Msg::Approve),
                        button("Reject", on_click=Msg::Reject),
                      ],
                      spacing=8.0,
                    ),
                  ],
                  spacing=7.0,
                ),
                width=550.0,
                padding=12.0,
              )
            None =>
              text(
                "No pending request. Read and navigation actions are autonomous.",
                width=550.0,
              )
          },
          column(
            model.console.policy.map(item => {
              text(
                item.decision + "  " + item.target + "  " + item.reason,
                width=540.0,
              )
            }),
            spacing=5.0,
          ),
        ],
        spacing=8.0,
      )
    ConsoleWorkspace::MCP =>
      column(
        [
          text("MCP calls", role=@views.TextRole::Headline, width=550.0),
          text("Default tools: read_semantics, perform_action", width=550.0),
          text(
            "Opt-in: skills/list, skills/get, skills/call, agent_read_trace, agent_replay_trace",
            role=@views.TextRole::Caption,
            width=550.0,
          ),
          column(
            model.console.mcp.map(item => {
              text(
                item.tool + "  " + item.result + "  " + item.error_code,
                width=540.0,
              )
            }),
            spacing=5.0,
          ),
        ],
        spacing=8.0,
      )
    ConsoleWorkspace::Trace => trace_view(model)
    ConsoleWorkspace::Replay =>
      column(
        [
          text("Replay regression", role=@views.TextRole::Headline, width=550.0),
          text(
            "Status: " +
            model.console.replay.status +
            "  /  completed " +
            model.console.replay.completed.to_string(),
            width=550.0,
          ),
          text("Failure: " + model.console.replay.failed_step, width=550.0),
          text(
            "Expected: " +
            model.console.replay.expected_target +
            "  Current: " +
            model.console.replay.actual_target,
            width=550.0,
          ),
          text(
            "Generation: " + model.console.replay.generation,
            role=@views.TextRole::Caption,
            width=550.0,
          ),
          row(
            [
              button("Replay trace", on_click=Msg::Replay),
              button("Switch fixture", on_click=Msg::ToggleFixture),
            ],
            spacing=8.0,
          ),
        ],
        spacing=8.0,
      )
    ConsoleWorkspace::Audit =>
      column(
        [
          text("AI-Ready Audit", role=@views.TextRole::Headline, width=550.0),
          text(
            "Status: " +
            model.console.audit.status +
            "  /  issues " +
            model.console.audit.issue_count.to_string(),
            width=550.0,
          ),
          text("Issues", role=@views.TextRole::Control, width=550.0),
          column(
            model.console.audit.issues.map(item => {
              text("! " + item, width=540.0)
            }),
            spacing=4.0,
          ),
          text("Passed checks", role=@views.TextRole::Control, width=550.0),
          column(
            model.console.audit.passed.map(item => {
              text("OK  " + item, width=540.0)
            }),
            spacing=4.0,
          ),
          row(
            [
              button("Run audit", on_click=Msg::Audit),
              button("Export report", on_click=Msg::ExportReport),
            ],
            spacing=8.0,
          ),
        ],
        spacing=8.0,
      )
  }
}

///|
fn agent_console_view(model : Model) -> @moui.View[Msg] {
  let snapshot = model.console
  card(
    scroll_view(
      column(
        [
          row(
            [
              text("Agent Console", role=@views.TextRole::Title, width=310.0),
              status_badge(demo_status_label(snapshot.demo_status), width=96.0),
            ],
            spacing=10.0,
          ),
          row(
            [
              badge("Generation " + snapshot.generation, width=125.0),
              badge("Trace " + snapshot.trace_entries.to_string(), width=90.0),
              badge(
                "Pending " + snapshot.pending_confirmations.to_string(),
                width=100.0,
              ),
              badge("Audit " + snapshot.audit_issues.to_string(), width=90.0),
            ],
            spacing=6.0,
          ),
          text(
            demo_step_label(snapshot.active_step) +
            "  /  " +
            snapshot.last_result,
            role=@views.TextRole::Caption,
            width=550.0,
          ),
          row(
            [
              button("Run demo", on_click=RunDemo).semantic_id(
                @moui.SemanticId::parse("agent.demo.run").unwrap(),
              ),
              button("Next step", on_click=Msg::NextStep).semantic_id(
                @moui.SemanticId::parse("agent.demo.next").unwrap(),
              ),
              button("Approve", on_click=Msg::Approve).semantic_id(
                @moui.SemanticId::parse("agent.demo.approve").unwrap(),
              ),
              button("Reject", on_click=Msg::Reject).semantic_id(
                @moui.SemanticId::parse("agent.demo.reject").unwrap(),
              ),
              button("Reset", on_click=ResetDemo).semantic_id(
                @moui.SemanticId::parse("agent.demo.reset").unwrap(),
              ),
            ],
            spacing=6.0,
          ),
          row(
            [
              button("Replay", on_click=Msg::Replay).semantic_id(
                @moui.SemanticId::parse("agent.demo.replay").unwrap(),
              ),
              button("Audit", on_click=Msg::Audit).semantic_id(
                @moui.SemanticId::parse("agent.demo.audit").unwrap(),
              ),
              button("Export report", on_click=Msg::ExportReport).semantic_id(
                @moui.SemanticId::parse("agent.demo.export-report").unwrap(),
              ),
            ],
            spacing=6.0,
          ),
          divider(),
          row(
            [
              console_button("Semantics", ConsoleWorkspace::Semantics),
              console_button("Skills", ConsoleWorkspace::Skills),
              console_button("Actions", ConsoleWorkspace::Actions),
              console_button("Policy", ConsoleWorkspace::Policy),
            ],
            spacing=5.0,
          ),
          row(
            [
              console_button("MCP", ConsoleWorkspace::MCP),
              console_button("Trace", ConsoleWorkspace::Trace),
              console_button("Replay", ConsoleWorkspace::Replay),
              console_button("Audit", ConsoleWorkspace::Audit),
            ],
            spacing=5.0,
          ),
          console_detail(model),
          divider(),
          text(snapshot.mode, role=@views.TextRole::Caption, width=550.0),
          text(
            "MCP: " + snapshot.mcp_status,
            role=@views.TextRole::Caption,
            width=550.0,
          ),
          text(
            "Sensitive values are redacted in Trace and MCP output by default.",
            role=@views.TextRole::Caption,
            width=550.0,
          ),
        ],
        spacing=9.0,
      ),
      width=590.0,
      height=744.0,
      shows_indicator=true,
    ),
    width=620.0,
    height=780.0,
    padding=18.0,
  )
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  row([workbench_view(model), agent_console_view(model)], spacing=14.0)
}

///|
pub fn program(
  driver? : DemoDriver = DemoDriver::offline(),
) -> @moui.Program[Model, Msg] {
  @moui.Program::new(
    init=() => (Model::new(), @moui.Effect::none()),
    update=(model, message) => update_with_driver(model, message, driver),
    view~,
  )
}

///|
/// Create a deterministic, host-independent demonstration driver.
pub fn DemoDriver::offline() -> DemoDriver {
  DemoDriver::new(run=(command, context) => local_demo_result(command, context))
}

///|
fn generation_increment(value : String) -> String {
  match value {
    "1" => "2"
    "2" => "3"
    "3" => "4"
    "4" => "5"
    "5" => "6"
    "6" => "7"
    "7" => "8"
    "8" => "9"
    _ => value
  }
}

///|
fn trace_row(
  step : String,
  target : String,
  action : String,
  policy : String,
  result : String,
  before : String,
  after : String,
) -> TraceRow {
  {
    step,
    target,
    action,
    policy,
    result,
    before_generation: before,
    after_generation: after,
  }
}

///|
fn local_snapshot(
  context : DemoContext,
  step : DemoStep,
  status : DemoStatus,
  active_skill : String,
  target : String,
  result : String,
) -> AgentConsoleSnapshot {
  {
    ..context.snapshot,
    active_step: step,
    demo_status: status,
    active_skill,
    selected_target: target,
    last_result: result,
  }
}

///|
fn append_local_trace(
  snapshot : AgentConsoleSnapshot,
  item : TraceRow,
) -> AgentConsoleSnapshot {
  let trace = snapshot.trace.copy()
  trace.push(item)
  { ..snapshot, trace, trace_entries: trace.length() }
}

///|
fn local_demo_result(
  command : DemoCommand,
  context : DemoContext,
) -> DemoResult {
  let current = context.snapshot
  match command {
    DemoCommand::Reset =>
      {
        snapshot: default_console(),
        event: "Demo reset",
        business: DemoBusinessAction::Reset,
      }
    DemoCommand::RunAll => {
      let before = current.generation
      let mut snapshot = local_snapshot(
        context,
        DemoStep::RequestTransitionConfirmation,
        DemoStatus::WaitingConfirmation,
        "workbench.transition",
        "workbench.transition",
        "Transition requires human confirmation",
      )
      snapshot = append_local_trace(
        snapshot,
        trace_row(
          "Read semantics", "semantic-tree", "read_semantics", "allow", "success",
          before, before,
        ),
      )
      snapshot = append_local_trace(
        snapshot,
        trace_row(
          "Search",
          "workbench.search.query",
          "SetText",
          "allow",
          "success",
          before,
          generation_increment(before),
        ),
      )
      snapshot = append_local_trace(
        snapshot,
        trace_row(
          "Open record",
          "workbench.record.101.open",
          "Activate",
          "allow",
          "success",
          generation_increment(before),
          generation_increment(generation_increment(before)),
        ),
      )
      snapshot = append_local_trace(
        snapshot,
        trace_row(
          "Sensitive read",
          "workbench.sensitive.contact",
          "read",
          "deny",
          "missing_scope",
          generation_increment(generation_increment(before)),
          generation_increment(generation_increment(before)),
        ),
      )
      snapshot = append_local_trace(
        snapshot,
        trace_row(
          "Transition",
          "workbench.transition",
          "Activate",
          "require_confirmation",
          "pending",
          generation_increment(generation_increment(before)),
          generation_increment(generation_increment(before)),
        ),
      )
      let policy = snapshot.policy.copy()
      policy.push({
        target: "workbench.transition",
        decision: "WAITING",
        reason: "high-risk workbench action",
        confirmation: "approval-demo-transition",
      })
      {
        snapshot: {
          ..snapshot,
          generation: generation_increment(generation_increment(before)),
          pending_confirmations: 1,
          pending_confirmation: Some("approval-demo-transition"),
          pending_confirmation_reason: Some("high-risk workbench action"),
          policy,
        },
        event: "Demo paused at transition confirmation",
        business: DemoBusinessAction::Search("Northwind"),
      }
    }
    DemoCommand::NextStep => {
      let before = current.generation
      match current.active_step {
        DemoStep::ReadSemantics => {
          let snapshot = append_local_trace(
            local_snapshot(
              context,
              DemoStep::Search,
              DemoStatus::Running,
              "workbench.search",
              "workbench.search.query",
              "Semantic tree read",
            ),
            trace_row(
              "Read semantics", "semantic-tree", "read_semantics", "allow", "success",
              before, before,
            ),
          )
          {
            snapshot,
            event: "Step 1 complete: semantics read",
            business: DemoBusinessAction::None,
          }
        }
        DemoStep::Search => {
          let after = generation_increment(before)
          let snapshot = append_local_trace(
            local_snapshot(
              context,
              DemoStep::OpenRecord,
              DemoStatus::Running,
              "workbench.open",
              "workbench.record.101.open",
              "Search executed",
            ),
            trace_row(
              "Search", "workbench.search.query", "SetText", "allow", "success",
              before, after,
            ),
          )
          {
            snapshot: { ..snapshot, generation: after },
            event: "Step 2 complete: search",
            business: DemoBusinessAction::Search("Northwind"),
          }
        }
        DemoStep::OpenRecord => {
          let after = generation_increment(before)
          let snapshot = append_local_trace(
            local_snapshot(
              context,
              DemoStep::SensitiveRead,
              DemoStatus::Running,
              "workbench.open",
              "workbench.record.101.open",
              "Record opened",
            ),
            trace_row(
              "Open record", "workbench.record.101.open", "Activate", "allow", "success",
              before, after,
            ),
          )
          {
            snapshot: { ..snapshot, generation: after },
            event: "Step 3 complete: record opened",
            business: DemoBusinessAction::Open(101),
          }
        }
        DemoStep::SensitiveRead => {
          let snapshot = append_local_trace(
            local_snapshot(
              context,
              DemoStep::RequestTransitionConfirmation,
              DemoStatus::WaitingConfirmation,
              "workbench.read_sensitive",
              "workbench.sensitive.contact",
              "Denied: missing Scope records.sensitive.read",
            ),
            trace_row(
              "Sensitive read", "workbench.sensitive.contact", "read", "deny", "missing_scope",
              before, before,
            ),
          )
          {
            snapshot,
            event: "Step 4 stopped: sensitive value remains redacted",
            business: DemoBusinessAction::None,
          }
        }
        DemoStep::RequestTransitionConfirmation =>
          local_demo_result(DemoCommand::RunAll, context)
        DemoStep::ApproveTransition =>
          local_demo_result(DemoCommand::Approve, context)
        DemoStep::RequestExportConfirmation =>
          local_demo_result(DemoCommand::Approve, context)
        DemoStep::ApproveExport =>
          local_demo_result(DemoCommand::Approve, context)
        DemoStep::Replay => local_demo_result(DemoCommand::Replay, context)
        DemoStep::Audit => local_demo_result(DemoCommand::Audit, context)
      }
    }
    DemoCommand::Approve => {
      let before = current.generation
      match current.pending_confirmation {
        None =>
          {
            snapshot: { ..current, last_result: "No confirmation is pending" },
            event: "Approve ignored",
            business: DemoBusinessAction::None,
          }
        Some(_) => {
          let after = generation_increment(before)
          let approving_export = current.active_step ==
            DemoStep::RequestExportConfirmation
          let next_step = if approving_export {
            DemoStep::Replay
          } else {
            DemoStep::RequestExportConfirmation
          }
          let result = if approving_export {
            "Export executed"
          } else {
            "Transition executed"
          }
          let snapshot = append_local_trace(
            local_snapshot(
              context,
              next_step,
              if approving_export {
                DemoStatus::Completed
              } else {
                DemoStatus::WaitingConfirmation
              },
              if approving_export {
                "workbench.export"
              } else {
                "workbench.transition"
              },
              if approving_export {
                "workbench.export"
              } else {
                "workbench.transition"
              },
              result,
            ),
            trace_row(
              if approving_export {
                "Export"
              } else {
                "Transition"
              },
              if approving_export {
                "workbench.export"
              } else {
                "workbench.transition"
              },
              "Activate",
              "approved",
              "success",
              before,
              after,
            ),
          )
          {
            snapshot: {
              ..snapshot,
              generation: after,
              pending_confirmations: if approving_export {
                0
              } else {
                1
              },
              pending_confirmation: if approving_export {
                None
              } else {
                Some("approval-demo-export")
              },
              pending_confirmation_reason: if approving_export {
                None
              } else {
                Some("export leaves the application boundary")
              },
            },
            event: result,
            business: if approving_export {
              DemoBusinessAction::Export
            } else {
              DemoBusinessAction::Transition("Approved")
            },
          }
        }
      }
    }
    DemoCommand::Reject => {
      let confirmation = current.pending_confirmation.unwrap_or("none")
      let mut snapshot = append_local_trace(
        current,
        trace_row(
          "Confirmation",
          current.selected_target,
          "approval",
          "deny",
          "rejected",
          current.generation,
          current.generation,
        ),
      )
      let policy = snapshot.policy.copy()
      policy.push({
        target: current.selected_target,
        decision: "DENY",
        reason: "rejected by human reviewer",
        confirmation,
      })
      snapshot = {
        ..snapshot,
        policy,
        demo_status: DemoStatus::Failed,
        pending_confirmations: 0,
        pending_confirmation: None,
        pending_confirmation_reason: None,
        last_result: "Rejected by human reviewer",
      }
      {
        snapshot,
        event: "Confirmation rejected; no business action executed",
        business: DemoBusinessAction::None,
      }
    }
    DemoCommand::Replay => {
      let failed = context.fixture_version == 2
      let replay = if failed {
        {
          status: "FAILED",
          completed: 4,
          failed_step: "5 / export semantic ID changed",
          expected_target: "workbench.export",
          actual_target: "workbench.export.v2",
          generation: current.generation,
        }
      } else {
        {
          status: "PASSED",
          completed: current.trace_entries,
          failed_step: "-",
          expected_target: "-",
          actual_target: "-",
          generation: current.generation,
        }
      }
      let snapshot = {
        ..current,
        active_step: DemoStep::Replay,
        replay,
        replay_status: replay.status,
        last_result: if failed {
          "Replay stopped at first semantic regression"
        } else {
          "Replay completed successfully"
        },
      }
      {
        snapshot,
        event: snapshot.last_result,
        business: DemoBusinessAction::None,
      }
    }
    DemoCommand::Audit => {
      let audit = {
        status: "PASSED",
        issue_count: 0,
        issues: [],
        passed: [
          "stable semantic IDs", "typed text actions", "high-risk policy", "sensitive field redaction",
          "MCP default route compatibility",
        ],
      }
      let snapshot = {
        ..current,
        active_step: DemoStep::Audit,
        audit,
        audit_issues: 0,
        last_result: "AI-Ready Audit passed",
      }
      {
        snapshot,
        event: "AI-Ready Audit passed",
        business: DemoBusinessAction::None,
      }
    }
    DemoCommand::ExportReport => {
      let report = "MoUI AI-Native UI report: generation=" +
        current.generation +
        "; trace=" +
        current.trace_entries.to_string() +
        "; replay=" +
        current.replay.status +
        "; audit=" +
        current.audit.status
      {
        snapshot: {
          ..current,
          report_text: report,
          last_result: "JSON/text report prepared",
        },
        event: "Report prepared without sensitive values",
        business: DemoBusinessAction::None,
      }
    }
  }
}
