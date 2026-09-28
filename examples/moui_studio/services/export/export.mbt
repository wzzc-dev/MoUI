///|
/// MoUI Studio 导出：把 StudioProgram 打包成自包含 MoUI 应用项目。
/// 编译轨口径：项目 IR 被真编译——`moonbit_codegen.generate_source` 生成的可读
/// MoonBit 事件源码落进 bundle 的 `app/generated_handlers.mbt` 参与 `moon build`
/// （Studio 预览展示的就是同一份字节）；`compiled_runtime` 提供生成源码唯一依赖的
/// 执行面，bundle 内不含指令流解释器。

///|
/// 领域内核源码根映射：bundle 相对路径 → 逐字节内核源码。
/// 常量（kernel_ir_mbt / kernel_studio_lang_*_mbt / kernel_codec_mbt / runner_source）
/// 由 tools/sync_kernel 从 domain 源文件生成；本表把它们落到 bundle 的目标路径。
/// 内核 .mbt 与 Studio 逐字节同源，export_test 的漂移测试保证「改了内核忘同步」会失败。
fn kernel_sources() -> Array[(String, String)] {
  [
    ("domain/ir/ir.mbt", kernel_ir_mbt()),
    ("domain/ir/invariants.mbt", kernel_ir_invariants_mbt()),
    ("domain/ir/signature.mbt", kernel_ir_signature_mbt()),
    ("domain/studio_lang/aliases.mbt", kernel_studio_lang_aliases_mbt()),
    ("domain/studio_lang/errors.mbt", kernel_studio_lang_errors_mbt()),
    ("domain/studio_lang/keywords.mbt", kernel_studio_lang_keywords_mbt()),
    ("domain/studio_lang/lexer.mbt", kernel_studio_lang_lexer_mbt()),
    ("domain/studio_lang/parser.mbt", kernel_studio_lang_parser_mbt()),
    ("domain/studio_lang/printer.mbt", kernel_studio_lang_printer_mbt()),
    ("domain/studio_lang/interp.mbt", kernel_studio_lang_interp_mbt()),
    ("domain/studio_lang/semantics.mbt", kernel_studio_lang_semantics_mbt()),
    ("domain/codec/codec.mbt", kernel_codec_mbt()),
    ("compiled_runtime/runtime.mbt", kernel_compiled_runtime_mbt()),
    ("app/runner.mbt", runner_source()),
  ]
}

///|
/// 生成一批「相对路径 → 内容」的文件。
/// `project_json` 必须是编码后的项目 JSON；`name` 用作目录与模块名。
pub fn export_bundle(
  project_json : String,
  name : String,
) -> Array[(String, String)] {
  let safe = sanitize_name(name)
  let files : Array[(String, String)] = []
  files.push(("\{safe}/moon.mod", moon_mod(safe)))
  // 领域内核的 moon.pkg 生成（模块路径指向 bundle 本地包；.mbt 才是逐字节快照）
  files.push(("\{safe}/domain/ir/moon.pkg", ir_pkg()))
  files.push(("\{safe}/domain/studio_lang/moon.pkg", studio_lang_pkg(safe)))
  files.push(("\{safe}/domain/codec/moon.pkg", codec_pkg(safe)))
  // app 包：组合根 moon.pkg + 内嵌项目数据 + 通用 runner + 内核快照
  files.push(("\{safe}/app/moon.pkg", app_pkg(safe)))
  files.push(("\{safe}/compiled_runtime/moon.pkg", compiled_runtime_pkg(safe)))
  files.push(("\{safe}/app/project_data.mbt", project_data_mbt(project_json)))
  // 编译轨的唯一事件源码：预览视图与 bundle 用同一个生成函数，逐字节同源。
  files.push(
    ("\{safe}/app/generated_handlers.mbt", generated_handlers_mbt(project_json)),
  )
  for pair in kernel_sources() {
    files.push(("\{safe}/\{pair.0}", pair.1))
  }
  // Web 入口（薄组合根 + ABI 垫片 + 宿主页）
  files.push(("\{safe}/web_wasm/moon.pkg", web_pkg(safe)))
  files.push(("\{safe}/web_wasm/main.mbt", web_main()))
  files.push(("\{safe}/web_wasm/abi.mbt", abi_mbt()))
  files.push(("\{safe}/web_wasm/index.html", web_index_html(safe)))
  // native 启动存活烟测：workspace 外构建可执行包并真跑一遍生成 handler。
  files.push(("\{safe}/native_smoke/moon.pkg", native_smoke_pkg(safe)))
  files.push(("\{safe}/native_smoke/main.mbt", native_smoke_main()))
  files.push(("\{safe}/README.md", readme(safe)))
  files.push(("\{safe}/deps.txt", deps_txt()))
  files
}

///|
/// 模块名只保留字母数字，其余折叠为连字符（MoonBit 模块名友好）。
pub fn sanitize_name(name : String) -> String {
  let mut out = ""
  for c in name {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') {
      out = out + c.to_string()
    } else {
      out = out + "-"
    }
  }
  while out.contains("--") {
    out = out.replace(old="--", new="-")
  }
  if out.is_empty() {
    "studio-export"
  } else {
    out
  }
}

///|
/// 导出项目的 moon.mod（版本与 Studio 发布口径一致，锁定运行时闭包）。
pub fn moon_mod(name : String) -> String {
  "name = \"\{name}\"\n\nversion = \"0.1.0\"\n\npreferred_target = \"native\"\n\nimport {\n  \"wzzc-dev/moui@0.1.12\",\n  \"wzzc-dev/window@0.5.4-0.1.7\",\n  \"wzzc-dev/moui_skia_renderer@0.1.11\",\n  \"wzzc-dev/moui_web_renderer@0.1.10\",\n  \"moonbitlang/async@0.22.1\",\n  \"moonbitlang/x@0.5.5\",\n}\n"
}

///|
/// domain/ir：零依赖纯 MoonBit。
pub fn ir_pkg() -> String {
  "supported_targets = \"native+wasm-gc\"\n"
}

///|
/// domain/studio_lang：只依赖 bundle 本地的 domain/ir。
pub fn studio_lang_pkg(name : String) -> String {
  "import {\n  \"\{name}/domain/ir\",\n}\n\nsupported_targets = \"native+wasm-gc\"\n"
}

///|
/// domain/codec：依赖本地 ir/studio_lang + core/json（与 Studio 源 moon.pkg 对齐）。
pub fn codec_pkg(name : String) -> String {
  "import {\n  \"moonbitlang/core/json\",\n  \"\{name}/domain/ir\",\n  \"\{name}/domain/studio_lang\",\n}\n\nsupported_targets = \"native+wasm-gc\"\n"
}

///|
/// app 包：组合根导入 moui + views + 本地领域内核（runner 只引用这些）。
pub fn app_pkg(name : String) -> String {
  "import {\n  \"\{name}/domain/ir\",\n  \"\{name}/domain/codec\",\n  \"\{name}/compiled_runtime\",\n  \"wzzc-dev/moui\",\n  \"wzzc-dev/moui/views\",\n  \"wzzc-dev/moui/core\",\n  \"wzzc-dev/moui/graphics\",\n  \"wzzc-dev/moui/views/style\",\n}\n\nsupported_targets = \"native+wasm-gc\"\n"
}

///|
/// 编译轨运行时包：只依赖 bundle 本地领域内核（ir/studio_lang）。
pub fn compiled_runtime_pkg(name : String) -> String {
  "import {\n  \"\{name}/domain/ir\",\n  \"\{name}/domain/studio_lang\",\n}\n\nsupported_targets = \"native+wasm-gc\"\n"
}

///|
/// app 包里的生成事件源码：导出时从项目 IR 烘死，和 Studio 预览同一函数。
pub fn generated_handlers_mbt(project_json : String) -> String {
  match @codec.decode_program(project_json) {
    Ok(program) => generate_source(program).source
    Err(_) =>
      "///|\npub fn studio_dispatch_handler(_control : String, _event_tag : String) -> @compiled_runtime.Handler? {\n  None\n}\n"
  }
}

///|
/// 项目数据内嵌为 `#|` 多行字符串字面量。`#|` **不做 `\{x}` 插值、不解析转义**，
/// 因此 JSON 的引号/花括号原样输出（先 parse+stringify 紧凑成单行，保证可放一行）。
pub fn project_data_mbt(project_json : String) -> String {
  let compact = try {
    match @json.parse(project_json) {
      value => value.stringify()
    }
  } catch {
    _ => project_json
  }
  "///|\n/// 导出的 MoUI Studio 项目（.studio.json v1）。由导出器内嵌，勿手改。\npub fn project_json() -> String {\n  let data =\n    #|\{compact}\n    #|\n  data\n}\n"
}

///|
/// 转义 MoonBit 字符串字面量（README/诊断等非 #| 场景用）。
pub fn escape_mbt(text : String) -> String {
  let mut out = ""
  for c in text {
    if c == '\\' {
      out = out + "\\\\"
    } else if c == '"' {
      out = out + "\\\""
    } else if c == '\n' {
      out = out + "\\n"
    } else if c == '\r' {
      out = out + "\\r"
    } else if c == '\t' {
      out = out + "\\t"
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
pub fn web_pkg(name : String) -> String {
  "import {\n  \"wzzc-dev/moui/backend/web\",\n  \"wzzc-dev/moui_web_renderer\" @webgpu_adapter,\n  \"wzzc-dev/moui/runtime\",\n  \"\{name}/app\" @exported_app,\n}\n\nsupported_targets = \"wasm-gc\"\n\npkgtype(kind: \"executable\")\n\noptions(\n  link: {\n    \"wasm-gc\": {\n      \"exports\": [\n        \"web_dispatch_event\",\n        \"web_dispatch_pointer_input\",\n        \"web_dispatch_semantics_action\",\n        \"web_dispatch_route\",\n        \"web_complete_async_clipboard_read\",\n        \"web_complete_async_file_dialog\",\n      ],\n    },\n  },\n  targets: { \"main.mbt\": [ \"wasm-gc\" ] },\n)\n"
}

///|
/// 可执行包的 ABI 垫片：Moon 的 wasm 链接器只导出「可执行包自身定义」的函数，
/// 因此 `moon.pkg` 的 `link.exports` 列出的宿主入口必须在本包内定义，
/// 再转发到 `moui/backend/web`。保持纯机械转发，不放平台/应用逻辑。
pub fn abi_mbt() -> String {
  let abi =
    #|///|
    #|// Moon only exports functions defined by the executable package. Keep this
    #|// mechanical ABI shim free of platform or application logic.
    #|pub fn web_dispatch_event(
    #|  kind : Int,
    #|  raw_id : Int,
    #|  arg0 : Int,
    #|  arg1 : Int,
    #|  argd : Double,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_pointer_input(
    #|  raw_id : Int,
    #|  kind : Int,
    #|  x_px : Double,
    #|  y_px : Double,
    #|  delta_x_px : Double,
    #|  delta_y_px : Double,
    #|  button : Int,
    #|  modifiers : Int,
    #|) -> Int {
    #|  @web.web_dispatch_pointer_input(
    #|    raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers,
    #|  )
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
    #|  @web.web_dispatch_route(source_code, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_semantics_action(
    #|  raw_id : Int,
    #|  node_id_text_id : Int,
    #|  generation_text_id : Int,
    #|  action_code : Int,
    #|  value_id : Int,
    #|  direction_code : Int,
    #|) -> Unit {
    #|  @web.web_dispatch_semantics_action(
    #|    raw_id, node_id_text_id, generation_text_id, action_code, value_id, direction_code,
    #|  )
    #|}
    #|
    #|///|
    #|pub fn web_complete_async_clipboard_read(
    #|  request_id : Int,
    #|  ok : Bool,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_complete_async_clipboard_read(request_id, ok, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_complete_async_file_dialog(
    #|  request_id : Int,
    #|  ok : Bool,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_complete_async_file_dialog(request_id, ok, text_id)
    #|}
  abi
}

///|
pub fn web_main() -> String {
  "///|\nfn main {\n  @runtime.run_app(\n    \"MoUI Studio Export\",\n    @runtime.new_program_with_dimensions(program=@exported_app.program(), width=960.0, height=640.0),\n  )\n  .render_all(@webgpu_adapter.from_env())\n  .backend(@web.entry())\n  .run()\n}\n"
}

///|
/// Web 宿主页。目录契约（导出应用在 workspace 外可启动的关键）：
/// `runtime.js` 从**本项目自己的依赖目录**加载——
/// `<bundle>/.mooncakes/wzzc-dev/moui_web_renderer/runtime.js`，
/// 其内部 `../moui/backend/web/browser_runtime.js` 导入因此解析到
/// `<bundle>/.mooncakes/wzzc-dev/moui/backend/web/browser_runtime.js`（`wzzc-dev/moui`
/// 是本项目 moon.mod 的依赖，`moon build` 后会出现在 `.mooncakes`），
/// 动态 `./canvas2d_runtime.js` 与 runtime.js 同目录。
/// wasm 路径相对于本页指向 `<bundle>/_build/...`。
/// 以 bundle 根目录为静态服务器根即可打开 `web_wasm/index.html`
/// （`python3 -m http.server` 会正常提供点号目录）。
pub fn web_index_html(name : String) -> String {
  ignore(name)
  let html =
    #|<!doctype html>
    #|<html lang="en">
    #|  <head>
    #|    <meta charset="utf-8" />
    #|    <meta name="viewport" content="width=device-width, initial-scale=1" />
    #|    <title>MoUI Studio Export</title>
    #|    <style>
    #|      * { box-sizing: border-box; }
    #|      html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; background: #f6f7f9; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    #|      canvas { display: block; width: 100%; height: 100%; outline: none; touch-action: none; }
    #|      #canvas-host { width: 100vw; height: 100vh; }
    #|      #diagnostics {
    #|        display: none;
    #|        position: fixed;
    #|        right: 12px;
    #|        bottom: 12px;
    #|        width: min(520px, calc(100vw - 24px));
    #|        max-height: 40vh;
    #|        overflow: auto;
    #|        padding: 12px;
    #|        border: 1px solid rgba(0, 0, 0, 0.16);
    #|        border-radius: 8px;
    #|        background: rgba(255, 255, 255, 0.94);
    #|        font: 12px/1.45 "SFMono-Regular", ui-monospace, Menlo, Consolas, monospace;
    #|      }
    #|      body.debug #diagnostics,
    #|      body.failed #diagnostics { display: block; }
    #|      #status { font-weight: 600; margin-bottom: 8px; }
    #|      #log { margin: 0; white-space: pre-wrap; }
    #|    </style>
    #|  </head>
    #|  <body>
    #|    <div id="canvas-host" aria-label="MoUI Studio Export canvas host"></div>
    #|    <aside id="diagnostics" aria-live="polite">
    #|      <div id="status">Loading wasm-gc...</div>
    #|      <pre id="log"></pre>
    #|    </aside>
    #|    <script type="module">
    #|      import { bootMouiWasmGcApp } from "../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js";
    #|
    #|      if (new URLSearchParams(window.location.search).get("debug") === "1") {
    #|        document.body.classList.add("debug");
    #|      }
    #|
    #|      const status = document.querySelector("#status");
    #|      const log = document.querySelector("#log");
    #|      let line = "";
    #|      const append = message => {
    #|        log.textContent += message + "\n";
    #|        log.scrollTop = log.scrollHeight;
    #|      };
    #|      const setStatus = message => {
    #|        status.textContent = message;
    #|        append(message);
    #|      };
    #|
    #|      bootMouiWasmGcApp({
    #|        wasmUrl: new URL(
    #|          "../_build/wasm-gc/debug/build/web_wasm/web_wasm.wasm",
    #|          import.meta.url,
    #|        ),
    #|        canvasHost: "#canvas-host",
    #|        onStatus: setStatus,
    #|        onPrint(ch) {
    #|          if (ch === "\n") {
    #|            append(line);
    #|            line = "";
    #|          } else {
    #|            line += ch;
    #|          }
    #|        },
    #|      }).then(() => {
    #|        status.textContent = "Running";
    #|        append("MoonBit wasm-gc started.");
    #|      }).catch(error => {
    #|        document.body.classList.add("failed");
    #|        status.textContent = "Failed";
    #|        append(error.stack || String(error));
    #|        console.error(error);
    #|      });
    #|    </script>
    #|  </body>
    #|</html>
  html
}

///|
pub fn readme(name : String) -> String {
  "# \{name}\n\n由 MoUI Studio 导出的可运行 MoUI 应用。\n\n## 运行\n\n```sh\n# Web（wasm-gc）\nmoon build \{name}/web_wasm --target wasm-gc\n\n# 以项目根为静态服务器根目录\npython3 -m http.server 8792\n# 浏览器打开 /\{name}/web_wasm/index.html\n\n# native（Skia 组合根可编译）\nmoon check \{name}/app --target native\n```\n\n## 说明\n\n本应用**可直接运行**，且走的是**编译轨**：项目 IR 在导出时被编译成\n`app/generated_handlers.mbt`（可由 MoUI Studio 的毕业通道预览逐字节查看），\n由 `compiled_runtime/runtime.mbt` 执行面直接执行——bundle 里没有指令流解释器。\n领域内核（`domain/ir`、`domain/studio_lang`、`domain/codec` 共 11 个 .mbt）与\nMoUI Studio 逐字节同源，两轨审计文本与运行语义可比。\n\n- 打开即加载项目并校验（非法项目会原样阻止并说明原因）；\n- 点击按钮 / 改变输入 / 选择列表项触发对应事件子程序，编译产物直接执行到终止态；\n- 跑到 `提交数据`/`询问` 闸门会**暂停等待人工确认**（确认/拒绝是真实按钮，确认前零真实外发）；\n- 底部审计日志逐步留痕，`message_box` 消息集中展示。\n\n离线即可完整跑通。可视化编辑、积木编排、AI 生成等创作能力请使用 MoUI Studio。\n"
}

///|
/// native 启动烟测包：只依赖 bundle 的 app（生成源码分派）+ 编译轨运行时，
/// 不依赖任何 renderer/窗口服务；`main` 真跑全部生成 handler 后打印标记退出 0。
pub fn native_smoke_pkg(name : String) -> String {
  "import {\n  \"\{name}/app\" @app,\n  \"\{name}/domain/codec\",\n  \"\{name}/domain/ir\",\n  \"\{name}/compiled_runtime\",\n  \"moonbitlang/x/sys\",\n}\n\nsupported_targets = \"native\"\n\npkgtype(kind: \"executable\")\n\noptions(\n  targets: { },\n)\n"
}

///|
pub fn native_smoke_main() -> String {
  "///|\n/// 导出 bundle 的 native 启动存活烟测：解码内嵌项目 → 逐 handler 走\n/// 编译轨分派与执行 → 闸门自动确认 → 打印可判定标记并退出 0。\nfn main {\n  let decoded = @codec.decode_program(@app.project_json())\n  if decoded is Err(errors) {\n    println(\"studio native export smoke: decode failed (\\{errors.length()})\")\n    @sys.exit(2)\n  }\n  let program = match decoded {\n    Ok(value) => value\n    Err(_) => @ir.empty_program()\n  }\n  let rt = @compiled_runtime.runtime_for_program(program)\n  let mut ran = 0\n  for handler in program.handlers {\n    match @app.studio_dispatch_handler(handler.control_name, handler.event.tag()) {\n      None => ()\n      Some(dispatch) => {\n        drain(rt, dispatch)\n        ran = ran + 1\n      }\n    }\n  }\n  if rt.status is @compiled_runtime.Failed {\n    println(\"studio native export smoke: runtime failed\")\n    @sys.exit(3)\n  }\n  println(\n    \"studio native export smoke: ok handlers=\\{program.handlers.length()} ran=\\{ran} audit=\\{rt.audit.length()}\"\n  )\n}\n\n///|\nfn drain(rt : @compiled_runtime.Runtime, handler : @compiled_runtime.Handler) -> Unit {\n  let mut status = @compiled_runtime.run_handler(rt, handler)\n  while status is @compiled_runtime.WaitingGate {\n    status = @compiled_runtime.answer_gate(rt, true)\n  }\n}\n"
}

///|
pub fn deps_txt() -> String {
  "wzzc-dev/moui@0.1.12\nwzzc-dev/moui_web_renderer@0.1.10\nwzzc-dev/moui_skia_renderer@0.1.11\n"
}
