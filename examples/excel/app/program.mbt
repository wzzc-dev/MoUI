///|
pub fn program_with_services(
  app : ExcelApp,
  services : @host.HostAppServices,
) -> @moui.Program[ExcelApp, ExcelMsg] {
  ignore(services)
  @moui.Program::new(
    init=() => (app, @moui.Effect::none()),
    update=(model, msg) => ExcelApp::update(model, msg),
    view=app => {
      @views.component(ctx => {
        let _ = ctx.watch(app.model)
        app.view()
      })
    },
    subscriptions=app => ExcelApp::subscriptions(app),
  )
}

///|
pub fn program() -> @moui.Program[ExcelApp, ExcelMsg] {
  let app = ExcelApp::new(@host.HostAppServices::unavailable())
  program_with_services(app, @host.HostAppServices::unavailable())
}

///|
pub fn action_commands(
  app : ExcelApp,
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
) -> @core.ActionCommandMap {
  ignore(services)
  @core.ActionCommandMap::new(bindings=[
    nav_binding("Left", "ArrowLeft", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(0, -1)))
    }),
    nav_binding("Right", "ArrowRight", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(0, 1)))
    }),
    nav_binding("Up", "ArrowUp", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(-1, 0)))
    }),
    nav_binding("Down", "ArrowDown", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(1, 0)))
    }),
    action_binding("Edit Cell", "Enter", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellEditStarted))
    }),
    action_binding("Cancel Edit", "Escape", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellEditCancelled))
    }),
    action_binding(
      "New Workbook",
      "n",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::NewWorkbook)) },
      meta=true,
    ),
    action_binding(
      "Open File",
      "o",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FileOpenRequested)) },
      meta=true,
    ),
    action_binding(
      "Save File",
      "s",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FileSaveRequested)) },
      meta=true,
    ),
    action_binding(
      "Load Demo",
      "d",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::LoadDemo)) },
      meta=true,
    ),
    action_binding(
      "Cut",
      "x",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::CutCells)) },
      meta=true,
    ),
    action_binding(
      "Copy",
      "c",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::CopyCells)) },
      meta=true,
    ),
    action_binding(
      "Paste",
      "v",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::PasteCells)) },
      meta=true,
    ),
    action_binding("Delete", "Backspace", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::DeleteSelectedCells))
    }),
  ])
}

///|
fn nav_binding(
  label : String,
  key : String,
  handle : () -> Unit,
) -> @core.CommandBinding {
  @core.CommandBinding::new(
    command=@core.ActionCommand::new(
      intent=@core.CommandIntent::Activate,
      label~,
      shortcut=Some(@core.KeyboardShortcut::new(key~)),
      context_menu=false,
    ),
    handle~,
  )
}

///|
fn action_binding(
  label : String,
  key : String,
  handle : () -> Unit,
  meta? : Bool = false,
) -> @core.CommandBinding {
  let modifiers = if meta {
    @core.KeyModifiers::new(meta=true)
  } else {
    @core.KeyModifiers::none()
  }
  @core.CommandBinding::new(
    command=@core.ActionCommand::new(
      intent=@core.CommandIntent::Activate,
      label~,
      shortcut=Some(@core.KeyboardShortcut::new(key~, modifiers~)),
      context_menu=false,
    ),
    handle~,
  )
}
