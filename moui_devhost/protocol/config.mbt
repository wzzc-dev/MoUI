///|
#derive(Eq, Debug)
pub(all) struct DevConfig {
  /// Plugin creation payload. Paths are dev-loop files; `None` keeps the app on
  /// its own init model for that transport, so an app without
  /// `program_with_dev_state` still runs.
  width : Double
  height : Double
  state_file : String?
  transient_file : String?
}

///|
pub fn DevConfig::new(
  width~ : Double,
  height~ : Double,
  state_file~ : String? = None,
  transient_file~ : String? = None,
) -> DevConfig {
  { width, height, state_file, transient_file, }
}

///|
pub fn encode_config(config : DevConfig) -> String {
  let fields : Map[String, Json] = Map([])
  fields["width"] = number_json(config.width)
  fields["height"] = number_json(config.height)
  fields["state_file"] = match config.state_file {
    Some(path) => string_json(path)
    None => Json::null()
  }
  fields["transient_file"] = match config.transient_file {
    Some(path) => string_json(path)
    None => Json::null()
  }
  Json::object(fields).stringify()
}

///|
pub fn decode_config(text : String) -> DevConfig? {
  let parsed = @json.parse(text) catch { _ => return None }
  let fields = match wire_object(Some(parsed)) {
    Some(fields) => fields
    None => return None
  }
  let width = match wire_number(fields.get("width")) {
    Some(width) => width
    None => return None
  }
  let height = match wire_number(fields.get("height")) {
    Some(height) => height
    None => return None
  }
  let state_file = match fields.get("state_file") {
    Some(Json::Null) | None => None
    Some(value) => wire_string(Some(value))
  }
  let transient_file = match fields.get("transient_file") {
    Some(Json::Null) | None => None
    Some(value) => wire_string(Some(value))
  }
  Some(DevConfig::new(width~, height~, state_file~, transient_file~))
}
