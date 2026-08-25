///|
/// A platform-neutral enterprise data workbench used as the reference
/// application for MoUI AI-Native UI and Agent Inspector.
using @views {button, column, row, text, text_field}

pub(all) struct Record {
  id : Int
  name : String
  owner : String
  status : String
  amount : String
} derive(Eq, Debug, ToJson)

pub(all) struct Model {
  query : String
  selected_status : String
  selected_record : Int?
  editor_value : String
  submitted : Bool
  exported : Bool
  last_event : String
  records : Array[Record]
}

pub(all) enum Msg {
  QueryChanged(String)
  RunSearch
  StatusChanged(String)
  SelectRecord(Int)
  EditorChanged(String)
  Submit
  ConfirmSubmit
  Export
}

///|
pub fn Model::new() -> Model {
  {
    query: "",
    selected_status: "All",
    selected_record: None,
    editor_value: "",
    submitted: false,
    exported: false,
    last_event: "Ready for an Agent scenario",
    records: [
      { id: 101, name: "Northwind renewal", owner: "A. Chen", status: "Review", amount: "$42,000" },
      { id: 102, name: "Contoso rollout", owner: "M. Li", status: "Approved", amount: "$18,500" },
      { id: 103, name: "Fabrikam migration", owner: "S. Wang", status: "Draft", amount: "$76,200" },
    ],
  }
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  match message {
    QueryChanged(value) => { ..model, query: value, last_event: "Search query changed" }
    RunSearch => { ..model, last_event: "Search executed" }
    StatusChanged(value) => { ..model, selected_status: value, last_event: "Filter changed" }
    SelectRecord(id) => {
      let mut editor_value = ""
      for record in model.records {
        if record.id == id {
          editor_value = record.name
        }
      }
      { ..model, selected_record: Some(id), editor_value, last_event: "Record opened" }
    }
    EditorChanged(value) => { ..model, editor_value: value, last_event: "Draft edited" }
    Submit => { ..model, last_event: "Confirmation required before submit" }
    ConfirmSubmit => { ..model, submitted: true, last_event: "Submitted after confirmation" }
    Export => { ..model, exported: true, last_event: "Export prepared" }
  }
}

///|
fn record_row(record : Record) -> @moui.View[Msg] {
  row([
    text(record.name, width=220.0),
    text(record.owner, width=110.0),
    text(record.status, width=100.0),
    text(record.amount, width=100.0),
    button("Open", on_click=SelectRecord(record.id)).semantic_id(
      @moui.SemanticId::parse("workbench.record." + record.id.to_string() + ".open").unwrap(),
    ),
  ], spacing=10.0)
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let selected = model.selected_record.map(id => "Selected record: " + id.to_string()).unwrap_or("No record selected")
  column([
    text("MoUI AI-Native UI / Enterprise Data Workbench", role=@views.TextRole::Title),
    row([
      text_field(model.query, on_input=value => QueryChanged(value), on_submit=Some(RunSearch), placeholder="Search records", width=300.0).semantic_id(
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
    ], spacing=8.0),
    text("Data table", role=@views.TextRole::Headline),
    column(model.records.map(record_row), spacing=6.0),
    text(selected, role=@views.TextRole::Headline),
    text_field(model.editor_value, on_input=value => EditorChanged(value), placeholder="Edit selected record", width=360.0).semantic_id(
      @moui.SemanticId::parse("workbench.editor.name").unwrap(),
    ),
    row([
      button("Submit", on_click=Submit).semantic_id(
        @moui.SemanticId::parse("workbench.submit").unwrap(),
      ),
      button("Confirm submit", on_click=ConfirmSubmit).semantic_id(
        @moui.SemanticId::parse("workbench.submit.confirm").unwrap(),
      ),
      button("Export", on_click=Export).semantic_id(
        @moui.SemanticId::parse("workbench.export").unwrap(),
      ),
    ], spacing=8.0),
    text("Inspector workspaces: Semantics | Actions | Trace | Replay | AI-Ready Audit"),
    text("Status: " + model.last_event),
  ], spacing=12.0)
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}
