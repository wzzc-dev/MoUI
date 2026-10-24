///|
/// World bundles: one world folder as a single shareable file.
///
/// The whole point of "the database is a folder" is that a world is portable.
/// A bundle is that folder serialized to one JSON file — every path and its
/// text — so a player can send a world to a friend, keep it in a git repo, or
/// move it between machines without a zip dependency on either host.
///
/// The format is intentionally boring:
///
///     {"format":"moui.new-world/2","name":"<world>","files":[["world.md","…"], …]}
///
/// Every decode is defensive, matching the folder codec: a damaged bundle is
/// rejected whole (there is nothing sensible to salvage from a truncated
/// archive), but a bundle whose `name` is unusable still imports under a
/// sanitized folder name.

///|
/// Marker so a future format change can be detected and refused instead of
/// silently mis-parsed. v2 added the six-block character cards and the
/// per-character memory files; v1 bundles still decode (their cards load
/// through the legacy tolerance path).
pub let bundle_format : String = "moui.new-world/2"

///|
/// The previous format, still readable.
let bundle_format_v1 : String = "moui.new-world/1"

///|
/// File extension a host should offer in its save/open dialog.
pub let bundle_extension : String = ".aiworld.json"

///|
/// Serialize a world's files into one bundle body.
pub fn bundle_encode(name : String, files : Array[(String, String)]) -> String {
  let rows : Array[Json] = []
  for pair in files {
    rows.push(Json::array([Json::string(pair.0), Json::string(pair.1)]))
  }
  let root : Map[String, Json] = {
    "format": Json::string(bundle_format),
    "name": Json::string(name),
    "files": Json::array(rows),
  }
  Json::object(root).stringify()
}

///|
/// One decoded bundle.
pub(all) struct WorldBundle {
  /// The folder name the bundle asks for, already sanitized for use inside a
  /// library.
  name : String
  files : Array[(String, String)]
} derive(Eq, Debug)

///|
pub extend WorldBundle with Debug::{to_repr}

///|
pub extend WorldBundle with Eq::{not_equal, equal}

///|
/// Parse a bundle body. `None` means the text is not a bundle this build can
/// read: wrong format marker, no files, or unparseable JSON.
pub fn bundle_decode(text : String) -> WorldBundle? {
  let parsed = @json.parse(text) catch { _ => return None }
  let fields = match parsed {
    Object(values) => values
    _ => return None
  }
  match fields.get("format") {
    Some(String(format)) =>
      if format != bundle_format && format != bundle_format_v1 {
        return None
      }
    _ => return None
  }
  let files : Array[(String, String)] = []
  match fields.get("files") {
    Some(Array(rows)) =>
      for row in rows {
        match row {
          Array(pair) =>
            if pair.length() == 2 {
              match (pair[0], pair[1]) {
                (String(path), String(content)) =>
                  // Only world files may enter a library: a bundle must not be
                  // able to write `.ssh/config` or escape the world folder.
                  // Portraits ride in the bundle too: a world sent to a friend
                  // should arrive with its faces, and the base64 form is
                  // already how the host carries them.
                  if (is_world_file_name(path) || is_portrait_file_name(path)) &&
                    !path.contains("..") {
                    files.push((path, content))
                  }
                _ => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  if files.is_empty() {
    return None
  }
  let name = match fields.get("name") {
    Some(String(value)) => world_folder_name(value)
    _ => "导入的世界"
  }
  Some({ name, files, })
}

///|
/// A folder name not already present in `taken`: the bundle's name, then
/// `名字 (2)`, `名字 (3)`, … Import must never merge into an existing world,
/// which would silently mix two histories.
pub fn unique_world_name(name : String, taken : Array[String]) -> String {
  let base = world_folder_name(name)
  if !taken.contains(base) {
    return base
  }
  let mut index = 2
  let mut candidate = "\{base} (\{index})"
  while taken.contains(candidate) {
    index += 1
    candidate = "\{base} (\{index})"
  }
  candidate
}

///|
/// The bundle body for one world on stage, or `None` when nothing is open.
///
/// Uses the same payload as a world-scope commit: the Markdown files, every
/// conversation file, and the event log. `config.json` is never included.
pub fn WorldModel::bundle_text(self : WorldModel) -> String? {
  match self.current {
    None => None
    Some(folder) => Some(bundle_encode(folder, commit_files(self, World)))
  }
}
