///|
/// Versioned, read-only DevTools document exchanged between a running app and
/// an inspector client. The first transport is a JSON file written by the
/// publisher; a socket/NDJSON transport can reuse this shape unchanged.
#derive(Eq, Debug, ToJson)
pub(all) struct DevtoolsDocument {
  schema_version : Int32
  snapshot : @devtools.InspectorReport
  report_text : String
  trace : @devtools.DevtoolsTraceReport?
  trace_text : String?
  diagnostics : Array[@diagnostics.DiagnosticEvent]
}

///|
pub extend DevtoolsDocument with Debug::{to_repr}

///|
pub extend DevtoolsDocument with Eq::{not_equal, equal}

///|
pub extend DevtoolsDocument with ToJson::{to_json}

///|
pub fn DevtoolsDocument::new(
  schema_version~ : Int32 = 1,
  snapshot~ : @devtools.InspectorReport,
  report_text~ : String,
  trace~ : @devtools.DevtoolsTraceReport?,
  trace_text~ : String?,
  diagnostics~ : Array[@diagnostics.DiagnosticEvent],
) -> DevtoolsDocument {
  { schema_version, snapshot, report_text, trace, trace_text, diagnostics, }
}

///|
pub fn DevtoolsDocument::to_json_string(
  self : DevtoolsDocument,
  indent~ : Int32 = 2,
) -> String {
  self.to_json().stringify(indent~)
}
