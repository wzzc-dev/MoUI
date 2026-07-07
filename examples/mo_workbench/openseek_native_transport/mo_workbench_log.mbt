// stderr logging for OpenSeek / HTTP failures (visible in the terminal).

///|
fn mo_workbench_log_error(context : String, detail : String) -> Unit {
  println("[Mo Workbench] " + context + ": " + detail)
}

///|
fn mo_workbench_log_caught(context : String, err : Error) -> Unit {
  mo_workbench_log_error(context, "\{err}")
}
