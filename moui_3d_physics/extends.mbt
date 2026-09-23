// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend BodyDesc with Debug::{to_repr}

///|
#doc(hidden)
pub extend BodyDesc with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BodyDesc with ToJson::{to_json}

///|
#doc(hidden)
pub extend BodyId with Debug::{to_repr}

///|
#doc(hidden)
pub extend BodyId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BodyId with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend BodyId with ToJson::{to_json}

///|
#doc(hidden)
pub extend BodyType with Debug::{to_repr}

///|
#doc(hidden)
pub extend BodyType with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BodyType with ToJson::{to_json}

///|
#doc(hidden)
pub extend ColliderDesc with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColliderDesc with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColliderDesc with ToJson::{to_json}

///|
#doc(hidden)
pub extend ColliderId with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColliderId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColliderId with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend ColliderId with ToJson::{to_json}

///|
#doc(hidden)
pub extend PhysicsWorld with Debug::{to_repr}

///|
#doc(hidden)
pub extend RayHit with Debug::{to_repr}

///|
#doc(hidden)
pub extend Shape with Debug::{to_repr}

///|
#doc(hidden)
pub extend Shape with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Shape with ToJson::{to_json}
