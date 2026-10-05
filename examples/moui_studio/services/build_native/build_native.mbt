///|
/// 通用构建执行器(native-only):BuildOwner 队列 + 活动进程句柄 + 取消 +
/// worker 循环。数据类型在 `services/build`(双目标);执行面在这里,
/// 镜像 compile_native 的「队列 + 句柄 + 随从 worker」模式。

///|
/// 构建队列与活动进程句柄(与 CompileOwner 同构)。
/// `active` 是正在运行的 moon 子进程句柄:取消经 `build_cancel` 同步生效。
pub(all) struct BuildOwner {
  queue : @async.Queue[@build.BuildRequest]
  active : Ref[@process.Process?]
}

///|
pub fn BuildOwner::new() -> BuildOwner {
  { queue: Queue(kind=Unbounded), active: Ref(None), }
}

///|
/// 取消当前构建的 moon 子进程(UI 线程同步;空闲时空操作)。
pub fn build_cancel(owner : BuildOwner) -> Unit {
  match owner.active.val {
    Some(process) => process.cancel()
    None => ()
  }
}

///|
/// 同步入队(UI 线程调用;队列无界)。
pub fn build_submit(owner : BuildOwner, request : @build.BuildRequest) -> Unit {
  ignore(owner.queue.try_put(request) catch { _ => false })
}

///|
/// 工作循环:随从任务,与窗口泵成对运行(同 compile_worker_loop)。
pub async fn build_worker_loop(owner : BuildOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let request = owner.queue.get()
      group.spawn_bg(async fn() { run_build(owner, request) })
    }
  })
}

///|
async fn run_build(owner : BuildOwner, request : @build.BuildRequest) -> Unit {
  let result = execute_build(owner, request) catch {
    err => Err("构建执行器错误:\{err}")
  }
  (request.on_result)(result)
}

///|
/// 执行一条 moon 命令并收集全量输出(双管道并发读,与 compile_native
/// 的 run_tool 同款;进程句柄登记 owner.active 供取消)。
async fn run_tool(
  owner : BuildOwner,
  args : Array[String],
  cwd : String,
) -> (Int, String) {
  let (out_reader, out_w) = @process.read_from_process()
  let (err_reader, err_w) = @process.read_from_process()
  let out_box = Ref("")
  let err_box = Ref("")
  let code_box = Ref(0)
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      defer out_reader.close()
      out_box.val = out_reader.read_all().text() catch { _ => "" }
    })
    group.spawn_bg(async fn() {
      defer err_reader.close()
      err_box.val = err_reader.read_all().text() catch { _ => "" }
    })
    let process = @process.spawn(
      group,
      args[0],
      @build.drop_first(args),
      stdout=out_w,
      stderr=err_w,
      cwd~,
      no_console_window=true,
    )
    owner.active.val = Some(process)
    code_box.val = process.wait()
    owner.active.val = None
  })
  (code_box.val, err_box.val + out_box.val)
}

///|
/// 执行 kind 的命令序列:全部零码才算 ok;任何一步失败即停。命令输出
/// 逐段累积,诊断在最终输出上解析一次。
async fn execute_build(
  owner : BuildOwner,
  request : @build.BuildRequest,
) -> Result[@build.BuildReport, String] {
  let mut output = ""
  let mut ok = true
  let mut exit_code = 0
  let commands = @build.build_commands(request.kind, request.entry_rel)
  let mut index = 0
  while index < commands.length() && ok {
    let args = commands[index]
    output = output + "$ " + @build.join_args(args) + "\n"
    let (code, text) = run_tool(owner, args, request.root) catch {
      err => {
        output = output + "无法启动 \{args[0]}:\{err}\n"
        return Ok(@build.BuildReport::{
          kind: request.kind,
          ok: false,
          exit_code: -1,
          output: @build.tail_output(output),
          diagnostics: [],
          web_root: "",
          web_index_rel: "",
          artifact_path: "",
        })
      }
    }
    exit_code = code
    ok = code == 0
    output = output + text + "\n"
    index = index + 1
  }
  let diagnostics = @export.parse_moon_diagnostics(output)
  // Web 构建:探测 workspace 根(moon 的 _build 归属规则)+ index 相对路径
  let mut web_root = ""
  let mut web_index_rel = ""
  if request.kind is BkWebPreview && ok {
    let ws = @webpreview.workspace_root_for(request.root)
    web_root = ws
    let project_rel = if request.root == ws {
      ""
    } else if request.root.has_prefix(ws + "/") {
      request.root[ws.length() + 1:].to_owned()
    } else {
      ""
    }
    web_index_rel = (if project_rel == "" { "" } else { project_rel + "/" }) +
      request.entry_rel +
      "/index.html"
  }
  // RunNative 构建:定位可执行产物(<ws>/_build/native/release/build/
  // <module>/<entry>/<entry>,逐层 readdir 探测)
  let mut artifact_path = ""
  if request.kind is BkRunNative && ok {
    let ws = @webpreview.workspace_root_for(request.root)
    artifact_path = find_native_artifact(
      ws + "/_build/native/release/build",
      last_segment(request.entry_rel),
    )
  }
  Ok(@build.BuildReport::{
    kind: request.kind,
    ok,
    exit_code,
    output: @build.tail_output(output),
    diagnostics,
    web_root,
    web_index_rel,
    artifact_path,
  })
}

///|
fn last_segment(path : String) -> String {
  match path.rev_find("/") {
    Some(idx) => path[idx + 1:].to_owned()
    None => path
  }
}

///|
/// 在 _build/native/release/build 下逐层找名为 entry 的目录,返回其中
/// 与目录同名的可执行(macOS 无扩展名;Windows 找 .exe)。找不到 → ""。
async fn find_native_artifact(
  build_dir : String,
  entry_name : String,
) -> String {
  let mut candidates : Array[String] = [build_dir]
  let mut found_dir = ""
  let mut depth = 0
  while depth < 8 && found_dir == "" && candidates.length() > 0 {
    let next : Array[String] = []
    for dir in candidates {
      let names = @fs.readdir(dir) catch { _ => [] }
      for name in names {
        let child = dir + "/" + name
        let kind = @fs.kind(child) catch { _ => Unknown }
        if kind is Directory {
          if name == entry_name {
            found_dir = child
          } else {
            next.push(child)
          }
        }
      }
      if found_dir != "" {
        break
      }
    }
    candidates = next
    depth = depth + 1
  }
  if found_dir == "" {
    return ""
  }
  let direct = found_dir + "/" + entry_name
  if @fs.exists(direct) {
    return direct
  }
  let exe = direct + ".exe"
  if @fs.exists(exe) {
    return exe
  }
  ""
}
