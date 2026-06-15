///|
test "engine mounts view spec into element and render trees" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [test_label("A"), test_label("B")],
  })
  let element = mount_view_spec(spec)
  inspect(element.children.length(), content="2")
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=80.0))
  inspect(render.children.length(), content="2")
  inspect(render.children[1].frame.origin.y, content="24")
}
