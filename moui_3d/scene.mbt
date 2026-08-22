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
pub(all) struct SamplerId {
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
pub fn SamplerId::new(value : Int) -> SamplerId {
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
pub fn SamplerId::value(self : SamplerId) -> Int {
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
  joints : (Int, Int, Int, Int)
  weights : Vec4
} derive(Eq, Debug, ToJson)

///|
pub fn Vertex::new(
  position~ : Vec3,
  normal? : Vec3 = Vec3::new(x=0.0, y=1.0, z=0.0),
  texcoord? : Vec2 = Vec2::zero(),
  joints? : (Int, Int, Int, Int) = (0, 0, 0, 0),
  weights? : Vec4 = Vec4::zero(),
) -> Vertex {
  { position, normal, texcoord, joints, weights }
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
pub fn Vertex::joints(self : Vertex) -> (Int, Int, Int, Int) {
  self.joints
}

///|
pub fn Vertex::weights(self : Vertex) -> Vec4 {
  self.weights
}

///|
pub(all) enum TextureSource {
  Uri(String)
  Embedded(Bytes)
} derive(Debug)

///|
pub(all) enum SamplerFilter {
  Nearest
  Linear
  NearestMipmapNearest
  LinearMipmapNearest
  NearestMipmapLinear
  LinearMipmapLinear
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SamplerWrap {
  Repeat
  MirroredRepeat
  ClampToEdge
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Sampler {
  mag_filter : SamplerFilter
  min_filter : SamplerFilter
  wrap_s : SamplerWrap
  wrap_t : SamplerWrap
} derive(Eq, Debug, ToJson)

///|
pub fn Sampler::new(
  mag_filter? : SamplerFilter = SamplerFilter::Linear,
  min_filter? : SamplerFilter = SamplerFilter::LinearMipmapLinear,
  wrap_s? : SamplerWrap = SamplerWrap::Repeat,
  wrap_t? : SamplerWrap = SamplerWrap::Repeat,
) -> Sampler {
  { mag_filter, min_filter, wrap_s, wrap_t }
}

///|
pub fn Sampler::mag_filter(self : Sampler) -> SamplerFilter {
  self.mag_filter
}

///|
pub fn Sampler::min_filter(self : Sampler) -> SamplerFilter {
  self.min_filter
}

///|
pub fn Sampler::wrap_s(self : Sampler) -> SamplerWrap {
  self.wrap_s
}

///|
pub fn Sampler::wrap_t(self : Sampler) -> SamplerWrap {
  self.wrap_t
}

///|
pub(all) struct Texture {
  source : TextureSource
  mime_type : String?
  sampler : SamplerId?
} derive(Debug)

///|
pub fn Texture::uri(
  uri : String,
  mime_type? : String? = None,
  sampler? : SamplerId? = None,
) -> Texture {
  { source: TextureSource::Uri(uri), mime_type, sampler }
}

///|
pub fn Texture::embedded(
  bytes : Bytes,
  mime_type? : String? = None,
  sampler? : SamplerId? = None,
) -> Texture {
  { source: TextureSource::Embedded(bytes), mime_type, sampler }
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
pub fn Texture::sampler(self : Texture) -> SamplerId? {
  self.sampler
}

///|
pub(all) struct Material {
  base_color : Vec4
  metallic : Double
  roughness : Double
  base_color_texture : TextureId?
  normal_texture : TextureId?
  occlusion_texture : TextureId?
  emissive_texture : TextureId?
  emissive_factor : Vec3
  alpha_mode : AlphaMode
  alpha_cutoff : Double
  double_sided : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum CameraProjection {
  Perspective(Double, Double, Double, Double)
  Orthographic(Double, Double, Double, Double)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Camera {
  name : String
  projection : CameraProjection
} derive(Eq, Debug, ToJson)

///|
pub fn Camera::new(
  name? : String = "",
  projection~ : CameraProjection,
) -> Camera {
  { name, projection }
}

///|
pub fn Camera::name(self : Camera) -> String {
  self.name
}

///|
pub fn Camera::projection(self : Camera) -> CameraProjection {
  self.projection
}

///|
pub(all) struct SceneDefinition {
  name : String
  roots : Array[NodeId]
} derive(Eq, Debug, ToJson)

///|
pub fn SceneDefinition::new(
  name? : String = "",
  roots~ : Array[NodeId],
) -> SceneDefinition {
  { name, roots: roots.copy() }
}

///|
pub fn SceneDefinition::name(self : SceneDefinition) -> String {
  self.name
}

///|
pub fn SceneDefinition::roots(self : SceneDefinition) -> Array[NodeId] {
  self.roots.copy()
}

///|
pub(all) struct VertexDelta {
  position : Vec3
  normal : Vec3
  tangent : Vec3
} derive(Eq, Debug, ToJson)

///|
pub fn VertexDelta::new(
  position? : Vec3 = Vec3::zero(),
  normal? : Vec3 = Vec3::zero(),
  tangent? : Vec3 = Vec3::zero(),
) -> VertexDelta {
  { position, normal, tangent }
}

///|
pub fn VertexDelta::position(self : VertexDelta) -> Vec3 {
  self.position
}

///|
pub fn VertexDelta::normal(self : VertexDelta) -> Vec3 {
  self.normal
}

///|
pub fn VertexDelta::tangent(self : VertexDelta) -> Vec3 {
  self.tangent
}

///|
pub(all) struct Skin {
  name : String
  joints : Array[NodeId]
  inverse_bind_matrices : Array[Mat4]
  skeleton : NodeId?
} derive(Debug)

///|
pub fn Skin::new(
  name? : String = "",
  joints~ : Array[NodeId],
  inverse_bind_matrices? : Array[Mat4] = [],
  skeleton? : NodeId? = None,
) -> Skin {
  {
    name,
    joints: joints.copy(),
    inverse_bind_matrices: inverse_bind_matrices.copy(),
    skeleton,
  }
}

///|
pub fn Skin::name(self : Skin) -> String {
  self.name
}

///|
pub fn Skin::joints(self : Skin) -> Array[NodeId] {
  self.joints.copy()
}

///|
pub fn Skin::inverse_bind_matrices(self : Skin) -> Array[Mat4] {
  self.inverse_bind_matrices.copy()
}

///|
pub fn Skin::skeleton(self : Skin) -> NodeId? {
  self.skeleton
}

///|
pub(all) enum AlphaMode {
  Opaque
  Mask
  Blend
} derive(Eq, Debug, ToJson)

///|
pub fn Material::pbr(
  base_color? : Vec4 = Vec4::new(x=1.0, y=1.0, z=1.0, w=1.0),
  metallic? : Double = 0.0,
  roughness? : Double = 1.0,
  base_color_texture? : TextureId? = None,
  normal_texture? : TextureId? = None,
  occlusion_texture? : TextureId? = None,
  emissive_texture? : TextureId? = None,
  emissive_factor? : Vec3 = Vec3::zero(),
  alpha_mode? : AlphaMode = AlphaMode::Opaque,
  alpha_cutoff? : Double = 0.5,
  double_sided? : Bool = false,
) -> Material {
  {
    base_color,
    metallic: clamp01(metallic),
    roughness: clamp_min(roughness, 0.04),
    base_color_texture,
    normal_texture,
    occlusion_texture,
    emissive_texture,
    emissive_factor,
    alpha_mode,
    alpha_cutoff: clamp01(alpha_cutoff),
    double_sided,
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
pub fn Material::normal_texture(self : Material) -> TextureId? {
  self.normal_texture
}

///|
pub fn Material::occlusion_texture(self : Material) -> TextureId? {
  self.occlusion_texture
}

///|
pub fn Material::emissive_texture(self : Material) -> TextureId? {
  self.emissive_texture
}

///|
pub fn Material::emissive_factor(self : Material) -> Vec3 {
  self.emissive_factor
}

///|
pub fn Material::alpha_mode(self : Material) -> AlphaMode {
  self.alpha_mode
}

///|
pub fn Material::alpha_cutoff(self : Material) -> Double {
  self.alpha_cutoff
}

///|
pub fn Material::double_sided(self : Material) -> Bool {
  self.double_sided
}

///|
pub(all) struct Primitive {
  vertices : Array[Vertex]
  indices : Array[Int]
  material : MaterialId?
  bounds : Aabb
  morph_targets : Array[Array[VertexDelta]]
} derive(Debug)

///|
pub fn Primitive::new(
  vertices~ : Array[Vertex],
  indices~ : Array[Int],
  material? : MaterialId? = None,
  morph_targets? : Array[Array[VertexDelta]] = [],
) -> Primitive {
  let points = vertices.map(vertex => vertex.position)
  {
    vertices: vertices.copy(),
    indices: indices.copy(),
    material,
    bounds: Aabb::from_points(points),
    morph_targets: morph_targets.map(target => target.copy()),
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
pub fn Primitive::morph_targets(self : Primitive) -> Array[Array[VertexDelta]] {
  self.morph_targets.map(target => target.copy())
}

///|
pub(all) struct Mesh {
  name : String
  primitives : Array[Primitive]
  weights : Array[Double]
  bounds : Aabb
} derive(Debug)

///|
pub fn Mesh::new(
  name? : String = "",
  primitives~ : Array[Primitive],
  weights? : Array[Double] = [],
) -> Mesh {
  let mut bounds = Aabb::empty()
  for primitive in primitives {
    bounds = bounds.union(primitive.bounds)
  }
  { name, primitives: primitives.copy(), weights: weights.copy(), bounds }
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
pub fn Mesh::weights(self : Mesh) -> Array[Double] {
  self.weights.copy()
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
  camera : Int?
  skin : Int?
  weights : Array[Double]?
} derive(Debug)

///|
pub fn Node::new(
  name? : String = "",
  parent? : NodeId? = None,
  local_transform? : Mat4 = Mat4::identity(),
  mesh? : MeshId? = None,
  camera? : Int? = None,
  skin? : Int? = None,
  weights? : Array[Double]? = None,
) -> Node {
  { name, parent, children: [], local_transform, mesh, camera, skin, weights }
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
/// Return a node with a replaced local transform. Scene animation applies
/// poses to a copied scene so the authored/rest transform remains reusable.
pub fn Node::with_local_transform(self : Node, local_transform : Mat4) -> Node {
  { ..self, local_transform, }
}

///|
pub fn Node::mesh(self : Node) -> MeshId? {
  self.mesh
}

///|
pub fn Node::camera(self : Node) -> Int? {
  self.camera
}

///|
pub fn Node::skin(self : Node) -> Int? {
  self.skin
}

///|
pub fn Node::weights(self : Node) -> Array[Double]? {
  self.weights
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
  samplers : Array[Sampler]
  cameras : Array[Camera]
  definitions : Array[SceneDefinition]
  skins : Array[Skin]
  mut default_scene : Int?
  nodes : Array[Node]
  animations : Array[AnimationClip]
} derive(Debug)

///|
pub fn Scene::empty() -> Scene {
  {
    meshes: [],
    materials: [],
    textures: [],
    samplers: [],
    cameras: [],
    definitions: [],
    skins: [],
    default_scene: None,
    nodes: [],
    animations: [],
  }
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
/// Copy the scene containers before applying a transient animation pose.
/// Mesh/material/animation values are immutable, while nodes are replaced in
/// the returned scene and never mutated in the authored scene.
pub fn Scene::copy(self : Scene) -> Scene {
  {
    meshes: self.meshes.copy(),
    materials: self.materials.copy(),
    textures: self.textures.copy(),
    samplers: self.samplers.copy(),
    cameras: self.cameras.copy(),
    definitions: self.definitions.copy(),
    skins: self.skins.copy(),
    default_scene: self.default_scene,
    nodes: self.nodes.copy(),
    animations: self.animations.copy(),
  }
}

///|
/// Apply sampled animation channels to a copied scene. Unknown node ids and
/// unsupported/empty samples are ignored so malformed optional channels do
/// not invalidate an otherwise renderable scene.
pub fn Scene::apply_animation_samples(
  self : Scene,
  samples : Array[AnimationSample],
) -> Scene {
  let result = self.copy()
  for sample in samples {
    let index = sample.node().value()
    if index >= 0 && index < result.nodes.length() {
      let node = result.nodes[index]
      let transform = apply_animation_sample(
        node.local_transform(),
        sample.path(),
        sample.value(),
      )
      result.nodes[index] = node.with_local_transform(transform)
    }
  }
  result
}

///|
fn apply_animation_sample(
  authored : Mat4,
  path : AnimationPath,
  values : Array[Double],
) -> Mat4 {
  match path {
    AnimationPath::Translation if values.length() >= 3 => {
      let matrix = authored.values()
      matrix[3] = values[0]
      matrix[7] = values[1]
      matrix[11] = values[2]
      Mat4::from_values(matrix)
    }
    AnimationPath::Scale if values.length() >= 3 => {
      let matrix = authored.values()
      matrix[0] = values[0]
      matrix[5] = values[1]
      matrix[10] = values[2]
      Mat4::from_values(matrix)
    }
    AnimationPath::Rotation if values.length() >= 4 => {
      let x = values[0]
      let y = values[1]
      let z = values[2]
      let w = values[3]
      let length = (x * x + y * y + z * z + w * w).sqrt()
      let rotation = if length <= 1.0e-12 {
        Quat::identity()
      } else {
        Quat::new(x=x / length, y=y / length, z=z / length, w=w / length)
      }
      let authored_values = authored.values()
      let sx = (authored_values[0] * authored_values[0] +
      authored_values[4] * authored_values[4] +
      authored_values[8] * authored_values[8]).sqrt()
      let sy = (authored_values[1] * authored_values[1] +
      authored_values[5] * authored_values[5] +
      authored_values[9] * authored_values[9]).sqrt()
      let sz = (authored_values[2] * authored_values[2] +
      authored_values[6] * authored_values[6] +
      authored_values[10] * authored_values[10]).sqrt()
      Mat4::translation(
        Vec3::new(
          x=authored_values[3],
          y=authored_values[7],
          z=authored_values[11],
        ),
      )
      .mul(rotation.to_mat4())
      .mul(
        Mat4::from_values([
          sx, 0.0, 0.0, 0.0, 0.0, sy, 0.0, 0.0, 0.0, 0.0, sz, 0.0, 0.0, 0.0, 0.0,
          1.0,
        ]),
      )
    }
    _ => authored
  }
}

///|
pub fn Scene::animations(self : Scene) -> Array[AnimationClip] {
  self.animations.copy()
}

///|
pub fn Scene::add_animation(self : Scene, animation : AnimationClip) -> Int {
  let index = self.animations.length()
  self.animations.push(animation)
  index
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
pub fn Scene::samplers(self : Scene) -> Array[Sampler] {
  self.samplers.copy()
}

///|
pub fn Scene::add_sampler(self : Scene, sampler : Sampler) -> SamplerId {
  let id = SamplerId::new(self.samplers.length())
  self.samplers.push(sampler)
  id
}

///|
pub fn Scene::cameras(self : Scene) -> Array[Camera] {
  self.cameras.copy()
}

///|
pub fn Scene::add_camera(self : Scene, camera : Camera) -> Int {
  let index = self.cameras.length()
  self.cameras.push(camera)
  index
}

///|
pub fn Scene::scene_definitions(self : Scene) -> Array[SceneDefinition] {
  self.definitions.copy()
}

///|
pub fn Scene::add_scene_definition(
  self : Scene,
  definition : SceneDefinition,
) -> Int {
  let index = self.definitions.length()
  self.definitions.push(definition)
  index
}

///|
pub fn Scene::skins(self : Scene) -> Array[Skin] {
  self.skins.copy()
}

///|
pub fn Scene::add_skin(self : Scene, skin : Skin) -> Int {
  let index = self.skins.length()
  self.skins.push(skin)
  index
}

///|
pub fn Scene::default_scene(self : Scene) -> Int? {
  self.default_scene
}

///|
pub fn Scene::set_default_scene(self : Scene, index : Int?) -> Unit {
  self.default_scene = index
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
