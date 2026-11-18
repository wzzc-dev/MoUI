///|
/// Exercises one queue turn with an in-memory fetch, without the network.
async fn run_once(
  loader : RemoteImageLoader,
  fetch : (String) -> Bytes?,
) -> Unit {
  let (source, complete) = loader.queue.get()
  complete(fetch(source))
}

///|
async test "remote image loader delivers fetched bytes" {
  let loader = RemoteImageLoader::new()
  let seen = Ref("")
  let received : Ref[Bytes?] = Ref(None)
  loader.fetcher()("https://example.com/pic.png", bytes => received.val = bytes)
  run_once(loader, fn(source) {
    seen.val = source
    Some(b"abc")
  })
  inspect(seen.val, content="https://example.com/pic.png")
  match received.val {
    Some(bytes) => inspect(bytes.length(), content="3")
    None => fail("completion was not called")
  }
}

///|
async test "remote image fetch refuses cleartext http" {
  let bytes = remote_png_fetch("http://example.com/pic.png")
  assert_true(bytes is None)
}
