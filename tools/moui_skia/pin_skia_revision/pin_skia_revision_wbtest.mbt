///|
let passing_acceptance_log =
  #|smoke_status=0
  #|native_smoke_marker=passed
  #|native_pkg_restore=passed
  #|skia_commit=0123456789ABCDEF0123456789abcdef01234567
  #|

///|
test "generates lowercased revision pin content" {
  match revision_pin_content(passing_acceptance_log) {
    Ok(content) =>
      inspect(content, content="0123456789abcdef0123456789abcdef01234567\n")
    Err(message) => fail(message)
  }
}

///|
test "uses the last valid skia commit" {
  match
    revision_pin_content(
      passing_acceptance_log +
      "skia_commit=fedcba9876543210fedcba9876543210fedcba98\n",
    ) {
    Ok(content) =>
      inspect(content, content="fedcba9876543210fedcba9876543210fedcba98\n")
    Err(message) => fail(message)
  }
}

///|
test "rejects missing restore marker" {
  let log =
    #|smoke_status=0
    #|native_smoke_marker=passed
    #|skia_commit=0123456789abcdef0123456789abcdef01234567
    #|
  inspect(
    match revision_pin_content(log) {
      Err(message) => message.contains("native_pkg_restore=passed")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects missing commit" {
  let log =
    #|smoke_status=0
    #|native_smoke_marker=passed
    #|native_pkg_restore=passed
    #|
  inspect(
    match revision_pin_content(log) {
      Err(message) => message.contains("skia_commit")
      Ok(_) => false
    },
    content="true",
  )
}
