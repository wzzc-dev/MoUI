///|
/// 宿主平台探测：`@env` + `@fs` 是 CLI 侧的能力，纯计划面（`@plan`）只接收
/// 已经探测好的 `@plan.HostPlatform`。

///|
fn detect_host_platform() -> @plan.HostPlatform {
  if @env.get_env_var("OS") == Some("Windows_NT") ||
    @env.get_env_var("SystemRoot") is Some(_) {
    @plan.HostPlatform::Windows
  } else if @fs.path_exists("/System/Library/CoreServices") {
    @plan.HostPlatform::Macos
  } else if @fs.path_exists("/proc/sys/kernel/ostype") ||
    @fs.path_exists("/etc/os-release") {
    @plan.HostPlatform::Linux
  } else {
    @plan.HostPlatform::Unknown
  }
}
