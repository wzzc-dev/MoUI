///|
/// Dev-loop model handoff for the Web `moui dev` loop. The browser keeps the
/// payload in `localStorage` across the state-preserving page refresh, so a
/// reload restores the last committed `Model` through the same
/// `ProgramStateTransport` seam the native loop uses. Only generated dev
/// composition roots construct these transports; production Web entrypoints
/// do not, so production behavior is unchanged.
pub fn dev_state_transport() -> @core.ProgramStateTransport {
  @core.ProgramStateTransport::new(
    read=() => {
      if web_settings_has_value(web_host_string(DEV_STATE_KEY)) {
        Some(
          web_host_string_to_string(
            web_settings_read(web_host_string(DEV_STATE_KEY)),
          ),
        )
      } else {
        None
      }
    },
    write=payload => {
      ignore(
        web_settings_write(
          web_host_string(DEV_STATE_KEY),
          web_host_string(payload),
        ),
      )
    },
  )
}

///|
/// Framework-owned transient handoff (scroll/focus/text selection) for the Web
/// dev refresh. Same storage and seam as `dev_state_transport`; ADR 0068
/// defines the snapshot and the restore semantics.
pub fn dev_transient_transport() -> @core.ProgramStateTransport {
  @core.ProgramStateTransport::new(
    read=() => {
      if web_settings_has_value(web_host_string(DEV_TRANSIENT_KEY)) {
        Some(
          web_host_string_to_string(
            web_settings_read(web_host_string(DEV_TRANSIENT_KEY)),
          ),
        )
      } else {
        None
      }
    },
    write=payload => {
      ignore(
        web_settings_write(
          web_host_string(DEV_TRANSIENT_KEY),
          web_host_string(payload),
        ),
      )
    },
  )
}

///|
const DEV_STATE_KEY : String = "moui.dev.state"

///|
const DEV_TRANSIENT_KEY : String = "moui.dev.transient"
