///|
fn metal_test_glyph_raster() -> @native_text.NativeRasterGlyph {
  // Half the box covered, half empty: a fully covered mask would pass even when
  // coverage lands only in alpha and the premultiplied colour paints a solid bar.
  let source : Array[Byte] = Array::make(6 * 8, b'\x00')
  for index in 0..<24 {
    source[index] = b'\xff'
  }
  @native_text.NativeRasterGlyph::new(
    width=6,
    height=8,
    bearing_x=0,
    // Providers report a negative bearing for ink above the baseline, the same
    // convention the CoreText provider's own tests pin.
    bearing_y=-8,
    format=@native_text.NativeRasterGlyphFormat::AlphaMask,
    pixels=Bytes::from_array(source),
  )
}

///|
fn metal_test_layout() -> @native_text.NativeTextLayout {
  @native_text.NativeTextLayout::new(
    size=@core.Size::new(width=6.0, height=8.0),
    baseline=8.0,
    glyphs=[
      @native_text.NativeGlyphPlacement::new(
        key=@native_text.native_platform_glyph_key(
          cache_key="metal-test-glyph",
          payload=Bytes::make(0, 0),
        ),
        x=0.0,
      ),
    ],
  )
}

///|
fn metal_test_text_engine() -> NativeTextEngine {
  native_platform_text_engine(
    @native_text.NativePlatformTextProvider::new(
      id="metal-test-text",
      measure=_input => Some(metal_test_layout()),
      layout_run=(_run, _scale_factor) => Some(metal_test_layout()),
      raster_glyph=(_cache_key, _payload) => Some(metal_test_glyph_raster()),
    ),
  )
}

///|
fn metal_test_text_run() -> @core.DrawCommand {
  @core.DrawText(
    @core.TextRun::new(
      text="i",
      frame=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
      font=@core.FontSpec::new(),
      color=@core.Color::white(),
      align=@core.TextStart,
    ),
  )
}

///|
test "metal draws one glyph run through the text pipeline" {
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=[metal_test_text_run()],
    text_engine=metal_test_text_engine(),
  )
  // The synthetic glyph is a fully covered 6x8 mask at the run origin, so its
  // ink must land where the layout says and nowhere else in the frame.
  assert_true(metal_is_white(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_white(metal_proof_pixel(pixels, 5, 3, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 1, 6, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 7, 1, 8)))
}

///|
test "a run the engine cannot lay out is counted, not painted" {
  let pixels = metal_proof(width=8, height=8, commands=[metal_test_text_run()])
  for y in 0..<8 {
    for x in 0..<8 {
      assert_true(metal_is_black(metal_proof_pixel(pixels, x, y, 8)))
    }
  }
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands([metal_test_text_run()]),
    metal_test_metrics(),
    metal_noop_text(),
  )
  assert_eq(geometry.text_runs_dropped, 1)
  assert_eq(geometry.item_count, 0)
}

///|
test "a glyph the engine cannot rasterize is counted per glyph" {
  let cache = @native_text.NativeTextCache::new_with_engine(
    native_platform_text_engine(
      @native_text.NativePlatformTextProvider::new(
        id="metal-missing-glyph-text",
        measure=_input => Some(metal_test_layout()),
        layout_run=(_run, _scale_factor) => Some(metal_test_layout()),
        raster_glyph=(_cache_key, _payload) => None,
      ),
    ),
  )
  let atlas = new_metal_glyph_atlas()
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands([metal_test_text_run()]),
    metal_test_metrics(),
    MetalFrameContext::{
      cache,
      atlas,
      images: new_metal_image_cache(),
      image_source: @render.HostImageSource::unavailable(),
      context: 0UL,
      async_images: false,
      image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
      retained: new_metal_retained_cache(),
    },
  )
  assert_eq(geometry.text_dropped_glyphs, 1)
  assert_eq(atlas.missing_glyphs, 1)
  assert_eq(geometry.item_count, 0)
}

///|
test "atlas packing wraps shelves and reports a full page" {
  // Sized from the page side, not literal: this pins the packing contract, and
  // a hard-coded box would break the day the residency budget moves.
  let half = METAL_ATLAS_SIZE / 2
  let page = new_metal_atlas_page()
  let first = place_metal_glyph_on_page(page, half, 40)
  let second = place_metal_glyph_on_page(page, half, 40)
  assert_eq(first, Some((0, 0)))
  // The shelf steps by the tallest glyph plus the trailing padding.
  assert_eq(second, Some((0, 40 + METAL_ATLAS_PADDING)))
  match place_metal_glyph_on_page(page, METAL_ATLAS_SIZE, 8) {
    None => ()
    Some(_) => fail("a glyph wider than the atlas must report no room")
  }
}

///|
fn metal_test_engine_for(
  raster : @native_text.NativeRasterGlyph,
) -> NativeTextEngine {
  native_platform_text_engine(
    @native_text.NativePlatformTextProvider::new(
      id="metal-test-text",
      measure=_input => Some(metal_test_layout()),
      layout_run=(_run, _scale_factor) => Some(metal_test_layout()),
      raster_glyph=(_cache_key, _payload) => Some(raster),
    ),
  )
}

///|
fn metal_test_run_coloured(color : @core.Color) -> @core.DrawCommand {
  @core.DrawText(
    @core.TextRun::new(
      text="i",
      frame=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
      font=@core.FontSpec::new(),
      color~,
      align=@core.TextStart,
    ),
  )
}

///|
fn metal_colour_glyph_raster() -> @native_text.NativeRasterGlyph {
  // The coverage fixture's exact footprint in the colour format CoreText hands
  // back for a bitmap emoji, and green rather than white: a run colour that
  // leaked into the glyph could not hide inside a white mask.
  let source : Array[Byte] = Array::make(6 * 8 * 4, b'\x00')
  for index in 0..<24 {
    source[index * 4 + 1] = b'\xff'
    source[index * 4 + 3] = b'\xff'
  }
  @native_text.NativeRasterGlyph::new(
    width=6,
    height=8,
    bearing_x=0,
    bearing_y=-8,
    format=@native_text.NativeRasterGlyphFormat::ColorRgba,
    pixels=Bytes::from_array(source),
  )
}

///|
test "a colour glyph paints its own pixels, not the run colour" {
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=[metal_test_run_coloured(@core.Color::rgba(r=1.0, g=0.0, b=0.0))],
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  assert_true(metal_is_green(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_green(metal_proof_pixel(pixels, 5, 3, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 1, 6, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 7, 1, 8)))
}

///|
test "the same footprint as a coverage mask takes the run colour" {
  // The pair above is what makes both non-vacuous: one identical glyph box, the
  // only difference being the raster format, painted in opposite colours.
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=[metal_test_run_coloured(@core.Color::rgba(r=1.0, g=0.0, b=0.0))],
    text_engine=metal_test_engine_for(metal_test_glyph_raster()),
  )
  assert_true(metal_is_red(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 5, 3, 8)))
}

///|
fn metal_shelf_glyph_raster() -> @native_text.NativeRasterGlyph {
  // 500x500 with the top half covered. Four of these exactly fill one 1024
  // atlas (two per shelf, two shelves: 2*(500+1) fits, a third shelf would put
  // next_y at 1002 and 1002+500 past the side), so the fifth request is a
  // residency test rather than a size accident.
  let source : Array[Byte] = Array::make(500 * 500, b'\x00')
  for index in 0..<(250 * 500) {
    source[index] = b'\xff'
  }
  @native_text.NativeRasterGlyph::new(
    width=500,
    height=500,
    bearing_x=0,
    bearing_y=-500,
    format=@native_text.NativeRasterGlyphFormat::AlphaMask,
    pixels=Bytes::from_array(source),
  )
}

///|
fn metal_shelf_layout(text : String) -> @native_text.NativeTextLayout {
  @native_text.NativeTextLayout::new(
    size=@core.Size::new(width=500.0, height=500.0),
    baseline=500.0,
    glyphs=[
      @native_text.NativeGlyphPlacement::new(
        key=@native_text.native_platform_glyph_key(
          cache_key="metal-shelf-\{text}",
          payload=Bytes::make(0, 0),
        ),
        x=0.0,
      ),
    ],
  )
}

///|
fn metal_shelf_text_engine() -> NativeTextEngine {
  native_platform_text_engine(
    @native_text.NativePlatformTextProvider::new(
      id="metal-shelf-text",
      measure=_input => Some(metal_shelf_layout("")),
      layout_run=(run, _scale_factor) => Some(metal_shelf_layout(run.text)),
      raster_glyph=(_cache_key, _payload) => Some(metal_shelf_glyph_raster()),
    ),
  )
}

///|
fn metal_shelf_run(text : String) -> @core.DrawCommand {
  @core.DrawText(
    @core.TextRun::new(
      text~,
      frame=@core.Rect::new(x=0.0, y=0.0, width=500.0, height=500.0),
      font=@core.FontSpec::new(),
      color=@core.Color::white(),
      align=@core.TextStart,
    ),
  )
}

///|
fn metal_shelf_metrics() -> @core.SurfaceMetrics {
  let size = @core.Size::new(width=600.0, height=600.0)
  @core.SurfaceMetrics::new(
    logical_size=size,
    physical_size=size,
    scale_factor=1.0,
  )
}

///|

///|
fn metal_shelf_frame(atlas : MetalGlyphAtlas) -> MetalFrameContext {
  MetalFrameContext::{
    cache: @native_text.NativeTextCache::new_with_engine(
      metal_shelf_text_engine(),
    ),
    atlas,
    images: new_metal_image_cache(),
    image_source: @render.HostImageSource::unavailable(),
    context: 0UL,
    async_images: false,
    image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
    retained: new_metal_retained_cache(),
  }
}

///|
test "a frame denser than one page grows the atlas instead of dropping" {
  // Four 500x500 boxes exactly fill a page, so the fifth is the case the single
  // atlas could not serve at all: one frame whose own glyph set outruns a page.
  // It used to be repacked into the same shortfall and lose that glyph every
  // frame.
  let atlas = new_metal_glyph_atlas()
  let first = build_metal_geometry(
    @render_common.lower_draw_commands([
      metal_shelf_run("a"),
      metal_shelf_run("b"),
      metal_shelf_run("c"),
      metal_shelf_run("d"),
    ]),
    metal_shelf_metrics(),
    metal_shelf_frame(atlas),
  )
  assert_eq(first.item_count, 4)
  assert_eq(first.text_dropped_glyphs, 0)
  assert_eq(metal_glyph_atlas_page_count(atlas), 1)
  // A fifth glyph the atlas has no room for on its last page.
  let second = build_metal_geometry(
    @render_common.lower_draw_commands([metal_shelf_run("e")]),
    metal_shelf_metrics(),
    metal_shelf_frame(atlas),
  )
  assert_eq(second.item_count, 1)
  assert_eq(second.text_dropped_glyphs, 0)
  assert_eq(metal_glyph_atlas_page_count(atlas), 2)
  assert_eq(atlas.resets, 0)
  assert_eq(atlas.placements.length(), 5)
  match atlas.placements.get("metal-shelf-e") {
    Some(placement) => assert_eq(placement.page, 1)
    None => fail("the glyph that overflowed page 0 was never placed")
  }
}

///|
test "a frame whose text outlives the atlas is repacked, not dropped" {
  // Every page at 500x500 boxes, which is the frame no page set can hold. Before
  // the residency policy existed this run was dropped for the rest of the
  // session, because nothing ever emptied the atlas; scrolling a long document
  // lost its text one glyph at a time and kept losing it.
  let atlas = new_metal_glyph_atlas()
  let frame = metal_shelf_frame(atlas)
  let cap_boxes = METAL_ATLAS_MAX_PAGES * 4
  let runs : Array[@core.DrawCommand] = []
  for index in 0..<cap_boxes {
    runs.push(metal_shelf_run("fill-\{index}"))
  }
  let filled = build_metal_geometry(
    @render_common.lower_draw_commands(runs),
    metal_shelf_metrics(),
    frame,
  )
  assert_eq(filled.item_count, cap_boxes)
  assert_eq(filled.text_dropped_glyphs, 0)
  assert_eq(metal_glyph_atlas_page_count(atlas), METAL_ATLAS_MAX_PAGES)
  assert_eq(atlas.resets, 0)
  let overflow = build_metal_geometry(
    @render_common.lower_draw_commands([metal_shelf_run("overflow")]),
    metal_shelf_metrics(),
    frame,
  )
  assert_eq(overflow.item_count, 1)
  assert_eq(overflow.text_dropped_glyphs, 0)
  assert_eq(atlas.resets, 1)
  // The repacked atlas holds this frame's working set only, which is the point:
  // the glyphs the next frame will not draw are not paying rent.
  assert_eq(atlas.placements.length(), 1)
  assert_eq(metal_glyph_atlas_page_count(atlas), 1)
}

///|
test "a cleared atlas places at the origin again" {
  let side = METAL_ATLAS_SIZE / 2
  let atlas = new_metal_glyph_atlas()
  ignore(place_metal_glyph(atlas, side, side))
  ignore(place_metal_glyph(atlas, side, side))
  assert_eq(metal_glyph_atlas_page_count(atlas), 2)
  clear_metal_glyph_atlas(atlas)
  match place_metal_glyph(atlas, side, side) {
    Some((0, 0, 0)) => ()
    _ => fail("a cleared atlas must place at the origin of page 0 again")
  }
  assert_true(metal_glyph_atlas_page_dirty(atlas, 0))
  // Clearing reuses page 0's buffer rather than reallocating it, so the bytes the
  // next frame reads are the same array it read before.
  assert_eq(
    metal_glyph_atlas_page_bytes(atlas, 0).length(),
    METAL_ATLAS_SIZE * METAL_ATLAS_SIZE * 4,
  )
}

///|
test "the atlas holds a retina page's distinct glyph boxes" {
  // 28 = a 14pt run at device scale 2.0, the normal Mac case for body text.
  // Measured through the real CoreText provider (`docs/plans/active/
  // no-third-party-gpu-route.md`, L3c): the 512 atlas placed only ~200 distinct
  // hanzi at that size, so a dense Chinese page dropped the rest of its own
  // glyphs on every frame; the 1024 atlas places ~818 of them. The floor sits
  // under the real number and well above the old one, so shrinking the residency
  // budget fails here rather than showing up as missing text.
  let page = new_metal_atlas_page()
  let mut placed = 0
  while place_metal_glyph_on_page(page, 28, 28) != None {
    placed += 1
  }
  assert_true(
    placed >= 700,
    msg="a \{METAL_ATLAS_SIZE}x\{METAL_ATLAS_SIZE} page only fit \{placed} distinct 28x28 glyph boxes",
  )
  // The page set is what a single frame may actually spend, so the same floor
  // scales with the cap: growth is the answer to a frame denser than a page.
  let atlas = new_metal_glyph_atlas()
  let mut across_pages = 0
  while place_metal_glyph(atlas, 28, 28) != None {
    across_pages += 1
  }
  assert_eq(metal_glyph_atlas_page_count(atlas), METAL_ATLAS_MAX_PAGES)
  assert_true(
    across_pages >= placed * METAL_ATLAS_MAX_PAGES,
    msg="the page set fit \{across_pages} boxes, under \{placed} per page x \{METAL_ATLAS_MAX_PAGES}",
  )
}

///|
fn metal_page_glyph_raster(shift : Int32) -> @native_text.NativeRasterGlyph {
  // A 512x512 box — one per page, so two of them never share a texture — with a
  // 100x100 square of ink `shift` pixels in from its origin. Two pages holding
  // different shifts cannot be mistaken for each other, which is what makes the
  // device proof below non-vacuous: a host that binds the wrong page paints the
  // square where the other glyph's ink is.
  let side = 512
  let source : Array[Byte] = Array::make(side * side, b'\x00')
  for row in 0..<100 {
    for column in 0..<100 {
      source[(row + shift) * side + column + shift] = b'\xff'
    }
  }
  @native_text.NativeRasterGlyph::new(
    width=side,
    height=side,
    bearing_x=0,
    bearing_y=-512,
    format=@native_text.NativeRasterGlyphFormat::AlphaMask,
    pixels=Bytes::from_array(source),
  )
}

///|
fn metal_page_layout() -> @native_text.NativeTextLayout {
  @native_text.NativeTextLayout::new(
    size=@core.Size::new(width=1024.0, height=512.0),
    baseline=512.0,
    glyphs=[
      @native_text.NativeGlyphPlacement::new(
        key=@native_text.native_platform_glyph_key(
          cache_key="metal-page-a",
          payload=Bytes::make(0, 0),
        ),
        x=0.0,
      ),
      @native_text.NativeGlyphPlacement::new(
        key=@native_text.native_platform_glyph_key(
          cache_key="metal-page-b",
          payload=Bytes::make(0, 0),
        ),
        x=512.0,
      ),
    ],
  )
}

///|
fn metal_page_text_engine() -> NativeTextEngine {
  native_platform_text_engine(
    @native_text.NativePlatformTextProvider::new(
      id="metal-page-text",
      measure=_input => Some(metal_page_layout()),
      layout_run=(_run, _scale_factor) => Some(metal_page_layout()),
      raster_glyph=(cache_key, _payload) => {
        Some(
          metal_page_glyph_raster(
            if cache_key == "metal-page-a" {
              80
            } else {
              160
            },
          ),
        )
      },
    ),
  )
}

///|
fn metal_page_run() -> @core.DrawCommand {
  @core.DrawText(
    @core.TextRun::new(
      text="ab",
      frame=@core.Rect::new(x=0.0, y=0.0, width=1024.0, height=512.0),
      font=@core.FontSpec::new(),
      color=@core.Color::white(),
      align=@core.TextStart,
    ),
  )
}

///|
test "a glyph run that spills onto a second page draws both pages" {
  // One run, two boxes that cannot share a page: it becomes two text items whose
  // texture keys name different pages, and the host has to upload and bind each.
  // The checks are paired — ink where this page's square is, clear where the
  // other page's square would have put it.
  let pixels = metal_proof(
    width=1024,
    height=512,
    commands=[metal_page_run()],
    text_engine=metal_page_text_engine(),
  )
  assert_true(metal_is_white(metal_proof_pixel(pixels, 100, 100, 1024)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 300, 300, 1024)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 612, 100, 1024)))
  assert_true(metal_is_white(metal_proof_pixel(pixels, 700, 200, 1024)))
  let atlas = new_metal_glyph_atlas()
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands([metal_page_run()]),
    @core.SurfaceMetrics::new(
      logical_size=@core.Size::new(width=1024.0, height=512.0),
      physical_size=@core.Size::new(width=1024.0, height=512.0),
      scale_factor=1.0,
    ),
    MetalFrameContext::{
      cache: @native_text.NativeTextCache::new_with_engine(
        metal_page_text_engine(),
      ),
      atlas,
      images: new_metal_image_cache(),
      image_source: @render.HostImageSource::unavailable(),
      context: 0UL,
      async_images: false,
      image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
      retained: new_metal_retained_cache(),
    },
  )
  assert_eq(geometry.item_count, 2)
  assert_eq(geometry.text_dropped_glyphs, 0)
  assert_eq(metal_glyph_atlas_page_count(atlas), 2)
  assert_eq(atlas.resets, 0)
}

///|
test "a colour glyph keeps its pixels through a layer composite" {
  // The half the `EmojiText` row named as missing. A group renders into its own
  // offscreen target and returns as one composite quad, so a route that reached
  // for the colour branch only on the main pass — or re-tinted inside a group —
  // would put red where green is due.
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=metal_layer(@core.LayerSpec::new(), [
      metal_test_run_coloured(@core.Color::rgba(r=1.0, g=0.0, b=0.0)),
    ]),
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  assert_true(metal_is_green(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_green(metal_proof_pixel(pixels, 5, 3, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 1, 6, 8)))
}

///|
test "a filter group rewrites a colour glyph as colour, not as coverage" {
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=metal_filter(@core.FilterEffect::Brightness(0.5), [
      metal_test_run_coloured(@core.Color::rgba(r=1.0, g=0.0, b=0.0)),
    ]),
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  let pixel = metal_proof_pixel(pixels, 1, 1, 8)
  // Half brightness over a pure-green glyph halves the green and leaves red low;
  // a route that had painted the glyph as a mask tinted by the run colour would
  // halve a *red* here.
  assert_true(
    pixel.1 > 90 && pixel.1 < 190,
    msg="green channel \{pixel.1} is not a halved glyph green",
  )
  assert_true(pixel.0 < 60, msg="red channel \{pixel.0} leaked the run colour")
  assert_true(pixel.3 > 240)
}

///|
test "a masked layer clips its colour glyph as well as its pixels" {
  // Nothing had put text inside a masked group: the mask tests all used fills.
  // A route that masked the composite but let the group's own draws escape, or
  // that dropped the group's text draw range, fails one of these two halves.
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=metal_layer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RectMask(metal_rect(0.0, 0.0, 4.0, height=4.0)),
      ),
      [metal_test_run_coloured(@core.Color::rgba(r=1.0, g=0.0, b=0.0))],
    ),
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  assert_true(metal_is_green(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 5, 3, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 6, 6, 8)))
}

///|
/// The rounded half of the row's missing scope, and the route's first device probe
/// of a `LayerMask::RoundedMask` carried by a `PushLayer` — until now the rounded
/// mask SDF had only ever been reached from inside `PushRoundedClip`.
///
/// The pair is the point, so a test that only checked the glyph could not pass by
/// dropping the mask: `(3, 3)` is the deepest inside the arc and inked, `(0, 0)` is
/// inked by the same fixture but outside the arc. A composite that ignored the mask
/// paints green at both; a mask that ate the whole group paints black at both.
test "a rounded-mask group rounds a colour glyph as well as tinting it" {
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=metal_layer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RoundedMask(
          @core.RoundedRect::new(
            rect=metal_rect(0.0, 0.0, 8.0, height=8.0),
            radius=3.0,
          ),
        ),
      ),
      [metal_test_run_coloured(@core.Color::rgba(r=1.0, g=0.0, b=0.0))],
    ),
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  assert_true(metal_is_green(metal_proof_pixel(pixels, 3, 3, 8)))
  assert_true(metal_is_green(metal_proof_pixel(pixels, 2, 2, 8)))
  assert_true(
    metal_is_black(metal_proof_pixel(pixels, 0, 0, 8)),
    msg="the corner the radius should clear is inked",
  )
  let report = metal_frame_report(
    commands=metal_layer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RoundedMask(
          @core.RoundedRect::new(
            rect=metal_rect(0.0, 0.0, 8.0, height=8.0),
            radius=3.0,
          ),
        ),
      ),
      [metal_test_run_coloured(@core.Color::rgba(r=1.0, g=0.0, b=0.0))],
    ),
    width=8.0,
    height=8.0,
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  assert_eq(report.layers, 1)
  assert_eq(report.text_dropped_glyphs, 0)
}

///|
/// Two composites between the glyph and the screen. Each group renders into its own
/// target and returns as one full-bleed quad, so a colour glyph that survived one
/// composite but got repainted by the run colour at the second would land red here.
test "two nested groups carry a colour glyph's own pixels" {
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0)
  let commands = metal_layer(
    @core.LayerSpec::new(),
    metal_layer(@core.LayerSpec::new(), [metal_test_run_coloured(red)]),
  )
  let pixels = metal_proof(
    width=8,
    height=8,
    commands~,
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  assert_true(metal_is_green(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_green(metal_proof_pixel(pixels, 5, 3, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 1, 6, 8)))
  let report = metal_frame_report(
    commands~,
    width=8.0,
    height=8.0,
    text_engine=metal_test_engine_for(metal_colour_glyph_raster()),
  )
  assert_eq(report.layers, 2)
  assert_eq(report.text_dropped_glyphs, 0)
}
