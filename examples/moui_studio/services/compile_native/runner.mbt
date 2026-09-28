///|
/// 真编译执行器（native-only）：导出 bundle → 工作区外 `moon update` →
/// `moon check --target native` → `moon build --target wasm-gc` →
/// `moon build ./native_smoke --target native` → native 产物启动存活。
///
/// 契约（编译轨不静默降级）：
/// - 任一步失败立即停止，返回已解析的 `CompileReport`（ok=false），
///   诊断含文件/行/列/错误码，交给 Studio 回渲染；**绝不回退解释轨**。
/// - 预览源码与 bundle 里 `app/generated_handlers.mbt` 是同一个 codegen
///   函数的同一次落盘（本执行器直接 `@export.export_bundle`）。
/// - UI 线程只做同步入队；全部进程 IO 在 async worker 上完成，
///   结果经回调回到 UI 线程（与 provider worker 同一模式）。

///|
/// 一次真编译任务：项目 JSON + 应用名 + 工作根目录（临时目录）。
pub(all) struct CompileJob {
  project_json : String
  app_name : String
  work_root : String
  on_result : (Result[@export.CompileReport, String]) -> Unit
}

///|
/// App 私有的编译队列与工作者句柄。
pub(all) struct CompileOwner {
  queue : @async.Queue[CompileJob]
}

///|
pub fn CompileOwner::new() -> CompileOwner {
  { queue: Queue(kind=Unbounded), }
}

///|
/// 同步入队（UI 线程调用）。队列无界，满不是失败模式。
pub fn compile_submit(owner : CompileOwner, job : CompileJob) -> Unit {
  ignore(owner.queue.try_put(job) catch { _ => false })
}

///|
/// 默认工作根目录：TMPDIR（macOS 上必存在），否则当前目录下的
/// `.studio-compile`。显式在 workspace 之外编译（root moon.work 不接管）。
pub fn default_work_root() -> String {
  let base = @env.get_env_var("TMPDIR").unwrap_or("")
  if base == "" {
    ".studio-compile"
  } else if base.has_suffix("/") {
    "\{base}moui-studio-compile"
  } else {
    "\{base}/moui-studio-compile"
  }
}

///|
/// 工作循环：与窗口泵成对运行（`@async.all([window_task, worker_task])`）。
pub async fn compile_worker_loop(owner : CompileOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let job = owner.queue.get()
      group.spawn_bg(async fn() { run_compile_job(job) })
    }
  })
}

///|
/// 执行一个编译任务；任何异常都转成结构化失败（不静默吞掉）。
async fn run_compile_job(job : CompileJob) -> Unit {
  let result = compile_project(job.project_json, job.app_name, job.work_root) catch {
    err => Err("编译执行器错误：\{err}")
  }
  (job.on_result)(result)
}

///|
/// 真编译主流程：清空并重建 `{work_root}/{safe_name}`，落 bundle 到该目录，
/// 然后在 bundle 目录里逐步执行工具链。
pub async fn compile_project(
  project_json : String,
  app_name : String,
  work_root : String,
) -> Result[@export.CompileReport, String] {
  let safe = @export.sanitize_name(app_name)
  let root = "\{work_root}/\{safe}"
  prepare_target_dir(root) catch {
    _ => return Err("无法准备工作目录 \{root}")
  }
  let bundle = @export.export_bundle(project_json, app_name)
  for pair in bundle {
    let path = "\{work_root}/\{pair.0}"
    ensure_parent_dir(path)
    @x/fs.write_string_to_file(path, pair.1) catch {
      _ => return Err("无法写入 \{path}")
    }
  }
  compile_bundle_at(root)
}

///|
/// 在已落盘的 bundle 目录里执行工具链（可独立单测：注入一个坏源码即可
/// 验证「moon check 失败 → 结构化诊断」）。
pub async fn compile_bundle_at(
  root : String,
) -> Result[@export.CompileReport, String] {
  let moon = moon_bin()
  // 1) moon update：解析/锁定依赖（离线缓存命中时很快）
  let (update_code, update_output) = run_tool(moon, ["update"], root) catch {
    err => return Err("无法运行 moon update：\{err}")
  }
  if update_code != 0 {
    return Ok(failed_report("update", update_code, update_output, root, ""))
  }
  // 2) moon check --target native：编译诊断的第一现场
  let (check_code, check_output) = run_tool(
    moon,
    ["check", "--target", "native"],
    root,
  ) catch {
    err => return Err("无法运行 moon check：\{err}")
  }
  if check_code != 0 {
    return Ok(
      failed_report("native", check_code, check_output, root, update_output),
    )
  }
  // 3) moon build --target wasm-gc：Web 产物真实存在
  let (wasm_code, wasm_output) = run_tool(
    moon,
    ["build", "--target", "wasm-gc"],
    root,
  ) catch {
    err => return Err("无法运行 moon build (wasm-gc)：\{err}")
  }
  if wasm_code != 0 {
    return Ok(
      failed_report("wasm-gc", wasm_code, wasm_output, root, update_output),
    )
  }
  // 4) moon build ./native_smoke --target native：native 可执行产物
  let (native_code, native_output) = run_tool(
    moon,
    ["build", "./native_smoke", "--target", "native"],
    root,
  ) catch {
    err => return Err("无法运行 moon build (native)：\{err}")
  }
  if native_code != 0 {
    return Ok(
      failed_report("native", native_code, native_output, root, update_output),
    )
  }
  // 5) native 产物启动存活：跑一遍生成 handler，标记可判定
  let smoke_exe = "\{root}/_build/native/debug/build/native_smoke/native_smoke.exe"
  let (smoke_code, smoke_output) = run_tool(smoke_exe, [], root) catch {
    err => return Err("无法启动 native 产物：\{err}")
  }
  if smoke_code != 0 || !smoke_output.contains("studio native export smoke: ok") {
    return Ok(
      failed_report("native", smoke_code, smoke_output, root, update_output),
    )
  }
  Ok(@export.CompileReport::{
    ok: true,
    exit_code: 0,
    target: "native",
    source_path: "\{root}/app/generated_handlers.mbt",
    output: build_output_summary(
      update_output, check_output, wasm_output, native_output, smoke_output,
    ),
    diagnostics: @export.parse_moon_diagnostics(native_output),
  })
}

///|
/// moon 可执行文件：默认 PATH 上的 `moon`，测试/沙箱可用 MOON_BIN 覆盖。
fn moon_bin() -> String {
  @env.get_env_var("MOON_BIN").unwrap_or("moon")
}

///|
/// 失败报告：诊断来自工具链原始输出；输出保留此前步骤的尾部
/// （截断到 20000 字符，防止 UI/内存被超大日志拖垮）。
fn failed_report(
  target : String,
  exit_code : Int,
  output : String,
  root : String,
  prefix_output : String,
) -> @export.CompileReport {
  {
    ok: false,
    exit_code,
    target,
    source_path: source_path_of(root, output),
    output: build_output_summary(prefix_output, output, "", "", ""),
    diagnostics: @export.parse_moon_diagnostics(output),
  }
}

///|
/// 生成源码路径（诊断文件里最可信的一个）：优先从诊断文本里截出
/// `app/generated_handlers.mbt`，否则回退 bundle 根目录约定。
fn source_path_of(root : String, output : String) -> String {
  let marker = "/app/generated_handlers.mbt"
  match output.find(marker) {
    Some(index) => {
      let mut start = index
      while start > 0 &&
            output[start - 1] != ' ' &&
            output[start - 1] != '[' &&
            output[start - 1] != '\n' {
        start = start - 1
      }
      let end = index + marker.length()
      output[start:end].to_owned()
    }
    None => "\{root}/app/generated_handlers.mbt"
  }
}

///|
/// 组合多步工具链输出（最近的失败输出在前，便于阅读）。
fn build_output_summary(
  first : String,
  second : String,
  third : String,
  fourth : String,
  fifth : String,
) -> String {
  let buf = StringBuilder()
  for chunk in [fifth, fourth, third, second, first] {
    if chunk.trim().to_owned() != "" {
      if !buf.is_empty() {
        buf.write_string("\n")
      }
      buf.write_string(truncate_tail(chunk, 20000))
    }
  }
  buf.to_string()
}

///|
fn truncate_tail(text : String, limit : Int) -> String {
  if text.length() <= limit {
    text
  } else {
    "…(截断)\n" + text[text.length() - limit:].to_owned()
  }
}

///|
/// 起一个子进程并收齐 stdout+stderr（合并流，保持原始相对顺序）。
async fn run_tool(
  command : String,
  args : Array[String],
  cwd : String,
) -> (Int, String) {
  let (code, data) = @process.collect_output_merged(
    command,
    args,
    cwd~,
    no_console_window=true,
  )
  (code, data.text() catch { _ => "" })
}

///|
/// 逐级创建父目录（x/fs 没有 recursive mkdir）。
fn ensure_parent_dir(path : String) -> Unit {
  let idx = match path.rev_find("/") {
    Some(index) => index
    None => return
  }
  let parent = path[:idx].to_owned()
  if parent.is_empty() || @x/fs.path_exists(parent) {
    return
  }
  ensure_parent_dir(parent)
  @x/fs.create_dir(parent) catch {
    _ => ()
  }
}

///|
/// 清空并重建目标目录（自写递归删除：x/fs 无 recursive remove）。
/// 目录不可写时向上抛错，由任务边界转成结构化失败。
fn prepare_target_dir(root : String) -> Unit raise {
  if @x/fs.path_exists(root) {
    remove_tree(root)
  }
  ensure_parent_dir(root + "/_")
  if !@x/fs.path_exists(root) {
    @x/fs.create_dir(root)
  }
}

///|
/// 递归删除目录树（先删内部条目，最后删目录本身）。
fn remove_tree(path : String) -> Unit raise {
  let entries = @x/fs.read_dir(path)
  for name in entries {
    let child = "\{path}/\{name}"
    if @x/fs.is_dir(child) {
      remove_tree(child)
    } else {
      @x/fs.remove_file(child) catch {
        _ => ()
      }
    }
  }
  @x/fs.remove_dir(path)
}
