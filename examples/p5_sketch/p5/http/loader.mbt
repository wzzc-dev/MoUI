///|
/// Native `https:` image loader for `Sketch::load_image_async`.
///
/// The sketch never blocks on the network: `fetcher()` enqueues a source and
/// returns immediately, and `run()` performs the fetch on the async runtime.
/// Completions run on the same event loop that owns the sketch, so filling the
/// placeholder in place needs no cross-thread marshalling.
///
/// Only `https:` is fetched, so a sketch cannot silently downgrade an image
/// source to cleartext.

///|
pub struct RemoteImageLoader {
  priv queue : @async.Queue[(String, (Bytes?) -> Unit)]
}

///|
pub fn RemoteImageLoader::new() -> RemoteImageLoader {
  { queue: Queue(kind=Unbounded), }
}

///|
/// The fetcher to install with `Sketch::set_image_fetcher` or
/// `set_default_image_fetcher`.
pub fn RemoteImageLoader::fetcher(self : RemoteImageLoader) -> @p5.ImageFetcher {
  (source, complete) => {
    ignore(self.queue.try_put((source, complete)) catch { _ => false })
  }
}

///|
/// Fetch loop. Run it through `with_loader` so it is cancelled when the window
/// closes instead of parking on an empty queue.
pub async fn RemoteImageLoader::run(self : RemoteImageLoader) -> Unit {
  @async.with_task_group(group => {
    while true {
      let (source, complete) = self.queue.get()
      group.spawn_bg(async fn() { complete(remote_png_fetch(source)) })
    }
  })
}

///|
/// Runs `window` with the loader worker attached as a cancellable background
/// child. A worker parked on an empty queue never finishes on its own, so it
/// must not be a peer task that `all` would wait for.
pub async fn with_loader(
  loader : RemoteImageLoader,
  window~ : async () -> Unit,
) -> Unit {
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, async fn() { loader.run() })
    window()
  })
}

///|
/// One bounded `https:` fetch. Non-`https:` sources and ordinary failures
/// return `None`; cancellation unwinds at the await point instead.
async fn remote_png_fetch(source : String) -> Bytes? {
  if !source.has_prefix("https://") {
    return None
  }
  try {
    match
      @async.with_timeout_opt(15000, async fn() {
        let (response, data) = @async_http.get(source)
        if response.code >= 200 && response.code < 300 {
          Some(data.binary())
        } else {
          None
        }
      }) {
      Some(result) => result
      None => None
    }
  } catch {
    _ => None
  }
}
