///|
fn leaf_update_structural_builder_key(index : Int32) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag="leaf-update.builder", fields=[
    ("index", @core.DeclarationKey::int(index)),
  ])
}

///|
fn leaf_update_structural_content_key(
  index : Int32,
  value : Int32,
) -> @core.DeclarationKey {
  if index == 0 {
    @core.DeclarationKey::record(type_tag="leaf-update.content", fields=[
      ("value", @core.DeclarationKey::int(value)),
    ])
  } else {
    @core.DeclarationKey::string("leaf-update.static")
  }
}

///|
fn leaf_update_structural_pointer() -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(position=@core.Point::new(x=4.0, y=4.0), phase=Up),
  )
}

///|
fn leaf_update_structural_leaf(on_tap~ : Int32? = None) -> @core.View[Int32] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="LeafUpdateStructuralLeaf"),
    declaration=() => {
      runtime_wb_fixture_exact_declaration("LeafUpdateStructuralLeaf", [])
    },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=8.0, height=8.0),
        ),
      )
    },
    paint=context => {
      @core.ViewPaintPlan::commands([
        FillRect(context.frame, @core.Color::blue()),
      ])
    },
    event=context => {
      match (context.event, on_tap) {
        (Pointer(event), Some(message)) if event.phase == Up &&
          context.frame.contains(event.position) =>
          @core.ViewEventResult::message(message)
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
test "builder-cache leaf update builds only the changed leaf at 1k nodes" {
  let leaf_count = 1000
  let root_builder_calls = Ref(0)
  let leaf_builds = Ref(0)
  let builder_keys : Array[@core.DeclarationKey] = []
  for index in 0..<leaf_count {
    builder_keys.push(leaf_update_structural_builder_key(index))
  }
  let builder_cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let program = @core.Program::simple(
    init=0,
    update=fn(model, _message) { model + 1 },
    view=fn(model) {
      root_builder_calls.val = root_builder_calls.val + 1
      let children : Array[@core.View[Int32]] = []
      for index in 0..<leaf_count {
        let leaf_index = index
        let content_key = leaf_update_structural_content_key(leaf_index, model)
        children.push(
          builder_cache.view(
            builder_key=builder_keys[leaf_index],
            content_key~,
            build=() => {
              leaf_builds.val = leaf_builds.val + 1
              leaf_update_structural_leaf(
                on_tap=if leaf_index == 0 { Some(1) } else { None },
              )
            },
          ),
        )
      }
      @views.column(children)
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=800.0, height=600.0),
  )
  ignore(runtime.draw_frame())
  let initial_root_calls = root_builder_calls.val
  let initial_leaf_builds = leaf_builds.val
  let initial_stats = builder_cache.stats()

  let updates = 3
  for index in 0..<updates {
    runtime.advance_time(16.0 * (index + 1).to_double())
    runtime.dispatch_event(leaf_update_structural_pointer())
    ignore(runtime.draw_frame())
  }

  let stats = builder_cache.stats()
  assert_eq(root_builder_calls.val - initial_root_calls, updates)
  assert_eq(leaf_builds.val - initial_leaf_builds, updates)
  assert_eq(stats.build_count() - initial_stats.build_count(), updates)
  assert_eq(stats.miss_count() - initial_stats.miss_count(), updates)
  assert_eq(
    stats.hit_count() - initial_stats.hit_count(),
    updates * (leaf_count - 1),
  )
  assert_eq(stats.entry_count(), leaf_count)
}
