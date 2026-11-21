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
/// macOS keeps MoonBit dylibs mapped after `dlclose`, so the host re-execs
/// itself after a bounded number of successful swaps instead of leaking an
/// image per edit. `0` disables the budget for a single spike run.
fn reload_limit() -> Int32 {
  match env_nonempty("MOUI_HOT_RELOAD_LIMIT") {
    Some(value) =>
      try {
        @string.parse_int(value[:])
      } catch {
        _ => 32
      }
    None => 32
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
pub fn initialize(plugin_path : String, width : Double, height : Double) -> Bool {
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
  let generation_path = generation_path_from_env()
  // The initial image is the env path; the next marker poll may move the host
  // onto a newer published generation.
  host_generation.val = plugin_path
  host_reloads.val = 0
  host_settings.val = Some({
    config_json,
    generation_path,
  })
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
    return false
  }
  host_generation.val = next_path
  host_reloads.val = host_reloads.val + 1
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
/// Decode the plugin's current frame for the bridge paint pass. A corrupt
/// frame paints nothing and leaves the last presented frame in place.
pub fn frame_commands() -> Array[@core.DrawCommand] {
  let bytes = moui_devhost_frame()
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  match @protocol.decode_frame(text) {
    Some(commands) => commands
    None => []
  }
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
