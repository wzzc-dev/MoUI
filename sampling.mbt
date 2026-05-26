///|
/// Cubic resampler coefficients for high-quality image scaling.
pub(all) struct CubicResampler {
  b : Scalar
  c : Scalar
} derive(Debug, Eq)

///|
pub fn CubicResampler::new(b : Scalar, c : Scalar) -> CubicResampler {
  { b, c }
}

///|
/// Mitchell-Netravali cubic resampler.
pub fn CubicResampler::mitchell() -> CubicResampler {
  { b: 1.0 / 3.0, c: 1.0 / 3.0 }
}

///|
/// Catmull-Rom cubic resampler.
pub fn CubicResampler::catmull_rom() -> CubicResampler {
  { b: 0.0, c: 0.5 }
}

///|
/// Image sampling options modeled after Skia's `SkSamplingOptions`.
pub(all) struct SamplingOptions {
  filter : FilterMode
  mipmap : MipmapMode
  cubic : CubicResampler?
} derive(Debug, Eq)

///|
pub fn SamplingOptions::new(
  filter? : FilterMode = Nearest,
  mipmap? : MipmapMode = None,
) -> SamplingOptions {
  { filter, mipmap, cubic: None }
}

///|
pub fn SamplingOptions::from_cubic(cubic : CubicResampler) -> SamplingOptions {
  { filter: Linear, mipmap: None, cubic: Some(cubic) }
}

///|
pub fn SamplingOptions::linear() -> SamplingOptions {
  SamplingOptions::new(filter=Linear)
}

///|
pub fn SamplingOptions::mitchell() -> SamplingOptions {
  SamplingOptions::from_cubic(CubicResampler::mitchell())
}

///|
pub fn SamplingOptions::catmull_rom() -> SamplingOptions {
  SamplingOptions::from_cubic(CubicResampler::catmull_rom())
}

///|
pub impl Default for SamplingOptions with default() {
  SamplingOptions::new()
}

///|
pub fn SamplingOptions::uses_cubic(self : SamplingOptions) -> Bool {
  self.cubic is Some(_)
}

///|
pub fn SamplingOptions::filter_ordinal(self : SamplingOptions) -> Int {
  self.filter.to_skia_ordinal()
}

///|
pub fn SamplingOptions::mipmap_ordinal(self : SamplingOptions) -> Int {
  self.mipmap.to_skia_ordinal()
}

///|
pub fn SamplingOptions::cubic_b(self : SamplingOptions) -> Scalar {
  match self.cubic {
    None => 0.0
    Some(cubic) => cubic.b
  }
}

///|
pub fn SamplingOptions::cubic_c(self : SamplingOptions) -> Scalar {
  match self.cubic {
    None => 0.0
    Some(cubic) => cubic.c
  }
}
