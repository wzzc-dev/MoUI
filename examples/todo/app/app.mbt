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
pub fn TodoApp::completed_binding(
  self : TodoApp,
  id : Int,
) -> @core.Binding[Bool] {
  @core.Binding::new(
    get=() => {
      for item in self.items.get() {
        if item.id == id {
          return item.completed
        }
      }
      false
    },
    set=completed => {
      self.items.update(items => {
        items.map(item => {
          if item.id == id {
            { ..item, completed }
          } else {
            item
          }
        })
      })
    },
  )
}

///|
pub fn TodoApp::root(
  self : TodoApp,
  ctx : @core.BuildContext,
) -> @core.ViewSpec {
  let theme = @core.Theme::light()
  let items = ctx.watch(self.items)
  let draft = ctx.binding(self.draft)
  let children : Array[@core.ViewSpec] = [
    @views.text("MoUI Todo")
    .font(theme.typography.title)
    .foreground(theme.palette.foreground),
    @views.row(
      [
        @views.text_field(
          draft,
          on_submit=Some(() => self.submit_draft()),
          placeholder="New todo",
          style=@core.TextFieldStyle::filled(theme~),
          width=220.0,
        ),
        @views.button(
          "Add",
          on_click=() => self.submit_draft(),
          style=@core.ButtonStyle::filled(theme~),
          width=120.0,
        ),
      ],
      spacing=8.0,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
  ]
  for item in items {
    children.push(self.todo_row(item, theme))
  }
  @views.surface(
    @views.column(children, spacing=theme.spacing_scale.sm),
    width=420.0,
    height=520.0,
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn TodoApp::todo_row(
  self : TodoApp,
  item : TodoItem,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.row(
    [
      @views.checkbox(
        item.text,
        checked=self.completed_binding(item.id),
        foreground=theme.palette.foreground,
        check_color=theme.palette.primary,
      ).frame(width=220.0, height=36.0),
      @views.button(
        "Remove",
        on_click=() => self.remove(item.id),
        style=@core.ButtonStyle::outline(theme~),
        width=120.0,
      ),
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
) -> @core.AppRuntime {
  @core.AppRuntime::new_component(
    root=@core.Component::new(ctx => self.root(ctx)),
    size=@core.Size::new(width~, height~),
  )
}
