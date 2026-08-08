///|
test "file importer maps dropped files into selection" {
  let model = FileImporterModel::new().update(
    FilesDropped(["/tmp/a.csv", "/tmp/b.json"]),
  )
  inspect(model.files.length(), content="2")
  inspect(model.files[0].source, content="Drop")
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
    @services.AppServices::unavailable(),
  )
  assert_true(update.model.status is FileImporterStatus::Requesting)
  let model = run_file_importer_effect(update)
  assert_true(model.status is FileImporterStatus::Unavailable(_))
  inspect(model.last_event, content="File dialog unavailable")
  inspect(model.availability_reason, content="file open is unavailable")
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
  let queue = @backend_common_services.ServiceAsyncQueue::new()
  let services = async_file_dialog_services(queue)
  let update = FileImporterModel::new().update_with_services(
    BrowseRequested,
    services,
  )
  assert_true(update.model.status is FileImporterStatus::Requesting)
  let summary = @runtime.effect_plan_summary(update.effect)
  inspect(summary.descriptors().length(), content="1")
  inspect(summary.descriptors()[0].key(), content="file:open")
  inspect(summary.descriptors()[0].kind(), content="service")
  inspect(summary.descriptors()[0].label(), content="Open file")
  let model = Ref(update.model)
  match update.effect {
    @moui.Effect::Task(_descriptor, start) =>
      ignore(start(message => model.val = model.val.update(message)))
    _ => fail("expected typed file dialog task")
  }
  assert_true(model.val.status is FileImporterStatus::Requesting)
  inspect(queue.pending_count(), content="1")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(
      pending[0].id,
      @host.HostServiceResponse::FileDialogSelection(["/tmp/later.txt"]),
    ),
  )
  match queue.take_completed(pending[0].id) {
    Some(_) => fail("expected registered completion to be consumed")
    None => ()
  }
  inspect(model.val.files[0].path, content="/tmp/later.txt")
  inspect(model.val.last_event, content="Imported 1 file(s) from Dialog")
}

///|
test "file importer runtime receives async file dialog completion" {
  let queue = @backend_common_services.ServiceAsyncQueue::new()
  let services = async_file_dialog_services(queue)
  let runtime = test_runtime(
    FileImporterModel::new().program(
      environment=@services.AppEnvironment::new(services~),
    ),
    width=860.0,
    height=620.0,
  )
  click_text(runtime, "Browse")
  assert_true(has_text(runtime.draw_commands(), "Waiting for file picker"))
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(
      pending[0].id,
      @host.HostServiceResponse::FileDialogSelection(["/tmp/later.txt"]),
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "/tmp/later.txt"))
  assert_true(has_text(commands, "Imported 1 file(s) from Dialog"))
}

///|
test "file importer runtime receives async file dialog rejection" {
  let queue = @backend_common_services.ServiceAsyncQueue::new()
  let services = async_file_dialog_services(queue)
  let runtime = test_runtime(
    FileImporterModel::new().program(
      environment=@services.AppEnvironment::new(services~),
    ),
    width=860.0,
    height=620.0,
  )
  click_text(runtime, "Browse")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(queue.reject(pending[0].id, "file picker canceled"))
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "File dialog unavailable"))
  assert_true(has_text(commands, "file picker canceled"))
}

///|
test "file importer runtime runs host service effects" {
  let services = host_services_for_file_dialog(["/tmp/runtime.csv"])
  let runtime = test_runtime(
    FileImporterModel::new().program(
      environment=@services.AppEnvironment::new(services~),
    ),
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
test "file importer child effect maps pending completion into parent" {
  let queue = @backend_common_services.ServiceAsyncQueue::new()
  let services = async_file_dialog_services(queue)
  let runtime = ParentImporterModel::new().runtime_with_services(
    services,
    width=900.0,
    height=680.0,
  )
  click_text(runtime, "Browse")
  assert_true(has_text(runtime.draw_commands(), "Parent Shell"))
  let pending_snapshot = runtime.program_runtime_snapshot()
  inspect(
    pending_snapshot.last_scheduled_effect_summary().descriptors().length(),
    content="1",
  )
  inspect(
    pending_snapshot.last_scheduled_effect_summary().descriptors()[0].key(),
    content="file:open",
  )
  inspect(
    pending_snapshot.last_scheduled_effect_summary().descriptors()[0].kind(),
    content="service",
  )
  inspect(
    pending_snapshot.last_scheduled_effect_summary().descriptors()[0].label(),
    content="Open file",
  )
  inspect(pending_snapshot.active_effect_task_count(), content="1")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(
      pending[0].id,
      @host.HostServiceResponse::FileDialogSelection(["/tmp/child-later.csv"]),
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Parent Shell"))
  assert_true(has_text(commands, "/tmp/child-later.csv"))
  assert_true(has_text(commands, "Imported 1 file(s) from Dialog"))
  let completed_snapshot = runtime.program_runtime_snapshot()
  inspect(completed_snapshot.active_effect_task_count(), content="0")
  inspect(completed_snapshot.completed_effect_task_count(), content="1")
}

///|
test "file importer runtime draws panel labels" {
  let commands = test_runtime(program(), width=860.0, height=620.0).draw_commands()
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
) -> @services.AppServices {
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
  @backend_common_services.app_services(bridge~)
}

///|
fn async_file_dialog_services(
  queue : @backend_common_services.ServiceAsyncQueue,
) -> @services.AppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) => queue.submit(request)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @backend_common_services.app_services(bridge~, async_queue=Some(queue))
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
  services : @services.AppServices,
) -> (ParentImporterModel, @moui.Effect[ParentImporterMsg]) {
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
) -> @moui.View[ParentImporterMsg] {
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
  services : @services.AppServices,
  width? : Double = 900.0,
  height? : Double = 680.0,
) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_program(
    program=@moui.Program::new(
      init=() => (self, @moui.Effect::none()),
      update=(model, message) => model.update_with_services(message, services),
      view=model => model.view(),
    ),
    size=@geometry.Size::new(width~, height~),
  )
}

///|
fn test_runtime(
  program : @moui.Program[FileImporterModel, FileImporterMsg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}

///|
fn run_file_importer_effect(update : FileImporterUpdate) -> FileImporterModel {
  let model = Ref(update.model)
  let dispatch = message => model.val = model.val.update(message)
  match update.effect {
    @moui.Effect::NoEffect => ()
    @moui.Effect::Batch(effects) =>
      for effect in effects {
        let next = run_file_importer_effect(
          FileImporterUpdate::new(model.val, effect~),
        )
        model.val = next
      }
    @moui.Effect::Send(message) => dispatch(message)
    @moui.Effect::Dispatch(run) => run(dispatch)
    @moui.Effect::Run(_descriptor, run) => run(dispatch)
    @moui.Effect::Task(_descriptor, start) => ignore(start(dispatch))
  }
  model.val
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for " + text)
  }
  let point = @geometry.Point::new(
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
