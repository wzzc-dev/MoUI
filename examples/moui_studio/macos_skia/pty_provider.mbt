///|
/// PTY native provider（M5）：vendor examples/terminal 的 pty_host 宿主
/// 技术（pty.c stub：openpty + posix_spawn FFI，已复制为本包 pty.c）。
/// MoonBit 跨 workspace 模块导入不可行（moon.mod import 仅版本化
/// registry 依赖，探针实测），供应商绑定按 Cordis「provider 在组合根」
/// 落在这里。形态照搬 terminal composition 的成熟模式：
/// queue + worker + task group（读循环与写入并行）+ 窗口关闭 Shutdown。

///|
#borrow(shell)
extern "C" fn pty_spawn(
  shell : Bytes,
  shell_len : Int,
  cols : Int,
  rows : Int,
) -> Int64 = "moonpty_spawn"

///|
#borrow(pid)
extern "C" fn pty_reap(pid : Int) -> Int64 = "moonpty_reap"

///|
#borrow(pid)
extern "C" fn pty_signal(pid : Int, sig : Int) -> Int64 = "moonpty_signal"

///|
/// PTY 会话：master 端 fd + 子进程 pid（raw_fd 异步读写，与
/// examples/terminal/pty_host 同构）。
priv struct Pty {
  pid : Int
  raw : @raw_fd.RawFd
}

///|
/// 派生一个运行 shell 的 PTY 会话（worker 异步上下文内调用）。
/// 仅 Unix：async 的 `Fd` 在 Windows 上是 opaque HANDLE，无法从 Int 构造，
/// 且 pty.c 依赖 openpty/posix_spawn。Windows 侧编不过也跑不了，直接报
/// 不可用（workspace check 在所有 native 平台做类型检查）。
#cfg(not(platform="windows"))
async fn Pty::spawn_shell(shell : String, cols : Int, rows : Int) -> Pty? {
  let bytes = @utf8.encode(shell)
  let arr : Array[Byte] = []
  for i in 0..<bytes.length() {
    arr.push(bytes[i])
  }
  arr.push(b'\x00')
  let packed = pty_spawn(Bytes::from_array(arr), bytes.length(), cols, rows)
  if packed < 0L {
    return None
  }
  let pid = (packed >> 32).to_int()
  let raw = @raw_fd.RawFd::RawFd(packed.to_int())
  Some({ pid, raw, })
}

///|
/// Windows 桩：无 PTY 可派生，spawn 直接失败（UI 侧走 on_exit 分支）。
#cfg(platform="windows")
async fn Pty::spawn_shell(_shell : String, _cols : Int, _rows : Int) -> Pty? {
  println("[pty] PTY is not supported on this platform")
  None
}

///|
/// 关闭会话（M8-fix 重排序）：**先退进程、再关 master fd**——macOS 上
/// slave 仍被 shell 持有时 close(master) 会阻塞在 tty close（真机卡死
/// 实证：主线程 UN+ 挂在 close）。顺序：SIGHUP → reap → SIGKILL 兜底
/// → reap → 最后 close（zsh 已死、slave 已关，close 立即返回）。
fn Pty::shutdown(self : Pty) -> Unit {
  ignore(pty_signal(self.pid, 1)) // SIGHUP：通知 shell 退出
  ignore(pty_reap(self.pid))
  ignore(pty_signal(self.pid, 9)) // SIGKILL 兜底：确保进程死透
  ignore(pty_reap(self.pid))
  self.raw.close()
}

///|
/// 输出读循环：持续读取 PTY 输出并以文本块 emit（decode_lossy——跨块
/// 多字节拆分时替换符，v1 诚实口径：shell 回显以 ASCII 为主）。
/// 子进程退出（EOF）时结束。
async fn Pty::pty_read_loop(self : Pty, emit : (String) -> Unit) -> Unit {
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  while true {
    let n = self.raw.read(buf)
    if n <= 0 {
      break
    }
    let text = @utf8.decode_lossy(buf.unsafe_reinterpret_as_bytes()[0:n])
    emit(text)
  }
}

///|
/// worker 工作项：派生（带输出/退出回调与 emit 泵）/ 写入 / 终止 / 退出。
priv enum PtyWork {
  PtySpawnWork(
    Int,
    Int,
    (String) -> @studio_app.Msg,
    () -> @studio_app.Msg,
    (@studio_app.Msg) -> Unit
  )
  PtyWriteWork(String)
  PtyKillWork
  PtyShutdown
}

///|
priv struct PtyProvider {
  queue : @async.Queue[PtyWork]
  pty_ref : Ref[Pty?]
}

///|
/// 默认 shell：env SHELL，回退 /bin/sh（terminal composition 同款）。
fn default_shell() -> String {
  @env.get_env_var("SHELL").unwrap_or("/bin/sh")
}

///|
/// 构造 native PtyService：spawn/write/kill 同步入队（UI 线程零阻塞，
/// 返回登记表句柄 0——单会话），worker 异步执行真实 PTY 操作。
fn pty_native_service(
  provider : PtyProvider,
) -> @kernel.PtyService[@studio_app.Msg] {
  {
    available: true,
    spawn: fn(cols, rows, on_output, on_exit, emit) {
      let _ = provider.queue.try_put(
        PtySpawnWork(cols, rows, on_output, on_exit, emit),
      ) catch {
        _ => false
      }
      Some(0)
    },
    write: fn(_handle, input) {
      let _ = provider.queue.try_put(PtyWriteWork(input)) catch { _ => false }
    },
    resize: fn(_handle, _cols, _rows) { () },
    kill: fn(_handle) {
      let _ = provider.queue.try_put(PtyKillWork) catch { _ => false }
    },
  }
}

///|
/// 请求一次优雅退出（窗口关闭时调用；worker 收尾 kill + 退出循环）。
fn pty_provider_shutdown(provider : PtyProvider) -> Unit {
  let _ = provider.queue.try_put(PtyShutdown) catch { _ => false }
}

///|
/// worker 主循环：等真实派生 → 读循环与写入并行（task group）→
/// Kill/Shutdown 走「先取消读循环再关闭 PTY」的既有顺序（避免与同一
/// fd 竞争）。
async fn pty_worker_loop(provider : PtyProvider) -> Unit {
  println("[pty] worker loop started")
  while true {
    match provider.queue.get() {
      PtySpawnWork(cols, rows, on_output, on_exit, emit) => {
        println("[pty] spawn request: \{cols}x\{rows}")
        // 重复派生前先收掉旧会话（单会话登记表）
        match provider.pty_ref.val {
          Some(old) => {
            old.shutdown()
            provider.pty_ref.val = None
          }
          None => ()
        }
        let shell = default_shell()
        println("[pty] spawning shell: \{shell}")
        match Pty::spawn_shell(shell, cols, rows) {
          Some(pty) => {
            println("[pty] spawned pid=\{pty.pid}")
            provider.pty_ref.val = Some(pty)
            @async.with_task_group(group => {
              let reader = group.spawn(no_wait=true, allow_failure=true) <| () => {
                pty.pty_read_loop(fn(text) { emit(on_output(text)) })
              }
              // 读循环占住本协程期间的写入：从队列继续取（Spawn 之外的项）
              // ——与 terminal composition 的 task group 同款分工。
              while true {
                match provider.queue.get() {
                  PtyWriteWork(text) =>
                    ignore(pty.raw.write(@utf8.encode(text)) catch { _ => 0 })
                  // Kill/Shutdown：先取消读循环再关 fd，**退出 group**——
                  // 下一次派生从外层循环全新开始。此前 Kill 不退出 group，
                  // reopen 的 SpawnWork 到达内层循环命中重入队分支 →
                  // 同一工作项无限入队/取出 = 卡死（真机采样实证）。
                  PtyKillWork => {
                    reader.cancel()
                    pty.shutdown()
                    provider.pty_ref.val = None
                    break
                  }
                  PtyShutdown => {
                    reader.cancel()
                    pty.shutdown()
                    provider.pty_ref.val = None
                    return
                  }
                  // group 活跃期 handle 必 Some → 不会触发新派生；防御性丢弃
                  PtySpawnWork(_, _, _, _, _) => ()
                }
              }
            })
          }
          None => emit(on_exit())
        }
      }
      PtyWriteWork(text) =>
        // 未派生时的写入：丢弃（无会话可写）
        ignore(text)
      PtyKillWork =>
        match provider.pty_ref.val {
          Some(pty) => {
            pty.shutdown()
            provider.pty_ref.val = None
          }
          None => ()
        }
      PtyShutdown => {
        match provider.pty_ref.val {
          Some(pty) => {
            pty.shutdown()
            provider.pty_ref.val = None
          }
          None => ()
        }
        return
      }
    }
  }
}
