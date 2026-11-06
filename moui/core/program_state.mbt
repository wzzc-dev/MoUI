///|
/// Transport the runtime uses to hand application model state across a
/// process restart (state-preserving dev restarts). `read` returns the
/// previously persisted payload, if any; `write` persists a fresh payload.
/// Both are pure closures: the I/O ownership stays with whoever constructs
/// the transport (typically the composition root), never with `core` or the
/// runtime itself.
pub struct ProgramStateTransport {
  priv read : () -> String?
  priv write : (String) -> Unit
}

///|
/// Application-supplied model serialization contract. `save` serializes the
/// current model; `load` recovers a model from a payload, returning `None`
/// when the payload is missing, stale, or unreadable so the runtime falls
/// back to the program's own init model.
pub struct ProgramStatePersistence[Model] {
  priv save : (Model) -> String
  priv load : (String) -> Model?
}

///|
pub fn ProgramStateTransport::new(
  read~ : () -> String?,
  write~ : (String) -> Unit,
) -> ProgramStateTransport {
  { read, write, }
}

///|
pub fn ProgramStateTransport::read(self : ProgramStateTransport) -> String? {
  (self.read)()
}

///|
pub fn ProgramStateTransport::write(
  self : ProgramStateTransport,
  payload : String,
) -> Unit {
  (self.write)(payload)
}

///|
pub fn[Model] ProgramStatePersistence::new(
  save~ : (Model) -> String,
  load~ : (String) -> Model?,
) -> ProgramStatePersistence[Model] {
  { save, load, }
}

///|
pub fn[Model] ProgramStatePersistence::save(
  self : ProgramStatePersistence[Model],
  model : Model,
) -> String {
  (self.save)(model)
}

///|
pub fn[Model] ProgramStatePersistence::load(
  self : ProgramStatePersistence[Model],
  payload : String,
) -> Model? {
  (self.load)(payload)
}
