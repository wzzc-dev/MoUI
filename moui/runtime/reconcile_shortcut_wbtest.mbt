///|
/// F1 regression coverage (plan `hot-path-invalidation-boilerplate-convergence`):
/// the reconcile-side shortcuts must keep dirty-marking results identical to
/// the pre-shortcut semantics for every contract-abiding node pair.

///|
/// Reference implementation of the pre-F1 dirty-kind computation: the
/// structural semantics comparison and the action-kind rebuild run on every
/// reconcile. The shortcut tests assert the optimized function returns the
/// same kind for every pair below.
fn f1_reference_dirty_kind(
  current : &RuntimeViewNode,
  next : &RuntimeViewNode,
) -> ReconcileDirtyKind {
  let changes = next.declaration().changes_from(current.declaration())
  {
    layout: changes.layout(),
    paint: changes.paint(),
    semantics: changes.semantics() ||
    current.semantics() != next.semantics() ||
    current.semantics_action_kinds() != next.semantics_action_kinds(),
    platform: changes.platform(),
  }
}

///|
fn f1_assert_same_dirty_kind(
  current : &RuntimeViewNode,
  next : &RuntimeViewNode,
) -> Unit raise {
  let optimized = runtime_view_node_reconcile_dirty_kind(current, next)
  let reference = f1_reference_dirty_kind(current, next)
  assert_true(optimized.layout == reference.layout)
  assert_true(optimized.paint == reference.paint)
  assert_true(optimized.semantics == reference.semantics)
  assert_true(optimized.platform == reference.platform)
}

///|
fn f1_semantics(label~ : String = "") -> @core.ViewSemanticsInfo {
  @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Button, label~)
}

///|
fn f1_exact_declaration(
  layout_key~ : String = "layout",
  semantics_key~ : String = "semantics",
  constant~ : Bool = false,
  uncacheable~ : Bool = false,
) -> () -> @core.ViewDeclaration {
  () => {
    let key = @core.DeclarationKey::string(semantics_key)
    if constant {
      @core.ViewDeclaration::constant()
    } else if uncacheable {
      @core.ViewDeclaration::uncacheable()
    } else {
      @core.ViewDeclaration::channels(
        layout=Exact(@core.DeclarationKey::string(layout_key)),
        paint=Exact(@core.DeclarationKey::string(layout_key)),
        semantics=Exact(key),
        platform=Exact(key),
      )
    }
  }
}

///|
fn f1_node(
  declaration~ : () -> @core.ViewDeclaration,
  label~ : String = "label",
  handlers~ : Int32 = 0,
) -> &RuntimeViewNode {
  let view : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="F1Node", key=Some(label)),
    declaration~,
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=8.0, height=8.0)),
      )
    },
    semantics=() => f1_semantics(label~),
    semantics_actions=() => {
      let handlers_array : Array[@core.ViewSemanticsActionHandler[Unit]] = []
      for _index in 0..<handlers {
        handlers_array.push(
          @core.ViewSemanticsActionHandler::activate(_ctx => {
            @core.ViewSemanticsActionResult::message(())
          }),
        )
      }
      handlers_array
    },
  )
  adapt_view_for_runtime(view, _message => ())
}

///|
test "F1: Exact semantics channel with unchanged key short-circuits to clean" {
  // Contract-abiding pair: same Exact key, same semantics payload. Both the
  // optimized and the reference computation must report a fully clean kind —
  // the shortcut skips the 26-field structural compare and the action-kind
  // array allocation without changing the verdict.
  let current = f1_node(declaration=f1_exact_declaration())
  let next = f1_node(declaration=f1_exact_declaration())
  let kind = runtime_view_node_reconcile_dirty_kind(current, next)
  assert_false(kind.layout)
  assert_false(kind.paint)
  assert_false(kind.semantics)
  assert_false(kind.platform)
  f1_assert_same_dirty_kind(current, next)
  f1_assert_same_dirty_kind(next, current)
}

///|
test "F1: Exact semantics channel with changed key stays dirty" {
  let current = f1_node(
    declaration=f1_exact_declaration(semantics_key="v1"),
    label="v1",
  )
  let next = f1_node(
    declaration=f1_exact_declaration(semantics_key="v2"),
    label="v2",
  )
  let kind = runtime_view_node_reconcile_dirty_kind(current, next)
  assert_true(kind.semantics)
  f1_assert_same_dirty_kind(current, next)
}

///|
test "F1: Constant and Uncacheable channels keep the defensive comparison" {
  // Constant channels with diverging semantics payloads violate the channel
  // contract; the pre-F1 code caught that through the structural comparison
  // and the shortcut deliberately keeps that behavior (only the Exact path
  // short-circuits).
  let current = f1_node(declaration=f1_exact_declaration(constant=true))
  let next = f1_node(
    declaration=f1_exact_declaration(constant=true),
    label="changed",
  )
  let kind = runtime_view_node_reconcile_dirty_kind(current, next)
  assert_true(kind.semantics)
  f1_assert_same_dirty_kind(current, next)
  // A differing action-kind set is likewise still caught on the kept path.
  let kinds_current = f1_node(declaration=f1_exact_declaration(constant=true))
  let kinds_next = f1_node(
    declaration=f1_exact_declaration(constant=true),
    handlers=1,
  )
  let kinds_kind = runtime_view_node_reconcile_dirty_kind(
    kinds_current, kinds_next,
  )
  assert_true(kinds_kind.semantics)
  f1_assert_same_dirty_kind(kinds_current, kinds_next)
  // Uncacheable channels always reconcile as changed.
  let uncacheable_current = f1_node(
    declaration=f1_exact_declaration(uncacheable=true),
  )
  let uncacheable_next = f1_node(
    declaration=f1_exact_declaration(uncacheable=true),
    label="changed",
  )
  let uncacheable_kind = runtime_view_node_reconcile_dirty_kind(
    uncacheable_current, uncacheable_next,
  )
  assert_true(uncacheable_kind.semantics)
  f1_assert_same_dirty_kind(uncacheable_current, uncacheable_next)
}

///|
test "F1: layout change still implies semantics for the Exact channel" {
  let current = f1_node(declaration=f1_exact_declaration(layout_key="l1"))
  let next = f1_node(declaration=f1_exact_declaration(layout_key="l2"))
  let kind = runtime_view_node_reconcile_dirty_kind(current, next)
  assert_true(kind.layout)
  assert_true(kind.paint)
  assert_true(kind.semantics)
  assert_true(kind.platform)
  f1_assert_same_dirty_kind(current, next)
}

///|
test "F1: identity reads serve the construction-time snapshot" {
  // The adapter caches the wrapped view's construction-time identity. The
  // cached value must stay equal to the view's own snapshot across repeated
  // reconcile-time reads (identity key, kind, and same-identity comparison).
  let identity_calls = Ref(0)
  let view : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => {
      identity_calls.val = identity_calls.val + 1
      @core.ViewIdentity::new(kind="Counted", key=Some("k"))
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=8.0, height=8.0)),
      )
    },
  )
  // `from_node` samples the node identity exactly once; the adapter must not
  // add further samples however often reconcile consults it.
  let node = adapt_view_for_runtime(view, _message => ())
  assert_eq(identity_calls.val, 1)
  let key = runtime_view_node_identity_key(node)
  assert_eq(key.map(k => k.value()), Some("k"))
  assert_eq(runtime_view_node_kind(node), "Counted")
  ignore(runtime_view_node_identity_key(node))
  ignore(runtime_view_node_inspector_kind_label(node))
  assert_true(runtime_view_nodes_have_same_identity(node, node))
  assert_eq(identity_calls.val, 1)
}

///|
test "F1: children memo reuses wrappers for the same adapter" {
  // The wrapper array is a pure function of the adapter's immutable view
  // value: repeated `children()` calls on one adapter must return wrappers
  // for the same child views (the same wrapper objects), and mutating a
  // returned array must not corrupt the memo.
  let child_a : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="Child", key=Some("a")),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=4.0, height=4.0)),
      )
    },
  )
  let child_b : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="Child", key=Some("b")),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=4.0, height=4.0)),
      )
    },
  )
  let parent : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="Parent"),
    children=() => [child_a, child_b],
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=8.0, height=4.0)),
      )
    },
  )
  let node = adapt_view_for_runtime(parent, _message => ())
  let first = node.children()
  assert_eq(first.length(), 2)
  let second = node.children()
  assert_true(physical_equal(first[0], second[0]))
  assert_true(physical_equal(first[1], second[1]))
  // A caller mutating the handed-out array must not corrupt the memo.
  let scratch = node.children()
  scratch.clear()
  let third = node.children()
  assert_eq(third.length(), 2)
  assert_true(physical_equal(first[0], third[0]))
  // Fresh wrappers for a different adapter wrap the same child views but are
  // distinct objects.
  let other = adapt_view_for_runtime(parent, _message => ())
  let other_children = other.children()
  assert_eq(other_children.length(), 2)
  assert_false(physical_equal(first[0], other_children[0]))
}
