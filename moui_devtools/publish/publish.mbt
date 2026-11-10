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
/// Answer one NDJSON DevTools request line. Read-only: unknown methods return
/// an error instead of dispatching input.
pub fn DevtoolsPublisher::respond(
  self : DevtoolsPublisher,
  line : String,
) -> String {
  let parsed = @json.parse(line) catch {
    _ => return "{\"ok\":false,\"error\":\"parse-error\"}"
  }
  let fields = match parsed {
    Object(fields) => fields
    _ => return "{\"ok\":false,\"error\":\"request-must-be-an-object\"}"
  }
  let request_method = match fields.get("method") {
    Some(String(value)) => value
    _ => "all"
  }
  match request_method {
    "ping" => "{\"ok\":true,\"protocolVersion\":1}"
    "hello" =>
      "{\"ok\":true,\"protocolVersion\":1,\"methods\":[\"snapshot\",\"trace\",\"diagnostics\",\"ping\"]}"
    "snapshot" | "all" =>
      match self.document() {
        Some(value) => value.to_json_string(indent=0)
        None => "{\"ok\":false,\"error\":\"snapshot-unavailable\"}"
      }
    "trace" =>
      match self.document() {
        Some(value) =>
          match value.trace {
            Some(trace) => {
              let result : Map[String, Json] = Map([])
              result["ok"] = Json::boolean(true)
              result["result"] = trace.to_json()
              Json::object(result).stringify(indent=0)
            }
            None => "{\"ok\":true,\"result\":null}"
          }
        None => "{\"ok\":false,\"error\":\"snapshot-unavailable\"}"
      }
    "diagnostics" =>
      match self.document() {
        Some(value) => {
          let result : Map[String, Json] = Map([])
          result["ok"] = Json::boolean(true)
          result["result"] = Json::array(
            value.diagnostics.map(event => event.to_json()),
          )
          Json::object(result).stringify(indent=0)
        }
        None => "{\"ok\":false,\"error\":\"snapshot-unavailable\"}"
      }
    _ => "{\"ok\":false,\"error\":\"unknown-method\"}"
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
