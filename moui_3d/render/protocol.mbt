///|
/// Capability state is explicit so a 2D MoUI page can remain usable when the
/// selected 3D host lacks WebGPU or native WGPU.
pub(all) enum ThreeDRendererStatus {
  Available
  Unavailable(String)
  Failed(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ThreeDRendererBackend {
  NativeWgpu
  WebGpu
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ThreeDRendererDescriptor {
  id : String
  backend : ThreeDRendererBackend
  status : ThreeDRendererStatus
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn ThreeDRendererDescriptor::new(
  id~ : String,
  backend~ : ThreeDRendererBackend,
  status~ : ThreeDRendererStatus,
  description? : String = "",
) -> ThreeDRendererDescriptor {
  { id, backend, status, description }
}

///|
pub fn ThreeDRendererDescriptor::id(self : ThreeDRendererDescriptor) -> String {
  self.id
}

///|
pub fn ThreeDRendererDescriptor::backend(
  self : ThreeDRendererDescriptor,
) -> ThreeDRendererBackend {
  self.backend
}

///|
pub fn ThreeDRendererDescriptor::status(
  self : ThreeDRendererDescriptor,
) -> ThreeDRendererStatus {
  self.status
}

///|
pub fn ThreeDRendererDescriptor::description(
  self : ThreeDRendererDescriptor,
) -> String {
  self.description
}

///|
pub(all) struct ThreeDViewportSize {
  width : Int
  height : Int
  scale_factor : Double
} derive(Eq, Debug, ToJson)

///|
pub fn ThreeDViewportSize::new(
  width~ : Int,
  height~ : Int,
  scale_factor? : Double = 1.0,
) -> ThreeDViewportSize {
  {
    width: if width < 1 {
      1
    } else {
      width
    },
    height: if height < 1 {
      1
    } else {
      height
    },
    scale_factor: if scale_factor <= 0.0 {
      1.0
    } else {
      scale_factor
    },
  }
}

///|
pub fn ThreeDViewportSize::width(self : ThreeDViewportSize) -> Int {
  self.width
}

///|
pub fn ThreeDViewportSize::height(self : ThreeDViewportSize) -> Int {
  self.height
}

///|
pub fn ThreeDViewportSize::scale_factor(self : ThreeDViewportSize) -> Double {
  self.scale_factor
}

///|
pub(all) struct ThreeDFrame {
  revision : Int64
  snapshot : @moui_3d.ViewportSnapshot
  size : ThreeDViewportSize
} derive(Debug)

///|
pub fn ThreeDFrame::new(
  revision~ : Int64,
  snapshot~ : @moui_3d.ViewportSnapshot,
  size~ : ThreeDViewportSize,
) -> ThreeDFrame {
  { revision, snapshot, size }
}

///|
pub fn ThreeDFrame::revision(self : ThreeDFrame) -> Int64 {
  self.revision
}

///|
pub fn ThreeDFrame::snapshot(self : ThreeDFrame) -> @moui_3d.ViewportSnapshot {
  self.snapshot
}

///|
pub fn ThreeDFrame::size(self : ThreeDFrame) -> ThreeDViewportSize {
  self.size
}

///|
pub(all) enum ThreeDRenderResult {
  Presented
  Queued
  Unavailable(String)
  Failed(String)
} derive(Eq, Debug, ToJson)

///|
pub struct ThreeDRendererSession {
  descriptor : ThreeDRendererDescriptor
  resize_fn : (ThreeDViewportSize) -> Unit
  render_fn : (ThreeDFrame) -> ThreeDRenderResult
  dispose_fn : () -> Unit
  mut disposed : Bool
  mut last_revision : Int64
}

///|
pub fn ThreeDRendererSession::new(
  descriptor~ : ThreeDRendererDescriptor,
  resize~ : (ThreeDViewportSize) -> Unit,
  render~ : (ThreeDFrame) -> ThreeDRenderResult,
  dispose? : () -> Unit = () => (),
) -> ThreeDRendererSession {
  {
    descriptor,
    resize_fn: resize,
    render_fn: render,
    dispose_fn: dispose,
    disposed: false,
    last_revision: -1L,
  }
}

///|
pub fn ThreeDRendererSession::descriptor(
  self : ThreeDRendererSession,
) -> ThreeDRendererDescriptor {
  self.descriptor
}

///|
pub fn ThreeDRendererSession::resize(
  self : ThreeDRendererSession,
  size : ThreeDViewportSize,
) -> Unit {
  if !self.disposed {
    (self.resize_fn)(size)
  }
}

///|
/// Stale CPU snapshots are ignored before a renderer sees them.
pub fn ThreeDRendererSession::render(
  self : ThreeDRendererSession,
  frame : ThreeDFrame,
) -> ThreeDRenderResult {
  if self.disposed {
    return ThreeDRenderResult::Failed("renderer disposed")
  }
  if frame.revision < self.last_revision {
    return ThreeDRenderResult::Queued
  }
  self.last_revision = frame.revision
  (self.render_fn)(frame)
}

///|
pub fn ThreeDRendererSession::dispose(self : ThreeDRendererSession) -> Unit {
  if !self.disposed {
    self.disposed = true
    (self.dispose_fn)()
  }
}

///|
pub struct ThreeDRendererProvider {
  descriptor : ThreeDRendererDescriptor
  bind_fn : () -> ThreeDRendererSession?
  bind_surface_fn : (UInt64, ThreeDViewportSize) -> ThreeDRendererSession?
}

///|
pub fn ThreeDRendererProvider::new(
  descriptor~ : ThreeDRendererDescriptor,
  bind~ : () -> ThreeDRendererSession?,
  bind_surface? : (UInt64, ThreeDViewportSize) -> ThreeDRendererSession? = (
    _handle,
    _size,
  ) => None,
) -> ThreeDRendererProvider {
  { descriptor, bind_fn: bind, bind_surface_fn: bind_surface }
}

///|
pub fn ThreeDRendererProvider::descriptor(
  self : ThreeDRendererProvider,
) -> ThreeDRendererDescriptor {
  self.descriptor
}

///|
pub fn ThreeDRendererProvider::bind(
  self : ThreeDRendererProvider,
) -> ThreeDRendererSession? {
  (self.bind_fn)()
}

///|
/// Bind a provider to a platform-owned opaque surface handle. This is the
/// bridge used by external platform-view plugins; the handle remains opaque
/// until interpreted by the selected concrete renderer.
pub fn ThreeDRendererProvider::bind_surface(
  self : ThreeDRendererProvider,
  handle : UInt64,
  size : ThreeDViewportSize,
) -> ThreeDRendererSession? {
  (self.bind_surface_fn)(handle, size)
}

///|
pub fn resolve_provider(
  providers : Array[ThreeDRendererProvider],
) -> ThreeDRendererSession? {
  for provider in providers {
    match provider.bind() {
      Some(session) => return Some(session)
      None => ()
    }
  }
  None
}

///|
/// Connect one addon viewport host to a selected renderer provider. The
/// connection owns the renderer session, avoids redundant surface resize,
/// rebinds when the opaque platform handle changes, and mirrors typed render
/// results back to the viewport binding.
pub fn connect_viewport_host(
  provider : ThreeDRendererProvider,
  host : @moui_3d.ThreeDViewportHost,
  unavailable_reason? : String = "3D GPU host is unavailable",
) -> Unit {
  let session : Ref[ThreeDRendererSession?] = Ref(None)
  let surface_handle : Ref[UInt64?] = Ref(None)
  let surface_size : Ref[ThreeDViewportSize?] = Ref(None)
  let bind_failed : Ref[Bool] = Ref(false)
  let binding = host.binding()
  let set_status = status => {
    if binding.status() != status {
      binding.set_status(status)
      host.invalidate()
    }
  }
  let dispose_session = () => {
    match session.val {
      Some(renderer) => renderer.dispose()
      None => ()
    }
    session.val = None
    surface_handle.val = None
    surface_size.val = None
    bind_failed.val = false
  }
  host.set_surface_handler((handle, width, height, scale) => {
    let size = ThreeDViewportSize::new(width~, height~, scale_factor=scale)
    let handle_changed = surface_handle.val != Some(handle)
    let size_changed = surface_size.val != Some(size)
    if handle_changed {
      dispose_session()
    }
    surface_handle.val = Some(handle)
    surface_size.val = Some(size)
    match session.val {
      Some(renderer) => if size_changed { renderer.resize(size) }
      None if !bind_failed.val || handle_changed || size_changed =>
        match provider.bind_surface(handle, size) {
          Some(renderer) => {
            session.val = Some(renderer)
            bind_failed.val = false
            set_status(@moui_3d.ViewportStatus::Ready)
          }
          None => {
            bind_failed.val = true
            set_status(@moui_3d.ViewportStatus::Unavailable(unavailable_reason))
          }
        }
      None => ()
    }
  })
  host.set_frame_handler((snapshot, width, height, scale) => {
    match session.val {
      Some(renderer) => {
        let result = renderer.render(
          ThreeDFrame::new(
            revision=snapshot.scene_revision(),
            snapshot~,
            size=ThreeDViewportSize::new(width~, height~, scale_factor=scale),
          ),
        )
        match result {
          ThreeDRenderResult::Presented =>
            set_status(@moui_3d.ViewportStatus::Ready)
          ThreeDRenderResult::Queued => ()
          ThreeDRenderResult::Unavailable(reason) =>
            set_status(@moui_3d.ViewportStatus::Unavailable(reason))
          ThreeDRenderResult::Failed(reason) =>
            set_status(@moui_3d.ViewportStatus::Failed(reason))
        }
      }
      None => ()
    }
  })
  host.set_dispose_handler(_window_handle => dispose_session())
}
