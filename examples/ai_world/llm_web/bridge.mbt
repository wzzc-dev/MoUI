///|
/// The web host bridge for the AI world (wasm-gc only).
///
/// The shared app package must stay a pure TEA package, so this app-private
/// package is where the browser does its IO. Messages cross the boundary with
/// the same exported-callback protocol the web backend's clipboard uses:
///
/// - MoonBit builds a JSON request and passes it to the `ai_world_host` JS
///   module through the `begin_create_string`/`string_append_char` handshake,
///   arriving as an opaque string id.
/// - The page's JS performs the fetch / directory operation and finally calls
///   the exported `ai_llm_complete` / `ai_fs_complete`, handing back another
///   string id; MoonBit reads it with `begin_read_string` and resolves the
///   pending callback.
///
/// Callbacks never cross the boundary: they stay in MoonBit-side maps keyed by
/// request id, which is what keeps the web target's single-threaded pump in
/// charge of every state change.

///|
extern "wasm" fn host_llm_submit(
  request_id : Int,
  endpoint_id : Int,
  key_id : Int,
  body_id : Int,
) -> Unit = "ai_world_host" "llm_submit"

///|
extern "wasm" fn host_fs_pick(request_id : Int) -> Unit = "ai_world_host" "fs_pick"

///|
extern "wasm" fn host_fs_list(request_id : Int) -> Unit = "ai_world_host" "fs_list"

///|
extern "wasm" fn host_fs_read(request_id : Int, folder_id : Int) -> Unit = "ai_world_host" "fs_read"

///|
extern "wasm" fn host_fs_write(
  request_id : Int,
  folder_id : Int,
  manifest_id : Int,
) -> Unit = "ai_world_host" "fs_write"

///|
extern "wasm" fn host_fs_config_read(request_id : Int) -> Unit = "ai_world_host" "fs_config_read"

///|
extern "wasm" fn host_fs_config_write(
  request_id : Int,
  content_id : Int,
) -> Unit = "ai_world_host" "fs_config_write"

///|
extern "wasm" fn host_fs_export_world(
  request_id : Int,
  folder_id : Int,
  manifest_id : Int,
) -> Unit = "ai_world_host" "fs_export_world"

///|
extern "wasm" fn host_fs_import_world(request_id : Int) -> Unit = "ai_world_host" "fs_import_world"

///|
extern "wasm" fn host_begin_create_string() -> Int = "ai_world_host" "begin_create_string"

///|
extern "wasm" fn host_string_append_char(handle : Int, code : Int) -> Unit = "ai_world_host" "string_append_char"

///|
extern "wasm" fn host_finish_create_string(handle : Int) -> Int = "ai_world_host" "finish_create_string"

///|
extern "wasm" fn host_begin_read_string(id : Int) -> Int = "ai_world_host" "begin_read_string"

///|
extern "wasm" fn host_string_read_char(handle : Int) -> Int = "ai_world_host" "string_read_char"

///|
extern "wasm" fn host_finish_read_string(handle : Int) -> Unit = "ai_world_host" "finish_read_string"

///|
/// Build a string on the JS side, receiving its id for later host calls.
fn host_string_id(text : String) -> Int {
  let handle = host_begin_create_string()
  for ch in text {
    host_string_append_char(handle, ch.to_int())
  }
  host_finish_create_string(handle)
}

///|
/// Read a JS-side string by id.
fn host_string(text_id : Int) -> String {
  if text_id == 0 {
    return ""
  }
  let handle = host_begin_read_string(text_id)
  let chars : Array[Char] = []
  let mut code = host_string_read_char(handle)
  while code >= 0 {
    // The page sends Unicode code points (`codePointAt`); a malformed one is
    // replaced rather than trapping the read loop.
    chars.push(code.to_char().unwrap_or('�'))
    code = host_string_read_char(handle)
  }
  host_finish_read_string(handle)
  String::from_array(chars)
}

///|
pub(all) enum FsJob {
  ListDone((Array[String]) -> Unit)
  ReadDone((Bool, Array[(String, String)]) -> Unit)
  WriteDone((Bool) -> Unit)
  ConfigRead((String?) -> Unit)
  ConfigWrite((Bool) -> Unit)
  ExportDone((Bool) -> Unit)
  ImportDone((Bool, String, Array[(String, String)]) -> Unit)
}

///|
/// The gateway: one instance per web composition root, created before the
/// program starts and shared by the ABI callbacks.
pub struct WebGateway {
  next_id : Ref[Int]
  llm_pending : Map[Int, (String?) -> Unit]
  fs_pending : Map[Int, FsJob]
}

///|
pub fn WebGateway::new() -> WebGateway {
  { next_id: Ref(1), llm_pending: {}, fs_pending: {}, }
}

///|
fn allocate(gateway : WebGateway) -> Int {
  let id = gateway.next_id.val
  gateway.next_id.val = gateway.next_id.val + 1
  id
}

///|
/// Start one provider request. `on_result` receives the raw HTTP body text
/// (or `None` after a transport failure); parsing the completion choice is
/// the composition root's job, shared with the native runner.
pub fn WebGateway::llm_turn(
  self : WebGateway,
  endpoint : String,
  api_key : String,
  body : String,
  on_result : (String?) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.llm_pending[id] = on_result
  host_llm_submit(
    id,
    host_string_id(endpoint),
    host_string_id(api_key),
    host_string_id(body),
  )
}

///|
/// The exported callback for provider replies.
pub fn WebGateway::llm_complete(
  self : WebGateway,
  request_id : Int,
  ok : Bool,
  body_text_id : Int,
) -> Unit {
  match self.llm_pending.get(request_id) {
    Some(on_result) => {
      self.llm_pending.remove(request_id)
      if ok {
        on_result(Some(host_string(body_text_id)))
      } else {
        on_result(None)
      }
    }
    None => ()
  }
}

///|
/// Ask the page for a library root (a directory-picker user gesture). Reports
/// the world-folder names found in it.
pub fn WebGateway::fs_pick(
  self : WebGateway,
  on_done : (Array[String]) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = ListDone(on_done)
  host_fs_pick(id)
}

///|
/// Re-list the library without a picker (recentre on the stored root).
pub fn WebGateway::fs_list(
  self : WebGateway,
  on_done : (Array[String]) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = ListDone(on_done)
  host_fs_list(id)
}

///|
/// Read one world folder; reports its `.md` files as `(path, content)` pairs.
pub fn WebGateway::fs_read(
  self : WebGateway,
  folder : String,
  on_done : (Bool, Array[(String, String)]) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = ReadDone(on_done)
  host_fs_read(id, host_string_id(folder))
}

///|
/// Write every file of one world folder.
pub fn WebGateway::fs_write(
  self : WebGateway,
  folder : String,
  files : Array[(String, String)],
  on_done : (Bool) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = WriteDone(on_done)
  host_fs_write(id, host_string_id(folder), host_string_id(files_json(files)))
}

///|
/// Read `config.json` at the library root. `None` = missing or unreadable.
pub fn WebGateway::config_read(
  self : WebGateway,
  on_done : (String?) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = ConfigRead(on_done)
  host_fs_config_read(id)
}

///|
/// Write `config.json` at the library root.
pub fn WebGateway::config_write(
  self : WebGateway,
  content : String,
  on_done : (Bool) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = ConfigWrite(on_done)
  host_fs_config_write(id, host_string_id(content))
}

///|
/// Write one world out as a shareable bundle.
pub fn WebGateway::fs_export_world(
  self : WebGateway,
  folder : String,
  files : Array[(String, String)],
  on_done : (Bool) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = ExportDone(on_done)
  host_fs_export_world(
    id,
    host_string_id(folder),
    host_string_id(files_json(files)),
  )
}

///|
/// Pick a bundle and unpack it into a new world folder.
pub fn WebGateway::fs_import_world(
  self : WebGateway,
  on_done : (Bool, String, Array[(String, String)]) -> Unit,
) -> Unit {
  let id = allocate(self)
  self.fs_pending[id] = ImportDone(on_done)
  host_fs_import_world(id)
}

///|
/// The exported callback for filesystem results.
pub fn WebGateway::fs_complete(
  self : WebGateway,
  request_id : Int,
  ok : Bool,
  payload_text_id : Int,
) -> Unit {
  let payload = if ok { host_string(payload_text_id) } else { "" }
  match self.fs_pending.get(request_id) {
    Some(ListDone(on_done)) => {
      self.fs_pending.remove(request_id)
      on_done(if ok { parse_names(payload) } else { [] })
    }
    Some(ReadDone(on_done)) => {
      self.fs_pending.remove(request_id)
      if ok {
        on_done(true, parse_files(payload))
      } else {
        on_done(false, [])
      }
    }
    Some(WriteDone(on_done)) => {
      self.fs_pending.remove(request_id)
      on_done(ok)
    }
    Some(ConfigRead(on_done)) => {
      self.fs_pending.remove(request_id)
      if ok {
        // The page wraps the file in {"content": ...}; unwrap before handing
        // the raw JSON to the app.
        on_done(Some(config_content(payload)))
      } else {
        on_done(None)
      }
    }
    Some(ConfigWrite(on_done)) => {
      self.fs_pending.remove(request_id)
      on_done(ok)
    }
    Some(ExportDone(on_done)) => {
      self.fs_pending.remove(request_id)
      on_done(ok)
    }
    Some(ImportDone(on_done)) => {
      self.fs_pending.remove(request_id)
      if ok {
        // The page answers with `{folder, files}`; a damaged payload is a
        // failed import rather than a half-built world.
        match parse_imported(payload) {
          Some(imported) => on_done(true, imported.0, parse_files(imported.1))
          None => on_done(false, "", [])
        }
      } else {
        on_done(false, "", [])
      }
    }
    None => ()
  }
}

///|
fn files_json(files : Array[(String, String)]) -> String {
  let rows : Array[Json] = []
  for pair in files {
    rows.push(Json::array([Json::string(pair.0), Json::string(pair.1)]))
  }
  let root : Map[String, Json] = { "files": Json::array(rows) }
  root.to_json().stringify()
}

///|
fn config_content(payload : String) -> String {
  let parsed = @json.parse(payload) catch { _ => return payload }
  match parsed {
    Object(fields) =>
      match fields.get("content") {
        Some(String(content)) => content
        _ => payload
      }
    _ => payload
  }
}

///|
/// Decode `{"names": [...]}` from the JS host.
fn parse_names(payload : String) -> Array[String] {
  let names : Array[String] = []
  let parsed = @json.parse(payload) catch { _ => return names }
  match parsed {
    Object(fields) =>
      match fields.get("names") {
        Some(Array(values)) =>
          for value in values {
            match value {
              String(name) => names.push(name)
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  names
}

///|
/// Decode `{"folder": "...", "files": [[path, content], ...]}` from the JS
/// host. Returns the folder plus the raw `files` JSON array text so the
/// existing row decoder can be reused.
fn parse_imported(payload : String) -> (String, String)? {
  let parsed = @json.parse(payload) catch { _ => return None }
  match parsed {
    Object(fields) =>
      match fields.get("folder") {
        Some(String(folder)) =>
          match fields.get("files") {
            Some(Array(_)) =>
              Some(
                (
                  folder,
                  Json::object({ "files": fields.get("files").unwrap() }).stringify(),
                ),
              )
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Decode `{"files": [[path, content], ...]}` from the JS host.
fn parse_files(payload : String) -> Array[(String, String)] {
  let files : Array[(String, String)] = []
  let parsed = @json.parse(payload) catch { _ => return files }
  match parsed {
    Object(fields) =>
      match fields.get("files") {
        Some(Array(values)) =>
          for value in values {
            match value {
              Array(pair) =>
                if pair.length() == 2 {
                  match (pair[0], pair[1]) {
                    (String(path), String(content)) =>
                      files.push((path, content))
                    _ => ()
                  }
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  files
}
