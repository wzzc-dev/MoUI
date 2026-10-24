///|
/// Thin browser composition root: the web backend + WebGPU renderer + the
/// `new_world_host` bridge (provider fetch + folder database).
///
/// The world, the cards, and both reply paths live in the app package. This
/// file injects the two IO capabilities `update` cannot own:
///
/// - a `TurnRunner` that submits an OpenAI-compatible request through
///   `@llm_web` and feeds the parsed reply back as a typed `Reply`;
/// - a `WorldHost` that lists / reads / writes one world folder of the
///   player's library through the same bridge (a real directory when the
///   File System Access API is available, an equivalent in-page store when
///   it is not).

///|
let gateway : @llm_web_gateway.WebGateway = @llm_web_gateway.WebGateway::new()

///|
fn turn_runner(
  request : @world_app.LlmRequest,
  on_reply : (String?) -> Unit,
  on_delta : (String) -> Unit,
) -> Unit {
  // The body is shared with the native runner: same wire format, same parser.
  // The provider is asked for a stream: the reply arrives in pieces, and
  // each piece is shown on the stage while it is still being written.
  let body = @world_app.llm_request_body(request, stream=true).stringify()
  gateway.llm_turn(
    request.endpoint(),
    request.api_key(),
    body,
    raw => {
      match raw {
        Some(text) => on_reply(@world_app.llm_parse_reply(text))
        None => on_reply(None)
      }
    },
    delta => on_delta(delta),
  )
}

///|
let world_host : @world_app.WorldHost = {
  list_worlds: done => gateway.fs_list(done),
  pick_root: done => gateway.fs_pick(done),
  read_world: (folder, done) => gateway.fs_read(folder, done),
  write_world: (folder, files, done) => gateway.fs_write(folder, files, done),
  read_config: done => gateway.config_read(done),
  write_config: (content, done) => gateway.config_write(content, done),
  export_world: (folder, files, done) => {
    gateway.fs_export_world(folder, files, done)
  },
  import_world: done => gateway.fs_import_world(done),
  copy_to_clipboard: text => gateway.copy_to_clipboard(text),
}

///|
fn main {
  @runtime.run_app(
    "MoUI New World",
    // Initial logical size only: the runtime replaces it with the canvas's
    // measured size on the first resize, and the shell derives wide / medium /
    // compact from whatever it reports. 1200×800 is the designed workbench, so
    // a host that never resizes still gets a sane frame.
    @runtime.new_program_with_dimensions(
      program=@world_app.program(turn_runner~, world_host~),
      width=1200.0,
      height=800.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
