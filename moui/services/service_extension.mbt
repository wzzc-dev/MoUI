///|
/// A versioned, app-facing service extension. Built-in service groups keep
/// their typed structs; an extension is the open slot for a host- or
/// third-party service that does not belong in `AppServices`.
///
/// The request/response payload is JSON because the host wire protocol already
/// uses JSON and MoonBit cannot store heterogeneous typed service closures in
/// one map. An app can wrap `call` with typed encode/decode helpers.
pub struct ServiceExtension {
  id : String
  version : String
  capability_label : String
  call_fn : (Json) -> ServiceTask[Json]
}

///|
pub fn ServiceExtension::new(
  id~ : String,
  version~ : String = "1",
  capability_label~ : String = "",
  call~ : (Json) -> ServiceTask[Json],
) -> ServiceExtension {
  { id, version, capability_label, call_fn: call, }
}

///|
pub fn ServiceExtension::id(self : ServiceExtension) -> String {
  self.id
}

///|
pub fn ServiceExtension::version(self : ServiceExtension) -> String {
  self.version
}

///|
pub fn ServiceExtension::capability_label(self : ServiceExtension) -> String {
  if self.capability_label == "" {
    self.id
  } else {
    self.capability_label
  }
}

///|
pub fn ServiceExtension::call(
  self : ServiceExtension,
  request : Json,
) -> ServiceTask[Json] {
  (self.call_fn)(request)
}

///|
/// A registered extension whose host has no implementation. It still appears
/// in capability labels, but every call completes with a typed `unavailable`.
pub fn ServiceExtension::unavailable(
  id~ : String,
  version~ : String = "1",
  capability_label~ : String = "",
) -> ServiceExtension {
  ServiceExtension::new(id~, version~, capability_label~, call=_request => {
    unavailable_task(
      id + ":extension",
      if capability_label == "" {
        id
      } else {
        capability_label
      },
    )
  })
}
