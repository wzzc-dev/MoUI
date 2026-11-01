///|
/// GPU-skinned render packet. Unlike `ThreeDRenderPacket`, which expands
/// every triangle into clip-space vertices on the CPU each frame, this
/// packet ships bind-pose geometry once and then only a small per-frame
/// payload (view-projection, bone palette and per-item model/color). The
/// concrete renderer applies skinning in the vertex shader, so an
/// articulated character costs a few hundred scalar host calls per frame
/// instead of re-serializing the whole mesh.

///|
pub(all) struct ThreeDSkinMeshKey {
  mesh : Int32
  primitive : Int32
} derive(Eq, Hash, Debug)

///|
pub extend ThreeDSkinMeshKey with Debug::{to_repr}

///|
pub extend ThreeDSkinMeshKey with Eq::{not_equal, equal}

///|
pub extend ThreeDSkinMeshKey with Hash::{hash, hash_combine}

///|
pub fn ThreeDSkinMeshKey::new(mesh~ : Int32, primitive~ : Int32) -> ThreeDSkinMeshKey {
  { mesh, primitive, }
}

///|
/// Bind-pose geometry for one primitive: 19 floats per expanded triangle
/// vertex (position xyz + skinned flag, normal xyz, base color rgba, joint
/// indices x4, joint weights x4). Joint indices carry the skin's palette
/// base offset.
pub(all) struct ThreeDSkinMesh {
  key : ThreeDSkinMeshKey
  vertices : Array[Double]
} derive(Debug)

///|
pub extend ThreeDSkinMesh with Debug::{to_repr}

///|
pub fn ThreeDSkinMesh::key(self : ThreeDSkinMesh) -> ThreeDSkinMeshKey {
  self.key
}

///|
pub fn ThreeDSkinMesh::vertices(self : ThreeDSkinMesh) -> Array[Double] {
  self.vertices.copy()
}

///|
pub(all) struct ThreeDSkinItem {
  key : ThreeDSkinMeshKey
  model : @moui_3d.Mat4
  color : @moui_3d.Vec4
  metallic : Double
  roughness : Double
  vertex_count : Int32
} derive(Debug)

///|
pub extend ThreeDSkinItem with Debug::{to_repr}

///|
pub fn ThreeDSkinItem::key(self : ThreeDSkinItem) -> ThreeDSkinMeshKey {
  self.key
}

///|
pub fn ThreeDSkinItem::model(self : ThreeDSkinItem) -> @moui_3d.Mat4 {
  self.model
}

///|
pub fn ThreeDSkinItem::color(self : ThreeDSkinItem) -> @moui_3d.Vec4 {
  self.color
}

///|
pub fn ThreeDSkinItem::metallic(self : ThreeDSkinItem) -> Double {
  self.metallic
}

///|
pub fn ThreeDSkinItem::roughness(self : ThreeDSkinItem) -> Double {
  self.roughness
}

///|
pub fn ThreeDSkinItem::vertex_count(self : ThreeDSkinItem) -> Int32 {
  self.vertex_count
}

///|
pub(all) struct ThreeDSkinPacket {
  view_projection : @moui_3d.Mat4
  camera_position : @moui_3d.Vec3
  bones : Array[@moui_3d.Mat4]
  items : Array[ThreeDSkinItem]
  meshes : Array[ThreeDSkinMesh]
} derive(Debug)

///|
pub extend ThreeDSkinPacket with Debug::{to_repr}

///|
pub fn ThreeDSkinPacket::view_projection(self : ThreeDSkinPacket) -> @moui_3d.Mat4 {
  self.view_projection
}

///|
pub fn ThreeDSkinPacket::camera_position(self : ThreeDSkinPacket) -> @moui_3d.Vec3 {
  self.camera_position
}

///|
pub fn ThreeDSkinPacket::bones(self : ThreeDSkinPacket) -> Array[@moui_3d.Mat4] {
  self.bones.copy()
}

///|
pub fn ThreeDSkinPacket::items(self : ThreeDSkinPacket) -> Array[ThreeDSkinItem] {
  self.items.copy()
}

///|
pub fn ThreeDSkinPacket::meshes(self : ThreeDSkinPacket) -> Array[ThreeDSkinMesh] {
  self.meshes.copy()
}

///|
/// Number of palette slots used by the packet's skins.
pub fn ThreeDSkinPacket::bone_count(self : ThreeDSkinPacket) -> Int32 {
  self.bones.length()
}

///|
/// Build the packet at the CPU/UI boundary. `uploaded` lists mesh keys the
/// renderer already retains; only missing keys carry bind-pose vertices in
/// this packet, so steady-state frames stay small.
pub fn ThreeDSkinPacket::from_snapshot(
  snapshot : @moui_3d.ViewportSnapshot,
  size~ : ThreeDViewportSize,
  uploaded~ : Array[ThreeDSkinMeshKey] = [],
) -> ThreeDSkinPacket {
  let scene = snapshot.scene()
  let aspect = if size.height() > 0 {
    size.width().to_double() / size.height().to_double()
  } else {
    1.0
  }
  let camera = snapshot.camera().with_aspect(aspect)
  let view_projection = camera.projection().mul(camera.view())
  let uploaded_keys : Set[ThreeDSkinMeshKey] = Set([])
  for key in uploaded {
    uploaded_keys.add(key)
  }
  let skins = scene.skins()
  let bones : Array[@moui_3d.Mat4] = []
  let skin_bases : Array[Int32] = []
  for skin in skins {
    skin_bases.push(bones.length())
    let inverse_bind = skin.inverse_bind_matrices()
    for joint_index, joint in skin.joints() {
      let world = scene.world_transform(joint)
      let bind = match inverse_bind.get(joint_index) {
        Some(matrix) => matrix
        None => @moui_3d.Mat4::identity()
      }
      bones.push(world.mul(bind))
    }
  }
  let items : Array[ThreeDSkinItem] = []
  let meshes : Array[ThreeDSkinMesh] = []
  for node_index, node in scene.nodes() {
    match node.mesh() {
      None => ()
      Some(mesh_id) =>
        match scene.mesh(mesh_id) {
          None => ()
          Some(mesh) => {
            let model = scene.world_transform(@moui_3d.NodeId::new(node_index))
            let skin = node.skin()
            for primitive_index, primitive in mesh.primitives() {
              let key = ThreeDSkinMeshKey::new(
                mesh=mesh_id.value(),
                primitive=primitive_index,
              )
              let material = match primitive.material() {
                Some(id) =>
                  match scene.materials().get(id.value()) {
                    Some(value) => value
                    None => @moui_3d.Material::pbr()
                  }
                None => @moui_3d.Material::pbr()
              }
              let joint_base = match skin {
                Some(index) if index >= 0 && index < skin_bases.length() =>
                  skin_bases[index]
                _ => 0
              }
              items.push({
                key,
                model,
                color: @moui_3d.Vec4::new(x=1.0, y=1.0, z=1.0, w=1.0),
                metallic: material.metallic(),
                roughness: material.roughness(),
                vertex_count: primitive.indices().length(),
              })
              if !uploaded_keys.contains(key) {
                meshes.push(
                  ThreeDSkinMesh::{
                    key,
                    vertices: expand_skin_vertices(
                      primitive,
                      material.base_color(),
                      skinned=skin is Some(_),
                      joint_base,
                    ),
                  },
                )
              }
            }
          }
        }
    }
  }
  { view_projection, camera_position: camera.position(), bones, items, meshes, }
}

///|
fn expand_skin_vertices(
  primitive : @moui_3d.Primitive,
  color : @moui_3d.Vec4,
  skinned~ : Bool,
  joint_base : Int32,
) -> Array[Double] {
  let vertices = primitive.vertices()
  let out : Array[Double] = []
  for index in primitive.indices() {
    match vertices.get(index) {
      Some(vertex) => {
        let position = vertex.position()
        let normal = vertex.normal()
        let (j0, j1, j2, j3) = vertex.joints()
        let weights = vertex.weights()
        let flag = if skinned { 1.0 } else { 0.0 }
        out.push(position.x)
        out.push(position.y)
        out.push(position.z)
        out.push(flag)
        out.push(normal.x())
        out.push(normal.y())
        out.push(normal.z())
        out.push(color.x())
        out.push(color.y())
        out.push(color.z())
        out.push(color.w())
        if skinned {
          out.push((j0 + joint_base).to_double())
          out.push((j1 + joint_base).to_double())
          out.push((j2 + joint_base).to_double())
          out.push((j3 + joint_base).to_double())
          out.push(weights.x())
          out.push(weights.y())
          out.push(weights.z())
          out.push(weights.w())
        } else {
          out.push(0.0)
          out.push(0.0)
          out.push(0.0)
          out.push(0.0)
          out.push(0.0)
          out.push(0.0)
          out.push(0.0)
          out.push(0.0)
        }
      }
      None => ()
    }
  }
  out
}
