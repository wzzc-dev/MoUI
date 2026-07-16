///|
pub(all) struct TodoItem {
  id : Int
  label : String
  completed : Bool
} derive(Eq, Debug)

///|
pub struct Model {
  route : String
  counter : Int
  todo_items : Array[TodoItem]
  todo_draft : String
  next_todo_id : Int
  profile_name : String
  data_filter : String
  workflow_step : Int
  notice : String
  scroll : @state.ScrollState
}

///|
pub(all) enum Msg {
  Navigate(String)
  Increment
  Decrement
  TodoDraftChanged(String)
  TodoSubmit
  TodoToggled(Int, Bool)
  TodoRemoved(Int)
  ProfileNameChanged(String)
  SaveProfile
  DataFilterChanged(String)
  WorkflowBack
  WorkflowNext
  DismissNotice
}

///|
pub fn Model::new(route? : String = "welcome") -> Model {
  {
    route: normalize_pattern_route(route),
    counter: 0,
    todo_items: [
      { id: 0, label: "Keep domain state in the feature package", completed: true },
      { id: 1, label: "Lift only feature messages at the app root", completed: false },
    ],
    todo_draft: "",
    next_todo_id: 2,
    profile_name: "Mira Chen",
    data_filter: "",
    workflow_step: 0,
    notice: "",
    scroll: @state.ScrollState::new(),
  }
}

///|
pub fn Model::route(self : Model) -> String {
  self.route
}

///|
pub fn Model::open(self : Model, route : String) -> Model {
  let next = normalize_pattern_route(route)
  if next != self.route {
    self.scroll.scroll_to(x=0.0, y=0.0)
  }
  { ..self, route: next }
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  match message {
    Navigate(route) => model.open(route)
    Increment => { ..model, counter: model.counter + 1 }
    Decrement => { ..model, counter: model.counter - 1 }
    TodoDraftChanged(value) => { ..model, todo_draft: value }
    TodoSubmit => {
      if model.todo_draft == "" {
        model
      } else {
        let items = model.todo_items.copy()
        items.push({
          id: model.next_todo_id,
          label: model.todo_draft,
          completed: false,
        })
        {
          ..model,
          todo_items: items,
          todo_draft: "",
          next_todo_id: model.next_todo_id + 1,
        }
      }
    }
    TodoToggled(id, completed) =>
      {
        ..model,
        todo_items: model.todo_items.map(item => if item.id == id {
          { ..item, completed, }
        } else {
          item
        }),
      }
    TodoRemoved(id) =>
      { ..model, todo_items: model.todo_items.filter(item => item.id != id) }
    ProfileNameChanged(value) => { ..model, profile_name: value }
    SaveProfile => { ..model, notice: "Profile saved locally" }
    DataFilterChanged(value) => { ..model, data_filter: value }
    WorkflowBack => { ..model, workflow_step: (model.workflow_step - 1).max(0) }
    WorkflowNext => { ..model, workflow_step: (model.workflow_step + 1).min(2) }
    DismissNotice => { ..model, notice: "" }
  }
}

///|
pub fn pattern_routes() -> Array[String] {
  [
    "welcome",
    "counter",
    "todo",
    "forms",
    "data",
    "navigation",
    "workflow",
    "text-media",
  ]
}

///|
fn normalize_pattern_route(route : String) -> String {
  if pattern_routes().contains(route) {
    route
  } else if route == "examples" {
    "counter"
  } else if route == "feedback" || route == "layout" {
    "workflow"
  } else {
    "welcome"
  }
}

///|
pub fn subscriptions(_model : Model) -> @moui.Subscription[Msg] {
  @moui.Subscription::none()
}

///|
pub fn program(route? : String = "welcome") -> @moui.Program[Model, Msg] {
  @moui.Program::simple_with_environment(
    init=Model::new(route~),
    update~,
    view~,
    subscriptions~,
  )
}
