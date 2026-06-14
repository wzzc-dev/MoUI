///|
fn drop_target_root(handler : FileDropHandler) -> ViewSpec {
  ViewSpec::ContainerSpec({
    key: None,
    size: Some(Size::new(width=120.0, height=80.0)),
    background: Some(Brush::solid(Color::white())),
    border: None,
    corner_radius: 0.0,
    shadow: None,
    child: None,
  }).on_file_drop(handler)
}

///|
test "file drop modifier dispatches dropped paths to hit target" {
  let dropped_path = Ref("")
  let dropped_x = Ref(0.0)
  let runtime = RuntimeKernel::new_spec(
    root=drop_target_root((paths, position) => {
      if paths.length() > 0 {
        dropped_path.val = paths[0]
      }
      dropped_x.val = position.x
    }),
    size=Size::new(width=120.0, height=80.0),
  )
  runtime.dispatch_event(
    AppEvent::DragDrop(
      DragDropEvent::new(
        phase=DragDropPhase::Dropped,
        paths=["/tmp/note.md"],
        position=Some(Point::new(x=24.0, y=16.0)),
      ),
    ),
  )
  inspect(dropped_path.val, content="/tmp/note.md")
  inspect(dropped_x.val, content="24")
  inspect(runtime.needs_rebuild(), content="true")
}

///|
test "file drop modifier ignores non-drop and outside events" {
  let drop_count = Ref(0)
  let runtime = RuntimeKernel::new_spec(
    root=drop_target_root((_paths, _position) => {
      drop_count.val = drop_count.val + 1
    }),
    size=Size::new(width=120.0, height=80.0),
  )
  runtime.dispatch_event(
    AppEvent::DragDrop(
      DragDropEvent::new(
        phase=DragDropPhase::Entered,
        paths=["/tmp/note.md"],
        position=Some(Point::new(x=24.0, y=16.0)),
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::DragDrop(
      DragDropEvent::new(
        phase=DragDropPhase::Dropped,
        paths=["/tmp/note.md"],
        position=Some(Point::new(x=140.0, y=16.0)),
      ),
    ),
  )
  inspect(drop_count.val, content="0")
}
