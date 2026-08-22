///|
/// Platform-neutral byte source injected by an application or service layer.
/// `moui_3d` never performs filesystem or network I/O itself.
pub(all) struct AssetByteSource {
  read_fn : (String) -> Bytes?
}

///|
pub fn AssetByteSource::new(read : (String) -> Bytes?) -> AssetByteSource {
  { read_fn: read }
}

///|
pub fn AssetByteSource::read(self : AssetByteSource, uri : String) -> Bytes? {
  (self.read_fn)(uri)
}

///|
pub(all) enum AssetLoadResult {
  Bytes(Bytes)
  Missing(String)
  Invalid(String)
} derive(Debug)

///|
/// Resolve an embedded asset directly or delegate URI lookup to the injected
/// source. This small helper is deterministic and easy to test.
pub fn load_asset(
  source : AssetByteSource,
  asset : TextureSource,
) -> AssetLoadResult {
  match asset {
    TextureSource::Embedded(bytes) => AssetLoadResult::Bytes(bytes)
    TextureSource::Uri(uri) =>
      match source.read(uri) {
        Some(bytes) => AssetLoadResult::Bytes(bytes)
        None => AssetLoadResult::Missing(uri)
      }
  }
}
