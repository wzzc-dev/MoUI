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
/// One pending remote image fetch. `cancelled` is shared with the starter's
/// returned cancel handle and checked by the worker before it fetches or
/// reports, so cancelling suppresses both the network work and the completion.
priv struct RemoteImageWork {
  source : String
  finish : (Bytes?) -> Unit
  cancelled : Ref[Bool]
}

///|
/// App-owned queue and worker handle for remote image sources.
pub struct RemoteImageOwner {
  priv queue : @async.Queue[RemoteImageWork]
}

///|
pub fn RemoteImageOwner::new() -> RemoteImageOwner {
  { queue: Queue(kind=Unbounded), }
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
    let work = {
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
      cancelled: Ref(false),
    }
    let queued = owner.queue.try_put(work) catch { _ => false }
    if !queued {
      // The queue is unbounded, so a rejected put is a host-side shutdown;
      // report it as no cancellable work and let the renderer lifecycle fail.
      return None
    }
    // A disposed renderer disposes its image source through this handle: the
    // worker skips the queued work and a late completion is rejected by the
    // request token as well.
    Some(fn() { work.cancelled.val = true })
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
/// surfaces through the renderer's image lifecycle instead of tearing down
/// the worker. Cancellation is not an error in the current async runtime: it
/// unwinds at the await points and never reaches `catch`, so the final
/// `finish` call is naturally skipped when the app asks the worker to stop.
///
/// A fetch retries with backoff before reporting failure. The renderer never
/// re-requests a source once its lifecycle says failed, so a single transient
/// connect failure — hosts like img.shields.io are routinely unreachable from
/// some networks while the same URL succeeds seconds later — would otherwise
/// blank the image for the whole session.
async fn remote_image_fetch(work : RemoteImageWork) -> Unit {
  if work.cancelled.val {
    return
  }
  if !remote_image_source_is_fetchable(work.source) {
    (work.finish)(None)
    return
  }
  let attempts = remote_image_fetch_retry_delays_ms.length() + 1
  let mut completed = false
  try {
    for attempt in 0..<attempts {
      if work.cancelled.val {
        return
      }
      match remote_image_fetch_once(work.source) {
        Some(data) => {
          if work.cancelled.val {
            return
          }
          (work.finish)(Some(data))
          completed = true
          break
        }
        None =>
          if attempt + 1 < attempts {
            @async.sleep(remote_image_fetch_retry_delays_ms[attempt])
          }
      }
    }
  } catch {
    _ => completed = false
  }
  if !completed && !work.cancelled.val {
    (work.finish)(None)
  }
}

///|
/// Backoff between fetch attempts, in milliseconds. The first entry follows
/// the initial attempt.
let remote_image_fetch_retry_delays_ms : Array[Int32] = [1000, 2000, 4000]

///|
/// Connect/transfer budget for one fetch attempt. Without it a stalled host
/// holds the image placeholder for the OS-level connect timeout, which can
/// run minutes.
let remote_image_fetch_timeout_ms : Int32 = 15000

///|
/// One bounded fetch attempt: `Some(bytes)` on a 2xx response, `None` on any
/// other status, timeout, or network error. Cancellation is not an error in
/// the current async runtime: it unwinds at the await point and never reaches
/// `catch`, so `catch` only maps ordinary errors to `None`.
async fn remote_image_fetch_once(source : String) -> Bytes? {
  try {
    match
      @async.with_timeout_opt(remote_image_fetch_timeout_ms, async fn() {
        let (response, data) = @http.get(source)
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

///|
/// Only `https:` is fetched; a cleartext `http:` source is refused.
fn remote_image_source_is_fetchable(source : String) -> Bool {
  source.has_prefix("https://")
}

///|
/// App-facing facade over the native remote-image loader. The concrete HTTP,
/// retry, queue, and worker stay in this implementation package; apps depend on
/// `moui/services.RemoteImageService` instead.
pub fn remote_image_service() -> @services.RemoteImageService {
  @services.RemoteImageService::new(set_completed_listener=listener => {
    set_remote_image_completed_listener(listener)
  })
}

///|
/// Owner-backed facade: the completion listener keeps feeding the
/// renderer-driven image pipeline, and `RemoteImageService::fetch` returns a
/// cancellable request handle backed by the same worker queue. Hosts that
/// offer explicit remote fetches (document/image addons) install this one
/// instead of the listener-only factory.
pub fn remote_image_service_with_owner(
  owner : RemoteImageOwner,
) -> @services.RemoteImageService {
  @services.RemoteImageService::new(
    set_completed_listener=listener => {
      set_remote_image_completed_listener(listener)
    },
    fetch=(source, on_complete) => {
      let work = { source, finish: on_complete, cancelled: Ref(false), }
      let queued = owner.queue.try_put(work) catch { _ => false }
      if !queued {
        None
      } else {
        Some(
          @services.RemoteImageRequest::new(cancel=fn() {
            work.cancelled.val = true
          }),
        )
      }
    },
  )
}
