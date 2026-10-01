///|
/// 产物启动执行器（native-only）：把「运行产物」做成**真的一键启动**。
///
/// 与 `services/compile_native` 同一模式：UI 线程只入队，`spawn` 在 async
/// worker 上做，结果经回调回到 UI 线程。差别只有一处——这里起的是**用户
/// 要用的应用**，所以必须让它**脱离 Studio 的生命周期**：
///
/// - `spawn_orphan` 起进程后立即 `close()` 句柄，不做 wait（没有僵尸、没有
///   task 引用）；macOS 上子进程被 reparent 到 launchd，Studio 退出/被关掉
///   都不会带走它。用普通 `spawn` 挂在 Studio 的 task group 上，关掉 Studio
///   就会把正在用的导出应用一起杀掉——那不是「运行产物」该有的语义。
/// - 起步即 detach 也意味着**拿不到退出码**：这是刻意的取舍，用户要的是
///   「点了就开窗」，而产物自己的生命周期归用户桌面会话管。
///
/// 失败面只有「起不来」（路径不存在 / 没有执行权限 / 架构不匹配），这些都
/// 在 `spawn` 处抛错并如实回传，不会被吞掉。

///|
/// 一次「运行产物」任务：要启动的可执行文件绝对路径。
pub(all) struct LaunchJob {
  path : String
  on_result : (Result[Unit, String]) -> Unit
}

///|
/// App 私有的启动队列与工作者句柄。
pub(all) struct LaunchOwner {
  queue : @async.Queue[LaunchJob]
}

///|
pub fn LaunchOwner::new() -> LaunchOwner {
  { queue: Queue(kind=Unbounded), }
}

///|
/// 同步入队（UI 线程调用）。队列无界，满不是失败模式。
pub fn launch_submit(owner : LaunchOwner, job : LaunchJob) -> Unit {
  ignore(owner.queue.try_put(job) catch { _ => false })
}

///|
/// 工作循环：作为**随从**与窗口泵成对运行
/// （经 `@macos.run_window_with_workers`：窗口一返回就取消本循环）。
pub async fn launch_worker_loop(owner : LaunchOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let job = owner.queue.get()
      group.spawn_bg(async fn() { run_launch_job(job) })
    }
  })
}

///|
/// 执行一次启动；任何异常都转成结构化失败（不静默吞掉）。
async fn run_launch_job(job : LaunchJob) -> Unit {
  let result = launch_detached(job.path) catch {
    err => Err("无法启动产物：\{err}")
  }
  (job.on_result)(result)
}

///|
/// 脱离式启动一个可执行文件。
///
/// 前置校验路径确实存在且是**普通文件**：不存在时 `spawn` 的原生错误信息
/// 在各平台措辞不一，先自己判一次能给出稳定、可读的失败原因（编译失败后
/// 重编目录会被清空，旧路径就这样失效）。
pub async fn launch_detached(path : String) -> Result[Unit, String] {
  if !@x/fs.path_exists(path) {
    return Err("产物不存在（可能已被重新编译清理）：\{path}")
  }
  let is_directory = @x/fs.is_dir(path) catch { _ => false }
  if is_directory {
    return Err("产物路径指向目录，不是可执行文件：\{path}")
  }
  // `no_console_window` 让 Windows 上不会为 GUI 产物闪出一个控制台黑框
  // （macOS/Linux 忽略该参数，无副作用）。
  ignore(
    @process.spawn_orphan(
      path,
      [],
      cwd=work_dir_of(path),
      no_console_window=true,
    ),
  )
  Ok(())
}

///|
/// 产物所在目录：作为子进程的工作目录。
///
/// 为什么要显式给 cwd：从 Studio 继承 cwd 的话，导出应用解析相对路径
/// （图片、数据文件）会落到 Studio 的工作目录上——产物应该以**自己所在
/// 的位置**为基准，这也与用户双击它的行为一致。
pub fn work_dir_of(path : String) -> String {
  match path.rev_find("/") {
    Some(index) => if index == 0 { "/" } else { path[:index].to_owned() }
    None => "."
  }
}
