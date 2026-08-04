///|
test "main scene emits an inspector window request" {
  let requests : Array[WindowRequest] = []
  let windows = WindowActions::new(dispatch=request => requests.push(request))
  let (_model, effect) = update(Model::new(Main), OpenInspector, windows~)
  match effect {
    @moui.Effect::Run(_, run) => run(_message => ())
    _ => fail("expected window effect")
  }
  match requests[0] {
    WindowRequest::Open({ title, scene, width, height }) => {
      inspect(title, content="MoUI Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="shared:0")
      inspect(width, content="420")
      inspect(height, content="320")
    }
    _ => fail("expected inspector open request")
  }
}

///|
test "close and focus require a host-confirmed window id" {
  let requests : Array[WindowRequest] = []
  let windows = WindowActions::new(dispatch=request => requests.push(request))
  let (without_id, focus_effect) = update(
    Model::new(Main),
    FocusInspector,
    windows~,
  )
  inspect(without_id.status, content="Inspector window id is not available")
  assert_true(focus_effect is @moui.Effect::NoEffect)
  let (opened, _) = update(
    without_id,
    WindowCompleted(WindowEvent::Opened(WindowId::new(7))),
    windows~,
  )
  let (_focused, focus_effect) = update(opened, FocusInspector, windows~)
  let (_closed, close_effect) = update(opened, CloseInspector, windows~)
  match focus_effect {
    @moui.Effect::Run(_, run) => run(_message => ())
    _ => fail("expected focus effect")
  }
  match close_effect {
    @moui.Effect::Run(_, run) => run(_message => ())
    _ => fail("expected close effect")
  }
  inspect(requests.length(), content="2")
  assert_true(requests[0] == WindowRequest::Focus(WindowId::new(7)))
  assert_true(requests[1] == WindowRequest::Close(WindowId::new(7)))
}

///|
test "window completion listener receives events and can unsubscribe" {
  let listener : Ref[((WindowEvent) -> Unit)?] = Ref(None)
  let windows = WindowActions::new(dispatch=_request => (), subscribe=handle => {
    listener.val = Some(handle)
    () => listener.val = None
  })
  let received : Array[WindowEvent] = []
  let cleanup = windows.listen(event => received.push(event))
  match listener.val {
    Some(handle) => handle(WindowEvent::Opened(WindowId::new(9)))
    None => fail("expected active window event listener")
  }
  assert_true(received[0] == WindowEvent::Opened(WindowId::new(9)))
  cleanup()
  assert_true(listener.val is None)
}

///|
test "shared counter updates without opening a window" {
  let (next, effect) = update(Model::new(Main), IncrementShared)
  inspect(next.shared_count, content="1")
  assert_true(effect is @moui.Effect::NoEffect)
}

///|
test "scene decoder recognizes the sample scenes" {
  inspect(
    scene_from_window(WindowScene::new(scene_id="main")) == Some(Main),
    content="true",
  )
  inspect(
    scene_from_window(WindowScene::new(scene_id="inspector", payload="main")) ==
    Some(Inspector("main")),
    content="true",
  )
  inspect(
    scene_from_window(WindowScene::new(scene_id="unknown")) == None,
    content="true",
  )
}
