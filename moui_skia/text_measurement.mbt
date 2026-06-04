///|
fn normalized_text_measurement_width(width : Float) -> Float {
  if font_descriptor_scalar_is_finite(width) && width > 0.0 {
    width
  } else {
    1000000000.0
  }
}

///|
/// Value-layer request for measuring or shaping a text run with stable cache
/// identity and explicit font/fallback dependencies.
pub(all) struct TextMeasurementDescriptor {
  run : TextRunDescriptor
  font_key : RendererResourceKey
  width : Float
  measure_bounds : Bool
  shape : Bool
} derive(Debug, Eq)

///|
pub fn TextMeasurementDescriptor::new(
  run? : TextRunDescriptor = TextRunDescriptor::new(),
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  width? : Float = 1000000000.0,
  measure_bounds? : Bool = true,
  shape? : Bool = false,
) -> TextMeasurementDescriptor {
  {
    run,
    font_key,
    width: normalized_text_measurement_width(width),
    measure_bounds,
    shape,
  }
}

///|
pub fn TextMeasurementDescriptor::is_shaped(
  self : TextMeasurementDescriptor,
) -> Bool {
  self.shape
}

///|
pub fn TextMeasurementDescriptor::with_run(
  self : TextMeasurementDescriptor,
  run : TextRunDescriptor,
) -> TextMeasurementDescriptor {
  { ..self, run, }
}

///|
pub fn TextMeasurementDescriptor::with_font_key(
  self : TextMeasurementDescriptor,
  font_key : RendererResourceKey,
) -> TextMeasurementDescriptor {
  { ..self, font_key, }
}

///|
pub fn TextMeasurementDescriptor::with_width(
  self : TextMeasurementDescriptor,
  width : Float,
) -> TextMeasurementDescriptor {
  { ..self, width: normalized_text_measurement_width(width) }
}

///|
pub fn TextMeasurementDescriptor::with_measure_bounds(
  self : TextMeasurementDescriptor,
  measure_bounds : Bool,
) -> TextMeasurementDescriptor {
  { ..self, measure_bounds, }
}

///|
pub fn TextMeasurementDescriptor::with_shape(
  self : TextMeasurementDescriptor,
  shape : Bool,
) -> TextMeasurementDescriptor {
  { ..self, shape, }
}

///|
pub fn TextMeasurementDescriptor::resource_key(
  self : TextMeasurementDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(
    b"moui_skia:text-measurement:v1" +
    text_run_cache_bytes(self.run.resource_key(text, font_key=self.font_key).id) +
    self.width.to_be_bytes() +
    text_run_cache_bytes(text_run_cache_bool(self.measure_bounds)) +
    text_run_cache_bytes(text_run_cache_bool(self.shape)),
  )
}

///|
pub fn TextMeasurementDescriptor::resource_descriptor(
  self : TextMeasurementDescriptor,
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
pub fn TextMeasurementDescriptor::resource_plan(
  self : TextMeasurementDescriptor,
  text : Bytes,
  measurement_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(
    self.resource_descriptor(text, byte_size=measurement_byte_size),
  )
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
fn normalized_measured_text_advance(advance : Float) -> Float {
  if font_descriptor_scalar_is_finite(advance) && advance >= 0.0 {
    advance
  } else {
    0.0
  }
}

///|
fn normalized_measured_text_bounds(bounds : Rect?) -> Rect? {
  match bounds {
    None => None
    Some(bounds) =>
      if bounds.is_finite() {
        Some(bounds.sorted())
      } else {
        None
      }
  }
}

///|
fn measured_text_bounds_cache_id(bounds : Rect?) -> Bytes {
  match bounds {
    None => b"none"
    Some(bounds) =>
      b"some" +
      bounds.left().to_be_bytes() +
      bounds.top().to_be_bytes() +
      bounds.right().to_be_bytes() +
      bounds.bottom().to_be_bytes()
  }
}

///|
/// Value-layer metadata for a native text measurement result.
pub(all) struct MeasuredTextRunDescriptor {
  measurement : TextMeasurementDescriptor
  advance : Float
  bounds : Rect?
} derive(Debug, Eq)

///|
pub fn MeasuredTextRunDescriptor::new(
  measurement? : TextMeasurementDescriptor = TextMeasurementDescriptor::new(),
  advance? : Float = 0.0,
  bounds? : Rect? = None,
) -> MeasuredTextRunDescriptor {
  {
    measurement,
    advance: normalized_measured_text_advance(advance),
    bounds: normalized_measured_text_bounds(bounds),
  }
}

///|
pub fn TextMeasurementDescriptor::measured_run_descriptor(
  self : TextMeasurementDescriptor,
  advance? : Float = 0.0,
  bounds? : Rect? = None,
) -> MeasuredTextRunDescriptor {
  MeasuredTextRunDescriptor::new(measurement=self, advance~, bounds~)
}

///|
pub fn MeasuredTextRunDescriptor::has_bounds(
  self : MeasuredTextRunDescriptor,
) -> Bool {
  self.bounds is Some(_)
}

///|
pub fn MeasuredTextRunDescriptor::is_valid(
  self : MeasuredTextRunDescriptor,
) -> Bool {
  let bounds_valid = match self.bounds {
    None => true
    Some(bounds) => bounds.is_finite() && bounds.is_sorted()
  }
  font_descriptor_scalar_is_finite(self.advance) &&
  self.advance >= 0.0 &&
  bounds_valid
}

///|
fn MeasuredTextRunDescriptor::resource_id(
  self : MeasuredTextRunDescriptor,
  text : Bytes,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    b"moui_skia:measured-text-run:v1" +
    text_run_cache_bytes(self.measurement.resource_key(text).id) +
    self.advance.to_be_bytes() +
    measured_text_bounds_cache_id(self.bounds)
  }
}

///|
pub fn MeasuredTextRunDescriptor::resource_key(
  self : MeasuredTextRunDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(self.resource_id(text))
}

///|
pub fn MeasuredTextRunDescriptor::resource_descriptor(
  self : MeasuredTextRunDescriptor,
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
pub fn MeasuredTextRunDescriptor::resource_plan(
  self : MeasuredTextRunDescriptor,
  text : Bytes,
  measured_byte_size? : Int64 = -1L,
  measurement_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(self.resource_descriptor(text, byte_size=measured_byte_size))
  if self.is_valid() {
    for
      descriptor in self.measurement.resource_plan(
        text,
        measurement_byte_size~,
        text_byte_size~,
        font_byte_size~,
        fallback_byte_size~,
      ).descriptors {
      descriptors.push(descriptor)
    }
  }
  RendererResourcePlan::new(descriptors)
}
