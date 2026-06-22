///|
test "Canvas tracks dirty region for clear and clipped rect" {
  let canvas = Canvas::new(3, 2)
  assert_true(canvas.get_dirty_region().is_empty())
  canvas.clear(Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )
  canvas.clear_dirty_region()
  assert_true(canvas.get_dirty_region().is_empty())
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=1.0, height=2.0))
  canvas.fill_rect(0.0, 0.0, 3.0, 2.0, Paint::new().set_color(Color::black()))
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=2)),
  )
}

///|
test "Canvas::save and restore preserve transform and clip state" {
  let canvas = Canvas::new(3, 1)
  assert_eq(canvas.get_save_count(), 0)
  assert_true(!canvas.restore())
  assert_true(canvas.get_transform() == Transform::identity())
  assert_true(canvas.get_clip_rect() == None)

  let base_transform = Transform::translate(tx=1.0, ty=0.0)
  let base_clip = Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)
  canvas.set_transform(base_transform)
  canvas.set_clip_rect(base_clip)
  canvas.save()
  assert_eq(canvas.get_save_count(), 1)

  canvas.set_transform(Transform::translate(tx=2.0, ty=0.0))
  canvas.set_clip_rect(Rect::new(x=2.0, y=0.0, width=1.0, height=1.0))
  canvas.save()
  assert_eq(canvas.get_save_count(), 2)

  canvas.clear_clip()
  canvas.set_transform(Transform::identity())
  assert_true(canvas.restore())
  assert_eq(canvas.get_save_count(), 1)
  assert_true(canvas.get_transform() == Transform::translate(tx=2.0, ty=0.0))
  assert_true(
    canvas.get_clip_rect() ==
    Some(Rect::new(x=2.0, y=0.0, width=1.0, height=1.0)),
  )

  assert_true(canvas.restore())
  assert_eq(canvas.get_save_count(), 0)
  assert_true(canvas.get_transform() == base_transform)
  assert_true(canvas.get_clip_rect() == Some(base_clip))
  assert_true(!canvas.restore())
  assert_true(canvas.get_transform() == base_transform)
  assert_true(canvas.get_clip_rect() == Some(base_clip))
}

///|
test "Canvas transform helpers concatenate and reset current transform" {
  let canvas = Canvas::new(1, 1)
  canvas.translate(tx=1.0, ty=2.0)
  canvas.scale(sx=2.0, sy=3.0)
  assert_true(
    canvas.get_transform() ==
    Transform::translate(tx=1.0, ty=2.0).multiply(
      Transform::scale(sx=2.0, sy=3.0),
    ),
  )
  let (x, y) = canvas.get_transform().apply(1.0, 1.0)
  assert_eq(x, 3.0)
  assert_eq(y, 5.0)

  canvas.reset_transform()
  assert_true(canvas.get_transform() == Transform::identity())
  canvas.concat_transform(Transform::translate(tx=2.0, ty=0.0))
  canvas.rotate(0.0)
  assert_true(canvas.get_transform() == Transform::translate(tx=2.0, ty=0.0))
}

///|
test "Canvas transform helpers affect path drawing and restore" {
  let canvas = Canvas::new(4, 1)
  canvas.clear(Color::white())
  canvas.save()
  canvas.translate(tx=1.0, ty=0.0)
  canvas.scale(sx=2.0, sy=1.0)
  let path = Path::new().add_rect(0.0, 0.0, 1.0, 1.0)
  canvas.fill_path(path, Paint::new().set_color(Color::black()))
  assert_true(canvas.restore())
  canvas.fill_path(path, Paint::new().set_color(Color::blue()))

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::blue())
  assert_eq(pixmap.get_pixel(1, 0), Color::black())
  assert_eq(pixmap.get_pixel(2, 0), Color::black())
  assert_eq(pixmap.get_pixel(3, 0), Color::white())
}

///|
test "Canvas::restore affects subsequent path drawing" {
  let canvas = Canvas::new(3, 1)
  canvas.clear(Color::white())
  canvas.set_transform(Transform::translate(tx=1.0, ty=0.0))
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=1.0, height=1.0))
  canvas.save()

  canvas.set_transform(Transform::identity())
  canvas.clear_clip()
  canvas.fill_path(
    Path::new().add_rect(0.0, 0.0, 1.0, 1.0),
    Paint::new().set_color(Color::black()),
  )

  assert_true(canvas.restore())
  canvas.fill_path(
    Path::new().add_rect(0.0, 0.0, 1.0, 1.0),
    Paint::new().set_color(Color::blue()),
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::black())
  assert_eq(pixmap.get_pixel(1, 0), Color::blue())
  assert_eq(pixmap.get_pixel(2, 0), Color::white())
}

///|
test "Canvas::intersect_clip_rect narrows current clip" {
  let canvas = Canvas::new(5, 1)
  canvas.intersect_clip_rect(Rect::new(x=0.0, y=0.0, width=4.0, height=1.0))
  assert_true(
    canvas.get_clip_rect() ==
    Some(Rect::new(x=0.0, y=0.0, width=4.0, height=1.0)),
  )
  canvas.intersect_clip_rect(Rect::new(x=1.0, y=0.0, width=2.0, height=1.0))
  assert_true(
    canvas.get_clip_rect() ==
    Some(Rect::new(x=1.0, y=0.0, width=2.0, height=1.0)),
  )

  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  canvas.fill_rect(0.0, 0.0, 5.0, 1.0, Paint::new().set_color(Color::black()))
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::black())
  assert_eq(pixmap.get_pixel(2, 0), Color::black())
  assert_eq(pixmap.get_pixel(3, 0), Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::intersect_clip_rect supports save restore and empty clips" {
  let canvas = Canvas::new(4, 1)
  canvas.set_clip_rect(Rect::new(x=0.0, y=0.0, width=3.0, height=1.0))
  canvas.save()
  canvas.intersect_clip_rect(Rect::new(x=2.0, y=0.0, width=2.0, height=1.0))
  assert_true(
    canvas.get_clip_rect() ==
    Some(Rect::new(x=2.0, y=0.0, width=1.0, height=1.0)),
  )
  canvas.intersect_clip_rect(Rect::new(x=4.0, y=0.0, width=1.0, height=1.0))
  assert_true(
    canvas.get_clip_rect() ==
    Some(Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)),
  )
  assert_true(canvas.restore())
  assert_true(
    canvas.get_clip_rect() ==
    Some(Rect::new(x=0.0, y=0.0, width=3.0, height=1.0)),
  )

  canvas.intersect_clip_rect(Rect::new(x=0.0, y=0.0, width=0.0, height=1.0))
  assert_true(
    canvas.get_clip_rect() ==
    Some(Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)),
  )
}

///|
test "Canvas::draw_placeholder_text composites instead of overwriting" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  canvas.draw_placeholder_text(
    "A",
    0.0,
    0.0,
    1.0,
    Color::new(r=255, g=0, b=0, a=128),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    Color::new(r=255, g=127, b=127, a=255),
  )
}

///|
test "Canvas::draw_placeholder_text respects clip rect" {
  let canvas = Canvas::new(3, 1)
  canvas.clear(Color::white())
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=1.0, height=1.0))
  canvas.draw_placeholder_text("A", 0.0, 0.0, 2.0, Color::black())
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::black())
  assert_eq(pixmap.get_pixel(2, 0), Color::white())
}

///|
test "Canvas::draw_pixel respects clip rect" {
  let canvas = Canvas::new(3, 1)
  canvas.clear(Color::white())
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=1.0, height=1.0))
  canvas.draw_pixel(0, 0, Color::black())
  canvas.draw_pixel(1, 0, Color::black())
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::black())
}
