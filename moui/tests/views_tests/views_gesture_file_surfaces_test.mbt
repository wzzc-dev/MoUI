///|
test "public view gesture wrappers can be composed from views" {
  let log = Ref("")
  let root = @views.surface(
      @views.text("Gesture", width=120.0),
      width=160.0,
      height=80.0,
    )
    .on_double_tap("double")
    .on_long_press("long")
    .on_drag(event => event.phase.label())
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=120.0),
    on_message=Some(message => log.val = log.val + message + ";"),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
        time_ms=0.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
        time_ms=20.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=11.0, y=10.0),
        phase=@core.PointerPhase::Down,
        time_ms=160.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=11.0, y=10.0),
        phase=@core.PointerPhase::Up,
        time_ms=180.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
        time_ms=400.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Move,
        time_ms=920.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
        time_ms=940.0,
      ),
    ),
  )
  inspect(log.val, content="double;long;")
}

///|
test "drop zone maps dropped files to app message" {
  let seen = Ref("")
  let root : @core.View[Array[String]] = @views.drop_zone(
    title="Drop files here",
    on_drop=paths => paths,
    width=240.0,
    height=80.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=320.0, height=160.0),
    on_message=Some(paths => if paths.length() > 0 { seen.val = paths[0] }),
  )
  runtime.dispatch_event(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(
        phase=@core.DragDropPhase::Dropped,
        paths=["/tmp/import.csv"],
        position=Some(@core.Point::new(x=12.0, y=12.0)),
      ),
    ),
  )
  inspect(seen.val, content="/tmp/import.csv")
}

///|
test "file import panel renders empty and unavailable states" {
  let empty = @runtime.AppRuntime::new_view(
    root=@views.file_import_panel(
      selection=@views.FileSelection::new(paths=[]),
      on_drop=_paths => (),
      on_browse=Some(()),
      empty_message="No file chosen",
      width=320.0,
    ),
    size=@core.Size::new(width=360.0, height=280.0),
  ).draw_commands()
  assert_true(has_text(empty, "No file chosen"))
  assert_true(has_text(empty, "Browse"))

  let unavailable = @runtime.AppRuntime::new_view(
    root=@views.file_import_panel(
      selection=@views.FileSelection::new(paths=["/tmp/a.txt"]),
      on_drop=_paths => (),
      availability=@views.FileImportAvailability::Unavailable(
        "File dialog unavailable",
      ),
      width=320.0,
    ),
    size=@core.Size::new(width=360.0, height=280.0),
  ).draw_commands()
  assert_true(has_text(unavailable, "File dialog unavailable"))
  assert_true(has_text(unavailable, "/tmp/a.txt"))
}
