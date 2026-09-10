///|
/// Read renderer-neutral image source bytes for a native host.
///
/// Registered scheme providers are consulted first — that is how a host adds
/// schemes it can reach beyond the filesystem, such as `https:` through a
/// platform network stack. `data:` URIs are left to the renderer decoder, and
/// anything else falls back to a local file read.
pub fn filesystem_image_source() -> @render.HostImageSource {
  @render.HostImageSource::new(read=source => {
    if source.has_prefix("data:") {
      return None
    }
    match @render_common.image_source_provider_read(source) {
      Some(bytes) => Some(bytes)
      None =>
        Some(@fs.read_file_to_bytes(source)) catch {
          _ => None
        }
    }
  })
}
