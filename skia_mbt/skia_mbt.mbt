///|
/// Skia uses single-precision scalar values for most geometry.
pub type Scalar = Float

///|
/// Project status for the current package.
///
/// The value-layer types are usable today. Native Skia object bindings are
/// introduced separately so their ownership and linker requirements stay
/// explicit.
pub fn binding_status() -> String {
  "value-layer"
}
