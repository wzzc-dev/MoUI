///|
test "remote image fetch refuses cleartext http sources" {
  // Deterministic: the cleartext guard runs before any network call, so this
  // test needs no connectivity.
  assert_false(remote_image_source_is_fetchable("http://example.com/a.png"))
  assert_true(remote_image_source_is_fetchable("https://example.com/a.png"))
  assert_false(remote_image_source_is_fetchable("/tmp/a.png"))
}

///|
async test "remote image fetch completes with no bytes for cleartext http" {
  let called = Ref(false)
  let received : Ref[Bytes?] = Ref(Some(b"sentinel"))
  remote_image_fetch({
    source: "http://example.com/a.png",
    finish: bytes => {
      received.val = bytes
      called.val = true
    },
  })
  // The completion still runs exactly once, so the renderer leaves the loading
  // state instead of stalling.
  assert_true(called.val)
  assert_true(received.val is None)
}
