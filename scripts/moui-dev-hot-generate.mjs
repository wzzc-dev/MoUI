#!/usr/bin/env node

import { existsSync, mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const args = process.argv.slice(2);
function value(name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}
const repoRoot = resolve(value("--root", "."));
const out = resolve(repoRoot, value("--out", "moui_devhost/dev_hot"));
const appModule = value("--app", "examples/counter");
const appPackage = value("--app-package", "app");
const programFn = value("--program-fn", "program_with_dev_state");
const title = value("--title", "MoUI Hot Counter");
const width = Number(value("--width", "520"));
const height = Number(value("--height", "360"));

if (!existsSync(join(repoRoot, appModule, appPackage, "moon.pkg"))) {
  console.error(`moui-dev-hot: app package not found: ${appModule}/${appPackage}`);
  process.exit(1);
}

const staging = `${out}.tmp`;
rmSync(staging, { recursive: true, force: true });
mkdirSync(join(staging, "host"), { recursive: true });
mkdirSync(join(staging, "plugin"), { recursive: true });

writeFileSync(
  join(staging, "plugin", "moon.pkg"),
  `import {
  "moonbitlang/core/encoding/utf8",
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui_devhost/plugin" @devplugin,
  "wzzc-dev/moui_devhost/protocol",
  "${appModule}/${appPackage}",
}

supported_targets = "native"

pkgtype(kind: "foreign_library")
`,
);

writeFileSync(
  join(staging, "plugin", "main.mbt"),
  `///|
let session : Ref[@devplugin.Session?] = Ref(None)

///|
let frame_buffer : Ref[Bytes?] = Ref(None)

///|
#export_name("dev_abi_version")
pub fn dev_abi_version() -> Int32 {
  @protocol.abi_version()
}

///|
#export_name("dev_create")
pub fn dev_create(data : Bytes, length : Int32) -> Int32 {
  let text = match @protocol.bytes_to_string(data, length) {
    Some(text) => text
    None => return 1
  }
  let config = match @protocol.decode_config(text) {
    Some(config) => config
    None => return 1
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.${programFn}(),
    width=config.width,
    height=config.height,
    state_transport=@devplugin.state_transport(config.state_file),
    transient_transport=@devplugin.state_transport(config.transient_file),
  )
  session.val = Some(@devplugin.Session::new(runtime, config.transient_file))
  0
}

///|
#export_name("dev_destroy")
pub fn dev_destroy() -> Unit {
  match session.val {
    Some(session) => session.destroy()
    None => ()
  }
  session.val = None
  frame_buffer.val = None
}

///|
#export_name("dev_event")
pub fn dev_event(data : Bytes, length : Int32) -> Int32 {
  let text = match @protocol.bytes_to_string(data, length) {
    Some(text) => text
    None => return 1
  }
  match session.val {
    Some(session) => if session.dispatch_json(text) { 0 } else { 1 }
    None => 1
  }
}

///|
#export_name("dev_frame")
pub fn dev_frame() -> Bytes {
  let text = match session.val {
    Some(session) => session.frame_json()
    None => "{\\"version\\":1,\\"commands\\":[]}"
  }
  let bytes = @utf8.encode(text[:], bom=false)
  frame_buffer.val = Some(bytes)
  bytes
}

///|
#export_name("dev_frame_len")
pub fn dev_frame_len() -> Int32 {
  match frame_buffer.val {
    Some(bytes) => bytes.length()
    None => 0
  }
}

///|
#export_name("dev_frame_release")
pub fn dev_frame_release() -> Unit {
  frame_buffer.val = None
}

///|
#export_name("dev_flush")
pub fn dev_flush() -> Unit {
  match session.val {
    Some(session) => session.flush()
    None => ()
  }
}

///|
#export_name("dev_resize")
pub fn dev_resize(width : Double, height : Double) -> Unit {
  match session.val {
    Some(session) => session.resize(width, height)
    None => ()
  }
}
`,
);

writeFileSync(
  join(staging, "host", "moon.pkg"),
  `import {
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/apphost",
  "wzzc-dev/moui/backend/macos",
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/services",
  "wzzc-dev/moui_devtools/publish" @devtools_publish,
  "wzzc-dev/moui_devtools/socket" @devtools_socket,
  "wzzc-dev/moui_skia_renderer" @render_skia,
  "wzzc-dev/moui_devhost/host" @devhost,
}

supported_targets = "native"

pkgtype(kind: "executable")

options(
  link: { "native": { "cc-link-flags": "" } },
  targets: { "main.mbt": [ "native" ] },
)
`,
);

writeFileSync(
  join(staging, "host", "main.mbt"),
  `///|
struct HostModel {
  revision : Int32
}

///|
enum HostMsg {
  Poll
  Input
}

///|
fn subscriptions(_model : HostModel) -> @core.Subscription[HostMsg] {
  @services.TimerSource::subscription(
    @macos.macos_timer_source(),
    interval_ms=250.0,
    map=_frame => Poll,
    key="dev-hot/poll",
    label="Dev hot poll",
  )
}

///|
fn update(model : HostModel, message : HostMsg) -> HostModel {
  match message {
    Poll =>
      if @devhost.poll_reload() {
        { revision: model.revision + 1 }
      } else {
        model
      }
    Input => { revision: model.revision + 1 }
  }
}

///|
fn view(model : HostModel) -> @core.View[HostMsg] {
  @core.View::from_node(
    @devhost.DevBridgeView::new(model.revision),
    event=(_node, context) => {
      if @devhost.dispatch_event(context.event) {
        @core.ViewEventResult::message(Input)
      } else {
        @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
fn host_program() -> @core.Program[HostModel, HostMsg] {
  @core.Program::simple(
    init={ revision: 0 },
    update~,
    view~,
    subscriptions~,
  )
}

///|
fn main {
  let plugin_path = match @devhost.plugin_path_from_env() {
    Some(path) => path
    None => {
      println("moui-devhot: set MOUI_HOT_PLUGIN to a built app plugin")
      return
    }
  }
  if !@devhost.initialize(plugin_path, ${width.toFixed(1)}, ${height.toFixed(1)}) {
    println("moui-devhot: failed to load \\{plugin_path}")
    return
  }
  @devhost.dump_frame_if_requested()
  let runtime = @runtime.new_program_with_dimensions(
    program=host_program(),
    width=${width.toFixed(1)},
    height=${height.toFixed(1)},
  )
  match @devtools_socket.devtools_port_file_path() {
    Some(port_file) =>
      @devtools_socket.install_devtools_socket(
        runtime,
        port_file~,
        file_path=@devtools_publish.devtools_file_path(),
      )
    None =>
      match @devtools_publish.devtools_file_path() {
        Some(path) =>
          @devtools_publish.install_devtools_publisher(runtime, path~)
        None => ()
      }
  }
  @apphost.run_app("${title}", runtime)
  .render_all(@render_skia.from_env(platform=MacOS))
  .backend(@macos.entry())
  .run()
  @devhost.shutdown()
}
`,
);

writeFileSync(
  join(staging, "manifest.json"),
  `${JSON.stringify(
    {
      schemaVersion: 1,
      app: `${appModule}/${appPackage}`,
      program: programFn,
      width,
      height,
      host: "host",
      plugin: "plugin",
    },
    null,
    2,
  )}\n`,
);

rmSync(out, { recursive: true, force: true });
renameSync(staging, out);
console.log(`moui-dev-hot: wrote ${out}`);
