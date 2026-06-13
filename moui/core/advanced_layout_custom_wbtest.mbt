///|
test "custom layout delegate measures places paints and exposes child semantics" {
  let spec = ViewSpec::custom_layout(
    children=[test_label("A").key("a"), test_label("B").key("b")],
    measure=ctx => {
      ctx.constraints.constrain(
        Size::new(
          width=ctx.child_sizes[0].width + ctx.child_sizes[1].width + 6.0,
          height=20.0,
        ),
      )
    },
    place=ctx => {
      [
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=ctx.child_sizes[0].width,
          height=ctx.frame.size.height,
        ),
        Rect::new(
          x=ctx.frame.origin.x + ctx.child_sizes[0].width + 6.0,
          y=ctx.frame.origin.y,
          width=ctx.child_sizes[1].width,
          height=ctx.frame.size.height,
        ),
      ]
    },
    paint=frame => {
      [
        DrawCommand::FillRoundedRectBrush(
          RoundedRect::new(rect=frame, radius=2.0),
          Brush::solid(Color::gray()),
        ),
      ]
    },
    semantics_role=SemanticsRole::Group,
    semantics_label="Custom row",
  ).key("custom-row")
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=120.0, height=32.0),
  )
  ignore(runtime.build_draw_commands())
  let layout = runtime.layout()
  inspect(layout.children.length(), content="2")
  inspect(layout.children[1].frame.origin.x, content="86")
  let commands = runtime.build_draw_commands()
  assert_true(
    commands.any(command => {
      command is DrawCommand::FillRoundedRectBrush(_, Brush::Solid(_))
    }),
  )
  let semantics = runtime.semantics()
  inspect(semantics.label, content="Custom row")
  inspect(semantics.children.length(), content="2")
  assert_true(runtime.element_tree.find_keyed("b") is Some(_))
}

///|
test "custom layout delegate receives child baselines and layout priorities" {
  let first_baseline_ref : Ref[Double?] = Ref(None)
  let first_priority_ref = Ref(0.0)
  let second_priority_ref = Ref(0.0)
  let cache_key_ref = Ref("")
  let cache_value_ref = Ref("")
  let center_guide_ref = Ref(0.0)
  let trailing_guide_ref = Ref(0.0)
  let mirrored_x_ref = Ref(0.0)
  let rtl_ref = Ref(false)
  let viewport_ref : Ref[Size?] = Ref(None)
  let spec = ViewSpec::custom_layout(
    children=[
      test_label("Title").layout_priority(2.0),
      ViewSpec::TextSpec({
        key: None,
        text: "Caption",
        size: Size::new(width=52.0, height=18.0),
        font: FontSpec::new(size=10.0, weight=400),
        color: Color::black(),
      }),
    ],
    measure=ctx => {
      first_baseline_ref.val = ctx.child_baselines[0]
      first_priority_ref.val = ctx.child_priorities[0]
      second_priority_ref.val = ctx.child_priorities[1]
      cache_key_ref.val = ctx.cache_key
      ctx.cache.set("measure", "cached")
      Size::new(width=132.0, height=32.0)
    },
    place=ctx => {
      rtl_ref.val = ctx.layout_direction == LayoutDirection::RightToLeft
      viewport_ref.val = ctx.viewport
      cache_value_ref.val = ctx.cache.get("measure").unwrap_or("missing")
      center_guide_ref.val = ctx.child_alignment_guides[0].center
      trailing_guide_ref.val = ctx.child_alignment_guides[1].trailing
      mirrored_x_ref.val = ctx.mirror_x(x=ctx.frame.origin.x + 10.0, width=20.0)
      let first_baseline = ctx.child_baselines[0].unwrap_or(0.0)
      let second_baseline = ctx.child_baselines[1].unwrap_or(0.0)
      let shared_baseline = if first_baseline > second_baseline {
        first_baseline
      } else {
        second_baseline
      }
      [
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y + shared_baseline - first_baseline,
          width=ctx.child_sizes[0].width,
          height=ctx.child_sizes[0].height,
        ),
        Rect::new(
          x=ctx.frame.origin.x + 80.0,
          y=ctx.frame.origin.y + shared_baseline - second_baseline,
          width=ctx.child_sizes[1].width,
          height=ctx.child_sizes[1].height,
        ),
      ]
    },
  ).key("custom-metrics")
  let environment = Environment::default().with_layout_direction(
    LayoutDirection::RightToLeft,
  )
  let layout = layout_spec(
    spec,
    Rect::new(x=0.0, y=0.0, width=132.0, height=32.0),
  )
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=132.0, height=32.0),
    environment~,
  )
  match first_baseline_ref.val {
    Some(baseline) => inspect(baseline, content="12.8")
    None => fail("expected text baseline")
  }
  inspect(first_priority_ref.val, content="2")
  inspect(second_priority_ref.val, content="0")
  assert_true(cache_key_ref.val.length() > 0)
  ignore(runtime.build_draw_commands())
  assert_true(rtl_ref.val)
  inspect(cache_value_ref.val, content="cached")
  inspect(center_guide_ref.val, content="40")
  inspect(trailing_guide_ref.val, content="52")
  inspect(mirrored_x_ref.val, content="102")
  match viewport_ref.val {
    Some(size) => inspect(size.width, content="132")
    None => fail("expected placement viewport metadata")
  }
  inspect(layout.children[0].frame.origin.y, content="0")
  inspect((layout.children[1].frame.origin.y * 10.0).to_int(), content="48")
}
