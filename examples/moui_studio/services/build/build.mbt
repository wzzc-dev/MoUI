///|
/// 通用构建服务(M0-7)——**数据面**(双目标):kind、报告、命令构造。
///
/// 执行面(队列/进程/worker)在 `services/build_native`(native-only),
/// 镜像 export(数据)/ compile_native(执行)的分层——app 包经由闭包
/// 注入消费构建能力,不直接 import 执行包,保持 wasm-gc 可编译。
///
/// 与编译轨(compile_native)的分工:
/// - **BkStudioCompile 不在本包**——编译轨是五阶段管线(export bundle →
///   update → check → build ×2 → smoke),由既有 `services/compile_native`
///   承担;app 层按 kind 分发时把它路由回 `CompileRun`,不复制管线。
/// - 本包只描述「工程目录里的单条 moon 命令」:FramePreview(`moon run`,
///   M1 接 harness)、WebPreview(`moon build --target wasm-gc`,M2)、
///   RunNative(`moon build --target native`,M3)。
///
/// 诊断:命令输出经 `@export.parse_moon_diagnostics` 解析(moon check/build
/// 输出格式与编译轨一致,同一解析器)。失败口径:**不静默**,ok=false +
/// 原始输出 + 诊断。

///|
/// 构建种类。app 层按它分发:StudioCompile 走既有编译轨,其余走 build_native。
pub(all) enum BuildKind {
  // Eq/Debug:测试断言与诊断报告需要
  /// 模式一:headless 预览帧(`moon run` 预览 harness;M1 挂 harness)
  BkFramePreview
  /// 模式二:Web 构建(`moon build <web 入口> --target wasm-gc`)
  BkWebPreview
  /// 模式三:native 构建(`moon build <native 入口> --target native`)
  BkRunNative
} derive(Eq, Debug)

///|
pub extend BuildKind with Eq::{not_equal, equal}

///|
pub extend BuildKind with @debug.Debug::{to_repr}

///|
/// kind 标签(稳定 token,日志/报告用;本地化在 app 层)。
pub fn BuildKind::tag(self : BuildKind) -> String {
  match self {
    BkFramePreview => "frame-preview"
    BkWebPreview => "web-preview"
    BkRunNative => "run-native"
  }
}

///|
/// 构建结果:ok = 全部命令零码退出;诊断来自输出解析;output 保留尾部
/// (截断到 20000 字符,与编译轨同一上限,防超大日志拖垮 UI/内存)。
pub(all) struct BuildReport {
  kind : BuildKind
  ok : Bool
  /// 命令退出码(取消/启动失败为 -1)
  exit_code : Int
  output : String
  diagnostics : Array[@export.CompileDiagnostic]
  /// Web 构建:静态服务应服务的**根目录**(workspace 根;向上找 moon.work,
  /// 独立模块 = 工程根)。非 Web 构建为空串。
  web_root : String
  /// Web 构建:index.html 相对服务根的路径。非 Web 构建为空串。
  web_index_rel : String
  /// RunNative 构建:可执行产物绝对路径(自动启动用)。其他为空串。
  artifact_path : String
}

///|
/// 构建请求(执行面消费;数据面只定义形状)。
pub(all) struct BuildRequest {
  kind : BuildKind
  /// 工程根目录(用户工程内构建,不走临时目录)
  root : String
  /// 入口包相对路径(web_wasm / macos_skia / .studio/preview)
  entry_rel : String
  on_result : (Result[BuildReport, String]) -> Unit
}

///|
/// moon 可执行文件(MOON_BIN 覆盖;与 compile_native 同一口径)。
fn moon_bin() -> String {
  @env.get_env_var("MOON_BIN").unwrap_or("moon")
}

///|
/// kind → moon 命令序列(在工程根执行)。
pub fn build_commands(
  kind : BuildKind,
  entry_rel : String,
) -> Array[Array[String]] {
  let moon = moon_bin()
  match kind {
    BkFramePreview => [[moon, "run", entry_rel, "--target", "native"]]
    BkWebPreview => [[moon, "build", entry_rel, "--target", "wasm-gc"]]
    BkRunNative => [[moon, "build", entry_rel, "--target", "native"]]
  }
}

///|
const BUILD_OUTPUT_LIMIT : Int = 20000

///|
/// 截断到上限,保留尾部(最新输出最有诊断价值)。
pub fn tail_output(output : String) -> String {
  if output.length() <= BUILD_OUTPUT_LIMIT {
    return output
  }
  output[output.length() - BUILD_OUTPUT_LIMIT:].to_owned()
}

///|
pub fn join_args(args : Array[String]) -> String {
  let mut out = ""
  let mut i = 0
  while i < args.length() {
    if i > 0 {
      out = out + " "
    }
    out = out + args[i]
    i = i + 1
  }
  out
}

///|
pub fn drop_first(args : Array[String]) -> Array[String] {
  let rest : Array[String] = []
  let mut i = 1
  while i < args.length() {
    rest.push(args[i])
    i = i + 1
  }
  rest
}
