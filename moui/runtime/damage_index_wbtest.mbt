///|
/// Test fixture: a RenderNode with only the fields DamageIndex reads.
fn damage_index_node(
  id : Int,
  paint_bounds : Rect,
  is_repaint_boundary? : Bool = false,
  children? : Array[RenderNode] = [],
) -> RenderNode {
  let base = RenderNode::empty()
  {
    ..base,
    element_id: ElementId::new(id),
    paint_bounds,
    is_repaint_boundary,
    children,
  }
}

///|
test "DamageIndex damage bounds resolve the nearest repaint boundary" {
  // root(1, boundary) → mid(2) → leaf(3): the leaf inherits the root's
  // bounds; mid does too (no nearer boundary exists).
  let leaf = damage_index_node(
    3,
    Rect::new(x=12.0, y=0.0, width=8.0, height=8.0),
  )
  let mid = damage_index_node(
    2,
    Rect::new(x=10.0, y=0.0, width=40.0, height=40.0),
    children=[leaf],
  )
  let root = damage_index_node(
    1,
    Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    is_repaint_boundary=true,
    children=[mid],
  )
  let index = DamageIndex::build(root, DirtyIdSet::new())
  let leaf_bounds = index.damage_bounds(ElementId::new(3)).unwrap()
  assert_eq(leaf_bounds.origin.x, 0.0)
  assert_eq(leaf_bounds.size.width, 100.0)
  // A repaint-boundary node reports its own bounds, not an ancestor's.
  let root_bounds = index.damage_bounds(ElementId::new(1)).unwrap()
  assert_eq(root_bounds.origin.x, 0.0)
  assert_eq(root_bounds.size.width, 100.0)
}

///|
test "DamageIndex damage bounds fall back to own bounds without a boundary" {
  // root(1) → leaf(2), no repaint boundary anywhere: the leaf reports its
  // own bounds (old find_damage_bounds contract).
  let leaf = damage_index_node(
    2,
    Rect::new(x=5.0, y=6.0, width=7.0, height=8.0),
  )
  let root = damage_index_node(
    1,
    Rect::new(x=0.0, y=0.0, width=50.0, height=50.0),
    children=[leaf],
  )
  let index = DamageIndex::build(root, DirtyIdSet::new())
  let leaf_bounds = index.damage_bounds(ElementId::new(2)).unwrap()
  assert_eq(leaf_bounds.origin.x, 5.0)
  assert_eq(leaf_bounds.origin.y, 6.0)
  assert_eq(leaf_bounds.size.width, 7.0)
  // A nearer boundary wins over a farther one: boundary root → boundary
  // child → leaf resolves to the child's bounds.
  let inner_boundary = damage_index_node(
    4,
    Rect::new(x=10.0, y=10.0, width=20.0, height=20.0),
    is_repaint_boundary=true,
    children=[leaf],
  )
  let outer_root = damage_index_node(
    5,
    Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    is_repaint_boundary=true,
    children=[inner_boundary],
  )
  let nested = DamageIndex::build(outer_root, DirtyIdSet::new())
  let nested_bounds = nested.damage_bounds(ElementId::new(2)).unwrap()
  assert_eq(nested_bounds.origin.x, 10.0)
  assert_eq(nested_bounds.size.width, 20.0)
}

///|
test "DamageIndex descendant dirty excludes the node itself" {
  let dirty = DirtyIdSet::new()
  dirty.push(ElementId::new(2))
  // root(1) → child(2): root has a dirty descendant; child(2) is dirty
  // itself but has no strict dirty descendant.
  let child = damage_index_node(
    2,
    Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
  )
  let root = damage_index_node(
    1,
    Rect::new(x=0.0, y=0.0, width=50.0, height=50.0),
    children=[child],
  )
  let index = DamageIndex::build(root, dirty)
  assert_eq(index.has_dirty_descendant(ElementId::new(1)), true)
  assert_eq(index.has_dirty_descendant(ElementId::new(2)), false)
  // Unknown ids report no dirty descendant and no bounds.
  assert_eq(index.has_dirty_descendant(ElementId::new(99)), false)
  assert_eq(index.damage_bounds(ElementId::new(99)), None)
}

///|
test "DamageIndex folds dirty state up through deep chains" {
  let dirty = DirtyIdSet::new()
  dirty.push(ElementId::new(4))
  // root(1) → mid(2) → mid(3) → leaf(4, dirty): only strict ancestors of 4
  // report a dirty descendant.
  let leaf = damage_index_node(
    4,
    Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
  )
  let mid3 = damage_index_node(
    3,
    Rect::new(x=1.0, y=1.0, width=4.0, height=4.0),
    children=[leaf],
  )
  let mid2 = damage_index_node(
    2,
    Rect::new(x=1.0, y=1.0, width=6.0, height=6.0),
    children=[mid3],
  )
  let root = damage_index_node(
    1,
    Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    children=[mid2],
  )
  let index = DamageIndex::build(root, dirty)
  assert_eq(index.has_dirty_descendant(ElementId::new(1)), true)
  assert_eq(index.has_dirty_descendant(ElementId::new(2)), true)
  assert_eq(index.has_dirty_descendant(ElementId::new(3)), true)
  assert_eq(index.has_dirty_descendant(ElementId::new(4)), false)
}
