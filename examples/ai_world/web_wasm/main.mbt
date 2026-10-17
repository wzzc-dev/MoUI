///|
/// Thin browser composition root: the web backend + WebGPU renderer + the
/// `ai_world_host` bridge (provider fetch + folder database).
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
let gateway : @llm_web.WebGateway = @llm_web.WebGateway::new()

///|
fn turn_runner(
  request : @app.LlmRequest,
  on_reply : (String?) -> Unit,
) -> Unit {
  // The body is shared with the native runner: same wire format, same parser.
  let body = @app.llm_request_body(request).stringify()
  gateway.llm_turn(
    request.endpoint(),
    request.api_key(),
    body,
    raw =>
      match raw {
        Some(text) => on_reply(@app.llm_parse_reply(text))
        None => on_reply(None)
      },
  )
}

///|
let world_host : @app.WorldHost = {
  list_worlds: done => gateway.fs_list(done),
  pick_root: done => gateway.fs_pick(done),
  read_world: (folder, done) => gateway.fs_read(folder, done),
  write_world: (folder, files, done) => gateway.fs_write(folder, files, done),
  read_config: done => gateway.config_read(done),
  write_config: (content, done) => gateway.config_write(content, done),
}

///|
fn main {
  @runtime.run_app(
    "MoUI AI World",
    @runtime.new_program_with_dimensions(
      program=@app.program(turn_runner=turn_runner, world_host=world_host),
      width=1560.0,
      height=1080.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
