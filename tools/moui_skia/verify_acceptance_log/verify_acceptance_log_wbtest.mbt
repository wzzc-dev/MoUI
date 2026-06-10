///|
let passing_log =
  #|smoke_status=0
  #|native_smoke_marker=passed
  #|native_pkg_restore=passed
  #|skia_commit=0123456789abcdef0123456789abcdef01234567
  #|

///|
test "accepts required fields and commit" {
  match @skia_acceptance.verify_acceptance_log_text(passing_log, true) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "rejects missing required field" {
  inspect(
    match
      @skia_acceptance.verify_acceptance_log_text("smoke_status=0\n", false) {
      Err(message) => message.contains("native_smoke_marker=passed")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects missing commit when required" {
  let log =
    #|smoke_status=0
    #|native_smoke_marker=passed
    #|native_pkg_restore=passed
    #|
  inspect(
    match @skia_acceptance.verify_acceptance_log_text(log, true) {
      Err(message) => message.contains("skia_commit")
      Ok(_) => false
    },
    content="true",
  )
}
