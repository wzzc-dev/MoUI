///|
test "main scene emits an inspector window request" {
  let requests : Array[@app.WindowRequest] = []
  let windows = @app.WindowActions::new(dispatch=request => {
    requests.push(request)
  })
  let (_model, effect) = @app.update(
    @app.Model::new(Main),
    OpenInspector,
    windows~,
  )
  match effect {
    Run(_, run) => run(_message => ())
    _ => fail("expected window effect")
  }
  match requests[0] {
    Open({ title, scene, width, height, }) => {
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
  let requests : Array[@app.WindowRequest] = []
  let windows = @app.WindowActions::new(dispatch=request => {
    requests.push(request)
  })
  let (without_id, focus_effect) = @app.update(
    @app.Model::new(Main),
    FocusInspector,
    windows~,
  )
  inspect(without_id.status, content="Inspector window id is not available")
  assert_true(focus_effect is NoEffect)
  let (opened, _) = @app.update(
    without_id,
    WindowCompleted(Opened(@app.WindowId::new(7))),
    windows~,
  )
  let (_focused, focus_effect) = @app.update(opened, FocusInspector, windows~)
  let (_closed, close_effect) = @app.update(opened, CloseInspector, windows~)
  match focus_effect {
    Run(_, run) => run(_message => ())
    _ => fail("expected focus effect")
  }
  match close_effect {
    Run(_, run) => run(_message => ())
    _ => fail("expected close effect")
  }
  inspect(requests.length(), content="2")
  assert_true(requests[0] == Focus(@app.WindowId::new(7)))
  assert_true(requests[1] == Close(@app.WindowId::new(7)))
}

///|
test "window completion listener receives events and can unsubscribe" {
  let listener : Ref[((@app.WindowEvent) -> Unit)?] = Ref(None)
  let windows = @app.WindowActions::new(dispatch=_request => (), subscribe=handle => {
    listener.val = Some(handle)
    () => listener.val = None
  })
  let received : Array[@app.WindowEvent] = []
  let cleanup = windows.listen(event => received.push(event))
  match listener.val {
    Some(handle) => handle(Opened(@app.WindowId::new(9)))
    None => fail("expected active window event listener")
  }
  assert_true(received[0] == Opened(@app.WindowId::new(9)))
  cleanup()
  assert_true(listener.val is None)
}

///|
test "shared counter updates without opening a window" {
  let (next, effect) = @app.update(@app.Model::new(Main), IncrementShared)
  inspect(next.shared_count, content="1")
  assert_true(effect is NoEffect)
}

///|
test "scene decoder recognizes the sample scenes" {
  inspect(
    @app.scene_from_window(@app.WindowScene::new(scene_id="main")) == Some(Main),
    content="true",
  )
  inspect(
    @app.scene_from_window(
      @app.WindowScene::new(scene_id="inspector", payload="main"),
    ) ==
    Some(Inspector("main")),
    content="true",
  )
  inspect(
    @app.scene_from_window(@app.WindowScene::new(scene_id="unknown")) == None,
    content="true",
  )
}
