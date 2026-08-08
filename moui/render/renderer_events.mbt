///|
/// Identifies one frame submission for one native-surface generation.
pub struct FrameToken {
  priv surface_generation : Int
  priv sequence : Int
} derive(Eq, Debug, ToJson)

///|
pub fn FrameToken::new(
  surface_generation~ : Int,
  sequence~ : Int,
) -> FrameToken {
  { surface_generation, sequence }
}

///|
pub fn FrameToken::surface_generation(self : FrameToken) -> Int {
  self.surface_generation
}

///|
pub fn FrameToken::sequence(self : FrameToken) -> Int {
  self.sequence
}

///|
/// A draw frame paired with the backend-owned submission identity.
pub struct RenderFrameSubmission {
  priv token : FrameToken
  priv frame : @core.DrawFrame
}

///|
pub fn RenderFrameSubmission::new(
  token~ : FrameToken,
  frame~ : @core.DrawFrame,
) -> RenderFrameSubmission {
  { token, frame }
}

///|
pub fn RenderFrameSubmission::token(self : RenderFrameSubmission) -> FrameToken {
  self.token
}

///|
pub fn RenderFrameSubmission::frame(
  self : RenderFrameSubmission,
) -> @core.DrawFrame {
  self.frame
}

///|
/// Opaque renderer-owned identity for one image I/O request.
pub struct RendererImageLoadToken {
  priv value : Int64
} derive(Eq, Debug, ToJson)

///|
fn RendererImageLoadToken::new(value : Int64) -> RendererImageLoadToken {
  { value, }
}

///|
pub struct RendererImageLoadRequest {
  priv token : RendererImageLoadToken
  priv source : String
  priv image_source : HostImageSource
  priv decoder : RendererImageDecoder
}

///|
fn RendererImageLoadRequest::new(
  token~ : RendererImageLoadToken,
  source~ : String,
  image_source~ : HostImageSource,
  decoder~ : RendererImageDecoder,
) -> RendererImageLoadRequest {
  { token, source, image_source, decoder }
}

///|
pub fn RendererImageLoadRequest::token(
  self : RendererImageLoadRequest,
) -> RendererImageLoadToken {
  self.token
}

///|
pub fn RendererImageLoadRequest::source(
  self : RendererImageLoadRequest,
) -> String {
  self.source
}

///|
pub fn RendererImageLoadRequest::load(
  self : RendererImageLoadRequest,
) -> RendererImageLoadCompletion {
  let bytes = self.image_source.read(self.source)
  RendererImageLoadCompletion::new(
    token=self.token,
    result=self.decoder.decode(self.source, bytes),
  )
}

///|
pub struct RendererImageLoadCompletion {
  priv token : RendererImageLoadToken
  priv result : ImageResourceLoadCompletion
}

///|
pub fn RendererImageLoadCompletion::new(
  token~ : RendererImageLoadToken,
  result~ : ImageResourceLoadCompletion,
) -> RendererImageLoadCompletion {
  { token, result }
}

///|
pub fn RendererImageLoadCompletion::token(
  self : RendererImageLoadCompletion,
) -> RendererImageLoadToken {
  self.token
}

///|
pub fn RendererImageLoadCompletion::result(
  self : RendererImageLoadCompletion,
) -> ImageResourceLoadCompletion {
  self.result
}

///|
pub(all) enum RendererImageCompletionResult {
  Applied(Bool)
  Stale
  Disposed
} derive(Eq, Debug, ToJson)

///|
pub struct RendererImageDiagnostics {
  priv records : Array[ImageResourceRecord]
  priv pending_request_count : Int
}

///|
fn RendererImageDiagnostics::new(
  records~ : Array[ImageResourceRecord],
  pending_request_count~ : Int,
) -> RendererImageDiagnostics {
  { records, pending_request_count }
}

///|
pub fn RendererImageDiagnostics::records(
  self : RendererImageDiagnostics,
) -> Array[ImageResourceRecord] {
  self.records.copy()
}

///|
pub fn RendererImageDiagnostics::pending_request_count(
  self : RendererImageDiagnostics,
) -> Int {
  self.pending_request_count
}

///|
pub(all) enum RendererEvent {
  PresentCompleted(RenderPresentCompletion)
  ImageLoadRequested(RendererImageLoadRequest)
}
