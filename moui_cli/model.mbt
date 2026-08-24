///|
let default_moui_dependency_version : String = "0.1.12"

///|
/// The web renderer releases independently from the framework; generated
/// projects pin it separately so a framework bump does not force a matching
/// renderer release.
let default_web_renderer_dependency_version : String = "0.1.10"

///|
/// The native Skia renderer releases independently from the framework;
/// generated projects pin it separately for native platform entries.
let default_moui_skia_renderer_dependency_version : String = "0.1.11"

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
  moui_skia_renderer_version : String
  /// App skeleton id: `counter` (default) or `hello`.
  template : String
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
priv struct AddPlatformOptions {
  project_root : String
  platforms : Array[String]
  bundle_id : String?
}

///|
priv struct PackageReportOptions {
  project_root : String
  platforms : Array[String]
  version : String?
  output_dir : String?
  manifest_path : String?
  build : Bool
  dry_run : Bool
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
