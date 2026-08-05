///|
/// Earliest native-work deadline reported by platform-view protocol handles.
pub fn platform_view_plugins_next_deadline(
  plugins : Array[@backend_host.PlatformViewPlugin],
) -> Int64? {
  let mut earliest : Int64? = None
  for plugin in plugins {
    match plugin.poll_native {
      Some(poll) =>
        match poll() {
          Some(deadline) =>
            match earliest {
              Some(current) =>
                if deadline < current {
                  earliest = Some(deadline)
                }
              None => earliest = Some(deadline)
            }
          None => ()
        }
      None => ()
    }
  }
  earliest
}
