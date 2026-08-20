///|
/// glTF 2.0 container and metadata model. Platform I/O remains outside this
/// package; callers provide bytes and an optional URI resolver.
priv struct GltfAsset {
  version : String
} derive(FromJson)

///|
priv struct GltfBuffer {
  byteLength : Int
  uri : String?
}

///|
priv struct GltfBufferView {
  buffer : Int
  byteOffset : Int?
  byteLength : Int
  byteStride : Int?
}

///|
priv struct GltfPrimitiveJson {
  attributes : Map[String, Int]
  indices : Int?
  material : Int?
  mode : Int?
}

///|
priv struct GltfMeshJson {
  primitives : Array[GltfPrimitiveJson]
  name : String?
}

///|
priv struct GltfNodeJson {
  mesh : Int?
  children : Array[Int]?
  name : String?
  matrix : Array[Double]?
  translation : Array[Double]?
  rotation : Array[Double]?
  scale : Array[Double]?
}

///|
priv struct GltfTextureInfo {
  index : Int
} derive(FromJson)

///|
priv struct GltfPbrJson {
  baseColorFactor : Array[Double]?
  metallicFactor : Double?
  roughnessFactor : Double?
  baseColorTexture : GltfTextureInfo?
}

///|
priv struct GltfMaterialJson {
  pbrMetallicRoughness : GltfPbrJson?
}

///|
priv struct GltfImageJson {
  uri : String?
  mimeType : String?
  bufferView : Int?
}

///|
priv struct GltfTextureJson {
  source : Int?
}

///|
priv struct GltfRoot {
  asset : GltfAsset
  buffers : Array[GltfBuffer]?
  bufferViews : Array[GltfBufferView]?
  accessors : Array[GltfAccessorJson]?
  meshes : Array[GltfMeshJson]?
  nodes : Array[GltfNodeJson]?
  materials : Array[GltfMaterialJson]?
  images : Array[GltfImageJson]?
  textures : Array[GltfTextureJson]?
  extensionsUsed : Array[String]?
}

///|
priv struct GltfAccessorJson {
  bufferView : Int?
  byteOffset : Int?
  componentType : Int
  normalized : Bool?
  count : Int
  accessor_kind : String
}

///|
impl @json.FromJson for GltfAccessorJson with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "accessor must be an object"))
  }
  let kind_json = match fields.get("type") {
    Some(value) => value
    None => raise @json.JsonDecodeError((path, "accessor.type is required"))
  }
  {
    bufferView: optional_field(fields, "bufferView", path),
    byteOffset: optional_field(fields, "byteOffset", path),
    componentType: required_field(fields, "componentType", path),
    normalized: optional_field(fields, "normalized", path),
    count: required_field(fields, "count", path),
    accessor_kind: @json.from_json(kind_json, path~),
  }
}

///|
fn object_fields(
  json : Json,
  path : @json.JsonPath,
) -> Map[String, Json] raise @json.JsonDecodeError {
  match json {
    Object(fields) => fields
    _ => raise @json.JsonDecodeError((path, "expected object"))
  }
}

///|
fn[T : @json.FromJson] required_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  match fields.get(key) {
    Some(value) => @json.from_json(value, path=path.add_key(key))
    None => raise @json.JsonDecodeError((path, "missing field " + key))
  }
}

///|
fn[T : @json.FromJson] optional_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T? raise @json.JsonDecodeError {
  match fields.get(key) {
    None => None
    Some(Null) => None
    Some(value) => Some(@json.from_json(value, path=path.add_key(key)))
  }
}

///|
impl @json.FromJson for GltfBuffer with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    byteLength: required_field(fields, "byteLength", path),
    uri: optional_field(fields, "uri", path),
  }
}

///|
impl @json.FromJson for GltfBufferView with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    buffer: required_field(fields, "buffer", path),
    byteOffset: optional_field(fields, "byteOffset", path),
    byteLength: required_field(fields, "byteLength", path),
    byteStride: optional_field(fields, "byteStride", path),
  }
}

///|
impl @json.FromJson for GltfPrimitiveJson with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    attributes: required_field(fields, "attributes", path),
    indices: optional_field(fields, "indices", path),
    material: optional_field(fields, "material", path),
    mode: optional_field(fields, "mode", path),
  }
}

///|
impl @json.FromJson for GltfMeshJson with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    primitives: required_field(fields, "primitives", path),
    name: optional_field(fields, "name", path),
  }
}

///|
impl @json.FromJson for GltfNodeJson with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    mesh: optional_field(fields, "mesh", path),
    children: optional_field(fields, "children", path),
    name: optional_field(fields, "name", path),
    matrix: optional_field(fields, "matrix", path),
    translation: optional_field(fields, "translation", path),
    rotation: optional_field(fields, "rotation", path),
    scale: optional_field(fields, "scale", path),
  }
}

///|
impl @json.FromJson for GltfPbrJson with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    baseColorFactor: optional_field(fields, "baseColorFactor", path),
    metallicFactor: optional_field(fields, "metallicFactor", path),
    roughnessFactor: optional_field(fields, "roughnessFactor", path),
    baseColorTexture: optional_field(fields, "baseColorTexture", path),
  }
}

///|
impl @json.FromJson for GltfMaterialJson with fn from_json(json, path) {
  let fields = object_fields(json, path)
  { pbrMetallicRoughness: optional_field(fields, "pbrMetallicRoughness", path) }
}

///|
impl @json.FromJson for GltfImageJson with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    uri: optional_field(fields, "uri", path),
    mimeType: optional_field(fields, "mimeType", path),
    bufferView: optional_field(fields, "bufferView", path),
  }
}

///|
impl @json.FromJson for GltfTextureJson with fn from_json(json, path) {
  let fields = object_fields(json, path)
  { source: optional_field(fields, "source", path) }
}

///|
impl @json.FromJson for GltfRoot with fn from_json(json, path) {
  let fields = object_fields(json, path)
  {
    asset: required_field(fields, "asset", path),
    buffers: optional_field(fields, "buffers", path),
    bufferViews: optional_field(fields, "bufferViews", path),
    accessors: optional_field(fields, "accessors", path),
    meshes: optional_field(fields, "meshes", path),
    nodes: optional_field(fields, "nodes", path),
    materials: optional_field(fields, "materials", path),
    images: optional_field(fields, "images", path),
    textures: optional_field(fields, "textures", path),
    extensionsUsed: optional_field(fields, "extensionsUsed", path),
  }
}

///|
pub(all) suberror GltfError {
  EmptyInput
  InvalidMagic
  UnsupportedVersion(Int)
  InvalidDeclaredLength
  TruncatedChunk
  MissingJsonChunk
  InvalidJson(String)
  UnsupportedAssetVersion(String)
  MissingBuffer(Int)
  MissingBufferView(Int)
  MissingAccessor(Int)
  MissingAttribute(String)
  InvalidAccessor(Int)
  UnsupportedComponentType(Int)
  UnsupportedAccessorType(String)
  UnsupportedPrimitiveMode(Int)
  UnsupportedExtension(String)
  ExternalResourceUnavailable(String)
  InvalidTexture(Int)
} derive(Eq, Debug, ToJson)

///|
/// Resolves a URI referenced by a JSON `.gltf` document.
pub type GltfResourceResolver = (String) -> Bytes?

///|
pub(all) struct GltfDocument {
  json : String
  binary : Bytes?
  mesh_count : Int
  node_count : Int
  material_count : Int
  texture_count : Int
} derive(Debug)

///|
pub fn GltfDocument::json(self : GltfDocument) -> String {
  self.json
}

///|
pub fn GltfDocument::binary(self : GltfDocument) -> Bytes? {
  self.binary
}

///|
pub fn GltfDocument::mesh_count(self : GltfDocument) -> Int {
  self.mesh_count
}

///|
pub fn GltfDocument::node_count(self : GltfDocument) -> Int {
  self.node_count
}

///|
pub fn GltfDocument::material_count(self : GltfDocument) -> Int {
  self.material_count
}

///|
pub fn GltfDocument::texture_count(self : GltfDocument) -> Int {
  self.texture_count
}

///|
pub fn parse_glb(bytes : Bytes) -> GltfDocument raise GltfError {
  if bytes.length() < 12 {
    raise GltfError::EmptyInput
  }
  if bytes[0] != b'g' ||
    bytes[1] != b'l' ||
    bytes[2] != b'T' ||
    bytes[3] != b'F' {
    raise GltfError::InvalidMagic
  }
  let version = read_u32_le(bytes, 4)
  if version != 2 {
    raise GltfError::UnsupportedVersion(version)
  }
  let declared_length = read_u32_le(bytes, 8)
  if declared_length < 12 || declared_length > bytes.length() {
    raise GltfError::InvalidDeclaredLength
  }
  let mut offset = 12
  let mut json_bytes : Bytes? = None
  let mut binary : Bytes? = None
  while offset < declared_length {
    if offset + 8 > declared_length {
      raise GltfError::TruncatedChunk
    }
    let chunk_length = read_u32_le(bytes, offset)
    let chunk_type = read_u32_le(bytes, offset + 4)
    if chunk_length % 4 != 0 {
      raise GltfError::TruncatedChunk
    }
    let chunk_start = offset + 8
    let chunk_end = chunk_start + chunk_length
    if chunk_end > declared_length || chunk_end > bytes.length() {
      raise GltfError::TruncatedChunk
    }
    if chunk_type == 0x4E4F534A {
      if json_bytes is None {
        json_bytes = Some(bytes[chunk_start:chunk_end].to_owned())
      }
    } else if chunk_type == 0x004E4942 {
      if binary is None {
        binary = Some(bytes[chunk_start:chunk_end].to_owned())
      }
    }
    offset = chunk_end
  }
  let json_chunk = match json_bytes {
    Some(value) => value
    None => raise GltfError::MissingJsonChunk
  }
  let json = @utf8.decode(json_chunk[:], ignore_bom=true) catch {
    _ => raise GltfError::InvalidJson("JSON chunk is not valid UTF-8")
  }
  parse_gltf_json(json, binary~)
}

///|
pub fn parse_gltf_json(
  json : String,
  binary? : Bytes? = None,
) -> GltfDocument raise GltfError {
  let root : GltfRoot = @json.from_json(@json.parse(json)) catch {
    err => raise GltfError::InvalidJson(err.to_string())
  }
  if root.asset.version != "2.0" {
    raise GltfError::UnsupportedAssetVersion(root.asset.version)
  }
  {
    json,
    binary,
    mesh_count: root.meshes.unwrap_or([]).length(),
    node_count: root.nodes.unwrap_or([]).length(),
    material_count: root.materials.unwrap_or([]).length(),
    texture_count: root.textures.unwrap_or([]).length(),
  }
}

///|
fn read_u32_le(bytes : Bytes, offset : Int) -> Int {
  if offset < 0 || offset + 3 >= bytes.length() {
    return 0
  }
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}
