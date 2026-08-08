///|
test "excel model loads, selects, edits, and formats workbook data" {
  let initial = ExcelModel::with_demo_data()
  debug_inspect(initial.sheet_names(), content="[\"Sales\", \"Inventory\"]")
  let selected = update(initial, ExcelMsg::CellSelected(1, 1))
  inspect(selected.selected_ref(), content="B2")
  let edited = update(
    update(selected, ExcelMsg::CellValueChanged("42")),
    ExcelMsg::CellEditCommitted,
  )
  inspect(edited.active_sheet().display_cell(1, 1), content="42")
  let formatted = update(edited, ExcelMsg::ToggleBold)
  assert_true(formatted.selected_format().bold)
  let undone = update(formatted, ExcelMsg::Undo)
  assert_false(undone.selected_format().bold)
}

///|
test "excel model applies range copy, paste, and selection navigation" {
  let model = ExcelModel::with_demo_data()
  let ranged = {
    ..model,
    workbook: model.workbook.select_range(1, 0, 2, 1),
  }
  let copied = update(ranged, ExcelMsg::CopyCells)
  let pasted = update(copied.select_cell(10, 0), ExcelMsg::PasteCells)
  inspect(pasted.active_sheet().display_cell(10, 0), content="Widget A")
  inspect(pasted.active_sheet().display_cell(11, 1), content="800")
  inspect(pasted.selected_ref(), content="A11:B12")
  let extended = update(pasted, ExcelMsg::SelectionNavigate(1, 1))
  inspect(extended.selected_ref(), content="A11:C13")
}

///|
test "excel app update is immutable and changes only the returned model" {
  let app = ExcelApp::new().with_model(ExcelModel::with_demo_data())
  let (next, _effect) = app.update(ExcelMsg::CellSelected(1, 1))
  inspect(app.model.selected_ref(), content="")
  inspect(next.model.selected_ref(), content="B2")
}

///|
test "excel app service completion returns a new model" {
  let app = ExcelApp::new()
  let (running, _) = app.handle_file_open(@services.AppServices::unavailable())
  assert_true(running.model.file_status is ExcelFileStatus::Running(_))
  assert_true(app.model.file_status is ExcelFileStatus::Idle)
  let (cancelled, _) = running.apply_service_completion(
    ExcelServiceCompletion::FileOpenPicked(
      @services.ServiceTaskResult::Cancelled,
    ),
    @services.AppServices::unavailable(),
  )
  inspect(cancelled.model.status, content="Cancelled")
  assert_true(cancelled.model.file_status is ExcelFileStatus::Idle)
}

///|
test "excel clipboard effect dispatches a typed completion into the model" {
  let clipboard = Ref("")
  let services = clipboard_services(clipboard)
  let model = ExcelModel::with_demo_data()
  let app = ExcelApp::new().with_model({
    ..model,
    workbook: model.workbook.select_range(1, 0, 2, 1),
  })
  let latest = Ref(app)
  let runtime = excel_tracked_runtime(
    app,
    latest,
    services~,
  )
  assert_true(
    excel_dispatch_shortcut(
      runtime,
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ) is Some(_),
  )
  inspect(clipboard.val, content="Widget A\t1200\nWidget B\t800")
  inspect(latest.val.model.status, content="Clipboard updated")
  assert_true(latest.val.model.last_clipboard_from_app)
}

///|
test "excel runtime text input changes the Program model through messages" {
  let app = ExcelApp::new().with_model(
    ExcelModel::with_demo_data().select_cell(1, 1),
  )
  let latest = Ref(app)
  let runtime = excel_tracked_runtime(
    app,
    latest,
    services=@services.AppServices::unavailable(),
  )
  assert_true(runtime.focus_key("excel-formula-input"))
  ignore(runtime.dispatch_focused_text_command(@core.CommandIntent::SelectAll))
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("42")),
  )
  inspect(latest.val.model.active_sheet().safe_raw(1, 1), content="42")
  inspect(app.model.active_sheet().safe_raw(1, 1), content="1200")
}

///|
test "excel command map dispatches navigation and formatting messages" {
  let app = ExcelApp::new().with_model(
    ExcelModel::with_demo_data().select_cell(1, 1),
  )
  let latest = Ref(app)
  let runtime = excel_tracked_runtime(
    app,
    latest,
    services=@services.AppServices::unavailable(),
  )
  assert_true(
    excel_dispatch_shortcut(
      runtime,
      @core.KeyboardEvent::new(key="Tab"),
    ) is Some(_),
  )
  inspect(latest.val.model.selected_ref(), content="C2")
  assert_true(
    excel_dispatch_shortcut(
      runtime,
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ) is Some(_),
  )
  assert_true(latest.val.model.selected_format().bold)
}

///|
test "excel view builds from the current immutable snapshot" {
  let app = ExcelApp::new().with_model(ExcelModel::with_demo_data())
  let commands = @runtime.new_program_with_dimensions(
    program=app.program(),
    width=shell_width,
    height=shell_height,
  ).draw_commands()
  assert_true(commands.length() > 0)
  assert_true(excel_has_text(commands, "New"))
  assert_true(excel_has_text(commands, "fx"))
  assert_true(excel_has_text(commands, "Heat"))
}

///|
fn excel_tracked_runtime(
  app : ExcelApp,
  latest : Ref[ExcelApp],
  services~ : @services.AppServices,
) -> @runtime.AppRuntime {
  let program = @moui.Program::new(
    init=() => (app, @moui.Effect::none()),
    update=(current, message) => current.update_with_services(message, services),
    view=current => {
      latest.val = current
      current.view()
    },
  ).with_commands(commands=current => {
    excel_program_commands(current)
  })
  @runtime.new_program_with_dimensions(
    program~,
    width=shell_width,
    height=shell_height,
  )
}

///|
fn excel_dispatch_shortcut(
  runtime : @runtime.AppRuntime,
  event : @core.KeyboardEvent,
) -> @core.CommandIntent? {
  let mut matched : @core.CommandIntent? = None
  for command in runtime.action_commands() {
    if command.matches(event) {
      matched = Some(command.intent)
      break
    }
  }
  runtime.dispatch_event(@core.AppEvent::Keyboard(event))
  matched
}

///|
fn excel_has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn clipboard_services(clipboard : Ref[String]) -> @services.AppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::WriteText(text)
        ) => {
          clipboard.val = text
          @host.HostServiceResponse::ClipboardWritten
        }
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => @host.HostServiceResponse::ClipboardText(clipboard.val)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @backend_common_services.app_services(bridge~)
}
