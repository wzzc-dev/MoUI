///|
/// Thin macOS composition root: runtime + Skia renderer + macOS backend + the
/// native workers.
///
/// The world, the cards, and both reply paths live in the app package; this
/// file owns the two pieces of IO the app cannot perform:
///
/// - the provider worker (`llm_native`), an OpenAI-compatible request loop;
/// - the folder-database host: the world library is a folder
///   (by default `./ai_world_library`; the ⚙ 选择世界库 action opens the
///   macOS directory dialog and re-roots the library on the spot) with one
///   subfolder of Markdown files per world, served through the app's
///   `WorldHost` contract.
///
/// Both capabilities are queued onto dedicated worker tasks beside the window
/// pump (`@macos.run_window_with_workers`, never `@async.all`), and the
/// results are delivered straight into the `dispatch` closure the app's
/// effect runtime hands out — the same pattern the provider worker already
/// uses, so only `update` ever mutates the world.

///|
/// The world library root. Starts relative to the process working directory;
/// the native directory dialog (`PickWorldRoot` → the macOS FileDialog
/// service) re-roots it for the rest of the session.
let library_root : Ref[String] = Ref("ai_world_library")

///|
/// One folder-database job. The callbacks are app-side dispatch closures; they
/// may be invoked from the worker task because `update` never runs on it.
priv struct FsJob {
  kind : FsKind
}

///|
priv enum FsKind {
  List((Array[String]) -> Unit)
  Read(String, (Bool, Array[(String, String)]) -> Unit)
  Write(String, Array[(String, String)], (Bool) -> Unit)
  ConfigRead((String?) -> Unit)
  ConfigWrite(String, (Bool) -> Unit)
}

///|
priv struct FsOwner {
  queue : @async.Queue[FsJob]
}

///|
async fn run_ai_world() -> Unit {
  let llm_owner = @llm_native.LlmOwner::new()
  let fs_owner : FsOwner = { queue: Queue(kind=Unbounded), }
  // The macOS backend's FileDialog service wraps an NSOpenPanel. Dispatching
  // a PickDirectory request opens a real folder dialog on the main thread.
  let service_bridge = @macos.macos_service_bridge()
  let turn_runner : @app.TurnRunner = (request, on_reply) => {
    @llm_native.llm_submit(
      llm_owner,
      request.endpoint(),
      request.api_key(),
      request.model(),
      request.temperature(),
      request.messages(),
      on_reply,
    )
  }
  let world_host : @app.WorldHost = {
    list_worlds: done => {
      ignore(
        fs_owner.queue.try_put(FsJob::{ kind: List(done), }) catch {
          _ => false
        },
      )
    },
    pick_root: done => {
      // Open the native directory dialog. `pick_root` runs inside the app's
      // effect pass on the window task — the main thread `runModal` needs.
      let response = service_bridge.dispatch(
        @backend.HostServiceRequest::FileDialog(
          @backend.HostFileDialogOptions::new(
            kind=@backend.HostFileDialogKind::PickDirectory,
            title="选择世界库",
          ),
        ),
      )
      match response {
        @backend.HostServiceResponse::FileDialogSelection([path, ..]) =>
          library_root.val = path
        // Cancelled or unavailable: keep the current library root and just
        // re-list it, so the player's worlds never disappear on a cancel.
        _ => ()
      }
      ignore(
        fs_owner.queue.try_put(FsJob::{ kind: List(done), }) catch {
          _ => false
        },
      )
    },
    read_world: (folder, done) => {
      ignore(
        fs_owner.queue.try_put(FsJob::{ kind: Read(folder, done), }) catch {
          _ => false
        },
      )
    },
    write_world: (folder, files, done) => {
      ignore(
        fs_owner.queue.try_put(FsJob::{ kind: Write(folder, files, done), }) catch {
          _ => false
        },
      )
    },
    read_config: done => {
      ignore(
        fs_owner.queue.try_put(FsJob::{ kind: ConfigRead(done), }) catch {
          _ => false
        },
      )
    },
    write_config: (content, done) => {
      ignore(
        fs_owner.queue.try_put(FsJob::{ kind: ConfigWrite(content, done), }) catch {
          _ => false
        },
      )
    },
  }
  let window_task : async () -> Unit = async fn() {
    let runtime = @runtime.new_program_with_dimensions(
      program=@app.program(turn_runner~, world_host~),
      width=1560.0,
      height=1080.0,
    )
    @runtime.run_app("MoUI AI World", runtime)
    .render_all(
      @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
    )
    .backend(@macos.entry())
    .run_async_pump(frame_interval_ms=16) catch {
      err => println("AI World exited with error: \{err}")
    }
  }
  let llm_task : async () -> Unit = async fn() {
    // The loop never returns on its own; the host cancels it when the window
    // closes.
    @llm_native.llm_worker_loop(llm_owner)
  }
  let fs_task : async () -> Unit = async fn() { fs_worker_loop(fs_owner) }
  @macos.run_window_with_workers(window=window_task, workers=[llm_task, fs_task])
}

///|
async fn main {
  run_ai_world()
}

///|
/// The filesystem worker loop performing the queued world-library jobs.
async fn fs_worker_loop(owner : FsOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let job = owner.queue.get()
      group.spawn_bg(async fn() { run_fs_job(job) })
    }
  })
}

///|
async fn run_fs_job(job : FsJob) -> Unit {
  match job.kind {
    List(done) => {
      // The library is the set of subfolders carrying a world.md world book.
      let entries = @fs.readdir(library_root.val, include_hidden=false) catch {
        _ => []
      }
      let worlds : Array[String] = []
      for name in entries {
        match
          (@fs.kind("\{library_root.val}/\{name}/world.md") catch {
            _ => @fs.FileKind::Directory
          }) {
          @fs.FileKind::Regular => worlds.push(name)
          _ => ()
        }
      }
      done(worlds)
    }
    Read(folder, done) => {
      let result = read_world_files(folder)
      done(result.0, result.1)
    }
    Write(folder, files, done) => {
      let ok = write_world_files(folder, files)
      done(ok)
    }
    ConfigRead(done) => {
      // Missing file = first run: an empty string reads as "no settings".
      let content = @fs.read_file("\{library_root.val}/config.json").text() catch {
        _ => ""
      }
      done(Some(content))
    }
    ConfigWrite(content, done) => {
      @fs.mkdir(library_root.val, recursive=true, allow_exist=true) catch {
        _ => ()
      }
      let mut ok = true
      @fs.write_file("\{library_root.val}/config.json", content) catch {
        _ => ok = false
      }
      done(ok)
    }
  }
}

///|
/// Read every file of one world folder, two levels deep. The file filter is
/// the app's `is_world_file_name`, so the native host and the web host agree
/// on what belongs to a world (Markdown plus the JSON journal).
async fn read_world_files(folder : String) -> (Bool, Array[(String, String)]) {
  let files : Array[(String, String)] = []
  let world_dir = "\{library_root.val}/\{folder}"
  let probe = @fs.kind(world_dir) catch { _ => @fs.FileKind::Unknown }
  if !(probe is @fs.FileKind::Directory) || folder == "" {
    return (false, files)
  }
  let entries = @fs.readdir(world_dir, include_hidden=false) catch { _ => [] }
  for name in entries {
    let full = "\{world_dir}/\{name}"
    let kind = @fs.kind(full) catch { _ => @fs.FileKind::Unknown }
    match kind {
      @fs.FileKind::Directory => {
        let sub = @fs.readdir(full, include_hidden=false) catch { _ => [] }
        for sub_name in sub {
          if @app.is_world_file_name(sub_name) {
            let file = "\{full}/\{sub_name}"
            let content = @fs.read_file(file).text() catch { _ => "" }
            let relative = "\{name}/\{sub_name}"
            files.push((relative, content))
          }
        }
      }
      @fs.FileKind::Regular =>
        if @app.is_world_file_name(name) {
          let content = @fs.read_file(full).text() catch { _ => "" }
          files.push((name, content))
        }
      _ => ()
    }
  }
  (true, files)
}

///|
/// Write every file of one world folder, creating it (and `characters/`) when
/// missing. A failed file flip the whole job to `false`; the model keeps its
/// in-memory world either way.
async fn write_world_files(
  folder : String,
  files : Array[(String, String)],
) -> Bool {
  @fs.mkdir("\{library_root.val}/\{folder}", recursive=true, allow_exist=true) catch {
    _ => ()
  }
  let mut ok = true
  for pair in files {
    // Paths are `world.md`, `world_book.md`, or `characters/<名>.md`; recreate
    // every intermediate folder before writing the file into it.
    let parts = pair.0.split("/").to_array()
    if parts.length() > 1 {
      let mut prefix = "\{library_root.val}/\{folder}"
      for index in 0..<(parts.length() - 1) {
        prefix = "\{prefix}/\{parts[index]}"
        @fs.mkdir(prefix, recursive=true, allow_exist=true) catch {
          _ => ()
        }
      }
    }
    let path = "\{library_root.val}/\{folder}/\{pair.0}"
    @fs.write_file(path, pair.1) catch {
      _ => ok = false
    }
  }
  ok
}
