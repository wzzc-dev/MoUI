///|
/// Neutral request to present an existing MoUI surface in a host-owned modal
/// layer. The host never receives application state or a second content model.
pub(all) struct HostModalRequest {
  request_id : Int
  presentation_id : String
  generation : Int
  bounds : @core.Rect
  modality : HostModalModality
  semantics_generation : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostModalModality {
  NonModal
  Modal
} derive(Eq, Debug, ToJson)

///|
/// Result of accepting or rejecting a request. `Pending` is represented by
/// the absence of a result while the host negotiates capabilities.
pub(all) enum HostModalResult {
  Accepted
  Rejected(String)
  Closed
} derive(Eq, Debug, ToJson)

///|
/// Typed host lifecycle facts returned to the runtime/TEA boundary.
pub(all) enum HostModalEvent {
  Pending(Int, String, Int)
  Accepted(Int, String, Int)
  Rejected(Int, String, Int, String)
  Closed(Int, String, Int)
  SurfaceAttached(Int, String, Int, String)
  SurfaceDetached(Int, String, Int, String)
  Input(Int, String, Int, @core.PointerEvent)
} derive(Eq, Debug, ToJson)

///|
/// Capabilities are declarative; a missing capability must transparently use
/// the view-level presentation path.
pub(all) struct HostModalCapabilities {
  native_modal : Bool
  surface_attach : Bool
  input_transform : Bool
  semantics_bridge : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn HostModalCapabilities::unavailable() -> HostModalCapabilities {
  {
    native_modal: false,
    surface_attach: false,
    input_transform: false,
    semantics_bridge: false,
  }
}

///|
pub fn HostModalCapabilities::full() -> HostModalCapabilities {
  {
    native_modal: true,
    surface_attach: true,
    input_transform: true,
    semantics_bridge: true,
  }
}

///|
pub fn HostModalCapabilities::supports_native_modal(
  self : HostModalCapabilities,
) -> Bool {
  self.native_modal
}

///|
pub fn HostModalCapabilities::supports_surface_attach(
  self : HostModalCapabilities,
) -> Bool {
  self.surface_attach
}

///|
pub fn HostModalCapabilities::supports_input_transform(
  self : HostModalCapabilities,
) -> Bool {
  self.input_transform
}

///|
pub fn HostModalCapabilities::supports_semantics_bridge(
  self : HostModalCapabilities,
) -> Bool {
  self.semantics_bridge
}

///|
pub fn HostModalRequest::new(
  request_id~ : Int,
  presentation_id~ : String,
  generation~ : Int,
  bounds~ : @core.Rect,
  modality? : HostModalModality = HostModalModality::NonModal,
  semantics_generation? : Int = 0,
) -> HostModalRequest {
  {
    request_id,
    presentation_id,
    generation,
    bounds,
    modality,
    semantics_generation,
  }
}

///|
pub fn HostModalRequest::request_id(self : HostModalRequest) -> Int {
  self.request_id
}

///|
pub fn HostModalRequest::presentation_id(self : HostModalRequest) -> String {
  self.presentation_id
}

///|
pub fn HostModalRequest::generation(self : HostModalRequest) -> Int {
  self.generation
}

///|
pub fn HostModalRequest::bounds(self : HostModalRequest) -> @core.Rect {
  self.bounds
}

///|
pub fn HostModalRequest::modality(self : HostModalRequest) -> HostModalModality {
  self.modality
}

///|
pub fn HostModalRequest::semantics_generation(self : HostModalRequest) -> Int {
  self.semantics_generation
}
