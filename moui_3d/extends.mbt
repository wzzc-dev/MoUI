// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend Aabb with Debug::{to_repr}

///|
#doc(hidden)
pub extend Aabb with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Aabb with ToJson::{to_json}

///|
#doc(hidden)
pub extend AlphaMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend AlphaMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AlphaMode with ToJson::{to_json}

///|
#doc(hidden)
pub extend AnimationChannel with Debug::{to_repr}

///|
#doc(hidden)
pub extend AnimationClip with Debug::{to_repr}

///|
#doc(hidden)
pub extend AnimationInterpolation with Debug::{to_repr}

///|
#doc(hidden)
pub extend AnimationInterpolation with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AnimationInterpolation with ToJson::{to_json}

///|
#doc(hidden)
pub extend AnimationKeyframe with Debug::{to_repr}

///|
#doc(hidden)
pub extend AnimationPath with Debug::{to_repr}

///|
#doc(hidden)
pub extend AnimationPath with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AnimationPath with ToJson::{to_json}

///|
#doc(hidden)
pub extend AnimationSample with Debug::{to_repr}

///|
#doc(hidden)
pub extend AssetLoadResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend Camera with Debug::{to_repr}

///|
#doc(hidden)
pub extend Camera with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Camera with ToJson::{to_json}

///|
#doc(hidden)
pub extend CameraProjection with Debug::{to_repr}

///|
#doc(hidden)
pub extend CameraProjection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CameraProjection with ToJson::{to_json}

///|
#doc(hidden)
pub extend GltfDocument with Debug::{to_repr}

///|
#doc(hidden)
pub extend GltfError with Debug::{to_repr}

///|
#doc(hidden)
pub extend GltfError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GltfError with ToJson::{to_json}

///|
#doc(hidden)
pub extend Mat4 with Debug::{to_repr}

///|
#doc(hidden)
pub extend Material with Debug::{to_repr}

///|
#doc(hidden)
pub extend Material with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Material with ToJson::{to_json}

///|
#doc(hidden)
pub extend MaterialId with Debug::{to_repr}

///|
#doc(hidden)
pub extend MaterialId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MaterialId with ToJson::{to_json}

///|
#doc(hidden)
pub extend Mesh with Debug::{to_repr}

///|
#doc(hidden)
pub extend MeshId with Debug::{to_repr}

///|
#doc(hidden)
pub extend MeshId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MeshId with ToJson::{to_json}

///|
#doc(hidden)
pub extend Node with Debug::{to_repr}

///|
#doc(hidden)
pub extend NodeId with Debug::{to_repr}

///|
#doc(hidden)
pub extend NodeId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NodeId with ToJson::{to_json}

///|
#doc(hidden)
pub extend OrbitCamera with Debug::{to_repr}

///|
#doc(hidden)
pub extend OrbitCamera with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend OrbitCamera with ToJson::{to_json}

///|
#doc(hidden)
pub extend PerspectiveCamera with Debug::{to_repr}

///|
#doc(hidden)
pub extend PerspectiveCamera with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PerspectiveCamera with ToJson::{to_json}

///|
#doc(hidden)
pub extend PickHit with Debug::{to_repr}

///|
#doc(hidden)
pub extend PickHit with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PickHit with ToJson::{to_json}

///|
#doc(hidden)
pub extend Primitive with Debug::{to_repr}

///|
#doc(hidden)
pub extend Quat with Debug::{to_repr}

///|
#doc(hidden)
pub extend Quat with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Quat with ToJson::{to_json}

///|
#doc(hidden)
pub extend Ray with Debug::{to_repr}

///|
#doc(hidden)
pub extend Ray with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Ray with ToJson::{to_json}

///|
#doc(hidden)
pub extend Sampler with Debug::{to_repr}

///|
#doc(hidden)
pub extend Sampler with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Sampler with ToJson::{to_json}

///|
#doc(hidden)
pub extend SamplerFilter with Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplerFilter with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SamplerFilter with ToJson::{to_json}

///|
#doc(hidden)
pub extend SamplerId with Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplerId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SamplerId with ToJson::{to_json}

///|
#doc(hidden)
pub extend SamplerWrap with Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplerWrap with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SamplerWrap with ToJson::{to_json}

///|
#doc(hidden)
pub extend Scene with Debug::{to_repr}

///|
#doc(hidden)
pub extend SceneDefinition with Debug::{to_repr}

///|
#doc(hidden)
pub extend SceneDefinition with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SceneDefinition with ToJson::{to_json}

///|
#doc(hidden)
pub extend Skin with Debug::{to_repr}

///|
#doc(hidden)
pub extend Texture with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureId with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextureId with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextureSource with Debug::{to_repr}

///|
#doc(hidden)
pub extend Vec2 with Debug::{to_repr}

///|
#doc(hidden)
pub extend Vec2 with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Vec2 with ToJson::{to_json}

///|
#doc(hidden)
pub extend Vec3 with Debug::{to_repr}

///|
#doc(hidden)
pub extend Vec3 with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Vec3 with ToJson::{to_json}

///|
#doc(hidden)
pub extend Vec4 with Debug::{to_repr}

///|
#doc(hidden)
pub extend Vec4 with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Vec4 with ToJson::{to_json}

///|
#doc(hidden)
pub extend Vertex with Debug::{to_repr}

///|
#doc(hidden)
pub extend Vertex with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Vertex with ToJson::{to_json}

///|
#doc(hidden)
pub extend VertexDelta with Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexDelta with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend VertexDelta with ToJson::{to_json}

///|
#doc(hidden)
pub extend ViewportEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewportEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewportSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewportStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewportStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewportStatus with ToJson::{to_json}
