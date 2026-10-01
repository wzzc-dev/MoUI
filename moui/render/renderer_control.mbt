///|
/// Ordered control messages shared by the renderer facade and the common
/// mailbox implementation. Frame submission policy remains in `render/common`.
pub(all) enum RendererControlMessage {
  Resize(@core.Size)
  Detach
  ContextLoss(String)
  Shutdown
} derive(Eq, Debug, ToJson)

///|
pub extend RendererControlMessage with Debug::{to_repr}

///|
pub extend RendererControlMessage with Eq::{not_equal, equal}

///|
pub extend RendererControlMessage with ToJson::{to_json}
