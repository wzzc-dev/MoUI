///|
/// State-preserving dev restart restore: when the program declares persistence
/// and the composition root supplies a transport, read the payload and recover
/// the model after init. Init effects still run; a missing, stale, or
/// unreadable payload falls back to the init model.
fn[Model, Msg] program_restore_model(
  program : @core.Program[Model, Msg],
  state_transport : @core.ProgramStateTransport?,
  initial_model : Model,
) -> Model {
  match (program.runtime_state_persistence(), state_transport) {
    (Some(persistence), Some(transport)) =>
      match transport.read() {
        Some(payload) =>
          match persistence.load(payload) {
            Some(restored) => restored
            None => initial_model
          }
        None => initial_model
      }
    _ => initial_model
  }
}

///|
/// Write the serialized model back through the transport after every
/// committed update so a dev-loop restart resumes from the last update.
fn[Model, Msg] program_save_model(
  program : @core.Program[Model, Msg],
  state_transport : @core.ProgramStateTransport?,
  model : Model,
) -> Unit {
  match (program.runtime_state_persistence(), state_transport) {
    (Some(persistence), Some(transport)) =>
      transport.write(persistence.save(model))
    _ => ()
  }
}
