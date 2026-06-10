///|
let passing_acceptance_log =
  #|smoke_status=0
  #|native_smoke_marker=passed
  #|native_pkg_restore=passed
  #|skia_commit=0123456789ABCDEF0123456789abcdef01234567
  #|

///|
test "accepts required fields and extracts last lowercased commit" {
  match
    accepted_commit_from_log_text(
      passing_acceptance_log +
      "skia_commit=fedcba9876543210fedcba9876543210fedcba98\n",
    ) {
    Ok(commit) =>
      inspect(commit, content="fedcba9876543210fedcba9876543210fedcba98")
    Err(message) => fail(message)
  }
}

///|
test "rejects missing required field" {
  inspect(
    match verify_acceptance_log_text("smoke_status=0\n", false) {
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
    match verify_acceptance_log_text(log, true) {
      Err(message) => message.contains("skia_commit")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "skips floating revision when requested" {
  match verify_revision_texts("main\n", "", true) {
    Ok(message) =>
      inspect(
        message,
        content="Skipping Skia revision pin check because revision is not pinned: main",
      )
    Err(message) => fail(message)
  }
}

///|
test "rejects mismatched acceptance commit" {
  inspect(
    match
      verify_revision_texts(
        "fedcba9876543210fedcba9876543210fedcba98\n", passing_acceptance_log, false,
      ) {
      Err(message) => message.contains("does not match")
      Ok(_) => false
    },
    content="true",
  )
}
