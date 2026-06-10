///|
let passing_acceptance_log =
  #|smoke_status=0
  #|native_smoke_marker=passed
  #|native_pkg_restore=passed
  #|skia_commit=0123456789ABCDEF0123456789abcdef01234567
  #|

///|
test "accepts matching pinned revision and acceptance commit" {
  match
    @skia_acceptance.verify_revision_texts(
      "0123456789abcdef0123456789abcdef01234567\n", passing_acceptance_log, false,
    ) {
    Ok(message) =>
      inspect(
        message,
        content="Verified skia-revision.txt matches accepted Skia commit 0123456789abcdef0123456789abcdef01234567.",
      )
    Err(message) => fail(message)
  }
}

///|
test "skips floating revision when requested" {
  match @skia_acceptance.verify_revision_texts("main\n", "", true) {
    Ok(message) =>
      inspect(
        message,
        content="Skipping Skia revision pin check because revision is not pinned: main",
      )
    Err(message) => fail(message)
  }
}

///|
test "rejects floating revision without skip" {
  inspect(
    match
      @skia_acceptance.verify_revision_texts(
        "main\n", passing_acceptance_log, false,
      ) {
      Err(message) => message.contains("not pinned")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects mismatched acceptance commit" {
  inspect(
    match
      @skia_acceptance.verify_revision_texts(
        "fedcba9876543210fedcba9876543210fedcba98\n", passing_acceptance_log, false,
      ) {
      Err(message) => message.contains("does not match")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects acceptance log missing commit" {
  let log =
    #|smoke_status=0
    #|native_smoke_marker=passed
    #|native_pkg_restore=passed
    #|
  inspect(
    match
      @skia_acceptance.verify_revision_texts(
        "0123456789abcdef0123456789abcdef01234567\n", log, false,
      ) {
      Err(message) => message.contains("skia_commit")
      Ok(_) => false
    },
    content="true",
  )
}
