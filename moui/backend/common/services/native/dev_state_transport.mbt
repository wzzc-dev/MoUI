///|
/// Dev-loop state file path from `MOUI_DEV_STATE_FILE`, which `moui dev`
/// sets for every native restart (default `.moui/dev-state.json`). Returns
/// `None` when unset or empty so apps running outside the dev loop stay
/// inert.
pub fn dev_state_transport_path() -> String? {
  match @env.get_env_var("MOUI_DEV_STATE_FILE") {
    Some(path) => if path != "" { Some(path) } else { None }
    None => None
  }
}

///|
/// File-backed transport for state-preserving dev restarts over the dev-loop
/// state file. Failures are swallowed: the handoff is best-effort dev
/// convenience, never a correctness dependency.
pub fn dev_state_transport(path : String) -> @core.ProgramStateTransport {
  @core.ProgramStateTransport::new(
    read=() => {
      if @fs.path_exists(path) {
        let bytes = @fs.read_file_to_bytes(path) catch { _ => return None }
        Some(@utf8.decode_lossy(bytes[:], ignore_bom=true))
      } else {
        None
      }
    },
    write=payload => {
      let bytes = @utf8.encode(payload[:], bom=false)
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return ()
      }
    },
  )
}
