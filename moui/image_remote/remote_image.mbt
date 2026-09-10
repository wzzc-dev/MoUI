///|
/// Remote (`https:`) image support for native hosts.
///
/// The renderer-neutral image pipeline resolves bytes synchronously, which a
/// network fetch cannot honour without blocking the UI thread. This module
/// bridges the two: a synchronous starter enqueues remote sources onto an
/// app-owned async queue, and a worker loop running as a sibling of the window
/// pump performs the fetch on the async runtime. The UI thread therefore never
/// waits on the network, and the completion comes back on the same thread the
/// renderer already owns — no cross-thread marshalling and no shared mutable
/// renderer state.
///
/// Only `https:` is fetched, so a document cannot silently downgrade an image
/// load to cleartext.

///|
/// One pending remote image fetch.
priv struct RemoteImageRequest {
  source : String
  finish : (Bytes?) -> Unit
}

///|
/// App-owned queue and worker handle for remote image sources.
pub struct RemoteImageOwner {
  priv queue : @async.Queue[RemoteImageRequest]
}

///|
pub fn RemoteImageOwner::new() -> RemoteImageOwner {
  { queue: @async.Queue(kind=Unbounded) }
}

///|
/// Completion listener: invoked with the source and the fetched bytes whenever
/// a remote image fetch succeeds. Hosts use it to feed intrinsic-size caches
/// and schedule a relayout. It runs on the async runtime thread that completed
/// the fetch — the same thread that owns the renderer — so no marshalling is
/// needed.
let remote_image_completed : Ref[(String, Bytes) -> Unit] = Ref((_, _) => ())

///|
/// Install the completion listener invoked when a remote image fetch succeeds.
pub fn set_remote_image_completed_listener(
  listener : (String, Bytes) -> Unit,
) -> Unit {
  remote_image_completed.val = listener
}

///|
/// A starter that routes remote sources through `owner`'s async worker and
/// every other source through the backend's synchronous path.
///
/// Install it with `@window_image.window_image_task_starter_install` before
/// launching, and run `remote_image_worker_loop(owner)` as a sibling of the
/// window pump.
pub fn remote_image_starter(
  owner : RemoteImageOwner,
) -> @window_image.WindowImageTaskStarter {
  @window_image.WindowImageTaskStarter::new(start=(request, complete) => {
    let source = request.source()
    if !@window_image.window_image_source_is_remote(source) {
      complete(request.load())
      return None
    }
    ignore(
      owner.queue.try_put({
        source,
        finish: bytes => {
          match bytes {
            Some(data) => {
              (remote_image_completed.val)(source, data)
              complete(request.load_bytes(data))
            }
            None => complete(request.load())
          }
        },
      }) catch {
        _ => false
      },
    )
    // Cancellation is cooperative: a source the renderer already disposed is
    // dropped by the worker, and a late completion is rejected by its token.
    // The queue is unbounded, so a full queue is not a failure mode here.
    None
  })
}

///|
/// Fetch loop. Run it as a child of `with_remote_images` rather than as a peer
/// of the window task — see that helper for why the distinction matters.
pub async fn remote_image_worker_loop(owner : RemoteImageOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let work = owner.queue.get()
      group.spawn_bg(async fn() { remote_image_fetch(work) })
    }
  })
}

///|
/// Run `window` with the remote image worker attached as a cancellable
/// background child.
///
/// Prefer this over `@async.all([window_task, worker_task])`. `all` waits for
/// *every* task, and a worker parked on an empty queue never finishes on its
/// own, so the pair is guaranteed to hang once the window loop returns; the
/// async runtime then reports a deadlock and aborts. Nesting the worker in a
/// task group instead lets the group cancel it the moment `window` returns,
/// which is what makes an orderly shutdown possible.
pub async fn with_remote_images(
  owner : RemoteImageOwner,
  window~ : async () -> Unit,
) -> Unit {
  @async.with_task_group(group => {
    // `no_wait` is required: without it the group would wait for a worker that
    // is designed to run until it is cancelled, reintroducing the hang.
    group.spawn_bg(no_wait=true, async fn() { remote_image_worker_loop(owner) })
    window()
  })
}

///|
/// Fetch one remote source and hand the bytes back.
///
/// Ordinary failures never escape: a task group cancels its siblings when a
/// child raises, so a network error is converted into a `None` completion that
/// surfaces through the renderer's image lifecycle instead of tearing down the
/// worker. Cancellation is deliberately re-raised — swallowing it would leave
/// the worker alive after the app asked it to stop.
async fn remote_image_fetch(work : RemoteImageRequest) -> Unit {
  if !remote_image_source_is_fetchable(work.source) {
    (work.finish)(None)
    return
  }
  try {
    let (response, data) = @http.get(work.source)
    if response.code >= 200 && response.code < 300 {
      (work.finish)(Some(data.binary()))
    } else {
      (work.finish)(None)
    }
  } catch {
    err =>
      if @async.is_cancellation_error(err) {
        raise err
      } else {
        (work.finish)(None)
      }
  }
}

///|
/// Only `https:` is fetched; a cleartext `http:` source is refused.
fn remote_image_source_is_fetchable(source : String) -> Bool {
  source.has_prefix("https://")
}
