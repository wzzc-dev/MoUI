///|
pub(all) struct ViewportSnapshot {
  scene_revision : Int64
  scene : Scene
  camera : OrbitCamera
  bounds : Aabb
} derive(Debug)

///|
pub fn ViewportSnapshot::new(
  scene_revision~ : Int64,
  scene~ : Scene,
  camera~ : OrbitCamera,
) -> ViewportSnapshot {
  { scene_revision, scene, camera, bounds: scene.bounds() }
}

///|
pub fn ViewportSnapshot::scene_revision(self : ViewportSnapshot) -> Int64 {
  self.scene_revision
}

///|
pub fn ViewportSnapshot::scene(self : ViewportSnapshot) -> Scene {
  self.scene
}

///|
pub fn ViewportSnapshot::camera(self : ViewportSnapshot) -> OrbitCamera {
  self.camera
}

///|
pub fn ViewportSnapshot::bounds(self : ViewportSnapshot) -> Aabb {
  self.bounds
}

///|
/// Latest-wins CPU bridge between a MoUI view and an external 3D surface.
/// Renderer residency and GPU cache state never cross this boundary.
pub struct ThreeDViewportBinding {
  latest : @ref.Ref[ViewportSnapshot?]
  status : @ref.Ref[ViewportStatus]
}

///|
pub(all) enum ViewportStatus {
  Loading
  Ready
  Unavailable(String)
  Failed(String)
} derive(Eq, Debug, ToJson)

///|
pub fn ThreeDViewportBinding::new() -> ThreeDViewportBinding {
  { latest: @ref.Ref(None), status: @ref.Ref(ViewportStatus::Loading) }
}

///|
pub fn ThreeDViewportBinding::publish(
  self : ThreeDViewportBinding,
  snapshot : ViewportSnapshot,
) -> Bool {
  match self.latest.val {
    Some(previous) =>
      if snapshot.scene_revision() < previous.scene_revision() {
        false
      } else {
        self.latest.val = Some(snapshot)
        true
      }
    None => {
      self.latest.val = Some(snapshot)
      true
    }
  }
}

///|
pub fn ThreeDViewportBinding::snapshot(
  self : ThreeDViewportBinding,
) -> ViewportSnapshot? {
  self.latest.val
}

///|
pub fn ThreeDViewportBinding::set_status(
  self : ThreeDViewportBinding,
  status : ViewportStatus,
) -> Unit {
  self.status.val = status
}

///|
pub fn ThreeDViewportBinding::status(
  self : ThreeDViewportBinding,
) -> ViewportStatus {
  self.status.val
}

///|
/// Addon-owned bridge between a platform-view plugin and a concrete 3D
/// renderer. The bridge carries only CPU snapshots and surface geometry;
/// renderer resources never cross into the MoUI frame contract.
pub struct ThreeDViewportHost {
  binding : ThreeDViewportBinding
  surface_handler : @ref.Ref[(UInt64, Int, Int, Double) -> Unit]
  frame_handler : @ref.Ref[(ViewportSnapshot, Int, Int, Double) -> Unit]
  dispose_handler : @ref.Ref[(UInt64) -> Unit]
  invalidate_handler : @ref.Ref[() -> Unit]
}

///|
pub fn ThreeDViewportHost::new(
  binding~ : ThreeDViewportBinding,
) -> ThreeDViewportHost {
  {
    binding,
    surface_handler: @ref.Ref((_handle, _width, _height, _scale) => ()),
    frame_handler: @ref.Ref((_snapshot, _width, _height, _scale) => ()),
    dispose_handler: @ref.Ref(_handle => ()),
    invalidate_handler: @ref.Ref(() => ()),
  }
}

///|
pub fn ThreeDViewportHost::binding(
  self : ThreeDViewportHost,
) -> ThreeDViewportBinding {
  self.binding
}

///|
/// Called by a concrete renderer composition root once it is ready to
/// interpret the platform surface handle.
pub fn ThreeDViewportHost::set_surface_handler(
  self : ThreeDViewportHost,
  handler : (UInt64, Int, Int, Double) -> Unit,
) -> Unit {
  self.surface_handler.val = handler
}

///|
pub fn ThreeDViewportHost::set_frame_handler(
  self : ThreeDViewportHost,
  handler : (ViewportSnapshot, Int, Int, Double) -> Unit,
) -> Unit {
  self.frame_handler.val = handler
}

///|
pub fn ThreeDViewportHost::set_dispose_handler(
  self : ThreeDViewportHost,
  handler : (UInt64) -> Unit,
) -> Unit {
  self.dispose_handler.val = handler
}

///|
/// Install the platform redraw hook used when renderer availability changes
/// outside the ordinary MoUI model update path.
pub fn ThreeDViewportHost::set_invalidate_handler(
  self : ThreeDViewportHost,
  handler : () -> Unit,
) -> Unit {
  self.invalidate_handler.val = handler
}

///|
pub fn ThreeDViewportHost::invalidate(self : ThreeDViewportHost) -> Unit {
  (self.invalidate_handler.val)()
}

///|
/// Synchronize all placements owned by the 3D addon. The plugin passes the
/// host window handle; a native backend may replace it with a child surface
/// handle before invoking the frame handler.
pub fn ThreeDViewportHost::sync_platform_views(
  self : ThreeDViewportHost,
  window_handle : UInt64,
  frame : @core.DrawFrame,
  content_offset_y : Double,
) -> Unit {
  for placement in frame.platform_views {
    if placement.kind == "moui_3d_viewport" {
      self.sync_platform_view(
        window_handle, placement, window_handle, frame, content_offset_y,
      )
    }
  }
}

///|
/// Sync one placement after a platform plugin has created or resolved its
/// concrete child surface handle.
pub fn ThreeDViewportHost::sync_platform_view(
  self : ThreeDViewportHost,
  window_handle : UInt64,
  placement : @core.PlatformViewPlacement,
  surface_handle : UInt64,
  frame : @core.DrawFrame,
  content_offset_y : Double,
  scale_factor? : Double = 1.0,
) -> Unit {
  if placement.kind != "moui_3d_viewport" {
    return ()
  }
  let width = placement.frame.size.width.to_int()
  let height = placement.frame.size.height.to_int()
  let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
  (self.surface_handler.val)(surface_handle, width, height, scale)
  match self.binding.snapshot() {
    Some(snapshot) => (self.frame_handler.val)(snapshot, width, height, scale)
    None => ()
  }
  ignore(window_handle)
  ignore(frame)
  ignore(content_offset_y)
}

///|
pub fn ThreeDViewportHost::dispose_platform_views(
  self : ThreeDViewportHost,
  window_handle : UInt64,
) -> Unit {
  (self.dispose_handler.val)(window_handle)
}

///|
pub fn[Msg] three_d_viewport(
  binding~ : ThreeDViewportBinding,
  snapshot~ : ViewportSnapshot,
  semantics_label? : String = "3D viewport",
  on_event? : ((ViewportEvent) -> Msg)? = None,
) -> @core.View[Msg] {
  ignore(binding.publish(snapshot))
  @core.View::from_node(ThreeDViewportNode::{ binding, semantics_label }, event=(
    _node,
    context,
  ) => {
    match (context.event, on_event) {
      (@core.AppEvent::PlatformView(event_id, event), Some(handler)) if event_id ==
        "moui-3d-viewport" =>
        match decode_viewport_event(event) {
          Some(value) => @core.ViewEventResult::message(handler(value))
          None => @core.ViewEventResult::ignored()
        }
      _ => @core.ViewEventResult::ignored()
    }
  })
}

///|
priv struct ThreeDViewportNode {
  binding : ThreeDViewportBinding
  semantics_label : String
}

///|
impl @core.ViewNode for ThreeDViewportNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="ThreeDViewport")
}

///|
impl @core.ViewNode for ThreeDViewportNode with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for ThreeDViewportNode with fn layout(_self, context) {
  let width = if context.constraints.max.width > 1.0e8 {
    320.0
  } else {
    context.constraints.max.width
  }
  // A viewport is an intrinsically sized platform surface. Letting a leaf use
  // the column's full max height pushes the status row below a small window.
  // Keep a stable 16:9 presentation with a bounded desktop height instead.
  let aspect_height = width * 0.5625
  let height = if context.constraints.max.height > 1.0e8 {
    aspect_height.min(360.0)
  } else {
    aspect_height.min(360.0).min(context.constraints.max.height)
  }
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width~, height~)),
  )
}

///|
impl @core.ViewNode for ThreeDViewportNode with fn platform_views(self, context) {
  let revision = match self.binding.snapshot() {
    Some(snapshot) => snapshot.scene_revision().to_string()
    None => "0"
  }
  [
    @core.PlatformViewPlacement::new(
      id="moui-3d-viewport",
      kind="moui_3d_viewport",
      frame=context.frame,
      clip=Some(context.frame),
      properties=[
        @core.PlatformViewProperty::new(key="scene_revision", value=revision),
      ],
    ),
  ]
}

///|
impl @core.ViewNode for ThreeDViewportNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Group,
    label=self.semantics_label,
    description="Interactive 3D model viewport",
  )
}

///|
pub(all) enum ViewportEvent {
  PointerDown(@core.Point)
  PointerMove(@core.Point)
  PointerUp(@core.Point)
  Wheel(Double)
  Resize(@core.Size)
  Focus(Bool)
  Pick(NodeId)
  RendererStatus
} derive(Eq, Debug)

///|
/// Decode the stable, human-readable platform event names used by the addon
/// plugin. Pointer payloads are `x,y`; wheel payload is a signed scalar.
pub fn decode_viewport_event(event : @core.PlatformViewEvent) -> ViewportEvent? {
  match event {
    @core.PlatformViewEvent::Named(name~, value~, detail~, flag~) => {
      ignore(detail)
      if name == "pointer_down" {
        parse_point(value).map(point => ViewportEvent::PointerDown(point))
      } else if name == "pointer_move" {
        parse_point(value).map(point => ViewportEvent::PointerMove(point))
      } else if name == "pointer_up" {
        parse_point(value).map(point => ViewportEvent::PointerUp(point))
      } else if name == "wheel" {
        let amount = @string.parse_double(value) catch { _ => return None }
        Some(ViewportEvent::Wheel(amount))
      } else if name == "resize" {
        parse_point(value).map(point => {
          ViewportEvent::Resize(@core.Size::new(width=point.x, height=point.y))
        })
      } else if name == "focus" {
        Some(ViewportEvent::Focus(flag))
      } else if name == "pick" {
        let node_id = @string.parse_int(value) catch { _ => return None }
        Some(ViewportEvent::Pick(NodeId::new(node_id)))
      } else if name == "renderer_status" {
        Some(ViewportEvent::RendererStatus)
      } else {
        None
      }
    }
  }
}

///|
fn parse_point(value : String) -> @core.Point? {
  let parts = value.split(",").to_array()
  if parts.length() != 2 {
    return None
  }
  let x = @string.parse_double(parts[0].to_owned()) catch { _ => return None }
  let y = @string.parse_double(parts[1].to_owned()) catch { _ => return None }
  Some(@core.Point::new(x~, y~))
}
