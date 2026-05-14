///|
pub(all) struct TodoItem {
  id : Int
  text : String
  completed : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct TodoApp {
  items : @core.State[Array[TodoItem]]
  next_id : @core.State[Int]
  draft : @core.State[String]
}

///|
pub fn TodoItem::new(id~ : Int, text~ : String) -> TodoItem {
  { id, text, completed: false }
}

///|
pub fn TodoItem::display_text(self : TodoItem) -> String {
  if self.completed {
    "[x] \{self.text}"
  } else {
    "[ ] \{self.text}"
  }
}

///|
pub fn TodoApp::new() -> TodoApp {
  {
    items: @core.State::new([]),
    next_id: @core.State::new(0),
    draft: @core.State::new(""),
  }
}

///|
pub fn TodoApp::items(self : TodoApp) -> Array[TodoItem] {
  self.items.get()
}

///|
pub fn TodoApp::count(self : TodoApp) -> Int {
  self.items.get().length()
}

///|
pub fn TodoApp::add(self : TodoApp, text : String) -> Unit {
  let id = self.next_id.get()
  self.next_id.set(id + 1)
  let items = self.items.get().copy()
  items.push(TodoItem::new(id~, text~))
  self.items.set(items)
}

///|
pub fn TodoApp::add_sample(self : TodoApp) -> Unit {
  self.add("Item \{self.next_id.get() + 1}")
}

///|
pub fn TodoApp::set_draft(self : TodoApp, text : String) -> Unit {
  self.draft.set(text)
}

///|
pub fn TodoApp::submit_draft(self : TodoApp) -> Unit {
  let text = self.draft.get()
  if text != "" {
    self.add(text)
    self.draft.set("")
  }
}

///|
pub fn TodoApp::toggle(self : TodoApp, id : Int) -> Unit {
  self.items.update(items => {
    items.map(item => {
      if item.id == id {
        { ..item, completed: !item.completed }
      } else {
        item
      }
    })
  })
}

///|
pub fn TodoApp::remove(self : TodoApp, id : Int) -> Unit {
  self.items.update(items => items.filter(item => item.id != id))
}

///|
pub fn TodoApp::root(self : TodoApp) -> @core.ViewNode {
  let children : Array[@core.ViewNode] = [
    @views.label("MoUI Todo"),
    @views.row(
      [
        @views.text_field_on_submit(
          self.draft.binding(),
          () => self.submit_draft(),
          placeholder="New todo",
          width=220.0,
        ),
        @views.button_on_click("Add", () => self.submit_draft(), width=120.0),
      ],
      spacing=8.0,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
  ]
  for item in self.items.get() {
    children.push(self.todo_row(item))
  }
  @views.column(children, spacing=8.0)
}

///|
fn TodoApp::todo_row(self : TodoApp, item : TodoItem) -> @core.ViewNode {
  @views.row(
    [
      @views.button_on_click(
        item.display_text(),
        () => self.toggle(item.id),
        width=220.0,
      ),
      @views.button_on_click("Remove", () => self.remove(item.id), width=120.0),
    ],
    spacing=8.0,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
  ).key("todo-\{item.id}")
}

///|
pub fn TodoApp::runtime(
  self : TodoApp,
  width? : Double = 800.0,
  height? : Double = 600.0,
) -> @backend.AppRuntime {
  @backend.AppRuntime::new_dynamic(
    root=() => self.root(),
    size=@core.Size::new(width~, height~),
  )
}
