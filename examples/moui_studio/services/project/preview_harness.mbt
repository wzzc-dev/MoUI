///|
/// 预览 harness 生成器(M1 第一步,纯函数)。
///
/// 向导入工程写 `.studio/preview/` 包:headless 构造工程的
/// `program()`(用户包以 `@user_app` 别名导入),把**绘制命令序列**与
/// **语义树**序列化成版本化 JSON 打到 stdout——`moon run` 的输出混有
/// 工具链日志,解析端以哨兵行定位有效载荷。
///
/// 纪律(计划 M1):harness 是**生成物**——带版本戳、只写 `.studio/`
/// 生成目录、绝不改用户文件;用户手改会被下次生成覆盖(文件头注明)。
/// 尺寸先取 Studio 设计坐标 640×480(参数化在后续里程碑)。

///|
/// harness 协议版本(与 Studio 解析端锁定)。
pub const PREVIEW_HARNESS_VERSION : Int = 1

///|
/// stdout 哨兵行:moon run 的编译日志之后,以此行开始才是有效载荷。
pub const PREVIEW_SENTINEL : String = "__STUDIO_PREVIEW_V1__"

///|
/// 预览舞台尺寸(与 Studio 设计坐标系一致)。
pub const PREVIEW_STAGE_WIDTH : Double = 640.0

///|
pub const PREVIEW_STAGE_HEIGHT : Double = 480.0

///|
/// harness 包在工程内的相对路径。
pub const PREVIEW_PACKAGE_REL : String = ".studio/preview"

///|
/// 生成 harness 包文件:(相对 `.studio/preview` 的文件名, 内容)。
/// `module_name` = moon.mod name;`program_rel` = 含 `pub fn program`
/// 的包相对路径(walk 已探测)。程序包以 `@user_app` 别名导入。
pub fn preview_harness_files(
  module_name : String,
  program_rel : String,
) -> Array[(String, String)] {
  let app_package = if program_rel == "" {
    module_name
  } else {
    "\{module_name}/\{program_rel}"
  }
  [
    ("moon.pkg", preview_moon_pkg(app_package)),
    ("main.mbt", preview_main_mbt()),
  ]
}

///|
fn preview_moon_pkg(app_package : String) -> String {
  let builder = StringBuilder()
  builder.write_string("import {\n")
  builder.write_string("  \"wzzc-dev/moui\",\n")
  builder.write_string("  \"wzzc-dev/moui/core\",\n")
  builder.write_string("  \"wzzc-dev/moui/runtime\",\n")
  builder.write_string("  \"moonbitlang/core/json\" @json,\n")
  builder.write_string("  \"\{app_package}\" @user_app,\n")
  builder.write_string("}\n\n")
  builder.write_string("supported_targets = \"native\"\n")
  builder.to_string()
}

///|
fn preview_main_mbt() -> String {
  let builder = StringBuilder()
  builder.write_string("/// 由 MoUI Studio 生成(.studio/preview/main.mbt,")
  builder.write_string(
    "harness v\{PREVIEW_HARNESS_VERSION})——勿手改,重新导入会覆盖。\n",
  )
  builder.write_string(
    "/// headless 构造本工程 program():绘制命令 + 语义树序列化为 JSON,\n",
  )
  builder.write_string(
    "/// 以哨兵行 \{PREVIEW_SENTINEL} 起头打到 stdout(工具链日志之后)。\n",
  )
  builder.write_string("fn main {\n")
  builder.write_string(
    "  let runtime = @runtime.new_program_with_dimensions(\n",
  )
  builder.write_string("    program=@user_app.program(),\n")
  builder.write_string("    width=\{PREVIEW_STAGE_WIDTH},\n")
  builder.write_string("    height=\{PREVIEW_STAGE_HEIGHT},\n")
  builder.write_string("  )\n")
  builder.write_string("  let commands : Array[@json.Json] = []\n")
  builder.write_string("  for command in runtime.draw_commands() {\n")
  builder.write_string("    commands.push(command.to_json())\n")
  builder.write_string("  }\n")
  builder.write_string("  let semantics : Array[@json.Json] = []\n")
  builder.write_string("  match runtime.read_semantics() {\n")
  builder.write_string("    Ok(full) =>\n")
  builder.write_string("      match full {\n")
  builder.write_string("        @runtime.Full(snapshot) =>\n")
  builder.write_string("          for node in snapshot.nodes() {\n")
  builder.write_string("            semantics.push(node.to_json())\n")
  builder.write_string("          }\n")
  builder.write_string("        _ => ()\n")
  builder.write_string("      }\n")
  builder.write_string("    _ => ()\n")
  builder.write_string("  }\n")
  builder.write_string("  let payload = @json.Json::object({\n")
  // 版本用字符串、尺寸写字面小数:不依赖 Double 插值的格式,协议两端稳定
  builder.write_string(
    "    \"version\": @json.Json::string(\"\{PREVIEW_HARNESS_VERSION}\"),\n",
  )
  builder.write_string("    \"width\": @json.Json::number(640.0),\n")
  builder.write_string("    \"height\": @json.Json::number(480.0),\n")
  builder.write_string("    \"commands\": @json.Json::array(commands),\n")
  builder.write_string("    \"semantics\": @json.Json::array(semantics),\n")
  builder.write_string("  })\n")
  builder.write_string("  println(\"\{PREVIEW_SENTINEL}\")\n")
  builder.write_string("  println(payload.stringify())\n")
  builder.write_string("}\n")
  builder.to_string()
}
