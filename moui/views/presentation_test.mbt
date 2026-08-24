///|
test "presentation placement falls back and clamps to viewport" {
  let placement = PresentationPlacement::new(
    anchor=PresentationAnchor::stable_key("anchor"),
    candidates=[
      PresentationPlacementCandidate::AboveCenter,
      PresentationPlacementCandidate::BelowCenter,
    ],
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
  let first : PresentationSpec[Unit] = PresentationSpec::new(
    id="first",
    kind=PresentationKind::Tooltip,
    content=@container.empty(),
  )
  let second : PresentationSpec[Unit] = PresentationSpec::new(
    id="second",
    kind=PresentationKind::Dialog,
    content=@container.empty(),
    modality=PresentationModality::Modal,
  )
  let view = overlay_host(@text.text("base"), [first, second])
  assert_eq(view.children().length(), 4)
}

///|
test "presentation transitions use shared motion specs" {
  let fade = PresentationTransition::Fade.spec().sample(0.5)
  let scale = PresentationTransition::Scale.spec().sample(0.0)
  let slide = PresentationTransition::Slide.spec().sample(0.0)
  assert_true(fade.style.opacity > 0.0 && fade.style.opacity < 1.0)
  assert_true(scale.style.scale.x < 1.0)
  assert_true(slide.style.offset.y > 0.0)
}

///|
test "presentation host policy keeps transparent fallback" {
  assert_true(!PresentationHostPolicy::ViewOnly.requests_native(true))
  assert_true(PresentationHostPolicy::PreferNative.requests_native(true))
  assert_true(!PresentationHostPolicy::PreferNative.requests_native(false))
  assert_true(PresentationHostPolicy::NativeRequired.shows_view_surface(false))
  assert_true(!PresentationHostPolicy::PreferNative.shows_view_surface(true))
}
