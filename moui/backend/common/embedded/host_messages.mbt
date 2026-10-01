///|
using @host {
  type HostPendingServiceRequest,
  type HostServiceRequestId,
  type HostServiceResponse,
  type PlatformChannelResponse,
  type HostServiceBridge,
  type HostClipboardRequest,
}

///|
using @window_input {text_input_ime_request_diagnostics}

///|
/// Wire-neutral IME request payload. Native adapters keep the existing JSON
/// schema while the runtime owns the conversion to and from core text ranges.
pub(all) struct EmbeddedImeRequest {
  revision : Int
  enabled : Bool
  text : String
  caret : Int
  selection : @core.TextRange?
  composition : String?
  composition_cursor : @core.TextRange?
  frame : @core.Rect
  candidate_anchor : @core.Rect
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedImeRequest with Debug::{to_repr}

///|
pub extend EmbeddedImeRequest with Eq::{not_equal, equal}

///|
pub extend EmbeddedImeRequest with ToJson::{to_json}

///|
pub(all) struct EmbeddedSemanticsNode {
  node_id : @core.SemanticsNodeId
  semantic_id : @core.SemanticId?
  role : @core.SemanticsRole
  level : Int?
  url : String
  label : String
  value : String
  description : String
  state : @core.SemanticsState
  numeric : @core.SemanticsNumericValue?
  text : @core.SemanticsTextValue?
  collection : @core.SemanticsCollectionInfo?
  relations : @core.SemanticsRelations
  live : @core.SemanticsLive
  live_atomic : Bool
  actions : Array[@core.SemanticsActionKind]
  focus_order : Int?
  frame : @core.Rect
  children : Array[@core.SemanticsNodeId]
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedSemanticsNode with Debug::{to_repr}

///|
pub extend EmbeddedSemanticsNode with Eq::{not_equal, equal}

///|
pub extend EmbeddedSemanticsNode with ToJson::{to_json}

///|
pub(all) struct EmbeddedSemanticsUpdate {
  kind : String
  generation : @core.SemanticsGeneration
  root : @core.SemanticsNodeId?
  focused : @core.SemanticsNodeId?
  semantic_focused : @core.SemanticsNodeId?
  nodes : Array[EmbeddedSemanticsNode]
  removed : Array[@core.SemanticsNodeId]
  issues : Array[@runtime.SemanticsIssue]
  announcements : Array[@runtime.AccessibilityAnnouncement]
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedSemanticsUpdate with Debug::{to_repr}

///|
pub extend EmbeddedSemanticsUpdate with Eq::{not_equal, equal}

///|
pub extend EmbeddedSemanticsUpdate with ToJson::{to_json}

///|
pub(all) struct EmbeddedPlatformViewSnapshot {
  revision : Int
  placements : Array[@core.PlatformViewPlacement]
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedPlatformViewSnapshot with Debug::{to_repr}

///|
pub extend EmbeddedPlatformViewSnapshot with Eq::{not_equal, equal}

///|
pub extend EmbeddedPlatformViewSnapshot with ToJson::{to_json}

///|
pub(all) enum EmbeddedHostUpdate {
  Ime(EmbeddedImeRequest)
  Clipboard(HostPendingServiceRequest)
  Semantics(EmbeddedSemanticsUpdate)
  Diagnostic(String)
  PlatformViews(EmbeddedPlatformViewSnapshot)
  PlatformChannel(HostPendingServiceRequest)
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedHostUpdate with Debug::{to_repr}

///|
pub extend EmbeddedHostUpdate with Eq::{not_equal, equal}

///|
pub extend EmbeddedHostUpdate with ToJson::{to_json}

///|
pub(all) enum EmbeddedHostResponse {
  TextInput(@core.TextInputEvent)
  Command(@core.CommandIntent)
  Clipboard(HostServiceRequestId, HostServiceResponse)
  Accessibility(@runtime.PerformSemanticsActionRequest)
  PlatformView(Int, String, String, @core.PlatformViewEvent)
  PlatformChannel(HostServiceRequestId, PlatformChannelResponse)
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedHostResponse with Debug::{to_repr}

///|
pub extend EmbeddedHostResponse with Eq::{not_equal, equal}

///|
pub extend EmbeddedHostResponse with ToJson::{to_json}

///|
pub(all) struct EmbeddedHostUpdateEnvelope {
  schema_version : Int
  session_generation : Int
  updates : Array[EmbeddedHostUpdate]
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedHostUpdateEnvelope with Debug::{to_repr}

///|
pub extend EmbeddedHostUpdateEnvelope with Eq::{not_equal, equal}

///|
pub extend EmbeddedHostUpdateEnvelope with ToJson::{to_json}

///|
pub(all) struct EmbeddedHostResponseEnvelope {
  schema_version : Int
  session_generation : Int
  response : EmbeddedHostResponse
} derive(Eq, Debug, ToJson)

///|
pub extend EmbeddedHostResponseEnvelope with Debug::{to_repr}

///|
pub extend EmbeddedHostResponseEnvelope with Eq::{not_equal, equal}

///|
pub extend EmbeddedHostResponseEnvelope with ToJson::{to_json}

///|
pub fn embedded_text_input_response(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> EmbeddedHostResponse? {
  let range = @core.TextRange::new(start~, end~)
  match kind {
    0 => Some(TextInput(InsertText(text)))
    1 => Some(TextInput(ReplaceText(range, text)))
    2 => Some(TextInput(SetSelection(range)))
    3 => Some(TextInput(CompositionStart))
    4 =>
      Some(
        TextInput(
          CompositionUpdate(
            @core.CompositionUpdate::new(text~, cursor=Some(range)),
          ),
        ),
      )
    5 => Some(TextInput(CompositionEnd(text)))
    6 => Some(TextInput(DeleteSurrounding(start, end)))
    7 => Some(TextInput(DeleteRange(range)))
    _ => None
  }
}

///|
pub fn embedded_command_response(kind : Int) -> EmbeddedHostResponse? {
  match kind {
    0 => Some(Command(Copy))
    1 => Some(Command(Cut))
    2 => Some(Command(Paste))
    3 => Some(Command(Submit))
    _ => None
  }
}

///|
pub fn embedded_accessibility_response(
  node_id : @core.SemanticsNodeId,
  generation : @core.SemanticsGeneration,
  action : @core.SemanticsAction,
) -> EmbeddedHostResponse {
  Accessibility({
    target: ByNodeId(node_id),
    action,
    precondition: Exact(generation),
  })
}

///|
pub struct EmbeddedRuntimeHostBridge {
  services : @host_services_embedded.EmbeddedHostServices
  session_generation : Int
  mut updates : Array[EmbeddedHostUpdate]
  mut ime_revision : Int
  mut last_text_input : @core.TextInputState?
  mut semantics_cursor : @core.SemanticsGeneration?
  mut platform_view_revision : Int
  mut last_platform_views : Array[@core.PlatformViewPlacement]
  mut disposed : Bool
}
