///|
/// Dev-only DevTools publisher. The first transport is a single JSON document
/// written by the app at a debounced frame boundary; `moui inspect` and the
/// dev server read the same file. The protocol shape is transport-neutral.
pub struct DevtoolsPublisher {
  priv path : String
  priv snapshot : () -> @runtime.InspectorSnapshot?
  priv trace : () -> @devtools.DevtoolsTrace?
  priv diagnostics : () -> Array[@diagnostics.DiagnosticEvent]
}

///|
pub fn DevtoolsPublisher::new(
  path~ : String,
  snapshot~ : () -> @runtime.InspectorSnapshot?,
  trace~ : () -> @devtools.DevtoolsTrace?,
  diagnostics~ : () -> Array[@diagnostics.DiagnosticEvent],
) -> DevtoolsPublisher {
  { path, snapshot, trace, diagnostics, }
}

///|
pub fn DevtoolsPublisher::document(
  self : DevtoolsPublisher,
) -> @protocol.DevtoolsDocument? {
  let snapshot = match (self.snapshot)() {
    Some(value) => value
    None => return None
  }
  let report = @devtools.inspector_report(snapshot)
  let report_text = @devtools.inspector_report_text(snapshot)
  let trace = (self.trace)()
  let trace_text = match trace {
    Some(value) => Some(@devtools.trace_report_text(value))
    None => None
  }
  let trace_report = match trace {
    Some(value) => Some(value.report())
    None => None
  }
  Some(
    @protocol.DevtoolsDocument::new(
      snapshot=report,
      report_text~,
      trace=trace_report,
      trace_text~,
      diagnostics=(self.diagnostics)(),
    ),
  )
}

///|
pub fn DevtoolsPublisher::publish(self : DevtoolsPublisher) -> Unit {
  let document = match self.document() {
    Some(value) => value
    None => return
  }
  let text = document.to_json_string(indent=2) + "\n"
  @fs.write_bytes_to_file(self.path, @utf8.encode(text[:], bom=false)) catch {
    _ => ()
  }
}

///|
/// Path from `MOUI_DEVTOOLS_FILE`; `moui dev --inspect` sets it. A missing
/// path leaves production starts inert.
pub fn devtools_file_path() -> String? {
  match @env.get_env_var("MOUI_DEVTOOLS_FILE") {
    Some(path) => if path != "" { Some(path) } else { None }
    None => None
  }
}

///|
/// Install a publisher on a runtime. The observer is sampled by
/// `AppRuntime::advance_time` at the devtools cadence; the runtime itself
/// performs no file I/O.
pub fn install_devtools_publisher(
  runtime : @runtime.AppRuntime,
  path~ : String,
) -> Unit {
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(Some(runtime))
  let publisher = DevtoolsPublisher::new(
    path~,
    snapshot=() => {
      match runtime_ref.val {
        Some(value) => Some(value.inspector_snapshot())
        None => None
      }
    },
    trace=() => None,
    diagnostics=() => [],
  )
  runtime.set_devtools_sample_observer(Some(() => publisher.publish()))
}
