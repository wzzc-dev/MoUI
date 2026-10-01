///|
pub(all) struct PlatformViewPlacement {
  id : String
  kind : String
  frame : Rect
  clip : Rect?
  properties : Array[PlatformViewProperty]
} derive(Eq, Debug, ToJson)

///|
pub extend PlatformViewPlacement with Debug::{to_repr}

///|
pub extend PlatformViewPlacement with Eq::{not_equal, equal}

///|
pub extend PlatformViewPlacement with ToJson::{to_json}

///|
pub(all) struct PlatformViewProperty {
  key : String
  value : String
} derive(Eq, Debug, ToJson)

///|
pub extend PlatformViewProperty with Debug::{to_repr}

///|
pub extend PlatformViewProperty with Eq::{not_equal, equal}

///|
pub extend PlatformViewProperty with ToJson::{to_json}

///|
pub(all) enum PlatformViewEvent {
  Named(name~ : String, value~ : String, detail~ : String, flag~ : Bool)
} derive(Eq, Debug, ToJson)

///|
pub extend PlatformViewEvent with Debug::{to_repr}

///|
pub extend PlatformViewEvent with Eq::{not_equal, equal}

///|
pub extend PlatformViewEvent with ToJson::{to_json}

///|
pub fn PlatformViewProperty::new(
  key~ : String,
  value~ : String,
) -> PlatformViewProperty {
  { key, value, }
}

///|
pub fn PlatformViewPlacement::new(
  id~ : String,
  kind~ : String,
  frame~ : Rect,
  clip? : Rect? = None,
  properties? : Array[PlatformViewProperty] = [],
) -> PlatformViewPlacement {
  { id, kind, frame, clip, properties, }
}

///|
pub fn PlatformViewPlacement::property(
  self : PlatformViewPlacement,
  key : String,
) -> String? {
  for property in self.properties {
    if property.key == key {
      return Some(property.value)
    }
  }
  None
}

///|
pub fn PlatformViewPlacement::property_or(
  self : PlatformViewPlacement,
  key : String,
  default : String,
) -> String {
  self.property(key).unwrap_or(default)
}
