///|
/// Value-layer request for shaping a text run with stable cache identity and
/// explicit font/fallback dependencies.
pub(all) struct TextShapingDescriptor {
  run : TextRunDescriptor
  font_key : RendererResourceKey
  width : Float
} derive(Debug, Eq)

///|
pub fn TextShapingDescriptor::new(
  run? : TextRunDescriptor = TextRunDescriptor::new(),
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  width? : Float = 1000000000.0,
) -> TextShapingDescriptor {
  { run, font_key, width: normalized_text_measurement_width(width) }
}

///|
pub fn TextShapingDescriptor::with_run(
  self : TextShapingDescriptor,
  run : TextRunDescriptor,
) -> TextShapingDescriptor {
  { ..self, run, }
}

///|
pub fn TextShapingDescriptor::with_font_key(
  self : TextShapingDescriptor,
  font_key : RendererResourceKey,
) -> TextShapingDescriptor {
  { ..self, font_key, }
}

///|
pub fn TextShapingDescriptor::with_width(
  self : TextShapingDescriptor,
  width : Float,
) -> TextShapingDescriptor {
  { ..self, width: normalized_text_measurement_width(width) }
}

///|
pub fn TextShapingDescriptor::measurement_descriptor(
  self : TextShapingDescriptor,
) -> TextMeasurementDescriptor {
  TextMeasurementDescriptor::new(
    run=self.run,
    font_key=self.font_key,
    width=self.width,
    measure_bounds=false,
    shape=true,
  )
}

///|
pub fn TextShapingDescriptor::resource_key(
  self : TextShapingDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(
    b"skia_mbt:text-shaping:v1" +
    text_run_cache_bytes(self.run.resource_key(text, font_key=self.font_key).id) +
    self.width.to_be_bytes(),
  )
}

///|
pub fn TextShapingDescriptor::resource_descriptor(
  self : TextShapingDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_key(text).id
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn TextShapingDescriptor::resource_plan(
  self : TextShapingDescriptor,
  text : Bytes,
  shaping_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(self.resource_descriptor(text, byte_size=shaping_byte_size))
  for
    descriptor in self.run.resource_plan(
      text,
      font_key=self.font_key,
      text_byte_size~,
      font_byte_size~,
      fallback_byte_size~,
    ).descriptors {
    descriptors.push(descriptor)
  }
  RendererResourcePlan::new(descriptors)
}

///|
fn normalized_shaped_text_advance(advance : Point) -> Point {
  if advance.is_finite() {
    advance
  } else {
    Point::zero()
  }
}

///|
/// Value-layer metadata for a native shaped text run result.
pub(all) struct ShapedTextRunDescriptor {
  shaping : TextShapingDescriptor
  glyph_count : Int
  cluster_count : Int
  advance : Point
} derive(Debug, Eq)

///|
pub fn ShapedTextRunDescriptor::new(
  shaping? : TextShapingDescriptor = TextShapingDescriptor::new(),
  glyph_count? : Int = 0,
  cluster_count? : Int = 0,
  advance? : Point = Point::zero(),
) -> ShapedTextRunDescriptor {
  {
    shaping,
    glyph_count: Int::max(0, glyph_count),
    cluster_count: Int::max(0, cluster_count),
    advance: normalized_shaped_text_advance(advance),
  }
}

///|
pub fn TextShapingDescriptor::shaped_run_descriptor(
  self : TextShapingDescriptor,
  glyph_count? : Int = 0,
  cluster_count? : Int = 0,
  advance? : Point = Point::zero(),
) -> ShapedTextRunDescriptor {
  ShapedTextRunDescriptor::new(
    shaping=self,
    glyph_count~,
    cluster_count~,
    advance~,
  )
}

///|
pub fn ShapedTextRunDescriptor::is_valid(
  self : ShapedTextRunDescriptor,
) -> Bool {
  self.glyph_count > 0 && self.cluster_count >= 0 && self.advance.is_finite()
}

///|
fn ShapedTextRunDescriptor::resource_id(
  self : ShapedTextRunDescriptor,
  text : Bytes,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    b"skia_mbt:shaped-text-run:v1" +
    text_run_cache_bytes(self.shaping.resource_key(text).id) +
    text_run_cache_u64(self.glyph_count) +
    text_run_cache_u64(self.cluster_count) +
    self.advance.x.to_be_bytes() +
    self.advance.y.to_be_bytes()
  }
}

///|
pub fn ShapedTextRunDescriptor::resource_key(
  self : ShapedTextRunDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(self.resource_id(text))
}

///|
pub fn ShapedTextRunDescriptor::resource_descriptor(
  self : ShapedTextRunDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id(text)
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn ShapedTextRunDescriptor::resource_plan(
  self : ShapedTextRunDescriptor,
  text : Bytes,
  shaped_byte_size? : Int64 = -1L,
  shaping_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(self.resource_descriptor(text, byte_size=shaped_byte_size))
  if self.is_valid() {
    for
      descriptor in self.shaping.resource_plan(
        text,
        shaping_byte_size~,
        text_byte_size~,
        font_byte_size~,
        fallback_byte_size~,
      ).descriptors {
      descriptors.push(descriptor)
    }
  }
  RendererResourcePlan::new(descriptors)
}

///|
fn normalized_shaped_glyph_run_count(
  glyph_ids : Array[Int],
  positions : Array[Point],
  clusters : Array[Int],
) -> Int {
  let mut count = glyph_ids.length()
  if positions.length() < count {
    count = positions.length()
  }
  if clusters.length() < count {
    count = clusters.length()
  }
  count
}

///|
fn normalized_shaped_glyph_ids(
  glyph_ids : Array[Int],
  count : Int,
) -> Array[Int] {
  let result : Array[Int] = Array::new(capacity=count)
  for index in 0..<count {
    result.push(Int::max(0, glyph_ids[index]))
  }
  result
}

///|
fn normalized_shaped_glyph_positions(
  positions : Array[Point],
  count : Int,
) -> Array[Point] {
  let result : Array[Point] = Array::new(capacity=count)
  for index in 0..<count {
    let position = positions[index]
    result.push(if position.is_finite() { position } else { Point::zero() })
  }
  result
}

///|
fn normalized_shaped_glyph_clusters(
  clusters : Array[Int],
  count : Int,
) -> Array[Int] {
  let result : Array[Int] = Array::new(capacity=count)
  for index in 0..<count {
    result.push(Int::max(0, clusters[index]))
  }
  result
}

///|
fn normalized_shaped_glyph_text_run(
  shaped_run : ShapedTextRunDescriptor,
  glyph_count : Int,
  cluster_count : Int,
) -> ShapedTextRunDescriptor {
  ShapedTextRunDescriptor::new(
    shaping=shaped_run.shaping,
    glyph_count~,
    cluster_count~,
    advance=shaped_run.advance,
  )
}

///|
/// Detailed glyph IDs, positions, and clusters for a shaped text run.
pub(all) struct ShapedGlyphRunDescriptor {
  shaped_run : ShapedTextRunDescriptor
  glyph_ids : Array[Int]
  positions : Array[Point]
  clusters : Array[Int]
} derive(Debug, Eq)

///|
pub fn ShapedGlyphRunDescriptor::new(
  shaped_run? : ShapedTextRunDescriptor = ShapedTextRunDescriptor::new(),
  glyph_ids? : Array[Int] = [],
  positions? : Array[Point] = [],
  clusters? : Array[Int] = [],
) -> ShapedGlyphRunDescriptor {
  let count = normalized_shaped_glyph_run_count(glyph_ids, positions, clusters)
  let glyph_ids = normalized_shaped_glyph_ids(glyph_ids, count)
  let positions = normalized_shaped_glyph_positions(positions, count)
  let clusters = normalized_shaped_glyph_clusters(clusters, count)
  {
    shaped_run: normalized_shaped_glyph_text_run(
      shaped_run,
      count,
      clusters.length(),
    ),
    glyph_ids,
    positions,
    clusters,
  }
}

///|
pub fn ShapedTextRunDescriptor::glyph_run_descriptor(
  self : ShapedTextRunDescriptor,
  glyph_ids? : Array[Int] = [],
  positions? : Array[Point] = [],
  clusters? : Array[Int] = [],
) -> ShapedGlyphRunDescriptor {
  ShapedGlyphRunDescriptor::new(
    shaped_run=self,
    glyph_ids~,
    positions~,
    clusters~,
  )
}

///|
pub fn ShapedGlyphRunDescriptor::glyph_count(
  self : ShapedGlyphRunDescriptor,
) -> Int {
  self.glyph_ids.length()
}

///|
pub fn ShapedGlyphRunDescriptor::cluster_count(
  self : ShapedGlyphRunDescriptor,
) -> Int {
  self.clusters.length()
}

///|
pub fn ShapedGlyphRunDescriptor::is_empty(
  self : ShapedGlyphRunDescriptor,
) -> Bool {
  self.glyph_ids.is_empty()
}

///|
pub fn ShapedGlyphRunDescriptor::is_valid(
  self : ShapedGlyphRunDescriptor,
) -> Bool {
  let glyph_count = self.glyph_count()
  let mut valid = self.shaped_run.is_valid() &&
    glyph_count > 0 &&
    self.positions.length() == glyph_count &&
    self.clusters.length() == glyph_count &&
    self.shaped_run.glyph_count == glyph_count &&
    self.shaped_run.cluster_count == self.cluster_count()
  for glyph_id in self.glyph_ids {
    if glyph_id < 0 {
      valid = false
    }
  }
  for position in self.positions {
    if !position.is_finite() {
      valid = false
    }
  }
  for cluster in self.clusters {
    if cluster < 0 {
      valid = false
    }
  }
  valid
}

///|
fn ShapedGlyphRunDescriptor::resource_id(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    let mut id = b"skia_mbt:shaped-glyph-run:v1" +
      text_run_cache_bytes(self.shaped_run.resource_key(text).id) +
      text_run_cache_u64(self.glyph_count())
    for glyph_id in self.glyph_ids {
      id = id + text_run_cache_u64(glyph_id)
    }
    for position in self.positions {
      id = id + position.x.to_be_bytes() + position.y.to_be_bytes()
    }
    for cluster in self.clusters {
      id = id + text_run_cache_u64(cluster)
    }
    id
  }
}

///|
pub fn ShapedGlyphRunDescriptor::resource_key(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(self.resource_id(text))
}

///|
pub fn ShapedGlyphRunDescriptor::resource_descriptor(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id(text)
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn ShapedGlyphRunDescriptor::resource_plan(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
  glyph_run_byte_size? : Int64 = -1L,
  shaped_byte_size? : Int64 = -1L,
  shaping_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(
    self.resource_descriptor(text, byte_size=glyph_run_byte_size),
  )
  if self.is_valid() {
    for
      descriptor in self.shaped_run.resource_plan(
        text,
        shaped_byte_size~,
        shaping_byte_size~,
        text_byte_size~,
        font_byte_size~,
        fallback_byte_size~,
      ).descriptors {
      descriptors.push(descriptor)
    }
  }
  RendererResourcePlan::new(descriptors)
}
