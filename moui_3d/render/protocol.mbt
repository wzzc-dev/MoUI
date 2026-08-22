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
/// Stable identity for renderer-owned GPU resources. The key is neutral;
/// concrete providers decide how it maps to buffers, textures and pipelines.
pub(all) enum ThreeDResourceKind {
  Mesh
  Material
  Texture
  Sampler
  Skin
  Pipeline
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ThreeDResourceKey {
  kind : ThreeDResourceKind
  value : Int64
} derive(Eq, Debug, ToJson)

///|
pub fn ThreeDResourceKey::new(
  kind~ : ThreeDResourceKind,
  value~ : Int64,
) -> ThreeDResourceKey {
  { kind, value }
}

///|
pub fn ThreeDResourceKey::kind(self : ThreeDResourceKey) -> ThreeDResourceKind {
  self.kind
}

///|
pub fn ThreeDResourceKey::value(self : ThreeDResourceKey) -> Int64 {
  self.value
}

///|
pub(all) enum ThreeDResourceChange {
  Create(ThreeDResourceKey)
  Update(ThreeDResourceKey)
  Remove(ThreeDResourceKey)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ThreeDResourceDiff {
  revision : Int64
  changes : Array[ThreeDResourceChange]
} derive(Debug)

///|
pub fn ThreeDResourceDiff::new(
  revision~ : Int64,
  changes~ : Array[ThreeDResourceChange],
) -> ThreeDResourceDiff {
  { revision, changes: changes.copy() }
}

///|
pub fn ThreeDResourceDiff::revision(self : ThreeDResourceDiff) -> Int64 {
  self.revision
}

///|
pub fn ThreeDResourceDiff::changes(
  self : ThreeDResourceDiff,
) -> Array[ThreeDResourceChange] {
  self.changes.copy()
}

///|
/// Tracks stable resource residency between renderer frames.
pub struct ThreeDResourceGraph {
  resident : Ref[Array[ThreeDResourceKey]]
  revisions : Ref[Array[Int64]]
}

///|
pub fn ThreeDResourceGraph::new() -> ThreeDResourceGraph {
  { resident: Ref([]), revisions: Ref([]) }
}

///|
pub fn ThreeDResourceGraph::resident(
  self : ThreeDResourceGraph,
) -> Array[ThreeDResourceKey] {
  self.resident.val.copy()
}

///|
/// Normalize a packet's resource observations into create/remove operations.
/// Repeated observations remain resident and therefore produce no upload.
pub fn ThreeDResourceGraph::sync(
  self : ThreeDResourceGraph,
  diff : ThreeDResourceDiff,
) -> ThreeDResourceDiff {
  let desired : Array[ThreeDResourceKey] = []
  let changes : Array[ThreeDResourceChange] = []
  for change in diff.changes() {
    match change {
      ThreeDResourceChange::Create(key) => {
        desired.push(key)
        match find_resource_key(self.resident.val, key) {
          None => {
            self.resident.val.push(key)
            self.revisions.val.push(diff.revision())
            changes.push(ThreeDResourceChange::Create(key))
          }
          Some(_) => ()
        }
      }
      ThreeDResourceChange::Update(key) => {
        desired.push(key)
        match find_resource_key(self.resident.val, key) {
          None => {
            self.resident.val.push(key)
            self.revisions.val.push(diff.revision())
            changes.push(ThreeDResourceChange::Create(key))
          }
          Some(index) if self.revisions.val[index] != diff.revision() => {
            self.revisions.val[index] = diff.revision()
            changes.push(ThreeDResourceChange::Update(key))
          }
          _ => ()
        }
      }
      ThreeDResourceChange::Remove(_) => ()
    }
  }
  let mut index = 0
  while index < self.resident.val.length() {
    let key = self.resident.val[index]
    if !contains_resource_key(desired, key) {
      changes.push(ThreeDResourceChange::Remove(key))
      ignore(self.resident.val.remove(index))
      ignore(self.revisions.val.remove(index))
    } else {
      index = index + 1
    }
  }
  ThreeDResourceDiff::new(revision=diff.revision(), changes~)
}

///|

///|
fn contains_resource_key(
  keys : Array[ThreeDResourceKey],
  wanted : ThreeDResourceKey,
) -> Bool {
  for key in keys {
    if key.kind() == wanted.kind() && key.value() == wanted.value() {
      return true
    }
  }
  false
}

///|
fn find_resource_key(
  keys : Array[ThreeDResourceKey],
  wanted : ThreeDResourceKey,
) -> Int? {
  for index, key in keys {
    if key.kind() == wanted.kind() && key.value() == wanted.value() {
      return Some(index)
    }
  }
  None
}

///|
/// A renderer-neutral primitive packet. Geometry is copied once at packet
/// creation; renderers no longer walk the mutable CPU Scene each frame.
pub(all) struct ThreeDRenderItem {
  node : @moui_3d.NodeId
  primitive_index : Int
  model : @moui_3d.Mat4
  vertices : Array[@moui_3d.Vertex]
  indices : Array[Int]
  base_color : @moui_3d.Vec4
  metallic : Double
  roughness : Double
  skin : Int?
  morph_targets : Array[Array[@moui_3d.VertexDelta]]
} derive(Debug)

///|
pub fn ThreeDRenderItem::node(self : ThreeDRenderItem) -> @moui_3d.NodeId {
  self.node
}

///|
pub fn ThreeDRenderItem::primitive_index(self : ThreeDRenderItem) -> Int {
  self.primitive_index
}

///|
pub fn ThreeDRenderItem::model(self : ThreeDRenderItem) -> @moui_3d.Mat4 {
  self.model
}

///|
pub fn ThreeDRenderItem::vertices(
  self : ThreeDRenderItem,
) -> Array[@moui_3d.Vertex] {
  self.vertices.copy()
}

///|
pub fn ThreeDRenderItem::indices(self : ThreeDRenderItem) -> Array[Int] {
  self.indices.copy()
}

///|
pub fn ThreeDRenderItem::base_color(self : ThreeDRenderItem) -> @moui_3d.Vec4 {
  self.base_color
}

///|
pub fn ThreeDRenderItem::metallic(self : ThreeDRenderItem) -> Double {
  self.metallic
}

///|
pub fn ThreeDRenderItem::roughness(self : ThreeDRenderItem) -> Double {
  self.roughness
}

///|
pub fn ThreeDRenderItem::skin(self : ThreeDRenderItem) -> Int? {
  self.skin
}

///|
pub fn ThreeDRenderItem::morph_targets(
  self : ThreeDRenderItem,
) -> Array[Array[@moui_3d.VertexDelta]] {
  self.morph_targets.map(target => target.copy())
}

///|
pub(all) struct ThreeDRenderPacket {
  revision : Int64
  view : @moui_3d.Mat4
  projection : @moui_3d.Mat4
  camera_position : @moui_3d.Vec3
  items : Array[ThreeDRenderItem]
  resources : ThreeDResourceDiff
} derive(Debug)

///|
pub fn ThreeDRenderPacket::new(
  revision~ : Int64,
  view~ : @moui_3d.Mat4,
  projection~ : @moui_3d.Mat4,
  camera_position~ : @moui_3d.Vec3,
  items~ : Array[ThreeDRenderItem],
  resources~ : ThreeDResourceDiff,
) -> ThreeDRenderPacket {
  {
    revision,
    view,
    projection,
    camera_position,
    items: items.copy(),
    resources,
  }
}

///|
pub fn ThreeDRenderPacket::revision(self : ThreeDRenderPacket) -> Int64 {
  self.revision
}

///|
pub fn ThreeDRenderPacket::view(self : ThreeDRenderPacket) -> @moui_3d.Mat4 {
  self.view
}

///|
pub fn ThreeDRenderPacket::projection(
  self : ThreeDRenderPacket,
) -> @moui_3d.Mat4 {
  self.projection
}

///|
pub fn ThreeDRenderPacket::camera_position(
  self : ThreeDRenderPacket,
) -> @moui_3d.Vec3 {
  self.camera_position
}

///|
pub fn ThreeDRenderPacket::items(
  self : ThreeDRenderPacket,
) -> Array[ThreeDRenderItem] {
  self.items.copy()
}

///|
pub fn ThreeDRenderPacket::resources(
  self : ThreeDRenderPacket,
) -> ThreeDResourceDiff {
  self.resources
}

///|
/// Stable text descriptor for host-side material/texture/sampler residency.
/// Concrete hosts may cache this descriptor independently from vertex bytes;
/// image decode and GPU upload remain renderer-owned concerns.
pub fn ThreeDRenderPacket::resource_payload(
  self : ThreeDRenderPacket,
) -> String {
  let output = StringBuilder::new()
  let mut first = true
  for change in self.resources().changes() {
    if first {
      first = false
    } else {
      output.write_char(';')
    }
    match change {
      ThreeDResourceChange::Create(_) => output.write_string("create:")
      ThreeDResourceChange::Update(_) => output.write_string("update:")
      ThreeDResourceChange::Remove(_) => output.write_string("remove:")
    }
    match change {
      ThreeDResourceChange::Create(key)
      | ThreeDResourceChange::Update(key)
      | ThreeDResourceChange::Remove(key) => {
        output.write_string(resource_kind_name(key.kind()))
        output.write_char(':')
        output.write_string(key.value().to_string())
      }
    }
  }
  output.to_string()
}

///|
fn resource_kind_name(kind : ThreeDResourceKind) -> String {
  match kind {
    ThreeDResourceKind::Mesh => "mesh"
    ThreeDResourceKind::Material => "material"
    ThreeDResourceKind::Texture => "texture"
    ThreeDResourceKind::Sampler => "sampler"
    ThreeDResourceKind::Skin => "skin"
    ThreeDResourceKind::Pipeline => "pipeline"
  }
}

///|
pub fn ThreeDRenderPacket::with_resources(
  self : ThreeDRenderPacket,
  resources : ThreeDResourceDiff,
) -> ThreeDRenderPacket {
  {
    revision: self.revision,
    view: self.view,
    projection: self.projection,
    camera_position: self.camera_position,
    items: self.items.copy(),
    resources,
  }
}

///|
/// Compact host payload: each vertex is clip xyzw, normal xyz and color rgba.
pub fn ThreeDRenderPacket::vertex_payload(self : ThreeDRenderPacket) -> String {
  let output = StringBuilder::new()
  let mut first = true
  for item in self.items() {
    let mvp = self.projection().mul(self.view()).mul(item.model())
    let vertices = item.vertices()
    for index in item.indices() {
      match vertices.get(index) {
        Some(vertex) => {
          let world = item.model().transform_homogeneous(vertex.position())
          let clip = mvp.transform_homogeneous(vertex.position())
          let normal = item
            .model()
            .transform_point(vertex.position().add(vertex.normal()))
            .sub(@moui_3d.Vec3::new(x=world.x, y=world.y, z=world.z))
            .normalized()
          let light = normal
            .dot(@moui_3d.Vec3::new(x=0.35, y=0.8, z=0.5).normalized())
            .max(0.18)
          let color = item.base_color()
          for
            value in [
              clip.x,
              clip.y,
              clip.z,
              clip.w,
              normal.x(),
              normal.y(),
              normal.z(),
              color.x() * light,
              color.y() * light,
              color.z() * light,
              color.w(),
            ] {
            if first {
              first = false
            } else {
              output.write_char(',')
            }
            output.write_string(value.to_string())
          }
        }
        None => ()
      }
    }
  }
  output.to_string()
}

///|
/// Binary counterpart of vertex_payload. The payload is little-endian
/// float32 records with 11 values per expanded triangle vertex: clip xyzw,
/// normal xyz and color rgba.
pub fn ThreeDRenderPacket::vertex_payload_bytes(
  self : ThreeDRenderPacket,
) -> Bytes {
  let bytes : Array[Byte] = []
  for item in self.items() {
    let mvp = self.projection().mul(self.view()).mul(item.model())
    let vertices = item.vertices()
    for index in item.indices() {
      match vertices.get(index) {
        Some(vertex) => {
          let world = item.model().transform_homogeneous(vertex.position())
          let clip = mvp.transform_homogeneous(vertex.position())
          let normal = item
            .model()
            .transform_point(vertex.position().add(vertex.normal()))
            .sub(@moui_3d.Vec3::new(x=world.x, y=world.y, z=world.z))
            .normalized()
          let light = normal
            .dot(@moui_3d.Vec3::new(x=0.35, y=0.8, z=0.5).normalized())
            .max(0.18)
          let color = item.base_color()
          push_vertex_f32(bytes, clip.x)
          push_vertex_f32(bytes, clip.y)
          push_vertex_f32(bytes, clip.z)
          push_vertex_f32(bytes, clip.w)
          push_vertex_f32(bytes, normal.x())
          push_vertex_f32(bytes, normal.y())
          push_vertex_f32(bytes, normal.z())
          push_vertex_f32(bytes, color.x() * light)
          push_vertex_f32(bytes, color.y() * light)
          push_vertex_f32(bytes, color.z() * light)
          push_vertex_f32(bytes, color.w())
        }
        None => ()
      }
    }
  }
  Bytes::from_array(bytes)
}

///|
fn push_vertex_f32(out : Array[Byte], value : Double) -> Unit {
  let bits = Float::from_double(value).reinterpret_as_uint()
  out.push((bits & 0xFFU).to_byte())
  out.push(((bits >> 8) & 0xFFU).to_byte())
  out.push(((bits >> 16) & 0xFFU).to_byte())
  out.push(((bits >> 24) & 0xFFU).to_byte())
}

///|
/// Build a packet at the CPU/UI boundary. This is the only place that walks
/// Scene nodes and primitives for a frame.
pub fn ThreeDRenderPacket::from_snapshot(
  snapshot : @moui_3d.ViewportSnapshot,
  size : ThreeDViewportSize,
) -> ThreeDRenderPacket {
  let scene = snapshot.scene()
  let camera = snapshot
    .camera()
    .with_aspect(size.width.to_double() / size.height.to_double())
  let items : Array[ThreeDRenderItem] = []
  let changes : Array[ThreeDResourceChange] = []
  for node_index, node in scene.nodes() {
    match node.mesh() {
      None => ()
      Some(mesh_id) =>
        match scene.mesh(mesh_id) {
          None => ()
          Some(mesh) => {
            changes.push(
              ThreeDResourceChange::Update(
                ThreeDResourceKey::new(
                  kind=ThreeDResourceKind::Mesh,
                  value=mesh_id.value().to_int64(),
                ),
              ),
            )
            let model = scene.world_transform(@moui_3d.NodeId::new(node_index))
            match node.skin() {
              None => ()
              Some(skin) =>
                changes.push(
                  ThreeDResourceChange::Update(
                    ThreeDResourceKey::new(
                      kind=ThreeDResourceKind::Skin,
                      value=skin.to_int64(),
                    ),
                  ),
                )
            }
            for primitive_index, primitive in mesh.primitives() {
              let material = match primitive.material() {
                Some(id) =>
                  match scene.materials().get(id.value()) {
                    Some(value) => value
                    None => @moui_3d.Material::pbr()
                  }
                None => @moui_3d.Material::pbr()
              }
              match primitive.material() {
                Some(id) => {
                  changes.push(
                    ThreeDResourceChange::Update(
                      ThreeDResourceKey::new(
                        kind=ThreeDResourceKind::Material,
                        value=id.value().to_int64(),
                      ),
                    ),
                  )
                  match material.base_color_texture() {
                    Some(texture) =>
                      changes.push(
                        ThreeDResourceChange::Update(
                          ThreeDResourceKey::new(
                            kind=ThreeDResourceKind::Texture,
                            value=texture.value().to_int64(),
                          ),
                        ),
                      )
                    None => ()
                  }
                  match material.normal_texture() {
                    Some(texture) =>
                      changes.push(
                        ThreeDResourceChange::Update(
                          ThreeDResourceKey::new(
                            kind=ThreeDResourceKind::Texture,
                            value=texture.value().to_int64(),
                          ),
                        ),
                      )
                    None => ()
                  }
                  match material.occlusion_texture() {
                    Some(texture) =>
                      changes.push(
                        ThreeDResourceChange::Update(
                          ThreeDResourceKey::new(
                            kind=ThreeDResourceKind::Texture,
                            value=texture.value().to_int64(),
                          ),
                        ),
                      )
                    None => ()
                  }
                  match material.emissive_texture() {
                    Some(texture) =>
                      changes.push(
                        ThreeDResourceChange::Update(
                          ThreeDResourceKey::new(
                            kind=ThreeDResourceKind::Texture,
                            value=texture.value().to_int64(),
                          ),
                        ),
                      )
                    None => ()
                  }
                  for
                    texture in [
                      material.base_color_texture(),
                      material.normal_texture(),
                      material.occlusion_texture(),
                      material.emissive_texture(),
                    ] {
                    match texture {
                      None => ()
                      Some(texture_id) =>
                        match scene.textures().get(texture_id.value()) {
                          None => ()
                          Some(texture_value) =>
                            match texture_value.sampler() {
                              None => ()
                              Some(sampler_id) =>
                                changes.push(
                                  ThreeDResourceChange::Update(
                                    ThreeDResourceKey::new(
                                      kind=ThreeDResourceKind::Sampler,
                                      value=sampler_id.value().to_int64(),
                                    ),
                                  ),
                                )
                            }
                        }
                    }
                  }
                }
                None => ()
              }
              items.push(ThreeDRenderItem::{
                node: @moui_3d.NodeId::new(node_index),
                primitive_index,
                model,
                vertices: primitive.vertices(),
                indices: primitive.indices(),
                base_color: material.base_color(),
                metallic: material.metallic(),
                roughness: material.roughness(),
                skin: node.skin(),
                morph_targets: primitive.morph_targets(),
              })
            }
          }
        }
    }
  }
  ThreeDRenderPacket::new(
    revision=snapshot.scene_revision(),
    view=camera.view(),
    projection=camera.projection(),
    camera_position=camera.position(),
    items~,
    resources=ThreeDResourceDiff::new(
      revision=snapshot.scene_revision(),
      changes~,
    ),
  )
}

///|
pub(all) struct ThreeDFrame {
  revision : Int64
  snapshot : @moui_3d.ViewportSnapshot
  packet : ThreeDRenderPacket
  size : ThreeDViewportSize
} derive(Debug)

///|
pub fn ThreeDFrame::new(
  revision~ : Int64,
  snapshot~ : @moui_3d.ViewportSnapshot,
  size~ : ThreeDViewportSize,
) -> ThreeDFrame {
  let packet = ThreeDRenderPacket::from_snapshot(snapshot, size)
  { revision, snapshot, packet, size }
}

///|
pub fn ThreeDFrame::from_packet(
  revision~ : Int64,
  snapshot~ : @moui_3d.ViewportSnapshot,
  packet~ : ThreeDRenderPacket,
  size~ : ThreeDViewportSize,
) -> ThreeDFrame {
  { revision, snapshot, packet, size }
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
pub fn ThreeDFrame::packet(self : ThreeDFrame) -> ThreeDRenderPacket {
  self.packet
}

///|
pub fn ThreeDFrame::with_packet(
  self : ThreeDFrame,
  packet : ThreeDRenderPacket,
) -> ThreeDFrame {
  { revision: self.revision, snapshot: self.snapshot, packet, size: self.size }
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
  residency : ThreeDResourceGraph
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
    residency: ThreeDResourceGraph::new(),
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
  let resources = self.residency.sync(frame.packet().resources())
  (self.render_fn)(frame.with_packet(frame.packet().with_resources(resources)))
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
