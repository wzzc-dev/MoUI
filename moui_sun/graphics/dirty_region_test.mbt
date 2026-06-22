///|
test "PixelRect geometry helpers" {
  let rect = PixelRect::new(x=1, y=2, width=3, height=4)
  assert_eq(rect.right(), 4)
  assert_eq(rect.bottom(), 6)
  assert_eq(rect.area(), 12)
  assert_eq(PixelRect::new(x=0, y=0, width=0, height=4).area(), 0)
  assert_true(rect.contains(1, 2))
  assert_true(rect.contains(3, 5))
  assert_true(!rect.contains(4, 5))
  assert_true(!PixelRect::new(x=0, y=0, width=0, height=1).contains(0, 0))
}

///|
test "PixelRect intersection and union" {
  let a = PixelRect::new(x=1, y=1, width=3, height=3)
  let b = PixelRect::new(x=3, y=0, width=3, height=3)
  assert_true(a.intersects(b))
  assert_true(
    a.intersection(b) == Some(PixelRect::new(x=3, y=1, width=1, height=2)),
  )
  assert_true(a.union(b) == PixelRect::new(x=1, y=0, width=5, height=4))
  assert_true(
    a.intersection(PixelRect::new(x=8, y=8, width=1, height=1)) == None,
  )
}

///|
test "DirtyRegion accumulates clipped rectangles and bounds" {
  let region = DirtyRegion::new()
  assert_true(region.is_empty())
  region.add_rect(PixelRect::new(x=0, y=0, width=0, height=2))
  assert_eq(region.get_rect_count(), 0)
  region.add_clipped_rect(
    PixelRect::new(x=-1, y=1, width=4, height=4),
    PixelRect::new(x=0, y=0, width=3, height=3),
  )
  region.add_rect(PixelRect::new(x=4, y=0, width=2, height=1))
  assert_eq(region.get_rect_count(), 2)
  assert_true(
    region.bounds() == Some(PixelRect::new(x=0, y=0, width=6, height=3)),
  )
  region.clear()
  assert_true(region.is_empty())
  assert_true(region.bounds() == None)
}

///|
test "DirtyRegion merges overlapping and edge-adjacent rectangles" {
  let region = DirtyRegion::new()
  region.add_rect(PixelRect::new(x=0, y=0, width=2, height=2))
  region.add_rect(PixelRect::new(x=2, y=0, width=2, height=2))
  assert_eq(region.get_rect_count(), 1)
  assert_true(
    region.bounds() == Some(PixelRect::new(x=0, y=0, width=4, height=2)),
  )
  region.add_rect(PixelRect::new(x=1, y=1, width=2, height=3))
  assert_eq(region.get_rect_count(), 1)
  assert_true(
    region.bounds() == Some(PixelRect::new(x=0, y=0, width=4, height=4)),
  )
}

///|
test "DirtyRegion keeps diagonally touching rectangles separate" {
  let region = DirtyRegion::new()
  region.add_rect(PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(PixelRect::new(x=1, y=1, width=1, height=1))
  assert_eq(region.get_rect_count(), 2)
}

///|
test "DirtyRegion::get_rects returns an isolated rect array" {
  let region = DirtyRegion::new()
  region.add_rect(PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(PixelRect::new(x=2, y=0, width=1, height=1))

  let rects = region.get_rects()
  assert_eq(rects.length(), 2)
  rects[0] = PixelRect::new(x=20, y=20, width=5, height=5)
  rects.push(PixelRect::new(x=30, y=30, width=1, height=1))

  assert_eq(region.get_rect_count(), 2)
  assert_true(
    region.bounds() == Some(PixelRect::new(x=0, y=0, width=3, height=1)),
  )
  let fresh = region.get_rects()
  assert_eq(fresh.length(), 2)
  assert_true(fresh[0] == PixelRect::new(x=0, y=0, width=1, height=1))
  assert_true(fresh[1] == PixelRect::new(x=2, y=0, width=1, height=1))
}

///|
test "DirtyRegion::present_rects clips and falls back to bounds over limit" {
  let region = DirtyRegion::new()
  region.add_rect(PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(PixelRect::new(x=3, y=0, width=1, height=1))
  region.add_rect(PixelRect::new(x=6, y=0, width=1, height=1))
  let bounds = PixelRect::new(x=0, y=0, width=7, height=2)
  let rects = region.present_rects(bounds, 4)
  assert_eq(rects.length(), 3)
  let fallback = region.present_rects(bounds, 2)
  assert_eq(fallback.length(), 1)
  assert_true(fallback[0] == PixelRect::new(x=0, y=0, width=7, height=1))
}

///|
test "DirtyRegion::present_plan exposes dirty present strategy" {
  let region = DirtyRegion::new()
  region.add_rect(PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(PixelRect::new(x=3, y=0, width=1, height=1))
  region.add_rect(PixelRect::new(x=6, y=0, width=1, height=1))

  let empty = region.present_plan(
    PixelRect::new(x=10, y=0, width=1, height=1),
    4,
  )
  assert_true(empty.is_empty())
  assert_true(empty.get_mode() == DirtyPresentPlanMode::Empty)
  assert_eq(empty.get_rect_count(), 0)
  assert_true(empty.get_present_bounds() == None)
  assert_eq(empty.get_present_pixel_count(), 0)
  assert_eq(empty.get_present_byte_count(), 0)
  assert_true(!empty.saves_full_present_pixels(7, 2))
  assert_true(empty.get_present_strategy(7, 2) == DirtyPresentStrategy::Skip)

  let rect_plan = region.present_plan(
    PixelRect::new(x=0, y=0, width=7, height=2),
    4,
  )
  assert_true(!rect_plan.is_empty())
  assert_true(rect_plan.get_mode() == DirtyPresentPlanMode::Rects)
  assert_true(!rect_plan.uses_bounds_fallback())
  assert_eq(rect_plan.get_rect_count(), 3)
  assert_true(
    rect_plan.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=7, height=1)),
  )
  assert_eq(rect_plan.get_present_pixel_count(), 3)
  assert_eq(rect_plan.get_present_byte_count(), 12)
  assert_true(rect_plan.saves_full_present_pixels(7, 2))
  assert_true(!rect_plan.saves_full_present_pixels(3, 1))
  assert_true(
    rect_plan.get_present_strategy(7, 2) == DirtyPresentStrategy::Partial,
  )
  assert_true(
    rect_plan.get_present_strategy(3, 1) == DirtyPresentStrategy::Full,
  )
  assert_true(
    rect_plan.get_rects()[1] == PixelRect::new(x=3, y=0, width=1, height=1),
  )

  let bounds_plan = region.present_plan(
    PixelRect::new(x=0, y=0, width=7, height=2),
    2,
  )
  assert_true(bounds_plan.get_mode() == DirtyPresentPlanMode::Bounds)
  assert_true(bounds_plan.uses_bounds_fallback())
  assert_eq(bounds_plan.get_rect_count(), 1)
  assert_true(
    bounds_plan.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=7, height=1)),
  )
  assert_eq(bounds_plan.get_present_pixel_count(), 7)
  assert_eq(bounds_plan.get_present_byte_count(), 28)
  assert_true(bounds_plan.saves_full_present_pixels(7, 2))
  assert_true(!bounds_plan.saves_full_present_pixels(7, 1))
  assert_true(
    bounds_plan.get_present_strategy(7, 2) == DirtyPresentStrategy::Partial,
  )
  assert_true(
    bounds_plan.get_present_strategy(7, 1) == DirtyPresentStrategy::Full,
  )
  assert_true(
    bounds_plan.get_rects()[0] == PixelRect::new(x=0, y=0, width=7, height=1),
  )
}

///|
test "DirtyPresentPlan::get_rects returns an isolated rect array" {
  let region = DirtyRegion::new()
  region.add_rect(PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(PixelRect::new(x=3, y=0, width=1, height=1))

  let plan = region.present_plan(PixelRect::new(x=0, y=0, width=4, height=1), 4)
  let rects = plan.get_rects()
  assert_eq(rects.length(), 2)
  rects[0] = PixelRect::new(x=20, y=20, width=5, height=5)
  rects.push(PixelRect::new(x=30, y=30, width=1, height=1))

  assert_eq(plan.get_rect_count(), 2)
  assert_true(
    plan.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=4, height=1)),
  )
  assert_eq(plan.get_present_pixel_count(), 2)
  let fresh = plan.get_rects()
  assert_eq(fresh.length(), 2)
  assert_true(fresh[0] == PixelRect::new(x=0, y=0, width=1, height=1))
  assert_true(fresh[1] == PixelRect::new(x=3, y=0, width=1, height=1))
}

///|
test "DirtySubmitPlan exposes scheduler state" {
  let clean = RenderFrame::new(1, 1).dirty_submit_plan(MemorySurface::new(1, 1))
  assert_true(clean.get_state() == DirtySubmitState::Clean)
  assert_true(!clean.has_dirty())
  assert_true(!clean.needs_present())
  assert_eq(clean.get_present_pixel_count(), 0)
  assert_eq(clean.get_present_byte_count(), 0)
  assert_true(!clean.saves_full_present_pixels(1, 1))
  assert_true(clean.get_present_strategy(1, 1) == DirtyPresentStrategy::Skip)

  let clipped_frame = RenderFrame::new(4, 1)
  clipped_frame.mark_dirty_rect(PixelRect::new(x=3, y=0, width=1, height=1))
  let clipped = clipped_frame.dirty_submit_plan(MemorySurface::new(2, 1))
  assert_true(clipped.get_state() == DirtySubmitState::DirtyClippedAway)
  assert_true(clipped.has_dirty())
  assert_true(!clipped.needs_present())
  assert_true(clipped.get_present_bounds() == None)
  assert_eq(clipped.get_present_pixel_count(), 0)
  assert_eq(clipped.get_present_byte_count(), 0)
  assert_true(!clipped.saves_full_present_pixels(2, 1))
  assert_true(clipped.get_present_strategy(2, 1) == DirtyPresentStrategy::Skip)

  let present_frame = RenderFrame::new(2, 1)
  present_frame.mark_dirty_rect(PixelRect::new(x=0, y=0, width=1, height=1))
  let present = present_frame.dirty_submit_plan(MemorySurface::new(2, 1))
  assert_true(present.get_state() == DirtySubmitState::Present)
  assert_true(present.has_dirty())
  assert_true(present.needs_present())
  assert_true(
    present.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(present.get_present_pixel_count(), 1)
  assert_eq(present.get_present_byte_count(), 4)
  assert_true(present.saves_full_present_pixels(2, 1))
  assert_true(!present.saves_full_present_pixels(1, 1))
  assert_true(
    present.get_present_strategy(2, 1) == DirtyPresentStrategy::Partial,
  )
  assert_true(present.get_present_strategy(1, 1) == DirtyPresentStrategy::Full)
}
