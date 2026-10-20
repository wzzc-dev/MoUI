///|
/// Immutable programmatic scroll request. A monotonically increasing `id`
/// lets the runtime-owned element slot apply each request at most once.
pub(all) struct ScrollRequest {
  id : Int32
  offset : Point
} derive(Eq, Debug, ToJson)

///|
pub extend ScrollRequest with Debug::{to_repr}

///|
pub extend ScrollRequest with Eq::{not_equal, equal}

///|
pub extend ScrollRequest with ToJson::{to_json}

///|
pub fn ScrollRequest::new(id~ : Int32, offset~ : Point) -> ScrollRequest {
  { id, offset, }
}

///|
/// Immutable programmatic focus request. Reusing an id is a no-op for an
/// already mounted target.
pub(all) struct FocusRequest {
  id : Int32
  key : String
} derive(Eq, Debug, ToJson)

///|
pub extend FocusRequest with Debug::{to_repr}

///|
pub extend FocusRequest with Eq::{not_equal, equal}

///|
pub extend FocusRequest with ToJson::{to_json}

///|
pub fn FocusRequest::new(id~ : Int32, key~ : String) -> FocusRequest {
  { id, key, }
}
