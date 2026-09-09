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
  let index = DamageIndex::build(root)
  let leaf_bounds = index.damage_bounds(ElementId::new(3)).unwrap()
  assert_eq(leaf_bounds.origin.x, 0.0)
  assert_eq(leaf_bounds.size.width, 100.0)
  // A repaint-boundary node reports its own bounds, not an ancestor's.
  let root_bounds = index.damage_bounds(ElementId::new(1)).unwrap()
  assert_eq(root_bounds.origin.x, 0.0)
  assert_eq(root_bounds.size.width, 100.0)
  // Unknown ids report no bounds.
  assert_eq(index.damage_bounds(ElementId::new(99)), None)
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
  let index = DamageIndex::build(root)
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
  let nested = DamageIndex::build(outer_root)
  let nested_bounds = nested.damage_bounds(ElementId::new(2)).unwrap()
  assert_eq(nested_bounds.origin.x, 10.0)
  assert_eq(nested_bounds.size.width, 20.0)
}

///|
test "DamageIndex shared ids resolve to the outermost node" {
  // Rich-text editors emit ViewPaintLayer nodes that reuse the owning
  // element's id; the index must resolve that id to the owner's own bounds
  // (written after its same-id children), not to any single layer.
  let layer = damage_index_node(
    7,
    Rect::new(x=0.0, y=90.0, width=100.0, height=20.0),
    is_repaint_boundary=true,
  )
  let owner = damage_index_node(
    7,
    Rect::new(x=0.0, y=0.0, width=100.0, height=80.0),
    children=[layer],
  )
  let index = DamageIndex::build(owner)
  let owner_bounds = index.damage_bounds(ElementId::new(7)).unwrap()
  assert_eq(owner_bounds.size.height, 80.0)
}
