///|
let valid_patch =
  #|diff --git a/skia-revision.txt b/skia-revision.txt
  #|index 1111111..2222222 100644
  #|--- a/skia-revision.txt
  #|+++ b/skia-revision.txt
  #|@@ -1 +1 @@
  #|-main
  #|+0123456789abcdef0123456789abcdef01234567
  #|diff --git a/skia-platform-status.json b/skia-platform-status.json
  #|index 3333333..4444444 100644
  #|--- a/skia-platform-status.json
  #|+++ b/skia-platform-status.json
  #|@@ -1 +1 @@
  #|-{"platforms":{"linux":{"accepted":false}}}
  #|+{"platforms":{"linux":{"accepted":true,"accepted_commit":"0123456789abcdef0123456789abcdef01234567"}}}
  #|

///|
let valid_status =
  #|{
  #|  "platforms": {
  #|    "linux": {
  #|      "accepted": true,
  #|      "accepted_commit": "0123456789abcdef0123456789abcdef01234567"
  #|    }
  #|  }
  #|}

///|
test "accepts valid acceptance state patch text" {
  inspect(
    validate_acceptance_state_patch_text(valid_patch) is Ok(_),
    content="true",
  )
}

///|
test "rejects acceptance state patch touching unexpected file" {
  let patch = valid_patch.replace(
    old="diff --git a/skia-revision.txt b/skia-revision.txt",
    new="diff --git a/README.md b/README.md",
  )
  inspect(
    match validate_acceptance_state_patch_text(patch) {
      Err(message) => message.contains("unexpected file")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects acceptance state patch renaming files" {
  let patch = valid_patch.replace(
    old="diff --git a/skia-revision.txt b/skia-revision.txt",
    new="diff --git a/skia-revision.txt b/other-revision.txt",
  )
  inspect(
    match validate_acceptance_state_patch_text(patch) {
      Err(message) => message.contains("must not rename files")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects acceptance state patch without platform status diff" {
  let patch =
    #|diff --git a/skia-revision.txt b/skia-revision.txt
    #|--- a/skia-revision.txt
    #|+++ b/skia-revision.txt
    #|@@ -1 +1 @@
    #|-main
    #|+0123456789abcdef0123456789abcdef01234567
    #|
  inspect(
    validate_acceptance_state_patch_text(patch) ==
    Err("acceptance state patch must update skia-platform-status.json"),
    content="true",
  )
}

///|
test "accepts patched Linux accepted status" {
  inspect(
    validate_linux_accepted_status_text(valid_status) is Ok(_),
    content="true",
  )
}

///|
test "rejects patched status without Linux accepted marker" {
  let status = valid_status.replace(
    old="\"accepted\": true",
    new="\"accepted\": false",
  )
  inspect(
    validate_linux_accepted_status_text(status) ==
    Err("acceptance state patch does not mark Linux accepted"),
    content="true",
  )
}

///|
test "rejects patched status without full Linux accepted commit" {
  let status = valid_status.replace(
    old="0123456789abcdef0123456789abcdef01234567",
    new="main",
  )
  inspect(
    validate_linux_accepted_status_text(status) ==
    Err("acceptance state patch does not record a Linux accepted_commit"),
    content="true",
  )
}
