///|
pub let platform_order : ReadOnlyArray[String] = [
  "web", "macos", "windows", "linux", "android", "ios", "harmonyos",
]

///|
pub fn is_platform(value : String) -> Bool {
  platform_order.contains(value)
}

///|
pub fn is_mobile_platform(value : String) -> Bool {
  value == "android" || value == "ios" || value == "harmonyos"
}

///|
pub fn default_platforms(host : HostPlatform) -> Array[String] {
  let result = ["web"]
  match host {
    Macos => result.push("macos")
    Windows => result.push("windows")
    Linux => result.push("linux")
    Unknown => ()
  }
  result
}

///|
pub fn normalize_platforms(
  host : HostPlatform,
  requested : Array[String],
) -> Result[Array[String], String] {
  let selected : Map[String, Bool] = Map([])
  for platform in default_platforms(host) {
    selected[platform] = true
  }
  for requested_platform in requested {
    let platform = requested_platform.to_lower()
    if platform == "all" {
      for value in platform_order {
        selected[value] = true
      }
    } else if is_platform(platform) {
      selected[platform] = true
    } else {
      return Err(
        "unsupported platform: " +
        requested_platform +
        " (expected web|macos|windows|linux|android|ios|harmonyos|all)",
      )
    }
  }
  let result : Array[String] = []
  for platform in platform_order {
    if selected.contains(platform) {
      result.push(platform)
    }
  }
  Ok(result)
}

///|
pub fn validate_project_options(
  options : ProjectOptions,
) -> Result[Unit, String] {
  if options.target == "" {
    return Err("project target path must not be empty")
  }
  if !valid_project_id(options.id) {
    return Err(
      "project id must start with a letter and contain only letters, digits, and underscores",
    )
  }
  if !valid_module_name(options.module_name) {
    return Err(
      "module name must use owner/name form and contain only letters, digits, '.', '-', '_', and '/'",
    )
  }
  if options.title.trim() == "" {
    return Err("project title must not be empty")
  }
  if !valid_version(options.moui_version) {
    return Err("MoUI version contains unsupported characters")
  }
  for platform in options.platforms {
    if !is_platform(platform) {
      return Err("unsupported normalized platform: " + platform)
    }
  }
  let requires_bundle = options.platforms.any(is_mobile_platform)
  match (requires_bundle, options.bundle_id) {
    (true, None) =>
      return Err("--bundle-id is required when generating a mobile platform")
    (_, Some(value)) if !valid_bundle_id(value) =>
      return Err("bundle id is invalid: " + value)
    _ => ()
  }
  Ok(())
}

///|
fn moon_mod_text(options : ProjectOptions) -> String {
  let renderer_imports : Array[String] = []
  if options.platforms.contains("web") {
    renderer_imports.push(
      "  \"wzzc-dev/moui_web_renderer@" +
      default_web_renderer_dependency_version +
      "\",",
    )
  }
  if options.platforms.any(platform => platform != "web") {
    renderer_imports.push(
      "  \"wzzc-dev/moui_skia_renderer@" +
      options.moui_skia_renderer_version +
      "\",",
    )
  }
  let template =
    #|name = "__MODULE__"
    #|
    #|version = "0.1.0"
    #|
    #|preferred_target = "native"
    #|
    #|import {
    #|  "wzzc-dev/moui@__MOUI_VERSION__",
    #|__RENDERER_IMPORTS__
    #|}
  template
  .replace_all(old="__MODULE__", new=options.module_name)
  .replace_all(old="__MOUI_VERSION__", new=options.moui_version)
  .replace_all(old="__RENDERER_IMPORTS__", new=renderer_imports.join("\n"))
}

///|
fn app_pkg_text() -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/views",
    #|  "wzzc-dev/moui",
    #|}
    #|
    #|supported_targets = "+native+wasm-gc"
    #|
    #|options(
    #|  targets: { },
    #|)
  template
}

///|
fn dev_runner_text() -> String {
  (
    #|#!/usr/bin/env node
    #|
    #|import fs from "node:fs";
    #|import http from "node:http";
    #|import path from "node:path";
    #|import { spawn } from "node:child_process";
    #|const args = process.argv.slice(2);
    #|const value = (name, fallback) => { const i = args.findIndex((a) => a === name || a.startsWith(name + "=")); if (i < 0) return fallback; return args[i].includes("=") ? args[i].slice(args[i].indexOf("=") + 1) : (args[i + 1] || fallback); };
    #|const has = (name) => args.includes(name) || args.some((a) => a.startsWith(name + "="));
    #|const root = path.resolve(value("--project-root", process.cwd()));
    #|const pkg = value("--package", fs.existsSync(path.join(root, "web_wasm", "moon.pkg")) ? "web_wasm" : "app");
    #|const target = value("--target", pkg.endsWith("web_wasm") ? "wasm-gc" : "native");
    #|const once = has("--once") || has("--build-only");
    #|const web = has("--web") || target.startsWith("wasm");
    #|const interval = Math.max(150, Number(value("--interval-ms", "500")) || 500);
    #|const port = Math.max(1, Number(value("--port", "3000")) || 3000);
    #|const stateFile = value("--state", path.join(root, ".moui", "dev-state.json"));
    #|const status = { schemaVersion: 1, ok: true, phase: "starting", generation: 0, package: pkg, target, error: "" };
    #|const update = (patch) => { Object.assign(status, patch, { updatedAt: Date.now() }); fs.mkdirSync(path.join(root, ".moui"), { recursive: true }); fs.writeFileSync(path.join(root, ".moui", "dev-status.json"), JSON.stringify(status, null, 2)); };
    #|const log = (message) => console.log("[moui dev] " + message);
    #|const run = (command, argv, env = {}) => new Promise((resolve) => { const child = spawn(command, argv, { cwd: root, env: { ...process.env, ...env }, stdio: ["ignore", "pipe", "pipe"] }); let output = ""; child.stdout.on("data", (x) => { process.stdout.write(x); output += x; }); child.stderr.on("data", (x) => { process.stderr.write(x); output += x; }); child.on("error", () => resolve({ code: 1, output })); child.on("exit", (code) => resolve({ code: code || 0, output })); });
    #|const files = (dir, out = []) => { if (!fs.existsSync(dir)) return out; for (const e of fs.readdirSync(dir, { withFileTypes: true })) { if ([".git", ".moui", "_build", "node_modules"].includes(e.name)) continue; const f = path.join(dir, e.name); if (e.isDirectory()) files(f, out); else if (/\.(mbt|mbti|json|md|html|css|js|mjs)$/.test(e.name)) { const s = fs.statSync(f); out.push(f + ":" + s.mtimeMs + ":" + s.size); } } return out.sort().join("\n"); };
    #|const build = async () => { update({ phase: "building", error: "" }); log("building " + pkg + " (" + target + ")"); const result = await run(process.env.MOON || "moon", ["build", pkg, "--target", target]); if (result.code) { update({ ok: false, phase: "error", error: result.output.trim() || "build failed" }); return false; } update({ ok: true, phase: web ? "ready" : "built", generation: status.generation + 1 }); log("build ready (generation " + status.generation + ")"); return true; };
    #|const client = "(() => { let generation = null; const box = document.createElement('pre'); Object.assign(box.style, {position:'fixed',inset:'12px',zIndex:2147483647,padding:'16px',background:'#2b1111',color:'#ffd6d6',whiteSpace:'pre-wrap',display:'none'}); document.body.appendChild(box); async function poll(){try{const s=await (await fetch('/__moui/status',{cache:'no-store'})).json(); if(generation!==null&&s.ok&&s.generation!==generation) location.reload(); generation=s.generation; box.textContent=s.error||''; box.style.display=s.error?'block':'none';}catch(_){} setTimeout(poll,700)} poll()})();";
    #|const server = web ? http.createServer((req, res) => { const u = new URL(req.url, "http://localhost"); if (u.pathname === "/__moui/status") { res.setHeader("content-type", "application/json"); res.end(JSON.stringify(status)); return; } if (u.pathname === "/__moui/client.js") { res.setHeader("content-type", "text/javascript"); res.end(client); return; } const rel = decodeURIComponent(u.pathname).replace(/^\/+/, "") || "web_wasm/index.html"; const file = path.resolve(root, rel); if ((file !== root && !file.startsWith(root + path.sep)) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.statusCode = 404; res.end("Not found"); return; } let data = fs.readFileSync(file); if (file.endsWith(".html")) { data = Buffer.from(data.toString().replace(/<head>/i, '<head><script src="/__moui/client.js"></script>')); res.setHeader("content-type", "text/html; charset=utf-8"); } res.end(data); }).listen(port, "127.0.0.1", () => log("web server: http://127.0.0.1:" + port + "/")) : null;
    #|let child = null; let stopping = false; const stop = async () => { if (!child || child.exitCode !== null) return; child.kill("SIGTERM"); await new Promise((resolve) => { const timer = setTimeout(() => { child.kill("SIGKILL"); resolve(); }, 1500); child.once("exit", () => { clearTimeout(timer); resolve(); }); }); child = null; };
    #|const initial = await build(); if (once) { if (server) server.close(); process.exit(initial ? 0 : 1); } if (initial && !web) { child = spawn(process.env.MOON || "moon", ["run", pkg, "--target", target], { cwd: root, env: { ...process.env, MOUI_DEV_STATE_FILE: stateFile, MOUI_DEV_GENERATION: String(status.generation) }, stdio: "inherit" }); }
    #|let last = files(root); log("watching " + root + " every " + interval + "ms"); const timer = setInterval(async () => { const next = files(root); if (next === last || stopping) return; last = next; await stop(); if (await build() && !web) child = spawn(process.env.MOON || "moon", ["run", pkg, "--target", target], { cwd: root, env: { ...process.env, MOUI_DEV_STATE_FILE: stateFile, MOUI_DEV_GENERATION: String(status.generation) }, stdio: "inherit" }); }, interval);
    #|const shutdown = async () => { if (stopping) return; stopping = true; clearInterval(timer); await stop(); if (server) server.close(); process.exit(0); }; process.once("SIGINT", shutdown); process.once("SIGTERM", shutdown);
  )
}

///|
fn app_text(title : String, template_id~ : String = "counter") -> String {
  let title = moon_string(title)
  if template_id == "hello" {
    let template =
      #|///|
      #|using @views {button, card, center, column, text}
      #|
      #|///|
      #|pub struct Model {
      #|  greeted : Bool
      #|}
      #|
      #|///|
      #|pub(all) enum Msg {
      #|  Greet
      #|}
      #|
      #|///|
      #|pub fn Model::new() -> Model {
      #|  { greeted: false }
      #|}
      #|
      #|///|
      #|pub fn update(model : Model, msg : Msg) -> Model {
      #|  match msg {
      #|    Greet => { greeted: true }
      #|  }
      #|}
      #|
      #|///|
      #|pub fn view(model : Model) -> @moui.View[Msg] {
      #|  center(
      #|    card(
      #|      column([
      #|        text("__TITLE__").title(),
      #|        text(
      #|          if model.greeted {
      #|            "Hello from MoUI."
      #|          } else {
      #|            "Press the button."
      #|          },
      #|        ),
      #|        button("Say hello", on_click=Greet),
      #|      ]),
      #|    ),
      #|  )
      #|}
      #|
      #|///|
      #|pub fn program() -> @moui.Program[Model, Msg] {
      #|  @moui.Program::simple(init=Model::new(), update~, view~)
      #|}
    return template.replace_all(old="__TITLE__", new=title)
  }
  let template =
    #|///|
    #|using @views {button, card, center, column, row, text}
    #|
    #|///|
    #|pub struct Model {
    #|  count : Int
    #|}
    #|
    #|///|
    #|pub(all) enum Msg {
    #|  Increment
    #|  Decrement
    #|  Reset
    #|}
    #|
    #|///|
    #|pub fn Model::new() -> Model {
    #|  { count: 0 }
    #|}
    #|
    #|///|
    #|pub fn update(model : Model, msg : Msg) -> Model {
    #|  match msg {
    #|    Increment => { count: model.count + 1 }
    #|    Decrement => { count: model.count - 1 }
    #|    Reset => { count: 0 }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn view(model : Model) -> @moui.View[Msg] {
    #|  center(
    #|    card(
    #|      column([
    #|        text("__TITLE__").title(),
    #|        text("Count: \{model.count}").title(),
    #|        row([
    #|          button("-", on_click=Decrement),
    #|          button("Reset", on_click=Reset),
    #|          button("+", on_click=Increment),
    #|        ]),
    #|      ]),
    #|    ),
    #|  )
    #|}
    #|
    #|///|
    #|pub fn program() -> @moui.Program[Model, Msg] {
    #|  @moui.Program::simple(init=Model::new(), update~, view~)
    #|}
  template.replace_all(old="__TITLE__", new=title)
}

///|
fn app_test_text(template_id~ : String = "counter") -> String {
  if template_id == "hello" {
    return (
      #|///|
      #|test "hello greet flips greeted" {
      #|  let model = Model::new()
      #|  inspect(model.greeted, content="false")
      #|  inspect(update(model, Greet).greeted, content="true")
      #|}
    )
  }
  let template =
    #|///|
    #|test "counter update is deterministic" {
    #|  let model = Model::new()
    #|  inspect(update(model, Increment).count, content="1")
    #|  inspect(update(model, Decrement).count, content="-1")
    #|  inspect(update(model, Reset).count, content="0")
    #|}
  template
}

///|
/// Web 入口包清单。`app_alias` 是组合根包（`<module>/app`）在本包的导入别名：
/// `moui new` 用它默认的 `@app`，Studio 导出 bundle 用 `@exported_app`——
/// 除此之外两边是同一份契约（含 `web_abi_exports` 的宿主入口名单）。
pub fn web_pkg_text(
  module_name : String,
  app_alias~ : String = "app",
) -> String {
  let exports = web_abi_exports.map(name => "        \"\{name}\",").join("\n")
  let template =
    #|import {
    #|  "wzzc-dev/moui/backend/web",
    #|  "wzzc-dev/moui_web_renderer" @webgpu_adapter,
    #|  "wzzc-dev/moui/runtime",
    #|  "__MODULE__/app" @__APP_ALIAS__,
    #|}
    #|
    #|supported_targets = "wasm-gc"
    #|
    #|pkgtype(kind: "executable")
    #|
    #|options(
    #|  link: {
    #|    "wasm-gc": {
    #|      "exports": [
    #|__EXPORTS__
    #|      ],
    #|    },
    #|  },
    #|  targets: { "main.mbt": [ "wasm-gc" ] },
    #|)
  template
  .replace_all(old="__MODULE__", new=module_name)
  .replace_all(old="__APP_ALIAS__", new=app_alias)
  .replace_all(old="__EXPORTS__", new=exports)
}

///|
/// Web 入口包的 `main.mbt`：组合根接线 + 宿主入口转发。ABI 部分与 Studio 导出
/// bundle 共用 `web_abi_shim_mbt()`，这里只负责插入。
pub fn web_main_text(title : String) -> String {
  let title = moon_string(title)
  let template =
    #|///|
    #|fn main {
    #|  let runtime = @runtime.new_program_with_dimensions(
    #|    program=@app.program(),
    #|    width=720.0,
    #|    height=480.0,
    #|  )
    #|  @runtime.run_app("__TITLE__", runtime)
    #|    .render_all(@webgpu_adapter.from_env())
    #|    .backend(@web.entry())
    #|    .run()
    #|}
    #|
    #|__ABI__
  template
  .replace_all(old="__TITLE__", new=title)
  .replace_all(old="__ABI__", new=web_abi_shim_mbt().trim_end())
}

///|
pub fn web_html_text(title : String) -> String {
  let title = html_text(title)
  let template =
    #|<!doctype html>
    #|<html lang="en">
    #|  <head>
    #|    <meta charset="utf-8" />
    #|    <meta name="viewport" content="width=device-width, initial-scale=1" />
    #|    <title>__TITLE__</title>
    #|    <style>
    #|      * { box-sizing: border-box; }
    #|      html, body, #canvas-host { width: 100%; height: 100%; margin: 0; }
    #|      body { overflow: hidden; background: #f6f7f9; }
    #|      canvas { display: block; width: 100%; height: 100%; outline: none; touch-action: none; }
    #|    </style>
    #|  </head>
    #|  <body>
    #|    <div id="canvas-host" aria-label="MoUI canvas host"></div>
    #|    <script type="module">
    #|      import { bootMouiWasmGcApp } from "../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js";
    #|      bootMouiWasmGcApp({
    #|        wasmUrl: new URL("../_build/wasm-gc/debug/build/web_wasm/web_wasm.wasm", import.meta.url),
    #|        canvasHost: "#canvas-host",
    #|      }).catch(error => console.error(error));
    #|    </script>
    #|  </body>
    #|</html>
  template.replace_all(old="__TITLE__", new=title)
}

///|
pub fn desktop_pkg_text(module_name : String, platform : String) -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/runtime",
    #|  "wzzc-dev/moui/backend/__PLATFORM__" @platform_host,
    #|  "wzzc-dev/moui_skia_renderer" @render_skia,
    #|  "__MODULE__/app" @app,
    #|}
    #|
    #|supported_targets = "native"
    #|
    #|pkgtype(kind: "executable")
    #|
    #|options(
    #|  link: { "native": { "cc-link-flags": "" } },
    #|  targets: { "main.mbt": [ "native" ] },
    #|)
  template
  .replace_all(old="__MODULE__", new=module_name)
  .replace_all(old="__PLATFORM__", new=platform)
}

///|
pub fn desktop_main_text(title : String, platform : String) -> String {
  let title = moon_string(title)
  let skia_platform = match platform {
    "macos" => "MacOS"
    "windows" => "Windows"
    "linux" => "Linux"
    _ => abort("unsupported desktop platform: " + platform)
  }
  let template =
    #|///|
    #|fn main {
    #|  let runtime = @runtime.new_program_with_dimensions(
    #|    program=@app.program(),
    #|    width=720.0,
    #|    height=480.0,
    #|  )
    #|  @runtime.run_app("__TITLE__", runtime)
    #|    .render_all(@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::__SKIA_PLATFORM__))
    #|    .backend(@platform_host.entry())
    #|    .run()
    #|}
  template
  .replace_all(old="__TITLE__", new=title)
  .replace_all(old="__SKIA_PLATFORM__", new=skia_platform)
}

///|
fn gitignore_text() -> String {
  let template =
    #|/.mooncakes/
    #|/_build/
    #|/target/
    #|/artifacts/
    #|/.skia-cache/
    #|.moui/dev-state.json
    #|.moui/dev-status.json
    #|*.log
    #|*.tmp
    #|.DS_Store
  template
}

///|
pub fn moon_work_text() -> String {
  // Single-module workspace root. Local path deps later go through moon.work
  // members (or moon.mod.json deps.path); moon.mod import stays registry-only.
  (
    #|members = [
    #|  ".",
    #|]
    #|
  )
}

///|
pub fn readme_text(options : ProjectOptions, cli_version : String) -> String {
  let builder = StringBuilder()
  builder.write_string("# " + options.title + "\n\n")
  builder.write_string(
    "Generated by `moui` CLI " +
    cli_version +
    " for module `" +
    options.module_name +
    "` (template `" +
    options.template +
    "`).\n\n",
  )
  builder.write_string(
    "This is a standalone MoUI app. Prefer this project over cloning the full MoUI monorepo unless you are changing the framework.\n\n",
  )
  builder.write_string("## Versions\n\n")
  builder.write_string("- CLI: `" + cli_version + "`\n")
  builder.write_string(
    "- Default/framework dependency: `wzzc-dev/moui@" +
    options.moui_version +
    "`\n",
  )
  builder.write_string(
    "- These versions are independent: upgrading the CLI does not change the project dependency until you edit `moon.mod` / regenerate.\n\n",
  )
  builder.write_string("## Platforms\n\n")
  for platform in options.platforms {
    builder.write_string("- `" + platform + "`\n")
  }
  builder.write_string("\n## First run (~10 minutes)\n\n")
  builder.write_string("```sh\n")
  builder.write_string("moon update\n")
  builder.write_string("moui doctor\n")
  if options.platforms.contains("macos") {
    builder.write_string("moon run macos_skia --target native\n")
  }
  if options.platforms.contains("windows") {
    builder.write_string("moon run windows_skia --target native\n")
  }
  if options.platforms.contains("linux") {
    builder.write_string("moon run linux_skia --target native\n")
  }
  if options.platforms.contains("web") {
    builder.write_string("moon build web_wasm --target wasm-gc\n")
    builder.write_string(
      "# serve web_wasm/ (static HTTP) and open index.html in a WebGPU browser\n",
    )
  }
  builder.write_string("```\n\n")
  builder.write_string("## Next steps\n\n")
  builder.write_string("```sh\n")
  builder.write_string("moon update\n")
  builder.write_string("moui doctor\n")
  if options.platforms.contains("web") {
    builder.write_string("moon check web_wasm --target wasm-gc\n")
  }
  if options.platforms.contains("macos") {
    builder.write_string("moon run macos_skia --target native\n")
  }
  if options.platforms.contains("windows") {
    builder.write_string("moon run windows_skia --target native\n")
  }
  if options.platforms.contains("linux") {
    builder.write_string("moon run linux_skia --target native\n")
  }
  builder.write_string("```\n\n")
  builder.write_string("## Project maintenance\n\n")
  builder.write_string(
    "- Add a platform later: `moui add platform <name> [--bundle-id ID]`\n",
  )
  builder.write_string(
    "- Package inventory: `moui package` / `moui package --json`\n",
  )
  builder.write_string("- Safe doctor remediations: `moui doctor --fix`\n")
  builder.to_string()
}

///|
fn mobile_platform_json(fields : Array[(String, Json)]) -> Json {
  let values : Map[String, Json] = Map([])
  for field in fields {
    let (key, value) = field
    values[key] = value
  }
  Json::object(values)
}

///|
pub fn mobile_config_text(options : ProjectOptions) -> String {
  let root : Map[String, Json] = Map([
    ("schemaVersion", Json((1 : Int32))),
    ("id", Json(options.id)),
    ("displayName", Json(options.title)),
    ("artifactName", Json(options.id)),
    ("appPackage", Json("app")),
  ])
  let bundle_id = options.bundle_id.unwrap_or("")
  if options.platforms.contains("android") {
    root["android"] = mobile_platform_json([
      ("applicationId", Json(bundle_id)),
      ("minSdk", Json((23 : Int32))),
    ])
  }
  if options.platforms.contains("ios") {
    root["ios"] = mobile_platform_json([
      ("bundleId", Json(bundle_id)),
      ("productName", Json(product_name(options.id))),
      ("deploymentTarget", Json("15.0")),
    ])
  }
  if options.platforms.contains("harmonyos") {
    root["harmonyos"] = mobile_platform_json([
      ("bundleName", Json(bundle_id)),
      ("productName", Json(product_name(options.id))),
      ("appName", Json(options.title)),
      ("moduleName", Json("entry")),
      ("moduleDescription", Json(options.title + " HarmonyOS app")),
      ("entryDescription", Json(options.title + " entry ability")),
      ("compatibleSdkVersion", Json((20 : Int32))),
    ])
  }
  Json::object(root).stringify(indent=2) + "\n"
}

///|
pub fn build_project_file_plan(
  options : ProjectOptions,
  cli_version : String,
) -> Result[Array[PlannedFile], String] {
  match validate_project_options(options) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let manifest : ProjectManifest = {
    schema_version: 1,
    id: options.id,
    title: options.title,
    module_name: options.module_name,
    moui_version: options.moui_version,
    platforms: options.platforms.copy(),
    bundle_id: options.bundle_id,
  }
  let files = [
    text_file(".gitignore", gitignore_text()),
    text_file("README.md", readme_text(options, cli_version)),
    text_file(".moui/dev.mjs", dev_runner_text()),
    text_file("moon.mod", moon_mod_text(options)),
    text_file("moon.work", moon_work_text()),
    text_file("moui.project.json", manifest.to_json_text()),
    text_file("app/moon.pkg", app_pkg_text()),
    text_file(
      "app/app.mbt",
      app_text(options.title, template_id=options.template),
    ),
    text_file("app/app_test.mbt", app_test_text(template_id=options.template)),
  ]
  if options.platforms.contains("web") {
    files.push(
      text_file("web_wasm/moon.pkg", web_pkg_text(options.module_name)),
    )
    files.push(text_file("web_wasm/main.mbt", web_main_text(options.title)))
    files.push(text_file("web_wasm/index.html", web_html_text(options.title)))
  }
  for platform in ["macos", "windows", "linux"] {
    if options.platforms.contains(platform) {
      let directory = platform + "_skia"
      files.push(
        text_file(
          directory + "/moon.pkg",
          desktop_pkg_text(options.module_name, platform),
        ),
      )
      files.push(
        text_file(
          directory + "/main.mbt",
          desktop_main_text(options.title, platform),
        ),
      )
    }
  }
  if options.platforms.any(is_mobile_platform) {
    files.push(text_file("moui.mobile.json", mobile_config_text(options)))
    for platform in ["android", "ios", "harmonyos"] {
      if options.platforms.contains(platform) {
        let directory = platform + "_window_hosted"
        files.push(
          text_file(
            directory + "/moon.pkg",
            mobile_entrypoint_pkg_text(options.module_name, platform),
          ),
        )
        files.push(
          text_file(
            directory + "/main.mbt",
            mobile_entrypoint_main_text(platform),
          ),
        )
      }
    }
  }
  let sorted = files.copy()
  sorted.sort_by((left, right) => left.path.lexical_compare(right.path))
  Ok(sorted)
}
