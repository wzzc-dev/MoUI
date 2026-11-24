///|
#borrow(path, config)
extern "C" fn moui_devhost_open(
  path : Bytes,
  path_len : Int32,
  config : Bytes,
  config_len : Int32,
) -> Int32 = "moui_devhost_open"

///|
#borrow(path, config)
extern "C" fn moui_devhost_reload(
  path : Bytes,
  path_len : Int32,
  config : Bytes,
  config_len : Int32,
) -> Int32 = "moui_devhost_reload"

///|
#borrow(data)
extern "C" fn moui_devhost_event(data : Bytes, length : Int32) -> Int32 = "moui_devhost_event"

///|
extern "C" fn moui_devhost_frame() -> Bytes = "moui_devhost_frame"

///|
#borrow(data)
extern "C" fn moui_devhost_semantics_action(
  data : Bytes,
  length : Int32,
) -> Bytes = "moui_devhost_semantics_action"

///|
extern "C" fn moui_devhost_resize(width : Double, height : Double) -> Unit = "moui_devhost_resize"

///|
extern "C" fn moui_devhost_destroy() -> Unit = "moui_devhost_destroy"

///|
extern "C" fn moui_devhost_reexec() -> Unit = "moui_devhost_reexec"

///|
priv struct HostSettings {
  config_json : String
  generation_path : String?
}

///|
let host_settings : Ref[HostSettings?] = Ref(None)

///|
let host_generation : Ref[String] = Ref("")

///|
let host_reloads : Ref[Int32] = Ref(0)

///|
/// Installed by the generated host once a renderer session binds. The host
/// keeps the renderer across plugin swaps, so the session must drop source-
/// keyed caches after a generation change. `None` means no renderer has bound
/// yet (startup/shutdown) or a renderer without a reset path was selected.
let renderer_cache_reset : Ref[(() -> Unit)?] = Ref(None)

///|
let host_polls : Ref[Int32] = Ref(0)

///|
let host_frames : Ref[Int32] = Ref(0)

///|
/// Number of newline-terminated lines already dispatched from the dev event
/// injection file. Hot smokes use this to drive synthetic input without
/// reaching into the plugin image.
let host_injected_lines : Ref[Int32] = Ref(0)

///|
/// macOS keeps MoonBit dylibs mapped after `dlclose`, so the host re-execs
/// itself after a bounded number of successful swaps instead of leaking an
/// image per edit. Linux `dlclose` unmaps the image, so the dev runner sets
/// the budget to `0` there; `0` disables the budget entirely. Windows
/// `FreeLibrary` unload behaviour is not measured yet, so the dev runner keeps
/// the conservative 32-swap budget there.
fn reload_limit() -> Int32 {
  match env_nonempty("MOUI_HOT_RELOAD_LIMIT") {
    Some(value) => @string.parse_int(value[:]) catch { _ => 32 }
    None => 32
  }
}

///|
fn hot_debug(message : String) -> Unit {
  if env_nonempty("MOUI_HOT_DEBUG") is Some(_) {
    println("moui-devhost: " + message)
  }
}

///|
fn env_nonempty(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) if value != "" => Some(value)
    _ => None
  }
}

///|
/// Plugin path set by the dev runner. Returns `None` outside `moui dev --hot`.
pub fn plugin_path_from_env() -> String? {
  env_nonempty("MOUI_HOT_PLUGIN")
}

///|
/// Published generation marker set by the dev runner. Its content is the
/// current generation's absolute dylib path: `dlopen` identifies images by
/// path, so a reload must name a new file instead of rewriting the old one.
pub fn generation_path_from_env() -> String? {
  env_nonempty("MOUI_HOT_GENERATION")
}

///|
fn utf8_bytes(text : String) -> Bytes {
  @utf8.encode(text[:], bom=false)
}

///|
fn read_generation(path : String) -> String? {
  if !@fs.path_exists(path) {
    return None
  }
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return None }
  Some(@utf8.decode_lossy(bytes[:], ignore_bom=true).trim().to_owned())
}

///|
/// Load the first plugin generation and publish it through DevTools. The host
/// runtime is created after this call, so plugin state restoration happens
/// before the first frame.
pub fn initialize(
  plugin_path : String,
  width : Double,
  height : Double,
) -> Bool {
  let config = @protocol.DevConfig::new(
    width~,
    height~,
    state_file=env_nonempty("MOUI_DEV_STATE_FILE"),
    transient_file=env_nonempty("MOUI_DEV_TRANSIENT_FILE"),
  )
  let config_json = @protocol.encode_config(config)
  let path_bytes = utf8_bytes(plugin_path)
  let config_bytes = utf8_bytes(config_json)
  let result = moui_devhost_open(
    path_bytes,
    path_bytes.length(),
    config_bytes,
    config_bytes.length(),
  )
  if result != 0 {
    return false
  }
  clear_after_reload()
  let generation_path = generation_path_from_env()
  // The initial image is the env path; the next marker poll may move the host
  // onto a newer published generation.
  host_generation.val = plugin_path
  host_reloads.val = 0
  host_settings.val = Some({ config_json, generation_path, })
  true
}

///|
/// Poll the generation marker. A changed marker asks the bridge to load the
/// new dylib; a failed load keeps the previous generation live.
pub fn poll_reload() -> Bool {
  let settings = match host_settings.val {
    Some(settings) => settings
    None => return false
  }
  if host_polls.val == 0 {
    hot_debug("polling started")
  }
  host_polls.val = host_polls.val + 1
  let generation_path = match settings.generation_path {
    Some(path) => path
    None => return false
  }
  let next_path = match read_generation(generation_path) {
    Some(path) => path
    None => return false
  }
  if next_path == host_generation.val {
    return false
  }
  let path_bytes = utf8_bytes(next_path)
  let config_bytes = utf8_bytes(settings.config_json)
  let result = moui_devhost_reload(
    path_bytes,
    path_bytes.length(),
    config_bytes,
    config_bytes.length(),
  )
  if result != 0 {
    hot_debug("reload failed; keeping " + host_generation.val)
    return false
  }
  hot_debug("reloaded " + next_path)
  host_generation.val = next_path
  host_reloads.val = host_reloads.val + 1
  clear_after_reload()
  // `host_reloads` counts swaps; the plugin generation that the host is now
  // serving is one past it (the initial plugin is generation 1).
  hot_debug(
    "renderer caches reset after generation " +
    (host_reloads.val + 1).to_string(),
  )
  let limit = reload_limit()
  if limit > 0 && host_reloads.val >= limit {
    // Flush state before replacing the image; the re-exec reads the same
    // marker and state files.
    shutdown()
    moui_devhost_reexec()
    false
  } else {
    true
  }
}

///|
/// Forward one host event to the plugin. Unsupported events stay on the host
/// side instead of entering a lossy protocol path.
pub fn dispatch_event(event : @core.AppEvent) -> Bool {
  match @protocol.encode_event(event) {
    Some(payload) => {
      let bytes = utf8_bytes(payload)
      moui_devhost_event(bytes, bytes.length()) == 0
    }
    None => false
  }
}

///|
/// How often the debug frame trace repeats. `0` traces only the first frame.
fn frame_trace_interval() -> Int32 {
  match env_nonempty("MOUI_HOT_FRAME_TRACE_INTERVAL") {
    Some(value) => @string.parse_int(value[:]) catch { _ => 30 }
    None => 30
  }
}

///|
fn draw_command_kind(command : @core.DrawCommand) -> String {
  match command {
    @core.DrawCommand::Clear(_) => "clear"
    @core.DrawCommand::FillRect(_) => "fill_rect"
    @core.DrawCommand::StrokeRect(_) => "stroke_rect"
    @core.DrawCommand::FillRoundedRect(_) => "fill_rounded_rect"
    @core.DrawCommand::StrokeRoundedRect(_) => "stroke_rounded_rect"
    @core.DrawCommand::FillRoundedRectBrush(_) => "fill_rounded_rect_brush"
    @core.DrawCommand::StrokeRoundedRectBrush(_) => "stroke_rounded_rect_brush"
    @core.DrawCommand::DrawShadow(_) => "draw_shadow"
    @core.DrawCommand::DrawText(_) => "draw_text"
    @core.DrawCommand::DrawImage(_) => "draw_image"
    @core.DrawCommand::PushClip(_) => "push_clip"
    @core.DrawCommand::PopClip => "pop_clip"
    @core.DrawCommand::PushRoundedClip(_) => "push_rounded_clip"
    @core.DrawCommand::PopRoundedClip => "pop_rounded_clip"
    @core.DrawCommand::PushPathClip(_) => "push_path_clip"
    @core.DrawCommand::PopPathClip => "pop_path_clip"
    @core.DrawCommand::PushTransform(_) => "push_transform"
    @core.DrawCommand::PopTransform => "pop_transform"
    @core.DrawCommand::PushOpacity(_) => "push_opacity"
    @core.DrawCommand::PopOpacity => "pop_opacity"
    @core.DrawCommand::PushLayer(_) => "push_layer"
    @core.DrawCommand::PopLayer => "pop_layer"
    @core.DrawCommand::BeginRetainedLayer(_) => "begin_retained_layer"
    @core.DrawCommand::EndRetainedLayer(_) => "end_retained_layer"
    @core.DrawCommand::PushFilter(_) => "push_filter"
    @core.DrawCommand::PopFilter => "pop_filter"
    @core.DrawCommand::DrawPath(_) => "draw_path"
    @core.DrawCommand::DrawShaderEffect(_) => "draw_shader_effect"
  }
}

///|
/// Debug-only frame summary. It gives the hot smoke a cheap way to assert that
/// a real app produced the expected command vocabulary, no unsupported
/// commands, and the text it expected after a state-restoring swap.
fn trace_frame(payload : @protocol.FramePayload) -> Unit {
  host_frames.val = host_frames.val + 1
  if env_nonempty("MOUI_HOT_DEBUG") is None {
    return
  }
  let interval = frame_trace_interval()
  let due = host_frames.val == 1 ||
    (interval > 0 && host_frames.val % interval == 0)
  if !due {
    return
  }
  let commands = payload.commands()
  let kinds : Array[String] = []
  let texts : Array[String] = []
  for command in commands {
    kinds.push(draw_command_kind(command))
    match command {
      @core.DrawCommand::DrawText(run) => texts.push(run.text)
      _ => ()
    }
  }
  let mut summary = "frame " +
    host_frames.val.to_string() +
    " commands=" +
    commands.length().to_string() +
    " unsupported=" +
    payload.unsupported().to_string() +
    " kinds=" +
    kinds.join(",")
  if texts.length() > 0 {
    summary = summary + " texts=[" + texts.join(" || ") + "]"
  }
  hot_debug(summary)
}

///|
fn decode_frame_payload() -> @protocol.FramePayload? {
  let bytes = moui_devhost_frame()
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  @protocol.decode_frame_payload(text)
}

///|
fn with_clear(
  commands : Array[@core.DrawCommand],
  clear_color : @core.Color,
) -> Array[@core.DrawCommand] {
  let starts_with_clear = if commands.length() > 0 {
    match commands[0] {
      @core.DrawCommand::Clear(_) => true
      _ => false
    }
  } else {
    false
  }
  if starts_with_clear {
    return commands
  }
  let output : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(clear_color),
  ]
  for command in commands {
    output.push(command)
  }
  output
}

///|
/// Decode the plugin's current frame for the bridge paint pass and publish the
/// platform state it carries. The frame's `clear_color` becomes a leading
/// `Clear` command because a host `DrawFrame` paints commands rather than
/// carrying a separate clear color. A corrupt frame paints nothing and leaves
/// the last presented frame in place.
pub fn frame_commands() -> Array[@core.DrawCommand] {
  match decode_frame_payload() {
    Some(payload) => {
      ignore(publish_frame(payload))
      trace_frame(payload)
      with_clear(payload.commands(), payload.clear_color())
    }
    None => []
  }
}

///|
/// Decode and dispatch one JSON `AppEvent`. Shared by the injection hook and
/// by tests that need to drive the plugin without a platform event source.
pub fn dispatch_event_json(payload : String) -> Bool {
  match @protocol.decode_event(payload) {
    Some(event) => dispatch_event(event)
    None => false
  }
}

///|
/// Dev-only event injection. `MOUI_HOT_INJECT_FILE` names a file of JSON
/// `AppEvent` lines; each complete line is dispatched exactly once. The hot
/// smoke uses this to synthesize input (a click that increments the model)
/// without depending on `xdotool` or a platform-specific input driver.
pub fn poll_injected_events() -> Unit {
  let path = match env_nonempty("MOUI_HOT_INJECT_FILE") {
    Some(path) => path
    None => return
  }
  if !@fs.path_exists(path) {
    return
  }
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  let pieces = text.split("\n").to_array()
  // The last piece is incomplete whether or not the file ends in a newline;
  // only complete lines are dispatched, so a partially written append is
  // picked up on the next poll instead of being lost as invalid JSON.
  let complete = if pieces.length() > 0 { pieces.length() - 1 } else { 0 }
  let mut consumed = 0
  for index in 0..<complete {
    let line = pieces[index].trim()
    if index >= host_injected_lines.val && line != "" {
      let accepted = dispatch_event_json(line.to_owned())
      let prefix = if accepted { "injected " } else { "rejected injection " }
      hot_debug(prefix + line.to_owned())
    }
    consumed = consumed + 1
  }
  host_injected_lines.val = consumed
}

///|
/// Forward a host resize to the plugin runtime.
pub fn resize(width : Double, height : Double) -> Unit {
  moui_devhost_resize(width, height)
}

///|
/// Flush transient state and unload the plugin. Safe to call after a failed
/// initialization.
pub fn shutdown() -> Unit {
  moui_devhost_destroy()
  host_settings.val = None
  host_generation.val = ""
  clear_after_reload()
  renderer_cache_reset.val = None
}

///|
/// Development diagnostic: print the raw plugin frame when
/// `MOUI_HOT_DUMP_FRAME` is set. Used by the Phase 0 evidence harness and kept
/// inert in normal runs.
pub fn dump_frame_if_requested() -> Unit {
  match env_nonempty("MOUI_HOT_DUMP_FRAME") {
    Some(_) => {
      let bytes = moui_devhost_frame()
      eprintln(@utf8.decode_lossy(bytes[:], ignore_bom=true))
    }
    None => ()
  }
}
