///|
/// Renderer-owned interpretation policy for opaque native surface handles.
pub(all) enum WgpuNativePlatform {
  MacOS
  Windows
  Linux
} derive(Eq, Debug, ToJson)

///|
pub fn WgpuNativePlatform::label(self : WgpuNativePlatform) -> String {
  match self {
    MacOS => "macos"
    Windows => "windows"
    Linux => "linux"
  }
}
