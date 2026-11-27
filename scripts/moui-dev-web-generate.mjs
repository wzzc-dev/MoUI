#!/usr/bin/env node

// Generates the Web dev composition root used by `moui dev --web --hot`.
//
// The generated package is a normal wasm-gc executable: it boots the app with
// the browser's localStorage-backed transports instead of the app's production
// `web_wasm` entrypoint, and exposes one extra export (`web_dev_flush`) so the
// runtime can hand transient state over before the dev page reloads. Generated
// sources live in a gitignored directory, mirroring `moui-dev-hot-generate.mjs`.

import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const args = process.argv.slice(2);
function value(name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}
const repoRoot = resolve(value("--root", "."));
const out = resolve(repoRoot, value("--out", "moui_devhost/dev_web"));
const appModule = value("--app", "examples/counter");
// `--app` is the workspace-relative directory; `--app-import` is the full
// MoonBit package import path (e.g. wzzc-dev/moui_tests/web_hot_fixture/app).
const appPackage = value("--app-package", "app");
const appImport = value("--app-import", `${appModule}/${appPackage}`);
const programFn = value("--program-fn", "program_with_dev_state");
const webDir = value("--web-dir", "web_wasm");
const appPackageDir = join(repoRoot, appModule, appPackage);
const webPackageDir = join(repoRoot, appModule, webDir);

if (!existsSync(join(appPackageDir, "moon.pkg"))) {
  console.error(`moui-dev-web: app package not found: ${appModule}/${appPackage}`);
  process.exit(1);
}
if (!existsSync(join(webPackageDir, "moon.pkg")) || !existsSync(join(webPackageDir, "index.html"))) {
  console.error(
    `moui-dev-web: ${appModule}/${webDir} needs moon.pkg and index.html; the dev server serves that page`,
  );
  process.exit(1);
}

// The app opts in to model handoff exactly as native `moui dev --hot` requires:
// a program function that installs its own persistence via
// `Program::with_state_persistence`. The dev root supplies the transports.
const appSources = readdirSync(appPackageDir)
  .filter((name) => name.endsWith(".mbt"))
  .map((name) => readFileSync(join(appPackageDir, name), "utf8"))
  .join("\n");
if (!new RegExp(`pub fn ${programFn}\\b`).test(appSources)) {
  console.error(
    `moui-dev-web: ${appModule}/${appPackage} does not define pub fn ${programFn}; ` +
      "expose the same opt-in seam native --hot uses (see docs/development.md)",
  );
  process.exit(1);
}

const webMain = existsSync(join(webPackageDir, "main.mbt"))
  ? readFileSync(join(webPackageDir, "main.mbt"), "utf8")
  : "";
const pageHtml = readFileSync(join(webPackageDir, "index.html"), "utf8");
function appTitle() {
  const fromMain = webMain.match(/run_app\(\s*"([^"]*)"/);
  if (fromMain && fromMain[1]) return fromMain[1];
  const fromHtml = pageHtml.match(/<title>([^<]*)<\/title>/i);
  if (fromHtml && fromHtml[1].trim()) return fromHtml[1].trim();
  return `${appModule} dev`;
}
function dimensions() {
  const block = webMain.match(/new_program_with_dimensions\(([\s\S]{0,400})/);
  const source = block ? block[1] : "";
  const width = Number(source.match(/width\s*=\s*([0-9.]+)/)?.[1] ?? "520");
  const height = Number(source.match(/height\s*=\s*([0-9.]+)/)?.[1] ?? "360");
  return { width: Number.isFinite(width) && width > 0 ? width : 520, height: Number.isFinite(height) && height > 0 ? height : 360 };
}
const title = value("--title", appTitle());
const { width, height } = dimensions();
const overrideWidth = Number(value("--width", ""));
const overrideHeight = Number(value("--height", ""));
const finalWidth = overrideWidth > 0 ? overrideWidth : width;
const finalHeight = overrideHeight > 0 ? overrideHeight : height;

const abiShim = `///|
// Moon only exports definitions carrying #export_name and owned by the
// foreign-library package. Keep this mechanical ABI shim free of platform or
// application logic.
#export_name("web_dispatch_event")
pub fn web_dispatch_event(
  kind : Int32,
  raw_id : Int32,
  arg0 : Int32,
  arg1 : Int32,
  argd : Double,
  text_id : Int32,
) -> Unit {
  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
}

///|
#export_name("web_dispatch_pointer_input")
pub fn web_dispatch_pointer_input(
  raw_id : Int32,
  kind : Int32,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int32,
  modifiers : Int32,
  pointer_id : Int32,
  pressure : Double,
) -> Int32 {
  @web.web_dispatch_pointer_input(
    raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers, pointer_id,
    pressure,
  )
}

///|
#export_name("web_dispatch_route")
pub fn web_dispatch_route(source_code : Int32, text_id : Int32) -> Unit {
  @web.web_dispatch_route(source_code, text_id)
}

///|
#export_name("web_dispatch_semantics_action")
pub fn web_dispatch_semantics_action(
  raw_id : Int32,
  node_id_text_id : Int32,
  generation_text_id : Int32,
  action_code : Int32,
  value_id : Int32,
  direction_code : Int32,
) -> Unit {
  @web.web_dispatch_semantics_action(
    raw_id, node_id_text_id, generation_text_id, action_code, value_id, direction_code,
  )
}

///|
#export_name("web_complete_async_clipboard_read")
pub fn web_complete_async_clipboard_read(
  request_id : Int32,
  ok : Bool,
  text_id : Int32,
) -> Unit {
  @web.web_complete_async_clipboard_read(request_id, ok, text_id)
}

///|
#export_name("web_complete_async_file_dialog")
pub fn web_complete_async_file_dialog(
  request_id : Int32,
  ok : Bool,
  text_id : Int32,
) -> Unit {
  @web.web_complete_async_file_dialog(request_id, ok, text_id)
}
`;

const staging = `${out}.tmp`;
rmSync(staging, { recursive: true, force: true });
mkdirSync(staging, { recursive: true });

writeFileSync(
  join(staging, "moon.pkg"),
  `import {
  "wzzc-dev/moui/backend/web",
  "wzzc-dev/moui_web_renderer" @webgpu_adapter,
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/apphost",
  "${appImport}",
}

supported_targets = "wasm-gc"

pkgtype(kind: "foreign_library")

options(
  targets: { "main.mbt": [ "wasm-gc" ] },
)
`,
);

writeFileSync(
  join(staging, "main.mbt"),
  `///|
// Generated by scripts/moui-dev-web-generate.mjs. Do not edit.
let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)

///|
#export_name("_start")
pub fn start() -> Unit {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.${programFn}(),
    width=${finalWidth.toFixed(1)},
    height=${finalHeight.toFixed(1)},
    state_transport=Some(@web.dev_state_transport()),
    transient_transport=Some(@web.dev_transient_transport()),
  )
  runtime_ref.val = Some(runtime)
  @apphost.run_app("${title.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}

///|
// Called by the shared Web renderer before the dev page unloads. A reload is
// the Web state-preserving refresh: this writes the runtime transient snapshot
// so focus, scroll and text selection survive the new instance.
#export_name("web_dev_flush")
pub fn web_dev_flush() -> Unit {
  match runtime_ref.val {
    Some(runtime) =>
      @web.dev_transient_transport().write(runtime.capture_dev_transient())
    None => ()
  }
}

${abiShim}`,
);

writeFileSync(
  join(staging, "manifest.json"),
  `${JSON.stringify(
    {
      schemaVersion: 1,
      app: `${appModule}/${appPackage}`,
      import: appImport,
      program: programFn,
      web: webDir,
      title,
      width: finalWidth,
      height: finalHeight,
    },
    null,
    2,
  )}\n`,
);

rmSync(out, { recursive: true, force: true });
renameSync(staging, out);
console.log(`moui-dev-web: wrote ${out}`);
