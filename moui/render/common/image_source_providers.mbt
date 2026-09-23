///|
/// A byte reader claimed by one URL prefix.
priv struct ImageSourceProvider {
  prefix : String
  read : (String) -> Bytes?
}

///|
/// Scheme-keyed byte-source plugin registry.
///
/// `HostImageSource` is a single closure supplied by the platform backend, so
/// by default it can only serve the schemes that backend owns — local files
/// and `data:` URIs on native hosts. A host that can also reach other schemes
/// (a platform network stack for `https:`, a virtual asset mount, an archive)
/// registers a reader here, and the backend's composed source consults these
/// providers before falling back to its own logic.
///
/// Providers are matched by URL prefix in registration order. An empty
/// registry returns `None`, so a backend that ignores this registry keeps its
/// original behaviour.
let image_source_providers : Ref[Array[ImageSourceProvider]] = Ref([])

///|
/// Register a reader for every source beginning with `prefix`.
pub fn image_source_provider_register(
  prefix~ : String,
  read~ : (String) -> Bytes?,
) -> Unit {
  image_source_providers.val = image_source_providers.val + [{ prefix, read, }]
}

///|
/// Drop every registered reader, restoring the untouched fallback path.
pub fn image_source_provider_clear() -> Unit {
  image_source_providers.val = []
}

///|
/// Number of currently registered readers, for diagnostics and tests.
pub fn image_source_provider_count() -> Int {
  image_source_providers.val.length()
}

///|
/// Read `source` through the registered providers in registration order.
/// Returns `None` when no prefix matches, or when the matching reader cannot
/// produce bytes, leaving the caller free to fall back.
pub fn image_source_provider_read(source : String) -> Bytes? {
  for provider in image_source_providers.val {
    if source.has_prefix(provider.prefix) {
      match (provider.read)(source) {
        Some(bytes) => return Some(bytes)
        None => ()
      }
    }
  }
  None
}
