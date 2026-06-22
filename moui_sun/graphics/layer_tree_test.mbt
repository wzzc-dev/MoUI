///|
test "LayerTree stores layers in z order" {
  let tree = LayerTree::new()
  let bottom = Layer::new(1, 1)
  let top = Layer::new(1, 1).set_position(1, 0)
  assert_eq(tree.add_layer(bottom), 0)
  assert_eq(tree.add_layer(top), 1)
  assert_eq(tree.get_layer_count(), 2)
  match tree.get_layer(0) {
    Some(layer) => assert_eq(layer.get_x(), 0)
    None => abort("expected layer 0")
  }
  match tree.get_layer(1) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected layer 1")
  }
  match tree.get_layer(2) {
    Some(_) => abort("unexpected layer 2")
    None => ()
  }
}

///|
test "LayerTree::add_layer invalidates clean compositable layer bounds" {
  let target = Canvas::new(3, 1)
  target.clear(Color::white())
  target.clear_dirty_region()

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  layer.clear_dirty_region()
  assert_true(layer.get_dirty_region().is_empty())

  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(tree.dirty_bounds() == None)

  assert_eq(tree.add_layer(Layer::new(1, 1).set_visible(false)), 1)
  assert_true(tree.dirty_bounds() == None)
  assert_eq(tree.add_layer(Layer::new(1, 1).set_opacity(0.0)), 2)
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree counts compositable layers" {
  let tree = LayerTree::new()
  ignore(tree.add_layer(Layer::new(1, 1)))
  ignore(tree.add_layer(Layer::new(1, 1).set_visible(false)))
  ignore(tree.add_layer(Layer::new(1, 1).set_opacity(0.0)))
  assert_eq(tree.get_layer_count(), 3)
  assert_eq(tree.get_compositable_layer_count(), 1)

  assert_true(tree.set_layer_visible(1, true))
  assert_eq(tree.get_compositable_layer_count(), 2)

  assert_true(tree.set_layer_opacity(2, 0.25))
  assert_eq(tree.get_compositable_layer_count(), 3)

  assert_true(tree.set_layer_opacity(0, 0.0))
  assert_eq(tree.get_compositable_layer_count(), 2)
}

///|
test "LayerTree::composite_to draws later layers above earlier layers" {
  let target = Canvas::new(2, 1)
  target.clear(Color::white())

  let bottom = Layer::new(2, 1)
  bottom.get_canvas().draw_pixel(0, 0, Color::red())
  bottom.get_canvas().draw_pixel(1, 0, Color::red())

  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(bottom))
  ignore(tree.add_layer(top))

  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
}

///|
test "LayerTree propagates translated dirty rectangles" {
  let tree = LayerTree::new()
  let left = Layer::new(3, 2).set_position(10, 1)
  let right = Layer::new(4, 2).set_position(20, 4)
  ignore(tree.add_layer(left))
  ignore(tree.add_layer(right))
  tree.clear_dirty_regions()

  left.get_canvas().draw_pixel(1, 0, Color::red())
  right.get_canvas().draw_pixel(2, 1, Color::blue())

  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=11, y=1, width=12, height=5)),
  )
  let rects = tree.dirty_rects(8)
  assert_eq(rects.length(), 2)
  assert_true(rects[0] == PixelRect::new(x=11, y=1, width=1, height=1))
  assert_true(rects[1] == PixelRect::new(x=22, y=5, width=1, height=1))
  let fallback = tree.dirty_rects(1)
  assert_eq(fallback.length(), 1)
  assert_true(fallback[0] == PixelRect::new(x=11, y=1, width=12, height=5))
}

///|
test "LayerTree::composite_dirty_to redraws dirty target area in z order and clears visible dirty state" {
  let target = Canvas::new(3, 1)
  target.clear(Color::white())
  target.clear_dirty_region()

  let bottom = Layer::new(3, 1)
  bottom.get_canvas().draw_pixel(0, 0, Color::red())
  bottom.get_canvas().draw_pixel(1, 0, Color::red())
  bottom.get_canvas().draw_pixel(2, 0, Color::red())
  bottom.clear_dirty_region()

  let top = Layer::new(1, 1).set_position(1, 0)

  let tree = LayerTree::new()
  ignore(tree.add_layer(bottom))
  ignore(tree.add_layer(top))
  tree.clear_dirty_regions()

  top.get_canvas().draw_pixel(0, 0, Color::blue())

  let draws = tree.composite_dirty_to(target, 8)
  assert_eq(draws, 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(bottom.get_dirty_region().is_empty())
  assert_true(top.get_dirty_region().is_empty())
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree keeps hidden layer dirty until it can be composited" {
  let target = Canvas::new(1, 1)
  target.clear(Color::white())

  let hidden = Layer::new(1, 1).set_visible(false)
  hidden.get_canvas().draw_pixel(0, 0, Color::red())

  let transparent = Layer::new(1, 1).set_opacity(0.0)
  transparent.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(hidden))
  ignore(tree.add_layer(transparent))

  assert_true(tree.dirty_bounds() == None)
  assert_eq(tree.composite_dirty_to(target, 8), 0)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())
  assert_true(!hidden.get_dirty_region().is_empty())
  assert_true(!transparent.get_dirty_region().is_empty())
}

///|
test "LayerTree::clear_dirty_regions clears every child" {
  let tree = LayerTree::new()
  let visible = Layer::new(1, 1)
  let hidden = Layer::new(1, 1).set_visible(false)
  visible.get_canvas().draw_pixel(0, 0, Color::red())
  hidden.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(tree.add_layer(visible))
  ignore(tree.add_layer(hidden))

  tree.clear_dirty_regions()
  assert_true(visible.get_dirty_region().is_empty())
  assert_true(hidden.get_dirty_region().is_empty())
}

///|
test "LayerTree::set_layer_position invalidates old and new bounds" {
  let target = Canvas::new(4, 1)
  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let moving = Layer::new(1, 1).set_position(1, 0)
  moving.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(moving), 1)
  ignore(tree.composite_to(target))
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_position(1, 2, 0))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::blue())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::set_layer_position preserves layer-local shader coordinates" {
  let target = Canvas::new(4, 1)
  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let gradient = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let moving = Layer::new(2, 1).set_shader(gradient)
  moving.clear(Color::white())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(moving), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::new(r=191, g=0, b=64))
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::new(r=64, g=0, b=191))
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_position(1, 2, 0))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=4, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::new(r=191, g=0, b=64))
  assert_eq(target.get_pixmap().get_pixel(3, 0), Color::new(r=64, g=0, b=191))
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::set_layer_position ignores unchanged position" {
  let target = Canvas::new(3, 1)
  let background = Layer::new(3, 1)
  background.clear(Color::white())

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(layer))
  ignore(tree.composite_to(target))
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_position(1, 1, 0))
  assert_true(tree.dirty_bounds() == None)
  assert_eq(tree.composite_dirty_to(target, 8), 0)
  assert_true(target.get_dirty_region().is_empty())
}

///|
test "LayerTree::set_layer_visible invalidates layer bounds" {
  let target = Canvas::new(3, 1)
  let background = Layer::new(3, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(top))
  ignore(tree.composite_to(target))
  tree.clear_dirty_regions()

  assert_true(tree.set_layer_visible(1, false))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())

  assert_true(tree.set_layer_visible(1, true))
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
}

///|
test "LayerTree::set_layer_opacity invalidates and reblends layer bounds" {
  let target = Canvas::new(1, 1)
  let background = Layer::new(1, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(top))
  ignore(tree.composite_to(target))
  tree.clear_dirty_regions()

  assert_true(tree.set_layer_opacity(1, 0.5))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    Color::new(r=127, g=127, b=255, a=255),
  )

  assert_true(tree.set_layer_opacity(1, 0.0 / 0.0))
  match tree.get_layer(1) {
    Some(layer) => assert_eq(layer.get_opacity(), 0.0)
    None => abort("expected top layer")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())

  assert_true(tree.set_layer_opacity(1, -1.0))
  assert_true(tree.dirty_bounds() is None)

  assert_true(tree.set_layer_opacity(1, 2.0))
  match tree.get_layer(1) {
    Some(layer) => assert_eq(layer.get_opacity(), 1.0)
    None => abort("expected top layer")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::set_layer_blend_mode invalidates and reblends layer bounds" {
  let target = Canvas::new(1, 1)
  let background = Layer::new(1, 1)
  background.clear(Color::blue())

  let top = Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(top))
  ignore(tree.composite_to(target))
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_blend_mode(1, BlendMode::Screen))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    Color::new(r=255, g=0, b=255, a=255),
  )
  assert_true(tree.dirty_bounds() == None)

  assert_true(tree.set_layer_blend_mode(1, BlendMode::Screen))
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::set_layer_blend_mode activates transparent-source modes" {
  let target = Canvas::new(1, 1)
  let background = Layer::new(1, 1)
  background.clear(Color::new(r=10, g=20, b=30))

  let top = Layer::new(1, 1).set_opacity(0.0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(top))
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::new(r=10, g=20, b=30))
  tree.clear_dirty_regions()

  assert_true(tree.set_layer_blend_mode(1, BlendMode::Clear))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::transparent())
}

///|
test "LayerTree::set_layer_blend_mode deactivates transparent-source modes" {
  let bounds = PixelRect::new(x=0, y=0, width=1, height=1)
  let target = Canvas::new(1, 1)
  let background_color = Color::new(r=10, g=20, b=30)
  let background = Layer::new(1, 1)
  background.clear(background_color)

  let top = Layer::new(1, 1).set_opacity(0.0).set_blend_mode(BlendMode::Clear)

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(top))
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::transparent())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_blend_mode(1, BlendMode::SourceOver))
  assert_true(tree.dirty_bounds() == Some(bounds))
  assert_eq(tree.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), background_color)
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::set_layer_filter invalidates and reblends layer bounds" {
  let target = Canvas::new(1, 1)
  let background = Layer::new(1, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(top))
  ignore(tree.composite_to(target))
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_filter(1, PaintFilter::invert()))
  match tree.get_layer(1) {
    Some(layer) => assert_true(layer.get_filter() is Some(_))
    None => abort("expected filtered layer")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::new(r=0, g=255, b=255))
  assert_true(tree.dirty_bounds() == None)

  assert_true(tree.set_layer_filter(1, PaintFilter::invert()))
  assert_true(tree.dirty_bounds() == None)

  assert_true(tree.set_layer_filter(1, PaintFilter::identity()))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  assert_true(tree.clear_layer_filter(1))
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree treats identity filter as no-op dirty style" {
  let target = Canvas::new(2, 1)
  target.clear(Color::white())

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_filter(0, PaintFilter::identity()))
  match tree.get_layer(0) {
    Some(layer) =>
      match layer.get_filter() {
        Some(filter) => assert_true(filter.is_identity())
        None => abort("expected stored identity filter")
      }
    None => abort("expected identity-filtered layer")
  }
  assert_true(tree.dirty_bounds() == None)

  let surface = MemorySurface::new(2, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_true(batch.is_empty())
      assert_eq(batch.get_rect_count(), 0)
      assert_true(batch.get_present_bounds() == None)
    }
    Err(_) => abort("expected empty identity-filter dirty present batch")
  }
  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(target.get_dirty_region().is_empty())

  assert_true(tree.clear_layer_filter(0))
  assert_true(tree.dirty_bounds() == None)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_true(batch.is_empty())
      assert_eq(batch.get_rect_count(), 0)
      assert_true(batch.get_present_bounds() == None)
    }
    Err(_) =>
      abort("expected empty cleared identity-filter dirty present batch")
  }
  assert_eq(surface.get_present_count(), 0)

  let partial_target = Canvas::new(4, 1)
  partial_target.clear(Color::white())
  let partial_layer = Layer::new(2, 1).set_position(1, 0)
  partial_layer.get_canvas().draw_pixel(0, 0, Color::red())
  partial_layer.get_canvas().draw_pixel(1, 0, Color::blue())
  let partial_tree = LayerTree::new()
  assert_eq(partial_tree.add_layer(partial_layer), 0)
  assert_eq(partial_tree.composite_to(partial_target), 1)
  partial_tree.clear_dirty_regions()
  partial_target.clear_dirty_region()

  match partial_tree.get_layer(0) {
    Some(layer) => layer.get_canvas().draw_pixel(1, 0, Color::green())
    None => abort("expected partial dirty identity-filter layer")
  }
  assert_true(
    partial_tree.dirty_bounds() ==
    Some(PixelRect::new(x=2, y=0, width=1, height=1)),
  )
  assert_true(partial_tree.set_layer_filter(0, PaintFilter::identity()))
  assert_true(
    partial_tree.dirty_bounds() ==
    Some(PixelRect::new(x=2, y=0, width=1, height=1)),
  )
  let partial_surface = MemorySurface::new(4, 1)
  match partial_tree.dirty_present_batch(partial_target, partial_surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=2, y=0, width=1, height=1)),
      )
    }
    Err(_) => abort("expected partial identity-filter dirty present batch")
  }
}

///|
test "LayerTree skips transparent no-output filter and shader invalidation" {
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  let tree = LayerTree::new()
  ignore(tree.add_layer(Layer::new(1, 1)))
  tree.clear_dirty_regions()

  assert_true(tree.set_layer_filter(0, PaintFilter::invert()))
  assert_true(tree.dirty_bounds() == None)
  match tree.get_layer(0) {
    Some(layer) => {
      assert_true(layer.get_filter() is Some(_))
      assert_true(!layer.has_dirty())
    }
    None => abort("expected transparent layer")
  }

  assert_true(tree.set_layer_shader(0, shader))
  assert_true(tree.dirty_bounds() == None)
  match tree.get_layer(0) {
    Some(layer) => {
      assert_true(layer.get_shader() is Some(_))
      assert_true(!layer.has_dirty())
    }
    None => abort("expected transparent layer")
  }

  assert_true(tree.clear_layer_shader(0))
  assert_true(tree.dirty_bounds() == None)
  assert_true(tree.clear_layer_filter(0))
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree preserves alpha-synthesizing filter and shader invalidation" {
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  let bounds = PixelRect::new(x=0, y=0, width=1, height=1)

  let filter_tree = LayerTree::new()
  ignore(filter_tree.add_layer(Layer::new(1, 1)))
  filter_tree.clear_dirty_regions()
  assert_true(filter_tree.set_layer_filter(0, make_layer_tree_alpha_filter()))
  assert_true(filter_tree.dirty_bounds() == Some(bounds))
  filter_tree.clear_dirty_regions()
  assert_true(filter_tree.clear_layer_filter(0))
  assert_true(filter_tree.dirty_bounds() == Some(bounds))

  let shader_tree = LayerTree::new()
  ignore(
    shader_tree.add_layer(
      Layer::new(1, 1).set_filter(make_layer_tree_alpha_filter()),
    ),
  )
  shader_tree.clear_dirty_regions()
  assert_true(shader_tree.set_layer_shader(0, shader))
  assert_true(shader_tree.dirty_bounds() == Some(bounds))
  shader_tree.clear_dirty_regions()
  assert_true(shader_tree.clear_layer_shader(0))
  assert_true(shader_tree.dirty_bounds() == Some(bounds))
}

///|
test "LayerTree filters source before blending dirty recomposition" {
  let target = Canvas::new(2, 1)

  let background = Layer::new(2, 1)
  background.clear(Color::red())

  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(top), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_filter(1, PaintFilter::invert()))
  assert_true(tree.set_layer_blend_mode(1, BlendMode::Multiply))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::black())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::composite_dirty_to keeps destination blend clean" {
  let gradient = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let target = Canvas::new(2, 1)
  let left = Color::new(r=20, g=40, b=60)
  let right = Color::new(r=200, g=150, b=100)
  target.get_pixmap().set_pixel(0, 0, left)
  target.get_pixmap().set_pixel(1, 0, right)
  target.clear_dirty_region()
  let layer = Layer::new(1, 1)
    .set_position(1, 0)
    .set_shader(gradient)
    .set_filter(PaintFilter::invert())
    .set_opacity(0.5)
    .set_blend_mode(BlendMode::Destination)
  layer.get_canvas().draw_pixel(0, 0, Color::white())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  tree.clear_dirty_regions()
  match tree.get_layer(0) {
    Some(value) => assert_true(!value.has_dirty())
    None => abort("expected clean destination layer")
  }

  match tree.get_layer(0) {
    Some(value) => value.get_canvas().draw_pixel(0, 0, Color::blue())
    None => abort("expected dirty destination layer")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), left)
  assert_eq(target.get_pixmap().get_pixel(1, 0), right)
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
  match tree.get_layer(0) {
    Some(value) => assert_true(!value.has_dirty())
    None => abort("expected cleared destination layer")
  }
}

///|
test "LayerTree::set_layer_shader invalidates and reblends layer bounds" {
  let target = Canvas::new(1, 1)
  let background = Layer::new(1, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  ignore(tree.add_layer(top))
  ignore(tree.composite_to(target))
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  let blue_shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  assert_true(tree.set_layer_shader(1, blue_shader))
  match tree.get_layer(1) {
    Some(layer) => assert_true(layer.get_shader() is Some(_))
    None => abort("expected shaded layer")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::blue())
  assert_true(tree.dirty_bounds() == None)

  assert_true(tree.set_layer_shader(1, blue_shader))
  assert_true(tree.dirty_bounds() == None)

  assert_true(tree.clear_layer_shader(1))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  assert_true(tree.clear_layer_shader(1))
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree composites positioned layer shaders in layer coordinates" {
  let target = Canvas::new(4, 1)
  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let top = Layer::new(2, 1).set_position(2, 0)
  top.get_canvas().draw_pixel(0, 0, Color::white())
  top.get_canvas().draw_pixel(1, 0, Color::white())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(top), 1)
  assert_eq(tree.composite_to(target), 2)
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  let gradient = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  assert_true(tree.set_layer_shader(1, gradient))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=2, y=0, width=2, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::new(r=191, g=0, b=64))
  assert_eq(target.get_pixmap().get_pixel(3, 0), Color::new(r=64, g=0, b=191))
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::resize_layer invalidates old and new bounds" {
  let target = Canvas::new(4, 1)
  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let top = Layer::new(2, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())
  top.get_canvas().draw_pixel(1, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(top), 1)
  ignore(tree.composite_to(target))
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.resize_layer(1, 1, 1))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())

  assert_true(tree.resize_layer(1, 3, 1))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=3, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(3, 0), Color::white())
}

///|
test "LayerTree::remove_layer invalidates removed layer bounds" {
  let target = Canvas::new(3, 1)
  let background = Layer::new(3, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(top), 1)
  ignore(tree.composite_to(target))
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  match tree.remove_layer(1) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected removed layer")
  }
  assert_eq(tree.get_layer_count(), 1)
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
}

///|
test "LayerTree::replace_layer invalidates old and new layer bounds" {
  let target = Canvas::new(4, 1)
  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let old_top = Layer::new(1, 1).set_position(1, 0)
  old_top.get_canvas().draw_pixel(0, 0, Color::red())

  let new_top = Layer::new(1, 1).set_position(2, 0)
  new_top.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(old_top), 1)
  ignore(tree.composite_to(target))
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  match tree.replace_layer(1, new_top) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected replaced layer")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::blue())
}

///|
test "LayerTree::reorder_layer changes z order and invalidates layer bounds" {
  let target = Canvas::new(1, 1)
  let bottom = Layer::new(1, 1)
  bottom.get_canvas().draw_pixel(0, 0, Color::red())
  let top = Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(bottom))
  ignore(tree.add_layer(top))
  ignore(tree.composite_to(target))
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::blue())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.reorder_layer(1, 0))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(tree.composite_dirty_to(target, 8), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  match tree.get_layer(0) {
    Some(layer) => assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::blue())
    None => abort("expected reordered layer")
  }
}

///|
test "LayerTree insertion helpers preserve following z order" {
  let make_layer = fn(color : Color) {
    let layer = Layer::new(1, 1)
    layer.get_canvas().draw_pixel(0, 0, color)
    layer
  }
  let tree = LayerTree::new()
  ignore(tree.add_layer(make_layer(Color::red())))
  ignore(tree.add_layer(make_layer(Color::green())))
  ignore(tree.add_layer(make_layer(Color::blue())))

  let replacement = make_layer(Color::white())
  match tree.replace_layer(1, replacement) {
    Some(_) => ()
    None => abort("expected replaced middle layer")
  }
  let replace_target = Canvas::new(1, 1)
  assert_eq(tree.composite_to(replace_target), 3)
  assert_eq(replace_target.get_pixmap().get_pixel(0, 0), Color::blue())

  assert_true(tree.reorder_layer(2, 0))
  let reorder_target = Canvas::new(1, 1)
  assert_eq(tree.composite_to(reorder_target), 3)
  assert_eq(reorder_target.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
test "LayerTree layer mutation helpers report invalid indexes" {
  let tree = LayerTree::new()
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  assert_true(!tree.invalidate_layer(0))
  assert_true(!tree.set_layer_position(0, 1, 1))
  assert_true(!tree.set_layer_visible(0, false))
  assert_true(!tree.set_layer_opacity(0, 0.5))
  assert_true(!tree.set_layer_blend_mode(0, BlendMode::Multiply))
  assert_true(!tree.set_layer_filter(0, PaintFilter::invert()))
  assert_true(!tree.clear_layer_filter(0))
  assert_true(!tree.set_layer_shader(0, shader))
  assert_true(!tree.clear_layer_shader(0))
  assert_true(!tree.resize_layer(0, 1, 1))
  match tree.remove_layer(0) {
    Some(_) => abort("unexpected removed layer")
    None => ()
  }
  match tree.replace_layer(0, Layer::new(1, 1)) {
    Some(_) => abort("unexpected replaced layer")
    None => ()
  }
  assert_true(!tree.reorder_layer(0, 0))
}

///|
test "LayerTree::present_dirty_to composites and presents dirty frame rects" {
  let target = Canvas::new(4, 1)
  let surface = MemorySurface::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(top), 1)

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_true(tree.dirty_bounds() == None)
  assert_true(target.get_dirty_region().is_empty())

  assert_true(tree.set_layer_position(1, 2, 0))
  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 2)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(surface.get_pixel(2, 0), Color::red())
}

///|
test "LayerTree::present_dirty_to_with_limit falls back to dirty bounds" {
  let target = Canvas::new(8, 1)
  let surface = MemorySurface::new(8, 1)

  let left = Layer::new(1, 1)
  left.get_canvas().draw_pixel(0, 0, Color::red())

  let middle = Layer::new(1, 1).set_position(3, 0)
  middle.get_canvas().draw_pixel(0, 0, Color::green())

  let right = Layer::new(1, 1).set_position(6, 0)
  right.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(left))
  ignore(tree.add_layer(middle))
  ignore(tree.add_layer(right))

  assert_true(tree.present_dirty_to_with_limit(target, surface, 2) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::red())
  assert_eq(surface.get_pixel(3, 0), Color::green())
  assert_eq(surface.get_pixel(6, 0), Color::blue())
}

///|
test "LayerTree::dirty_present_plan merges canvas and layer dirty regions" {
  let target = Canvas::new(8, 1)
  target.draw_pixel(0, 0, Color::white())

  let layer = Layer::new(1, 1).set_position(6, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let surface = MemorySurface::new(8, 1)
  let rect_plan = tree.dirty_present_plan(target, surface, 4)
  assert_true(rect_plan.get_mode() == DirtyPresentPlanMode::Rects)
  assert_eq(rect_plan.get_rect_count(), 2)
  assert_true(
    rect_plan.get_rects()[0] == PixelRect::new(x=0, y=0, width=1, height=1),
  )
  assert_true(
    rect_plan.get_rects()[1] == PixelRect::new(x=6, y=0, width=1, height=1),
  )

  let bounds_plan = tree.dirty_present_plan(target, surface, 1)
  assert_true(bounds_plan.get_mode() == DirtyPresentPlanMode::Bounds)
  assert_eq(bounds_plan.get_rect_count(), 1)
  assert_true(
    bounds_plan.get_rects()[0] == PixelRect::new(x=0, y=0, width=7, height=1),
  )
  assert_true(!target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=6, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_submit_plan snapshots unclipped dirty bounds" {
  let target = Canvas::new(8, 1)
  target.draw_pixel(7, 0, Color::white())

  let layer = Layer::new(1, 1).set_position(3, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let submit_plan = tree.dirty_submit_plan(target, MemorySurface::new(4, 1), 4)
  assert_true(submit_plan.has_dirty())
  assert_true(submit_plan.needs_present())
  assert_true(!submit_plan.uses_bounds_fallback())
  assert_true(
    submit_plan.get_dirty_bounds() ==
    Some(PixelRect::new(x=3, y=0, width=5, height=1)),
  )
  assert_eq(submit_plan.get_present_rect_count(), 1)
  assert_true(
    submit_plan.get_present_plan().get_rects()[0] ==
    PixelRect::new(x=3, y=0, width=1, height=1),
  )
  assert_true(!target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=3, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree policy schedules dirty clean and forced redraw paths" {
  let clean_target = Canvas::new(2, 1)
  clean_target.clear(Color::white())
  clean_target.clear_dirty_region()
  let clean_tree = LayerTree::new()
  let clean_surface = MemorySurface::new(2, 1)

  let dirty_only = clean_tree.submit_schedule_by_policy(
    clean_target,
    clean_surface,
    4,
    RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(dirty_only.get_action() == RenderFrameScheduleAction::Skip)
  assert_true(dirty_only.get_state() == DirtySubmitState::Clean)
  assert_true(!dirty_only.needs_present())
  assert_true(dirty_only.get_present_bounds() == None)

  let cached = clean_tree.redraw_schedule(clean_target, clean_surface, 4)
  assert_true(cached.get_action() == RenderFrameScheduleAction::Present)
  assert_true(cached.get_present_strategy() == DirtyPresentStrategy::Full)
  assert_true(cached.get_state() == DirtySubmitState::Clean)
  assert_true(cached.needs_present())
  assert_true(!cached.has_dirty())
  assert_true(
    cached.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_eq(cached.get_present_rect_count(), 1)
  assert_eq(cached.get_present_pixel_count(), 2)
  assert_eq(cached.get_present_byte_count(), 8)

  let dirty_target = Canvas::new(4, 1)
  dirty_target.clear(Color::white())
  dirty_target.clear_dirty_region()
  let layer = Layer::new(1, 1).set_position(2, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let dirty_tree = LayerTree::new()
  ignore(dirty_tree.add_layer(layer))
  let dirty_surface = MemorySurface::new(4, 1)

  let cached_dirty = dirty_tree.submit_schedule_by_policy(
    dirty_target,
    dirty_surface,
    4,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(cached_dirty.get_action() == RenderFrameScheduleAction::Present)
  assert_true(
    cached_dirty.get_present_strategy() == DirtyPresentStrategy::Partial,
  )
  assert_true(cached_dirty.get_state() == DirtySubmitState::Present)
  assert_true(cached_dirty.has_dirty())
  assert_true(cached_dirty.needs_present())
  assert_true(
    cached_dirty.get_dirty_bounds() ==
    Some(PixelRect::new(x=2, y=0, width=1, height=1)),
  )
  assert_true(
    cached_dirty.get_present_bounds() ==
    Some(PixelRect::new(x=2, y=0, width=1, height=1)),
  )
  assert_eq(cached_dirty.get_present_rect_count(), 1)
  assert_eq(cached_dirty.get_present_pixel_count(), 1)
  assert_true(cached_dirty.saves_full_present_pixels())

  let full_dirty = dirty_tree.submit_schedule_by_policy(
    dirty_target,
    dirty_surface,
    4,
    RenderFrameSubmitPolicy::FullRedraw,
  )
  assert_true(full_dirty.get_action() == RenderFrameScheduleAction::Present)
  assert_true(full_dirty.get_present_strategy() == DirtyPresentStrategy::Full)
  assert_true(full_dirty.get_state() == DirtySubmitState::Present)
  assert_true(
    full_dirty.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=4, height=1)),
  )
  assert_eq(full_dirty.get_present_pixel_count(), 4)
  assert_true(!full_dirty.saves_full_present_pixels())

  let clipped_target = Canvas::new(4, 1)
  clipped_target.clear_dirty_region()
  let clipped_layer = Layer::new(1, 1).set_position(3, 0)
  clipped_layer.get_canvas().draw_pixel(0, 0, Color::red())
  let clipped_tree = LayerTree::new()
  ignore(clipped_tree.add_layer(clipped_layer))
  let clipped_schedule = clipped_tree.submit_schedule(
    clipped_target,
    MemorySurface::new(2, 1),
    4,
  )
  assert_true(
    clipped_schedule.get_action() ==
    RenderFrameScheduleAction::SubmitWithoutPresent,
  )
  assert_true(
    clipped_schedule.get_state() == DirtySubmitState::DirtyClippedAway,
  )
  assert_true(clipped_schedule.has_dirty())
  assert_true(!clipped_schedule.needs_present())
  assert_true(clipped_schedule.was_clipped_away())
  assert_eq(clipped_schedule.get_present_rect_count(), 0)
}

///|
test "LayerTree submit requests preserve policy and execute schedules" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())
  target.clear_dirty_region()
  let surface = MemorySurface::new(4, 1)

  let layer = Layer::new(1, 1).set_position(2, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let request = tree.submit_request_by_policy(
    target,
    surface,
    4,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(request.get_policy() == RenderFrameSubmitPolicy::CachedRedraw)
  assert_true(request.get_action() == RenderFrameScheduleAction::Present)
  assert_true(request.get_present_strategy() == DirtyPresentStrategy::Partial)
  assert_true(request.get_state() == DirtySubmitState::Present)
  assert_eq(request.get_present_rect_count(), 1)
  assert_eq(surface.get_present_count(), 0)

  match tree.submit_request_to_with_limit(target, surface, 4, request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected scheduled layer tree submit")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(2, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::blue())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)

  let clean_surface = MemorySurface::new(4, 1)
  let clean_request = tree.submit_request_by_policy(
    target,
    clean_surface,
    4,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(clean_request.get_action() == RenderFrameScheduleAction::Present)
  assert_true(
    clean_request.get_present_strategy() == DirtyPresentStrategy::Full,
  )
  assert_true(clean_request.get_state() == DirtySubmitState::Clean)
  assert_true(!clean_request.has_dirty())

  match
    tree.submit_request_to_with_limit(target, clean_surface, 4, clean_request) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(result.did_present())
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 4)
    }
    Err(_) => abort("expected cached redraw submit")
  }
  assert_eq(clean_surface.get_present_count(), 1)
  assert_eq(clean_surface.get_pixel(2, 0), Color::blue())
}

///|
test "LayerTree cached redraw request preserves policy after clipped clean plan" {
  let target = Canvas::new(1, 1)
  target.clear(Color::green())
  target.clear_dirty_region()
  let tree = LayerTree::new()

  let clipped_surface = MemorySurface::new(0, 1)
  let request = tree.submit_request_by_policy(
    target,
    clipped_surface,
    4,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(request.get_policy() == RenderFrameSubmitPolicy::CachedRedraw)
  assert_true(request.get_action() == RenderFrameScheduleAction::Skip)
  assert_true(request.get_present_strategy() == DirtyPresentStrategy::Full)
  assert_true(request.get_state() == DirtySubmitState::Clean)
  assert_true(!request.needs_present())
  assert_true(!request.has_dirty())
  assert_eq(request.get_present_rect_count(), 0)
  assert_eq(request.get_present_pixel_count(), 0)

  let surface = MemorySurface::new(1, 1)
  match tree.submit_request_to_with_limit(target, surface, 4, request) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(!result.has_dirty())
      assert_true(
        result.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=1, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
    }
    Err(_) => abort("expected cached redraw request to keep policy")
  }

  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::green())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree scheduled clipped submit redraws target without presenting" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())
  target.clear_dirty_region()
  let layer = Layer::new(1, 1).set_position(3, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))
  let surface = MemorySurface::new(2, 1)
  let schedule = tree.submit_schedule(target, surface, 4)
  assert_true(
    schedule.get_action() == RenderFrameScheduleAction::SubmitWithoutPresent,
  )
  assert_true(schedule.get_state() == DirtySubmitState::DirtyClippedAway)
  assert_true(schedule.was_clipped_away())
  assert_true(schedule.has_dirty())
  assert_true(!schedule.needs_present())
  assert_eq(schedule.get_present_rect_count(), 0)

  match tree.submit_scheduled_to_with_limit(target, surface, 4, schedule) {
    Ok(result) => {
      assert_true(result.get_state() == DirtySubmitState::DirtyClippedAway)
      assert_true(result.was_clipped_away())
      assert_true(result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_present_rect_count(), 0)
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
    }
    Err(_) => abort("expected clipped scheduled submit")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(3, 0), Color::blue())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree submit request recomputes after Destination blend invalidation" {
  let target = Canvas::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::blue())
  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(top), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  let surface = MemorySurface::new(2, 1)
  let stale_request = tree.submit_request_by_policy(
    target,
    surface,
    4,
    RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(stale_request.get_policy() == RenderFrameSubmitPolicy::DirtyOnly)
  assert_true(stale_request.get_action() == RenderFrameScheduleAction::Skip)
  assert_true(stale_request.get_state() == DirtySubmitState::Clean)
  assert_true(!stale_request.has_dirty())
  assert_eq(stale_request.get_present_rect_count(), 0)

  assert_true(tree.set_layer_blend_mode(1, BlendMode::Destination))
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  match tree.submit_request_to_with_limit(target, surface, 4, stale_request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
    }
    Err(_) => abort("expected recomputed stale submit request")
  }

  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes without consuming dirty" {
  let target = Canvas::new(8, 1)
  target.draw_pixel(0, 0, Color::white())

  let layer = Layer::new(1, 1).set_position(6, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let surface = MemorySurface::new(8, 1)
  match tree.dirty_present_batch(target, surface, 1) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 7)
      assert_eq(batch.get_present_byte_count(), 28)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=0, y=0, width=7, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 28)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[24], Color::blue().r)
    }
    Err(_) => abort("expected layer tree dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(6, 0), Color::transparent())
  assert_true(!target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=6, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch recomposites clean layers over target dirty path without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())

  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(1, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
    .set_blend_mode(BlendMode::Multiply)
  layer.get_canvas().draw_pixel(0, 0, Color::white())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::new(r=255, g=255, b=0))
  tree.clear_dirty_regions()
  target.clear_dirty_region()
  match tree.get_layer(0) {
    Some(value) => assert_true(!value.has_dirty())
    None => abort("expected clean shader-filter layer")
  }

  target.fill_path(
    Path::new().add_rect(1.0, 0.0, 1.0, 1.0),
    Paint::new().set_color(Color::blue()),
  )
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(tree.dirty_bounds() == None)

  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::black().r)
      assert_eq(pixels[1], Color::black().g)
      assert_eq(pixels[2], Color::black().b)
      assert_eq(pixels[3], Color::black().a)
    }
    Err(_) => abort("expected recomposited target-dirty layer tree batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_true(tree.dirty_bounds() == None)
  match tree.get_layer(0) {
    Some(value) => assert_true(!value.has_dirty())
    None => abort("expected clean shader-filter layer after batch")
  }

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::black())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::black())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes filtered layer pixels without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())
  target.clear_dirty_region()

  let layer = Layer::new(1, 1)
    .set_position(1, 0)
    .set_filter(PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 1) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let cyan = Color::new(r=0, g=255, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], cyan.r)
      assert_eq(pixels[1], cyan.g)
      assert_eq(pixels[2], cyan.b)
      assert_eq(pixels[3], cyan.a)
    }
    Err(_) => abort("expected filtered layer tree dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes shader filtered layer pixels without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())
  target.clear_dirty_region()

  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(2, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, Color::white())
  layer.get_canvas().draw_pixel(1, 0, Color::white())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 4) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let left = Color::new(r=64, g=255, b=191)
      let right = Color::new(r=191, g=255, b=64)
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], left.r)
      assert_eq(pixels[1], left.g)
      assert_eq(pixels[2], left.b)
      assert_eq(pixels[3], left.a)
      assert_eq(pixels[4], right.r)
      assert_eq(pixels[5], right.g)
      assert_eq(pixels[6], right.b)
      assert_eq(pixels[7], right.a)
    }
    Err(_) => abort("expected shader filtered layer tree dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes moved layer bounds without consuming dirty" {
  let target = Canvas::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let moving = Layer::new(1, 1).set_position(1, 0)
  moving.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(moving), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_position(1, 2, 0))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
      assert_eq(pixels[4], Color::blue().r)
      assert_eq(pixels[5], Color::blue().g)
      assert_eq(pixels[6], Color::blue().b)
      assert_eq(pixels[7], Color::blue().a)
    }
    Err(_) => abort("expected moved layer dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes resized layer bounds without consuming dirty" {
  let target = Canvas::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let resizing = Layer::new(2, 1).set_position(1, 0)
  resizing.get_canvas().draw_pixel(0, 0, Color::red())
  resizing.get_canvas().draw_pixel(1, 0, Color::blue())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(resizing), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::blue())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.resize_layer(1, 1, 1))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
      assert_eq(pixels[4], Color::white().r)
      assert_eq(pixels[5], Color::white().g)
      assert_eq(pixels[6], Color::white().b)
      assert_eq(pixels[7], Color::white().a)
    }
    Err(_) => abort("expected resized layer dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::blue())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_eq(surface.get_pixel(2, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes hidden layer bounds without consuming dirty" {
  let target = Canvas::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(top), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_visible(1, false))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
    }
    Err(_) => abort("expected hidden layer dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes removed layer bounds without consuming dirty" {
  let target = Canvas::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(top), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  match tree.remove_layer(1) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected removed layer")
  }
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
    }
    Err(_) => abort("expected removed layer dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes replaced layer bounds without consuming dirty" {
  let target = Canvas::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let old_top = Layer::new(1, 1).set_position(1, 0)
  old_top.get_canvas().draw_pixel(0, 0, Color::red())
  let new_top = Layer::new(1, 1).set_position(2, 0)
  new_top.get_canvas().draw_pixel(0, 0, Color::green())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(old_top), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  match tree.replace_layer(1, new_top) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected replaced layer")
  }
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
      assert_eq(pixels[4], Color::green().r)
      assert_eq(pixels[5], Color::green().g)
      assert_eq(pixels[6], Color::green().b)
      assert_eq(pixels[7], Color::green().a)
    }
    Err(_) => abort("expected replaced layer dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(surface.get_pixel(2, 0), Color::green())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::green())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes reordered layer bounds without consuming dirty" {
  let target = Canvas::new(2, 1)

  let background = Layer::new(2, 1)
  background.clear(Color::white())
  let bottom = Layer::new(1, 1)
  bottom.get_canvas().draw_pixel(0, 0, Color::red())
  let top = Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(bottom), 1)
  assert_eq(tree.add_layer(top), 2)
  assert_eq(tree.composite_to(target), 3)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.reorder_layer(2, 1))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(2, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=0, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
    }
    Err(_) => abort("expected reordered layer dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::blue())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::red())
  assert_eq(surface.get_pixel(1, 0), Color::transparent())
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes opacity style invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(layer), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_opacity(1, 0.5))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let half_blue = Color::new(r=127, g=127, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], half_blue.r)
      assert_eq(pixels[1], half_blue.g)
      assert_eq(pixels[2], half_blue.b)
      assert_eq(pixels[3], half_blue.a)
    }
    Err(_) => abort("expected opacity style invalidation dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes filter style invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_filter(0, PaintFilter::invert()))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let cyan = Color::new(r=0, g=255, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], cyan.r)
      assert_eq(pixels[1], cyan.g)
      assert_eq(pixels[2], cyan.b)
      assert_eq(pixels[3], cyan.a)
    }
    Err(_) => abort("expected filtered style invalidation dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes transparent RGB filter invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_pixmap().set_pixel(0, 0, Color::new(r=128, g=0, b=0, a=0))
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_filter(0, make_layer_tree_red_to_alpha_filter()))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let gray = Color::new(r=127, g=127, b=127, a=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], gray.r)
      assert_eq(pixels[1], gray.g)
      assert_eq(pixels[2], gray.b)
      assert_eq(pixels[3], gray.a)
    }
    Err(_) =>
      abort("expected transparent RGB filter invalidation dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::new(r=127, g=127, b=127, a=255))
  assert_eq(
    target.get_pixmap().get_pixel(1, 0),
    Color::new(r=127, g=127, b=127, a=255),
  )
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes cleared filter invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())

  let layer = Layer::new(1, 1)
    .set_position(1, 0)
    .set_filter(PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  let cyan = Color::new(r=0, g=255, b=255)
  assert_eq(target.get_pixmap().get_pixel(1, 0), cyan)
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.clear_layer_filter(0))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
    }
    Err(_) => abort("expected cleared filter dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), cyan)
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes blend style invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::blue())
  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(layer), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_blend_mode(1, BlendMode::Screen))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let magenta = Color::new(r=255, g=0, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], magenta.r)
      assert_eq(pixels[1], magenta.g)
      assert_eq(pixels[2], magenta.b)
      assert_eq(pixels[3], magenta.a)
    }
    Err(_) => abort("expected blend style invalidation dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch reblends Destination shader filter invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)
  let background_left = Color::new(r=20, g=40, b=60)
  let background_right = Color::new(r=200, g=150, b=100)
  let cached_left = Color::new(r=42, g=148, b=126)
  let cached_right = Color::new(r=195, g=203, b=82)

  let background = Layer::new(4, 1)
  background.get_canvas().draw_pixel(0, 0, Color::white())
  background.get_canvas().draw_pixel(1, 0, background_left)
  background.get_canvas().draw_pixel(2, 0, background_right)
  background.get_canvas().draw_pixel(3, 0, Color::black())
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(2, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
    .set_opacity(0.5)
  layer.get_canvas().draw_pixel(0, 0, Color::white())
  layer.get_canvas().draw_pixel(1, 0, Color::white())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(layer), 1)
  assert_eq(tree.composite_to(target), 2)
  assert_eq(target.get_pixmap().get_pixel(1, 0), cached_left)
  assert_eq(target.get_pixmap().get_pixel(2, 0), cached_right)
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_blend_mode(1, BlendMode::Destination))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], background_left.r)
      assert_eq(pixels[1], background_left.g)
      assert_eq(pixels[2], background_left.b)
      assert_eq(pixels[3], background_left.a)
      assert_eq(pixels[4], background_right.r)
      assert_eq(pixels[5], background_right.g)
      assert_eq(pixels[6], background_right.b)
      assert_eq(pixels[7], background_right.a)
    }
    Err(_) => abort("expected Destination shader filter dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), cached_left)
  assert_eq(target.get_pixmap().get_pixel(2, 0), cached_right)
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_true(
    surface.get_present_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  assert_eq(surface.get_pixel(1, 0), background_left)
  assert_eq(surface.get_pixel(2, 0), background_right)
  assert_eq(target.get_pixmap().get_pixel(1, 0), background_left)
  assert_eq(target.get_pixmap().get_pixel(2, 0), background_right)
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes transparent-source blend invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)
  let background_color = Color::new(r=10, g=20, b=30)

  let background = Layer::new(4, 1)
  background.clear(background_color)
  let layer = Layer::new(1, 1).set_position(1, 0).set_opacity(0.0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(layer), 1)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), background_color)
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.set_layer_blend_mode(1, BlendMode::Clear))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let transparent = Color::transparent()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], transparent.r)
      assert_eq(pixels[1], transparent.g)
      assert_eq(pixels[2], transparent.b)
      assert_eq(pixels[3], transparent.a)
    }
    Err(_) => abort("expected transparent-source blend dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), background_color)
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_true(
    surface.get_present_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(surface.get_pixel(1, 0), Color::transparent())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::transparent())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes shader style invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  let blue_shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  assert_true(tree.set_layer_shader(0, blue_shader))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::blue().r)
      assert_eq(pixels[1], Color::blue().g)
      assert_eq(pixels[2], Color::blue().b)
      assert_eq(pixels[3], Color::blue().a)
    }
    Err(_) => abort("expected shader style invalidation dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::dirty_present_batch materializes positioned shader invalidation through filter in layer coordinates" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())

  let layer = Layer::new(2, 1)
    .set_position(1, 0)
    .set_filter(PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, Color::white())
  layer.get_canvas().draw_pixel(1, 0, Color::white())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::black())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::black())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  assert_true(tree.set_layer_shader(0, shader))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let left = Color::new(r=64, g=255, b=191)
      let right = Color::new(r=191, g=255, b=64)
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], left.r)
      assert_eq(pixels[1], left.g)
      assert_eq(pixels[2], left.b)
      assert_eq(pixels[3], left.a)
      assert_eq(pixels[4], right.r)
      assert_eq(pixels[5], right.g)
      assert_eq(pixels[6], right.b)
      assert_eq(pixels[7], right.a)
    }
    Err(_) =>
      abort("expected positioned shader filter style dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::black())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::black())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  match tree.get_layer(0) {
    Some(value) => assert_true(value.has_dirty())
    None => abort("expected dirty shader-filter layer")
  }
}

///|
test "LayerTree::dirty_present_batch materializes antialiased layer path through shader filter" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())
  target.clear_dirty_region()

  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(2, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
  let layer_canvas = layer.get_canvas()
  layer_canvas.fill_path(
    Path::new().add_rect(0.5, 0.0, 1.0, 1.0),
    Paint::new().set_color(Color::white()),
  )
  assert_eq(
    layer.get_pixmap().get_pixel(0, 0),
    Color::new(r=255, g=255, b=255, a=128),
  )
  assert_eq(
    layer.get_pixmap().get_pixel(1, 0),
    Color::new(r=255, g=255, b=255, a=128),
  )

  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  let left = Color::new(r=159, g=255, b=223)
  let right = Color::new(r=223, g=255, b=159)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], left.r)
      assert_eq(pixels[1], left.g)
      assert_eq(pixels[2], left.b)
      assert_eq(pixels[3], left.a)
      assert_eq(pixels[4], right.r)
      assert_eq(pixels[5], right.g)
      assert_eq(pixels[6], right.b)
      assert_eq(pixels[7], right.a)
    }
    Err(_) => abort("expected antialiased path shader-filter dirty batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(target.get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(surface.get_pixel(1, 0), left)
  assert_eq(surface.get_pixel(2, 0), right)
  assert_eq(target.get_pixmap().get_pixel(1, 0), left)
  assert_eq(target.get_pixmap().get_pixel(2, 0), right)
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::dirty_present_batch materializes cleared shader invalidation without consuming dirty" {
  let target = Canvas::new(4, 1)
  target.clear(Color::white())

  let blue_shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(1, 1).set_position(1, 0).set_shader(blue_shader)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = LayerTree::new()
  assert_eq(tree.add_layer(layer), 0)
  assert_eq(tree.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  tree.clear_dirty_regions()
  target.clear_dirty_region()

  assert_true(tree.clear_layer_shader(0))
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  match tree.dirty_present_batch(target, surface, 8) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
    }
    Err(_) => abort("expected cleared shader dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "LayerTree::present_dirty_to_with_limit consumes exposed dirty present plan" {
  let target = Canvas::new(8, 1)
  target.draw_pixel(0, 0, Color::white())

  let layer = Layer::new(1, 1).set_position(6, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let surface = RecordingSurface::new(8, 1)
  let plan = tree.dirty_present_plan(target, surface, 1)
  assert_true(plan.get_mode() == DirtyPresentPlanMode::Bounds)
  assert_true(
    plan.get_rects()[0] == PixelRect::new(x=0, y=0, width=7, height=1),
  )

  assert_true(tree.present_dirty_to_with_limit(target, surface, 1) == Ok(1))
  assert_eq(surface.get_rect_count(), 1)
  assert_true(surface.get_rect(0) == plan.get_rects()[0])
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::present_dirty_to consumes surface-clipped layer dirty" {
  let target = Canvas::new(4, 1)
  let layer = Layer::new(1, 1).set_position(3, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  let surface = MemorySurface::new(2, 1)
  let submit_plan = tree.dirty_submit_plan(target, surface, 4)
  assert_true(submit_plan.get_state() == DirtySubmitState::DirtyClippedAway)
  assert_true(tree.present_dirty_to_with_limit(target, surface, 4) == Ok(0))
  assert_eq(surface.get_present_count(), 0)
  assert_true(target.get_dirty_region().is_empty())
  assert_true(tree.dirty_bounds() == None)
}

///|
test "LayerTree::present_dirty_to preserves dirty state on surface error" {
  let target = Canvas::new(2, 1)
  let surface = FailingSurface::new(2, 1)

  let layer = Layer::new(2, 1)
  layer.get_canvas().draw_pixel(1, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  match tree.present_dirty_to(target, surface) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected rect out of bounds")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_true(target.get_dirty_region().is_empty())
  assert_eq(target.get_pixmap().get_pixel(1, 0), Color::transparent())
}

///|
test "LayerTree::present_dirty_to restores blended pixels before retry" {
  let target = Canvas::new(1, 1)
  target.clear(Color::white())
  target.clear_dirty_region()

  let layer = Layer::new(1, 1).set_opacity(0.5)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  match tree.present_dirty_to(target, FailingSurface::new(1, 1)) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected surface failure")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())

  let surface = MemorySurface::new(1, 1)
  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    Color::new(r=127, g=127, b=255, a=255),
  )
  assert_eq(surface.get_pixel(0, 0), Color::new(r=127, g=127, b=255, a=255))
  assert_true(tree.dirty_bounds() == None)
  assert_true(target.get_dirty_region().is_empty())
}

///|
test "LayerTree::present_dirty_to restores shader/filter pixels before retry" {
  let target = Canvas::new(1, 1)
  target.clear(Color::white())
  target.clear_dirty_region()

  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(1, 1)
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, Color::white())

  let tree = LayerTree::new()
  ignore(tree.add_layer(layer))

  match tree.present_dirty_to(target, FailingSurface::new(1, 1)) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected surface failure")
  }
  assert_true(
    tree.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_true(target.get_dirty_region().is_empty())
  assert_eq(target.get_pixmap().get_pixel(0, 0), Color::white())

  let surface = MemorySurface::new(1, 1)
  assert_true(tree.present_dirty_to(target, surface) == Ok(1))
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    Color::new(r=255, g=255, b=0, a=255),
  )
  assert_eq(surface.get_pixel(0, 0), Color::new(r=255, g=255, b=0, a=255))
  assert_true(tree.dirty_bounds() == None)
  assert_true(target.get_dirty_region().is_empty())
}

///|
struct RecordingSurface {
  width : Int
  height : Int
  rects : Array[PixelRect]
} derive(Debug)

///|
fn RecordingSurface::new(width : Int, height : Int) -> RecordingSurface {
  { width, height, rects: [] }
}

///|
fn RecordingSurface::get_rect_count(self : RecordingSurface) -> Int {
  self.rects.length()
}

///|
fn RecordingSurface::get_rect(
  self : RecordingSurface,
  index : Int,
) -> PixelRect {
  self.rects[index]
}

///|
impl Surface for RecordingSurface with fn get_width(self) {
  self.width
}

///|
impl Surface for RecordingSurface with fn get_height(self) {
  self.height
}

///|
impl Surface for RecordingSurface with fn present_pixels(
  self,
  width,
  height,
  row_bytes,
  pixels,
) {
  match
    validate_present_rect(
      self.width,
      self.height,
      0,
      0,
      width,
      height,
      row_bytes,
      pixels,
    ) {
    Err(error) => Err(error)
    Ok(_) => {
      self.rects.push(PixelRect::new(x=0, y=0, width~, height~))
      Ok(())
    }
  }
}

///|
impl Surface for RecordingSurface with fn present_pixels_rect(
  self,
  x,
  y,
  width,
  height,
  row_bytes,
  pixels,
) {
  match
    validate_present_rect(
      self.width,
      self.height,
      x,
      y,
      width,
      height,
      row_bytes,
      pixels,
    ) {
    Err(error) => Err(error)
    Ok(_) => {
      self.rects.push(PixelRect::new(x~, y~, width~, height~))
      Ok(())
    }
  }
}

///|
fn make_layer_tree_alpha_filter() -> PaintFilter {
  PaintFilter::color_matrix([
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 128.0,
  ])
}

///|
fn make_layer_tree_red_to_alpha_filter() -> PaintFilter {
  PaintFilter::color_matrix([
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
    0.0, 0.0, 0.0, 0.0,
  ])
}

///|
struct FailingSurface {
  width : Int
  height : Int
} derive(Debug)

///|
fn FailingSurface::new(width : Int, height : Int) -> FailingSurface {
  { width, height }
}

///|
impl Surface for FailingSurface with fn get_width(self) {
  self.width
}

///|
impl Surface for FailingSurface with fn get_height(self) {
  self.height
}

///|
impl Surface for FailingSurface with fn present_pixels(
  self,
  width,
  height,
  row_bytes,
  pixels,
) {
  ignore(self)
  ignore(width)
  ignore(height)
  ignore(row_bytes)
  ignore(pixels)
  Err(PresentError::InvalidDimensions(0, 0))
}

///|
impl Surface for FailingSurface with fn present_pixels_rect(
  self,
  x,
  y,
  width,
  height,
  row_bytes,
  pixels,
) {
  ignore(self)
  ignore(x)
  ignore(y)
  ignore(width)
  ignore(height)
  ignore(row_bytes)
  ignore(pixels)
  Err(PresentError::InvalidDimensions(0, 0))
}
