///|
test "file importer maps dropped files into selection" {
  let model = FileImporterModel::new().update(
    FilesDropped(["/tmp/a.csv", "/tmp/b.json"]),
  )
  inspect(model.files.length(), content="2")
  inspect(model.files[0].source, content="Drop")
  inspect(model.selection().summary(), content="2 files selected")
  inspect(model.last_event, content="Imported 2 file(s) from Drop")
}

///|
test "file importer handles empty selection" {
  let model = FileImporterModel::new().update(FilesDropped([]))
  inspect(model.files.length(), content="0")
  inspect(model.last_event, content="No files selected")
  assert_true(model.status is FileImporterStatus::Ready)
}

///|
test "file importer uses unavailable host service state" {
  let update = FileImporterModel::new().update_with_services(
    BrowseRequested,
    @host.HostAppServices::unavailable(),
  )
  assert_true(update.model.status is FileImporterStatus::Requesting)
  let model = run_file_importer_effect(update)
  assert_true(model.status is FileImporterStatus::Unavailable(_))
  inspect(model.last_event, content="File dialog unavailable")
  inspect(
    model.availability_reason,
    content="file dialog service is unavailable",
  )
}

///|
test "file importer handles immediate host file selection" {
  let services = host_services_for_file_dialog(["/tmp/report.csv"])
  let update = FileImporterModel::new().update_with_services(
    BrowseRequested,
    services,
  )
  assert_true(update.model.status is FileImporterStatus::Requesting)
  let model = run_file_importer_effect(update)
  inspect(model.files.length(), content="1")
  inspect(model.files[0].path, content="/tmp/report.csv")
  inspect(model.files[0].source, content="Dialog")
  inspect(model.last_event, content="Imported 1 file(s) from Dialog")
}

///|
test "file importer handles mocked pending completion" {
  let queue = @host.HostServiceAsyncQueue::new()
  let services = async_file_dialog_services(queue)
  let update = FileImporterModel::new().update_with_services(
    BrowseRequested,
    services,
  )
  assert_true(update.model.status is FileImporterStatus::Requesting)
  let pending_model = run_file_importer_effect(update)
  guard pending_model.status is FileImporterStatus::Pending(id) else {
    fail("expected pending file dialog")
  }
  inspect(services.pending_count(), content="1")
  let pending = services.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    services.complete(
      id,
      @host.HostServiceResponse::FileDialogSelection(["/tmp/later.txt"]),
    ),
  )
  guard services.take_completed(id) is Some(completion) else {
    fail("expected completion")
  }
  let completed = pending_model.update(HostCompleted(completion))
  inspect(completed.files.length(), content="1")
  inspect(completed.files[0].path, content="/tmp/later.txt")
  inspect(completed.last_event, content="Imported 1 file(s) from Dialog")
}

///|
test "file importer runtime runs host service effects" {
  let services = host_services_for_file_dialog(["/tmp/runtime.csv"])
  let runtime = FileImporterModel::new().runtime_with_services(
    services,
    width=860.0,
    height=620.0,
  )
  click_text(runtime, "Browse")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "/tmp/runtime.csv"))
  assert_true(has_text(commands, "Imported 1 file(s) from Dialog"))
}

///|
test "file importer composes as effect-capable child program" {
  let services = host_services_for_file_dialog(["/tmp/composed.csv"])
  let runtime = ParentImporterModel::new().runtime_with_services(
    services,
    width=900.0,
    height=680.0,
  )
  click_text(runtime, "Browse")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Parent Shell"))
  assert_true(has_text(commands, "/tmp/composed.csv"))
  assert_true(has_text(commands, "Imported 1 file(s) from Dialog"))
}

///|
test "file importer runtime draws panel labels" {
  let commands = @app.runtime(width=860.0, height=620.0).draw_commands()
  assert_true(has_text(commands, "File Importer"))
  assert_true(has_text(commands, "Import Files"))
  assert_true(has_text(commands, "Drop files here"))
  assert_true(has_text(commands, "No files selected"))
  assert_true(has_text(commands, "Selected files"))
  assert_true(has_text(commands, "Platform paths"))
}

///|
fn host_services_for_file_dialog(
  paths : Array[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(paths)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn async_file_dialog_services(
  queue : @host.HostServiceAsyncQueue,
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) => queue.submit(request)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~, async_queue=Some(queue))
}

///|
struct ParentImporterModel {
  child : FileImporterModel
}

///|
enum ParentImporterMsg {
  Child(FileImporterMsg)
}

///|
fn ParentImporterModel::new() -> ParentImporterModel {
  { child: FileImporterModel::new() }
}

///|
fn ParentImporterModel::update_with_services(
  self : ParentImporterModel,
  message : ParentImporterMsg,
  services : @host.HostAppServices,
) -> (ParentImporterModel, @core.Effect[ParentImporterMsg]) {
  match message {
    Child(child_message) => {
      let update = self.child.update_with_services(child_message, services)
      ({ child: update.model }, update.effect.map(message => Child(message)))
    }
  }
}

///|
fn ParentImporterModel::view(
  self : ParentImporterModel,
) -> @core.View[ParentImporterMsg] {
  @views.column(
    [
      @views.text("Parent Shell", width=220.0, height=28.0),
      self.child.view().map(message => Child(message)),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn ParentImporterModel::runtime_with_services(
  self : ParentImporterModel,
  services : @host.HostAppServices,
  width? : Double = 900.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::new(
      init=() => (self, @core.Effect::none()),
      update=(model, message) => model.update_with_services(message, services),
      view=model => model.view(),
    ),
    size=@core.Size::new(width~, height~),
  )
}

///|
fn run_file_importer_effect(update : FileImporterUpdate) -> FileImporterModel {
  let model = @core.State::new(update.model)
  let dispatch = message => model.set(model.get().update(message))
  match update.effect {
    @core.Effect::NoEffect => ()
    @core.Effect::Batch(effects) =>
      for effect in effects {
        let next = run_file_importer_effect(
          FileImporterUpdate::new(model.get(), effect~),
        )
        model.set(next)
      }
    @core.Effect::Send(message) => dispatch(message)
    @core.Effect::Dispatch(run) => run(dispatch)
  }
  model.get()
}

///|
fn click_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for " + text)
  }
  let point = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}
