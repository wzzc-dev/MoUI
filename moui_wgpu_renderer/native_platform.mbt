///|
/// Renderer-owned interpretation policy for opaque native surface handles.
pub(all) enum WgpuNativePlatform {
  MacOS
  Windows
  Linux
} derive(Eq, Debug, ToJson)

///|
pub extend WgpuNativePlatform with Debug::{to_repr}

///|
pub extend WgpuNativePlatform with Eq::{not_equal, equal}

///|
pub extend WgpuNativePlatform with ToJson::{to_json}

///|
pub fn WgpuNativePlatform::label(self : WgpuNativePlatform) -> String {
  match self {
    MacOS => "macos"
    Windows => "windows"
    Linux => "linux"
  }
}
