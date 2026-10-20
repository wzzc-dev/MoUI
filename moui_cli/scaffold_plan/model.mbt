///|
/// 文件计划的类型面：入参（`ProjectOptions`）、产物（`PlannedFile`）、
/// 工程身份（`ProjectManifest`）与平台轴（`HostPlatform`）。全部纯数据——
/// 本包不碰文件系统，落盘由调用方（CLI 的 stage/validate/commit 或
/// Studio 的逐文件 Effect）负责。

///|
pub let default_moui_dependency_version : String = "0.2.3"

///|
/// The web renderer releases independently from the framework; generated
/// projects pin it separately so a framework bump does not force a matching
/// renderer release.
let default_web_renderer_dependency_version : String = "0.2.2"

///|
/// The native Skia renderer releases independently from the framework;
/// generated projects pin it separately for native platform entries.
pub let default_moui_skia_renderer_dependency_version : String = "0.2.1"

///|
pub(all) enum HostPlatform {
  Macos
  Windows
  Linux
  Unknown
} derive(Eq)

///|
pub extend HostPlatform with Eq::{not_equal, equal}

///|
pub fn HostPlatform::name(self : HostPlatform) -> String {
  match self {
    Macos => "macos"
    Windows => "windows"
    Linux => "linux"
    Unknown => "unknown"
  }
}

///|
pub(all) struct PlannedFile {
  path : String
  bytes : Bytes
}

///|
pub(all) struct ProjectOptions {
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
pub(all) struct ProjectManifest {
  schema_version : Int32
  id : String
  title : String
  module_name : String
  moui_version : String
  platforms : Array[String]
  bundle_id : String?
}

///|
/// 一个待落盘文件：路径 + UTF-8 字节（末尾补齐换行）。
pub fn text_file(path : String, text : String) -> PlannedFile {
  {
    path,
    bytes: @utf8.encode(
      (if text.has_suffix("\n") { text } else { text + "\n" })[:],
      bom=false,
    ),
  }
}
