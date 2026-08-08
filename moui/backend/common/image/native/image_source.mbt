///|
/// Read renderer-neutral image source bytes for a native host. Data URIs are
/// left to the renderer decoder; this helper only performs filesystem I/O.
pub fn filesystem_image_source() -> @render.HostImageSource {
  @render.HostImageSource::new(read=source => {
    if source.has_prefix("data:") {
      None
    } else {
      Some(@fs.read_file_to_bytes(source)) catch {
        _ => None
      }
    }
  })
}
