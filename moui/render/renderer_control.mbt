///|
/// Ordered control messages shared by the renderer facade and the common
/// mailbox implementation. Frame submission policy remains in `render/common`.
pub(all) enum RendererControlMessage {
  Resize(@core.Size)
  Detach
  ContextLoss(String)
  Shutdown
} derive(Eq, Debug, ToJson)
