///|
#borrow(text)
extern "C" fn write_stderr_native(text : Bytes) -> Unit = "moui_cli_write_stderr"

///|
fn write_stderr(text : String) -> Unit {
  write_stderr_native(@utf8.encode(text[:], bom=false) + b"\x00")
}

///|
/// Log an informational message to stderr with the `[moui]` prefix.
fn log_info(message : String) -> Unit {
  write_stderr("[moui] " + message)
}

///|
/// Log a warning message to stderr with the `[moui:warn]` prefix.
fn log_warn(message : String) -> Unit {
  write_stderr("[moui:warn] " + message)
}

///|
/// Log an error message to stderr with the `[moui:error]` prefix.
fn log_error(message : String) -> Unit {
  write_stderr("[moui:error] " + message)
}

///|
/// Print the argv that will be executed, prefixed with `label`. Only emits
/// when `MOUI_DEBUG=1` is set in the environment. Used to trace build pipelines.
fn log_command(label : String, argv : Array[String]) -> Unit {
  match @env.get_env_var("MOUI_DEBUG") {
    Some(value) if value == "1" =>
      write_stderr("[moui:cmd] " + label + ": " + argv.join(" "))
    _ => ()
  }
}
