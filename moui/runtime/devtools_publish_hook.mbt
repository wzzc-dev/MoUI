// Dev-only DevTools sampling hook. The runtime owns the cadence; the
// composition root owns the publisher and its transport.

///|
const DEVTOOLS_SAMPLE_INTERVAL_MS : Double = 500.0

///|
fn RuntimeState::maybe_sample_devtools(self : RuntimeState) -> Unit {
  match self.devtools_sample_observer {
    Some(observer) =>
      if self.animfocus.now_ms - self.devtools_last_sample_ms >=
        DEVTOOLS_SAMPLE_INTERVAL_MS {
        self.devtools_last_sample_ms = self.animfocus.now_ms
        observer()
      }
    None => ()
  }
}

///|
/// Install or clear the dev-only DevTools sampler. The observer must not
/// dispatch input; it is called at a frame boundary after the clock advances.
pub fn AppRuntime::set_devtools_sample_observer(
  self : AppRuntime,
  observer : (() -> Unit)?,
) -> Unit {
  self.state.devtools_sample_observer = observer
}
