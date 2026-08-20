///|
pub(all) struct MeshId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MaterialId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextureId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NodeId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub fn MeshId::new(value : Int) -> MeshId {
  { value, }
}

///|
pub fn MaterialId::new(value : Int) -> MaterialId {
  { value, }
}

///|
pub fn TextureId::new(value : Int) -> TextureId {
  { value, }
}

///|
pub fn NodeId::new(value : Int) -> NodeId {
  { value, }
}

///|
pub fn MeshId::value(self : MeshId) -> Int {
  self.value
}

///|
pub fn MaterialId::value(self : MaterialId) -> Int {
  self.value
}

///|
pub fn TextureId::value(self : TextureId) -> Int {
  self.value
}

///|
pub fn NodeId::value(self : NodeId) -> Int {
  self.value
}

///|
pub(all) struct Vertex {
  position : Vec3
  normal : Vec3
  texcoord : Vec2
} derive(Eq, Debug, ToJson)

///|
pub fn Vertex::new(
  position~ : Vec3,
  normal? : Vec3 = Vec3::new(x=0.0, y=1.0, z=0.0),
  texcoord? : Vec2 = Vec2::zero(),
) -> Vertex {
  { position, normal, texcoord }
}

///|
pub fn Vertex::position(self : Vertex) -> Vec3 {
  self.position
}

///|
pub fn Vertex::normal(self : Vertex) -> Vec3 {
  self.normal
}

///|
pub fn Vertex::texcoord(self : Vertex) -> Vec2 {
  self.texcoord
}

///|
pub(all) enum TextureSource {
  Uri(String)
  Embedded(Bytes)
} derive(Debug)

///|
pub(all) struct Texture {
  source : TextureSource
  mime_type : String?
} derive(Debug)

///|
pub fn Texture::uri(uri : String, mime_type? : String? = None) -> Texture {
  { source: TextureSource::Uri(uri), mime_type }
}

///|
pub fn Texture::embedded(bytes : Bytes, mime_type? : String? = None) -> Texture {
  { source: TextureSource::Embedded(bytes), mime_type }
}

///|
pub fn Texture::source(self : Texture) -> TextureSource {
  self.source
}

///|
pub fn Texture::mime_type(self : Texture) -> String? {
  self.mime_type
}

///|
pub(all) struct Material {
  base_color : Vec4
  metallic : Double
  roughness : Double
  base_color_texture : TextureId?
} derive(Eq, Debug, ToJson)

///|
pub fn Material::pbr(
  base_color? : Vec4 = Vec4::new(x=1.0, y=1.0, z=1.0, w=1.0),
  metallic? : Double = 0.0,
  roughness? : Double = 1.0,
  base_color_texture? : TextureId? = None,
) -> Material {
  {
    base_color,
    metallic: clamp01(metallic),
    roughness: clamp_min(roughness, 0.04),
    base_color_texture,
  }
}

///|
pub fn Material::base_color(self : Material) -> Vec4 {
  self.base_color
}

///|
pub fn Material::metallic(self : Material) -> Double {
  self.metallic
}

///|
pub fn Material::roughness(self : Material) -> Double {
  self.roughness
}

///|
pub fn Material::base_color_texture(self : Material) -> TextureId? {
  self.base_color_texture
}

///|
pub(all) struct Primitive {
  vertices : Array[Vertex]
  indices : Array[Int]
  material : MaterialId?
  bounds : Aabb
} derive(Debug)

///|
pub fn Primitive::new(
  vertices~ : Array[Vertex],
  indices~ : Array[Int],
  material? : MaterialId? = None,
) -> Primitive {
  let points = vertices.map(vertex => vertex.position)
  {
    vertices: vertices.copy(),
    indices: indices.copy(),
    material,
    bounds: Aabb::from_points(points),
  }
}

///|
pub fn Primitive::vertices(self : Primitive) -> Array[Vertex] {
  self.vertices.copy()
}

///|
pub fn Primitive::indices(self : Primitive) -> Array[Int] {
  self.indices.copy()
}

///|
pub fn Primitive::material(self : Primitive) -> MaterialId? {
  self.material
}

///|
pub fn Primitive::bounds(self : Primitive) -> Aabb {
  self.bounds
}

///|
pub(all) struct Mesh {
  name : String
  primitives : Array[Primitive]
  bounds : Aabb
} derive(Debug)

///|
pub fn Mesh::new(name? : String = "", primitives~ : Array[Primitive]) -> Mesh {
  let mut bounds = Aabb::empty()
  for primitive in primitives {
    bounds = bounds.union(primitive.bounds)
  }
  { name, primitives: primitives.copy(), bounds }
}

///|
pub fn Mesh::name(self : Mesh) -> String {
  self.name
}

///|
pub fn Mesh::primitives(self : Mesh) -> Array[Primitive] {
  self.primitives.copy()
}

///|
pub fn Mesh::bounds(self : Mesh) -> Aabb {
  self.bounds
}

///|
pub(all) struct Node {
  name : String
  parent : NodeId?
  children : Array[NodeId]
  local_transform : Mat4
  mesh : MeshId?
} derive(Debug)

///|
pub fn Node::new(
  name? : String = "",
  parent? : NodeId? = None,
  local_transform? : Mat4 = Mat4::identity(),
  mesh? : MeshId? = None,
) -> Node {
  { name, parent, children: [], local_transform, mesh }
}

///|
pub fn Node::name(self : Node) -> String {
  self.name
}

///|
pub fn Node::parent(self : Node) -> NodeId? {
  self.parent
}

///|
pub fn Node::children(self : Node) -> Array[NodeId] {
  self.children.copy()
}

///|
pub fn Node::local_transform(self : Node) -> Mat4 {
  self.local_transform
}

///|
pub fn Node::mesh(self : Node) -> MeshId? {
  self.mesh
}

///|
pub fn Node::with_child(self : Node, child : NodeId) -> Node {
  self.children.push(child)
  self
}

///|
pub(all) struct PickHit {
  node : NodeId
  primitive_index : Int
  distance : Double
  position : Vec3
} derive(Eq, Debug, ToJson)

///|
pub fn PickHit::node(self : PickHit) -> NodeId {
  self.node
}

///|
pub fn PickHit::primitive_index(self : PickHit) -> Int {
  self.primitive_index
}

///|
pub fn PickHit::distance(self : PickHit) -> Double {
  self.distance
}

///|
pub fn PickHit::position(self : PickHit) -> Vec3 {
  self.position
}

///|
pub(all) struct Scene {
  meshes : Array[Mesh]
  materials : Array[Material]
  textures : Array[Texture]
  nodes : Array[Node]
} derive(Debug)

///|
pub fn Scene::empty() -> Scene {
  { meshes: [], materials: [], textures: [], nodes: [] }
}

///|
pub fn Scene::meshes(self : Scene) -> Array[Mesh] {
  self.meshes.copy()
}

///|
pub fn Scene::materials(self : Scene) -> Array[Material] {
  self.materials.copy()
}

///|
pub fn Scene::textures(self : Scene) -> Array[Texture] {
  self.textures.copy()
}

///|
pub fn Scene::nodes(self : Scene) -> Array[Node] {
  self.nodes.copy()
}

///|
pub fn Scene::add_mesh(self : Scene, mesh : Mesh) -> MeshId {
  let id = MeshId::new(self.meshes.length())
  self.meshes.push(mesh)
  id
}

///|
pub fn Scene::add_material(self : Scene, material : Material) -> MaterialId {
  let id = MaterialId::new(self.materials.length())
  self.materials.push(material)
  id
}

///|
pub fn Scene::add_texture(self : Scene, texture : Texture) -> TextureId {
  let id = TextureId::new(self.textures.length())
  self.textures.push(texture)
  id
}

///|
pub fn Scene::add_node(self : Scene, node : Node) -> NodeId {
  let id = NodeId::new(self.nodes.length())
  self.nodes.push(node)
  match node.parent {
    Some(parent) =>
      if parent.value >= 0 && parent.value < self.nodes.length() {
        let parent_node = self.nodes[parent.value]
        self.nodes[parent.value] = parent_node.with_child(id)
      }
    None => ()
  }
  // glTF permits a child to appear before its parent in the nodes array.
  // Back-link those already-added children when their parent arrives.
  let mut child_index = 0
  while child_index < self.nodes.length() - 1 {
    match self.nodes[child_index].parent {
      Some(parent) =>
        if parent == id {
          let parent_node = self.nodes[id.value]
          if !parent_node.children.contains(NodeId::new(child_index)) {
            self.nodes[id.value] = parent_node.with_child(
              NodeId::new(child_index),
            )
          }
        }
      None => ()
    }
    child_index = child_index + 1
  }
  id
}

///|
pub fn Scene::mesh(self : Scene, id : MeshId) -> Mesh? {
  if id.value < 0 || id.value >= self.meshes.length() {
    None
  } else {
    Some(self.meshes[id.value])
  }
}

///|
pub fn Scene::node(self : Scene, id : NodeId) -> Node? {
  if id.value < 0 || id.value >= self.nodes.length() {
    None
  } else {
    Some(self.nodes[id.value])
  }
}

///|
pub fn Scene::world_transform(self : Scene, id : NodeId) -> Mat4 {
  match self.node(id) {
    None => Mat4::identity()
    Some(node) =>
      match node.parent {
        None => node.local_transform
        Some(parent) => self.world_transform(parent).mul(node.local_transform)
      }
  }
}

///|
pub fn Scene::bounds(self : Scene) -> Aabb {
  let mut result = Aabb::empty()
  for index, node in self.nodes {
    match node.mesh {
      None => ()
      Some(mesh_id) =>
        match self.mesh(mesh_id) {
          None => ()
          Some(mesh) => {
            let node_id = NodeId::new(index)
            result = result.union(
              mesh.bounds.transformed(self.world_transform(node_id)),
            )
          }
        }
    }
  }
  result
}

///|
pub fn Scene::pick(self : Scene, ray : Ray) -> PickHit? {
  let mut best : PickHit? = None
  for node_index, node in self.nodes {
    match node.mesh {
      None => ()
      Some(mesh_id) =>
        match self.mesh(mesh_id) {
          None => ()
          Some(mesh) => {
            let node_id = NodeId::new(node_index)
            let transform = self.world_transform(node_id)
            let world_bounds = mesh.bounds.transformed(transform)
            if ray.intersect_aabb(world_bounds) {
              for primitive_index, primitive in mesh.primitives {
                let indices = primitive.indices
                let vertices = primitive.vertices
                let mut index = 0
                while index + 2 < indices.length() {
                  let first = indices[index]
                  let second = indices[index + 1]
                  let third = indices[index + 2]
                  if first >= 0 &&
                    second >= 0 &&
                    third >= 0 &&
                    first < vertices.length() &&
                    second < vertices.length() &&
                    third < vertices.length() {
                    let a = transform.transform_point(vertices[first].position)
                    let b = transform.transform_point(vertices[second].position)
                    let c = transform.transform_point(vertices[third].position)
                    match ray.intersect_triangle(a, b, c) {
                      None => ()
                      Some(distance) =>
                        match best {
                          None =>
                            best = Some(PickHit::{
                              node: node_id,
                              primitive_index,
                              distance,
                              position: ray.at(distance),
                            })
                          Some(previous) =>
                            if distance < previous.distance {
                              best = Some(PickHit::{
                                node: node_id,
                                primitive_index,
                                distance,
                                position: ray.at(distance),
                              })
                            }
                        }
                    }
                  }
                  index = index + 3
                }
              }
            }
          }
        }
    }
  }
  best
}

///|
fn clamp01(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn clamp_min(value : Double, minimum : Double) -> Double {
  if value < minimum {
    minimum
  } else {
    value
  }
}
