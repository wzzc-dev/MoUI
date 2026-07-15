///|
priv struct PlannedFile {
  path : String
  bytes : Bytes
}

///|
priv struct ProjectOptions {
  target : String
  id : String
  module_name : String
  title : String
  moui_version : String
  platforms : Array[String]
  bundle_id : String?
}

///|
priv struct ProjectManifest {
  schema_version : Int
  id : String
  title : String
  module_name : String
  moui_version : String
  platforms : Array[String]
  bundle_id : String?
}

///|
priv struct EjectOptions {
  project_root : String
  platform : String
  output : String
  moui_root : String?
}

///|
priv struct EjectResult {
  platform : String
  output : String
  source_template_digest : String
  config_digest : String
  plugin_digest : String
  content_digest : String
  file_count : Int
}

///|
priv enum HostPlatform {
  Macos
  Windows
  Linux
  Unknown
} derive(Eq)

///|
fn HostPlatform::name(self : HostPlatform) -> String {
  match self {
    Macos => "macos"
    Windows => "windows"
    Linux => "linux"
    Unknown => "unknown"
  }
}
