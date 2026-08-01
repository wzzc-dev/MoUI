///|
fn runtime_semantics_cache_leaf(label : String) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => {
      @core.ViewIdentity::new(kind="SemanticsCacheLeaf", key=Some(label))
    },
    declaration=() => {
      runtime_wb_fixture_exact_declaration("SemanticsCacheLeaf", [
        ("label", @core.DeclarationKey::string(label)),
      ])
    },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=24.0),
        ),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Boundary,
        role=@core.SemanticsRole::Text,
        label~,
      )
    },
  )
}

///|
fn runtime_semantics_cache_tree(
  composition? : @core.SemanticsComposition = @core.SemanticsComposition::Transparent,
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SemanticsCacheRoot"),
    children=() => {
      [
        runtime_semantics_cache_leaf("first"),
        runtime_semantics_cache_leaf("second"),
      ]
    },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=48.0),
        ),
        child_frames=[
          @core.Rect::new(x=0.0, y=0.0, width=100.0, height=24.0),
          @core.Rect::new(x=0.0, y=24.0, width=100.0, height=24.0),
        ],
      )
    },
    semantics=() => @core.ViewSemanticsInfo::new(composition~),
  )
}

///|
fn runtime_semantics_only_leaf(label : String) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SemanticsOnlyLeaf"),
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=@core.DeclarationChannel::Constant,
        paint=@core.DeclarationChannel::Constant,
        semantics=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string(label),
        ),
        platform=@core.DeclarationChannel::Constant,
      )
    },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=24.0),
        ),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Boundary,
        role=@core.SemanticsRole::Text,
        label~,
      )
    },
  )
}

///|
fn runtime_semantics_deep_chain(
  depth : Int,
  leaf_id : @core.SemanticId,
) -> @core.View[Unit] {
  let mut current = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SemanticsDeepLeaf"),
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=24.0),
        ),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Boundary,
        semantic_id=leaf_id,
        role=@core.SemanticsRole::Text,
        label="deep leaf",
      )
    },
  )
  for index in 0..<depth {
    let child = current
    current = runtime_wb_fixture_view(
      identity=() => {
        @core.ViewIdentity::new(kind="SemanticsDeepWrapper\{index}")
      },
      children=() => [child],
      layout=context => {
        let size = context.child_sizes
          .get(0)
          .unwrap_or(@core.Size::new(width=0.0, height=0.0))
        @core.ViewLayoutResult::new(size=context.constraints.constrain(size), child_frames=[
          @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
        ])
      },
      semantics=() => {
        @core.ViewSemanticsInfo::new(
          composition=@core.SemanticsComposition::Transparent,
        )
      },
    )
  }
  current
}

///|
fn runtime_semantics_action_leaf(
  semantic_id : @core.SemanticId,
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SemanticsActionLeaf"),
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=24.0),
        ),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Boundary,
        semantic_id~,
        role=@core.SemanticsRole::Button,
        label="action",
      )
    },
    semantics_actions=() => {
      [
        @core.ViewSemanticsActionHandler::activate(_context => {
          @core.ViewSemanticsActionResult::accepted(
            dirty=@core.ViewDirtyHint::ViewClean,
          )
        }),
      ]
    },
  )
}

///|
fn runtime_semantics_identified_leaf(
  semantic_id : @core.SemanticId,
  label : String,
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SemanticsIdentifiedLeaf"),
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=@core.DeclarationChannel::Constant,
        paint=@core.DeclarationChannel::Constant,
        semantics=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::record(
            type_tag="SemanticsIdentifiedLeaf.semantics",
            fields=[
              ("id", @core.DeclarationKey::string(semantic_id.value())),
              ("label", @core.DeclarationKey::string(label)),
            ],
          ),
        ),
        platform=@core.DeclarationChannel::Constant,
      )
    },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=24.0),
        ),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Boundary,
        semantic_id~,
        role=@core.SemanticsRole::Text,
        label~,
      )
    },
  )
}

///|
fn runtime_semantics_dynamic_container(
  children : Array[@core.View[Unit]],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SemanticsDynamicContainer"),
    children=() => children,
    layout=context => {
      let child_frames : Array[@core.Rect] = []
      let mut y = 0.0
      for size in context.child_sizes {
        child_frames.push(
          @core.Rect::new(x=0.0, y~, width=size.width, height=size.height),
        )
        y = y + size.height
      }
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=y),
        ),
        child_frames~,
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Transparent,
      )
    },
  )
}

///|
fn runtime_semantics_merge_container(
  child : @core.View[Unit],
  label : String,
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SemanticsMergeContainer"),
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=@core.DeclarationChannel::Constant,
        paint=@core.DeclarationChannel::Constant,
        semantics=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string(label),
        ),
        platform=@core.DeclarationChannel::Constant,
      )
    },
    children=() => [child],
    layout=context => {
      let size = context.child_sizes
        .get(0)
        .unwrap_or(@core.Size::new(width=0.0, height=0.0))
      @core.ViewLayoutResult::new(size=context.constraints.constrain(size), child_frames=[
        @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::MergeDescendants,
        label~,
      )
    },
  )
}

///|
test "hidden semantics consumes descendant dirtiness without repeated work" {
  let runtime = RuntimeState::new_view(
    root=runtime_semantics_cache_tree(
      composition=@core.SemanticsComposition::Hidden,
    ),
    size=@core.Size::new(width=100.0, height=48.0),
  )
  ignore(runtime.cached_semantics())
  inspect(runtime.stats.semantics_recompute_count, content="1")
  ignore(runtime.cached_semantics())
  inspect(runtime.stats.semantics_recompute_count, content="1")
  let first_leaf = runtime.element_tree.root.children[0].id
  runtime.mark_semantics_dirty(first_leaf)
  ignore(runtime.cached_semantics())
  inspect(runtime.stats.semantics_recompute_count, content="2")
  ignore(runtime.cached_semantics())
  inspect(runtime.stats.semantics_recompute_count, content="2")
}

///|
test "semantics-only component rebuild consumes queues without redraw" {
  let label = @core.State::new("before")
  let runtime = RuntimeState::new_view(
    root=runtime_component_view(context => {
      runtime_semantics_only_leaf(context.watch(label))
    }),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  ignore(runtime.cached_semantics())
  runtime.dirty.needs_redraw = false
  runtime.dirty.rebuild_wakeup_redraw = false
  let layout_passes = runtime.stats.layout_pass_count
  let paint_passes = runtime.stats.paint_pass_count
  label.set("after")
  inspect(runtime.dirty.needs_rebuild, content="true")
  inspect(runtime.dirty.needs_redraw, content="true")
  let snapshot = runtime.cached_semantics()
  inspect(snapshot.nodes()[0].label, content="after")
  inspect(runtime.stats.layout_pass_count == layout_passes, content="true")
  inspect(runtime.stats.paint_pass_count == paint_passes, content="true")
  inspect(runtime.dirty_count(), content="0")
  inspect(runtime.dirty.needs_redraw, content="false")
}

///|
test "nested component replacement runs the newly captured build closure" {
  let label = @core.State::new("before")
  let runtime = RuntimeState::new_view(
    root=runtime_component_view(outer_context => {
      let captured = outer_context.watch(label)
      runtime_component_view(_inner_context => {
        runtime_semantics_only_leaf(captured)
      })
    }),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  let before = runtime.cached_semantics()
  assert_eq(before.nodes()[0].label, "before")
  label.set("after")
  let after = runtime.cached_semantics()
  assert_eq(after.nodes()[0].label, "after")
  assert_true(after.generation() > before.generation())
}

///|
test "semantics cache recomputes only a dirty leaf and its ancestors" {
  let runtime = RuntimeState::new_view(
    root=runtime_semantics_cache_tree(),
    size=@core.Size::new(width=100.0, height=48.0),
  )
  ignore(runtime.cached_semantics())
  inspect(runtime.stats.semantics_recompute_count, content="3")
  inspect(runtime.dirty_count(), content="0")
  let layout_passes = runtime.stats.layout_pass_count
  let paint_passes = runtime.stats.paint_pass_count
  let first_leaf = runtime.element_tree.root.children[0].id
  runtime.mark_semantics_dirty(first_leaf)
  ignore(runtime.cached_semantics())
  inspect(runtime.stats.semantics_recompute_count, content="5")
  inspect(runtime.stats.layout_pass_count == layout_passes, content="true")
  inspect(runtime.stats.paint_pass_count == paint_passes, content="true")
  inspect(runtime.dirty_count(), content="0")
  ignore(runtime.cached_semantics())
  inspect(runtime.stats.semantics_recompute_count, content="5")
  inspect(runtime.stats.layout_pass_count == layout_passes, content="true")
  inspect(runtime.stats.paint_pass_count == paint_passes, content="true")
}

///|
test "persistent semantics tree keeps cache node-local across a deep chain" {
  let leaf_id = @core.SemanticId::parse("test.deep.leaf").unwrap()
  let depth = 48
  let runtime = RuntimeState::new_view(
    root=runtime_semantics_deep_chain(depth, leaf_id),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  let initial = runtime.cached_semantics()
  assert_eq(runtime.stats.semantics_recompute_count, depth + 1)
  assert_eq(runtime.semantics.semantics_tree.nodes.length(), 1)
  assert_eq(runtime.semantics.semantics_tree.routes.length(), 1)
  assert_eq(runtime.element_tree.root.semantics_cache.roots.length(), 1)
  let leaf_element = for element = runtime.element_tree.root {
    match element.children {
      [child] => continue child
      [] => break element
      _ => abort("deep semantics fixture must stay a chain")
    }
  }
  runtime.mark_semantics_dirty(leaf_element.id)
  let next = runtime.cached_semantics()
  assert_eq(runtime.stats.semantics_recompute_count, (depth + 1) * 2)
  assert_eq(next.generation(), initial.generation())
  assert_eq(runtime.semantics.semantics_tree.nodes.length(), 1)
  assert_eq(runtime.semantics.semantics_tree.routes.length(), 1)
}

///|
test "clean semantics action lookup does not recompute the tree" {
  let semantic_id = @core.SemanticId::parse("test.clean.action").unwrap()
  let runtime = RuntimeState::new_view(
    root=runtime_semantics_action_leaf(semantic_id),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  let snapshot = runtime.cached_semantics()
  let recomputes = runtime.stats.semantics_recompute_count
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(
        @core.SemanticsGeneration::new(snapshot.generation().value() + 1UL),
      ),
    }) {
    Err(SemanticsActionDispatchError::StaleGeneration(_, _)) => ()
    _ => fail("expected stale action rejection")
  }
  assert_eq(runtime.stats.semantics_recompute_count, recomputes)
}

///|
test "removed semantics nodes and action routes are pruned from the tree" {
  let visible = @core.State::new(true)
  let semantic_id = @core.SemanticId::parse("test.removed.route").unwrap()
  let runtime = RuntimeState::new_view(
    root=runtime_component_view(context => {
      let children = if context.watch(visible) {
        [runtime_semantics_action_leaf(semantic_id)]
      } else {
        []
      }
      runtime_semantics_dynamic_container(children)
    }),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  let initial = runtime.cached_semantics()
  let initial_nodes = initial.nodes()
  guard initial_nodes.search_by(node => node.semantic_id == Some(semantic_id))
    is Some(initial_index) else {
    fail("missing initial semantic node")
  }
  let initial_node = initial_nodes[initial_index]
  visible.set(false)
  let removed = runtime.cached_semantics()
  assert_false(
    runtime.semantics.semantics_tree.nodes.contains(initial_node.node_id),
  )
  assert_false(
    runtime.semantics.semantics_tree.routes.contains(initial_node.node_id),
  )
  assert_false(runtime.semantics.semantic_id_index.contains(semantic_id))
  assert_false(
    removed.nodes().any(node => node.node_id == initial_node.node_id),
  )
  match runtime.read_semantics(Some(initial.generation())) {
    Ok(SemanticsRead::Delta(delta)) =>
      assert_true(delta.removed().contains(initial_node.node_id))
    _ => fail("removed node id must be published in the delta")
  }
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::ByNodeId(initial_node.node_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(removed.generation()),
    }) {
    Err(SemanticsActionDispatchError::TargetNotFound(_)) => ()
    _ => fail("removed node id must not retain an action route")
  }
  visible.set(true)
  let restored = runtime.cached_semantics()
  let restored_nodes = restored.nodes()
  guard restored_nodes.search_by(node => node.semantic_id == Some(semantic_id))
    is Some(restored_index) else {
    fail("missing restored semantic node")
  }
  let restored_node = restored_nodes[restored_index]
  assert_true(restored_node.node_id > initial_node.node_id)
}

///|
test "one changed leaf publishes a one-node delta" {
  let changed_id = @core.SemanticId::parse("test.delta.changed").unwrap()
  let stable_id = @core.SemanticId::parse("test.delta.stable").unwrap()
  let label = @core.State::new("before")
  let runtime = RuntimeState::new_view(
    root=runtime_component_view(context => {
      runtime_semantics_dynamic_container([
        runtime_semantics_identified_leaf(changed_id, context.watch(label)),
        runtime_semantics_identified_leaf(stable_id, "stable"),
      ])
    }),
    size=@core.Size::new(width=100.0, height=48.0),
  )
  let initial = runtime.cached_semantics()
  label.set("after")
  match runtime.read_semantics(Some(initial.generation())) {
    Ok(SemanticsRead::Delta(delta)) => {
      let upserted = delta.upserted()
      assert_eq(upserted.length(), 1)
      assert_eq(upserted[0].semantic_id, Some(changed_id))
      assert_eq(upserted[0].label, "after")
      assert_true(delta.removed().is_empty())
    }
    _ => fail("expected a one-node semantics delta")
  }
}

///|
test "merged descendants rebuild after their internal nodes are pruned" {
  let child_id = @core.SemanticId::parse("test.merge.child").unwrap()
  let parent_label = @core.State::new("parent")
  let runtime = RuntimeState::new_view(
    root=runtime_component_view(context => {
      runtime_semantics_merge_container(
        runtime_semantics_identified_leaf(child_id, "child"),
        context.watch(parent_label),
      )
    }),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  let initial = runtime.cached_semantics()
  assert_eq(initial.nodes().length(), 1)
  assert_eq(initial.nodes()[0].label, "parent child")
  assert_eq(runtime.semantics.semantics_tree.nodes.length(), 1)
  parent_label.set("updated")
  let updated = runtime.cached_semantics()
  assert_eq(updated.nodes().length(), 1)
  assert_eq(updated.nodes()[0].label, "updated child")
  assert_eq(runtime.semantics.semantics_tree.nodes.length(), 1)
}

///|
test "semantics node identity exhaustion closes before publishing a wrapped id" {
  let runtime = RuntimeState::new_view(
    root=runtime_semantics_cache_leaf("identity exhaustion"),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  let before = runtime.cached_semantics()
  runtime.element_tree.root.semantics_node_id = None
  runtime.semantics.next_semantics_node_id = 18446744073709551615UL
  runtime.mark_semantics_dirty(runtime.element_tree.id())
  match runtime.read_semantics(None) {
    Err(SemanticsReadError::RuntimeClosed) => ()
    _ => fail("identity exhaustion must close the semantics runtime")
  }
  assert_eq(
    runtime.semantics.committed_semantics.generation(),
    before.generation(),
  )
  assert_false(
    runtime.semantics.committed_semantics
    .nodes()
    .any(node => node.node_id == @core.SemanticsNodeId::new(0UL)),
  )
}

///|
test "semantics generation exhaustion closes before wrapping to zero" {
  let runtime = RuntimeState::new_view(
    root=runtime_semantics_cache_leaf("generation exhaustion"),
    size=@core.Size::new(width=100.0, height=24.0),
  )
  let before = runtime.cached_semantics()
  runtime.semantics.committed_semantics = {
    ..runtime.semantics.committed_semantics,
    generation: @core.SemanticsGeneration::new(18446744073709551615UL),
  }
  runtime.animfocus.focused_element = Some(runtime.element_tree.id())
  runtime.mark_semantics_dirty(runtime.element_tree.id())
  match runtime.read_semantics(None) {
    Err(SemanticsReadError::RuntimeClosed) => ()
    _ => fail("generation exhaustion must close the semantics runtime")
  }
  assert_eq(
    runtime.semantics.committed_semantics.generation(),
    @core.SemanticsGeneration::new(18446744073709551615UL),
  )
  assert_true(
    before.generation() < runtime.semantics.committed_semantics.generation(),
  )
}
