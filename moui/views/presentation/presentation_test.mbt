///|
test "presentation placement falls back and clamps to viewport" {
  let placement = @presentation.PresentationPlacement::new(
    candidates=[AboveCenter, BelowCenter],
    viewport_insets=@core.Insets::all(4.0),
  )
  let resolved = placement.resolve(
    @core.Rect::new(x=42.0, y=4.0, width=20.0, height=10.0),
    @core.Rect::new(x=0.0, y=0.0, width=100.0, height=60.0),
    @core.Size::new(width=80.0, height=30.0),
  )
  assert_true(resolved.origin.x >= 4.0)
  assert_true(resolved.origin.y >= 4.0)
  assert_true(resolved.max_x() <= 96.0)
  assert_true(resolved.max_y() <= 56.0)
}

///|
test "overlay host preserves active presentation order" {
  let first : @presentation.PresentationSpec[Unit] = @presentation.PresentationSpec::new(
    id="first",
    kind=Tooltip,
    content=@container.empty(),
  )
  let second : @presentation.PresentationSpec[Unit] = @presentation.PresentationSpec::new(
    id="second",
    kind=Dialog,
    content=@container.empty(),
    modality=Modal,
  )
  let view = @presentation.overlay_host(@text.text("base"), [first, second])
  assert_eq(view.children().length(), 4)
}

///|
test "presentation transitions use shared motion specs" {
  let fade = @presentation.PresentationTransition::Fade.spec().sample(0.5)
  let scale = @presentation.PresentationTransition::Scale.spec().sample(0.0)
  let slide = @presentation.PresentationTransition::Slide.spec().sample(0.0)
  assert_true(fade.style.opacity > 0.0 && fade.style.opacity < 1.0)
  assert_true(scale.style.scale.x < 1.0)
  assert_true(slide.style.offset.y > 0.0)
}

///|
test "presentation host policy keeps transparent fallback" {
  assert_true(
    !@presentation.PresentationHostPolicy::ViewOnly.requests_native(true),
  )
  assert_true(
    @presentation.PresentationHostPolicy::PreferNative.requests_native(true),
  )
  assert_true(
    !@presentation.PresentationHostPolicy::PreferNative.requests_native(false),
  )
  assert_true(
    @presentation.PresentationHostPolicy::NativeRequired.shows_view_surface(
      false,
    ),
  )
  assert_true(
    !@presentation.PresentationHostPolicy::PreferNative.shows_view_surface(true),
  )
}

///|

///|
fn toast_panel() -> @core.View[String] {
  let panel : @core.View[String] = @layout.frame(
    @text.text("Toast"),
    width=40.0,
    height=20.0,
  )
  panel
}

///|
test "toast presentations dock bottom-center in the viewport" {
  let root = @presentation.overlay_host(@text.text("Base"), [
    @presentation.PresentationSpec::new(
      id="toast",
      kind=Toast,
      content=toast_panel(),
      placement=Some(
        @presentation.PresentationPlacement::new(
          viewport_insets=@core.Insets::all(12.0),
        ),
      ),
    ),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let layout = runtime.layout()
  // The toast content is 40x20 wide: docked at the bottom inset, centered.
  let frame = layout.children[1].frame
  assert_true(frame.origin.x == 80.0)
  assert_true(frame.origin.y == 68.0)
}

///|
/// 非模态屏障（toast / 上下文菜单）**只**消费 `Down`。
///
/// 回归：屏障曾把 `Move` 一并吃掉，而运行时一旦判定「事件已被覆盖层消费」，
/// 就会把覆盖点之下的在流子节点整帧跳过——屏上只要有一条 toast，整个 app
/// 的悬停全部失效（含顶栏既有图标按钮）。这里锁定「toast 在场时，底层
/// 内容仍能收到 `Move`」，这是 hover 可用的前提。
test "non-modal barrier passes Move through to the base" {
  let moves : Ref[Int] = Ref(0)
  let base : @core.View[Unit] = @container.container(
    @container.container(
      @text.text("Base"),
      width=200.0,
      height=100.0,
      padding=0.0,
    ),
    width=200.0,
    height=100.0,
    padding=0.0,
  ).on_hover(_hovered => {
    moves.val = moves.val + 1
    ()
  })
  let root = @presentation.overlay_host(base, [
    @presentation.PresentationSpec::new(
      id="toast",
      kind=Toast,
      content=@container.container(
        @text.text("Toast"),
        width=40.0,
        height=20.0,
        padding=0.0,
      ),
      dismiss=@presentation.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some(()),
      ),
    ),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  ignore(runtime.layout())
  // toast 停在底部中央（insets 12 + 内容 40x20）;点在上半区，
  // 那里没有 toast 内容，只有它的全屏屏障。
  runtime.dispatch_event(
    @core.Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=100.0, y=20.0),
        phase=Move,
      ),
    ),
  )
  if moves.val != 1 {
    fail(
      "toast 在场时底层内容应收到 Move（悬停可用），实际收到 \{moves.val} 次",
    )
  }
}

///|
/// 模态屏障仍然吞掉一切：`Move` 不得穿到背景内容（背景不可交互是模态的
/// 定义）。与上一条构成一对——放行只针对**非模态**屏障。
test "modal barrier still swallows Move" {
  let moves : Ref[Int] = Ref(0)
  let base : @core.View[Unit] = @container.container(
    @container.container(
      @text.text("Base"),
      width=200.0,
      height=100.0,
      padding=0.0,
    ),
    width=200.0,
    height=100.0,
    padding=0.0,
  ).on_hover(_hovered => {
    moves.val = moves.val + 1
    ()
  })
  let root = @presentation.overlay_host(base, [
    @presentation.PresentationSpec::new(
      id="dialog",
      kind=Dialog,
      content=@container.container(
        @text.text("Dialog"),
        width=40.0,
        height=20.0,
        padding=0.0,
      ),
      modality=@presentation.PresentationModality::Modal,
    ),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(
    @core.Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=100.0, y=20.0),
        phase=Move,
      ),
    ),
  )
  if moves.val != 0 {
    fail(
      "模态屏障应吞掉 Move，底层却收到了 \{moves.val} 次悬停",
    )
  }
}
