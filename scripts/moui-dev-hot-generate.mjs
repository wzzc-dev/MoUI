#!/usr/bin/env node

// Generate the native dev hot-reload bridge.
//
// The generated tree is a standalone MoonBit module with its own `moon.work`
// that mirrors the repository workspace. That is what lets any monorepo app
// package be imported by the generated plugin without editing
// `moui_devhost/moon.mod`: the app module is a sibling workspace member of the
// generated module, and the generated `moon.mod` carries the dependency edge.

import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join, relative, resolve } from "node:path";
import {
  DEV_HOT_GENERATOR_FORMAT,
  DEV_HOT_MANIFEST_SCHEMA_VERSION,
  DEV_HOT_MODULE_NAME,
} from "./lib/dev-hot-artifacts.mjs";

const args = process.argv.slice(2);
function value(name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}
const repoRoot = resolve(value("--root", "."));
const out = resolve(repoRoot, value("--out", "moui_devhost/dev_hot"));
const appModule = value("--app", "examples/counter");
const appPackage = value("--app-package", "app");
const requestedProgramFn = value("--program-fn", "auto");
const title = value("--title", "MoUI Hot App");
const width = Number(value("--width", "520"));
const height = Number(value("--height", "360"));
const frameIntervalMs = Number(value("--frame-interval-ms", "16"));
const platformViewPluginModule = value("--platform-view-plugin", "");
const platformViewPluginFn = value("--platform-view-plugin-fn", "plugin");
function nodePlatformToHost(nodePlatform) {
  if (nodePlatform === "darwin") return "macos";
  if (nodePlatform === "linux") return "linux";
  if (nodePlatform === "win32") return "windows";
  return "";
}
const hostPlatform = value("--platform", "") || nodePlatformToHost(process.platform);

if (!["macos", "linux", "windows"].includes(hostPlatform)) {
  console.error(`moui-dev-hot: unsupported host platform: ${hostPlatform || process.platform}`);
  process.exit(1);
}

const appRoot = resolve(repoRoot, appModule);
const appPackageDir = join(appRoot, appPackage);
if (!existsSync(join(appPackageDir, "moon.pkg"))) {
  console.error(`moui-dev-hot: app package not found: ${appModule}/${appPackage}`);
  process.exit(1);
}
const appFromRoot = relative(repoRoot, appRoot);
if (appFromRoot.startsWith("..") || appFromRoot === "") {
  console.error(
    `moui-dev-hot: app module ${appModule} is not a repository workspace member; ` +
      "native hot mode currently supports repository apps only",
  );
  process.exit(1);
}

function readModuleName(dir) {
  const text = readFileSync(join(dir, "moon.mod"), "utf8");
  const match = text.match(/^\s*name\s*=\s*"([^"]+)"/m);
  return match ? match[1] : null;
}

function readModuleVersion(dir) {
  const text = readFileSync(join(dir, "moon.mod"), "utf8");
  const match = text.match(/^\s*version\s*=\s*"([^"]+)"/m);
  return match ? match[1] : "0.0.0";
}

const workspaceText = readFileSync(join(repoRoot, "moon.work"), "utf8");
const membersBlock = workspaceText.match(/members\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
const memberDirs = [...membersBlock.matchAll(/"([^"]+)"/g)]
  .map((match) => resolve(repoRoot, match[1]))
  .filter((dir) => existsSync(join(dir, "moon.mod")));
if (!memberDirs.some((dir) => dir === appRoot)) {
  memberDirs.push(appRoot);
}

const moduleByName = new Map();
for (const dir of memberDirs) {
  const name = readModuleName(dir);
  if (name) moduleByName.set(name, dir);
}

function devDependency(name) {
  const dir = moduleByName.get(name);
  if (!dir) {
    console.error(`moui-dev-hot: workspace module not found: ${name}`);
    process.exit(1);
  }
  return `${name}@${readModuleVersion(dir)}`;
}

function detectProgramFn() {
  if (requestedProgramFn !== "auto") return requestedProgramFn;
  const source = readdirSync(appPackageDir)
    .filter((file) => file.endsWith(".mbt"))
    .map((file) => readFileSync(join(appPackageDir, file), "utf8"))
    .join("\n");
  for (const name of [
    "program_with_dev_environment",
    "program_with_dev_state",
    "program",
  ]) {
    if (new RegExp(`\\bfn\\s+${name}\\s*\\(`).test(source)) return name;
  }
  console.error(
    `moui-dev-hot: ${appModule}/${appPackage} has no program factory ` +
      "(program_with_dev_environment, program_with_dev_state or program)",
  );
  process.exit(1);
}
const programFn = detectProgramFn();
const programExpr =
  programFn === "program_with_dev_environment"
    ? "@app.program_with_dev_environment(@devplugin.hot_environment())"
    : `@app.${programFn}()`;

const staging = `${out}.tmp`;
rmSync(staging, { recursive: true, force: true });
mkdirSync(join(staging, "host"), { recursive: true });
mkdirSync(join(staging, "plugin"), { recursive: true });

// The generated workspace mirrors the repository workspace so every local
// module the app can import is available to the generated module by name.
// Paths are relative to the generated module root, which is what `moon.work`
// requires.
const workspaceMembers = [".", ...memberDirs.map((dir) => relative(out, dir))]
  .map((member) => member.split("\\").join("/"))
  .filter((member, index, all) => all.indexOf(member) === index);

writeFileSync(
  join(staging, "moon.work"),
  `members = [
${workspaceMembers.map((member) => `  "${member}",`).join("\n")}
]
`,
);

writeFileSync(
  join(staging, "moon.mod"),
  `name = "${DEV_HOT_MODULE_NAME}"

version = "0.0.0"

preferred_target = "native"

import {
  "${devDependency("wzzc-dev/moui")}",
  "${devDependency("wzzc-dev/moui_devhost")}",
  "${devDependency("wzzc-dev/moui_skia_renderer")}",
  "${devDependency("wzzc-dev/moui_devtools")}",
  "${appModule}@${readModuleVersion(appRoot)}",
}
`,
);

// MSVC objects are already position-independent and reject `-fPIC`.
const pluginCcFlags = hostPlatform === "windows" ? "" : "-fPIC";

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

// The host loads this archive as a shared image. POSIX hosts compile the
// generated C PIC; Linux additionally recompiles MoonBit's runtime C members
// PIC before linking (see scripts/moui-dev.mjs). MSVC needs no PIC flag.
options(
  link: { "native": { "cc-flags": "${pluginCcFlags}" } },
)
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
    program=${programExpr},
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
let action_buffer : Ref[Bytes?] = Ref(None)

///|
#export_name("dev_semantics_action")
pub fn dev_semantics_action(data : Bytes, length : Int32) -> Bytes {
  let text = match @protocol.bytes_to_string(data, length) {
    Some(text) => text
    None => ""
  }
  let result = match session.val {
    Some(session) =>
      match session.semantics_action_json(text) {
        Some(result) => @protocol.encode_semantics_action_result(result)
        None => ""
      }
    None => ""
  }
  let bytes = @utf8.encode(result[:], bom=false)
  action_buffer.val = Some(bytes)
  bytes
}

///|
#export_name("dev_semantics_action_len")
pub fn dev_semantics_action_len() -> Int32 {
  match action_buffer.val {
    Some(bytes) => bytes.length()
    None => 0
  }
}

///|
#export_name("dev_semantics_action_release")
pub fn dev_semantics_action_release() -> Unit {
  action_buffer.val = None
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

const platformViewPluginsExpr = platformViewPluginModule
  ? `platform_view_plugins=[@devhost.wrap_platform_view_plugin(@platform_view_plugin.${platformViewPluginFn}(), forward=(id, event) => ignore(@devhost.dispatch_event(@core.AppEvent::PlatformView(id, event))))]`
  : "platform_view_plugins=[]";

const hostBackends = {
  macos: {
    importLine: `"wzzc-dev/moui/backend/macos"`,
    timerExpr: "@macos.macos_timer_source()",
    optionsExpr: `@macos.MacosHostAppOptions::new(
    event_sources=Some(sources),
    driver_hooks=Some(@devhost.driver_hooks()),
    ${platformViewPluginsExpr},
  )`,
    entryExpr: "@macos.entry(options=options)",
    rendererPlatform: "MacOS",
  },
  linux: {
    importLine: `"wzzc-dev/moui/backend/linux" @linux_backend`,
    timerExpr: "@linux_backend.linux_timer_source()",
    optionsExpr: `@linux_backend.LinuxHostAppOptions::new(
    event_sources=Some(sources),
    driver_hooks=Some(@devhost.driver_hooks()),
    ${platformViewPluginsExpr},
  )`,
    entryExpr: "@linux_backend.entry(options=options)",
    rendererPlatform: "Linux",
  },
  // The Windows timer callback only constructs the `Poll` message; the
  // plugin swap itself runs in `update` on the host UI thread. The Windows
  // backend has no driver-hooks option, so host events and platform-view
  // plugins are passed through WindowsHostAppOptions instead.
  windows: {
    importLine: `"wzzc-dev/moui/backend/windows" @windows_backend`,
    timerExpr: "@windows_backend.windows_timer_source()",
    optionsExpr: `@windows_backend.WindowsHostAppOptions::new(
    event_sources=Some(sources),
    ${platformViewPluginsExpr},
  )`,
    entryExpr: "@windows_backend.entry(options=options)",
    rendererPlatform: "Windows",
  },
};
const hostBackend = hostBackends[hostPlatform];

// Windows hosted runners cannot create an interactive HWND, so the generated
// Windows host can opt into the dev-only offscreen entry. Other platforms keep
// their existing generated output byte-for-byte.
const offscreenSupported = hostPlatform === "windows";

const windowedSubscriptionsExpr = `  @core.Subscription::batch([
    @services.TimerSource::subscription(
      ${hostBackend.timerExpr},
      interval_ms=250.0,
      map=_frame => Poll,
      key="dev-hot/poll",
      label="Dev hot poll",
    ),
    @services.TimerSource::subscription(
      ${hostBackend.timerExpr},
      interval_ms=${frameIntervalMs.toFixed(1)},
      map=frame => Tick(frame),
      key="dev-hot/frame",
      label="Dev hot frame",
    ),
    host_event_sources()
    .host_events()
    .subscription(
      key="dev-hot/host-events",
      label="Dev hot host events",
      map=event =>
        match event {
          // Resize already reaches the plugin through the runtime event
          // observer; forwarding it here would dispatch it twice.
          @backend_host.Event::Resized(_) => None
          _ =>
            if @devhost.forward_host_event(event) {
              Some(Input)
            } else {
              None
            }
        },
    ),
  ])`;

// In offscreen mode the loop polls reloads and synthetic input itself, so only
// the host frame tick stays a subscription. It uses the offscreen timer source
// so the loop can fire it on the drawing thread with real monotonic time;
// the platform timer source would report time zero and never advance plugin
// timers.
const offscreenSubscriptionsExpr = `  if @devhost.offscreen_requested() {
    @core.Subscription::batch([
      @services.TimerSource::subscription(
        @devhost.offscreen_timer_source(),
        interval_ms=${frameIntervalMs.toFixed(1)},
        map=frame => Tick(frame),
        key="dev-hot/frame",
        label="Dev hot frame",
      ),
    ])
  } else {
${windowedSubscriptionsExpr}
  }`;

const subscriptionsExpr = offscreenSupported
  ? offscreenSubscriptionsExpr
  : windowedSubscriptionsExpr;

const backendExpr = `  let backend = if @devhost.offscreen_requested() {
    @devhost.offscreen_entry(
      width=${width.toFixed(1)},
      height=${height.toFixed(1)},
      frame_interval_ms=${Math.round(frameIntervalMs)},
    )
  } else {
    ${hostBackend.entryExpr}
  }`;

const backendPrelude = offscreenSupported ? backendExpr + "\n" : "";
const backendRef = offscreenSupported ? "backend" : hostBackend.entryExpr;

writeFileSync(
  join(staging, "host", "moon.pkg"),
  `import {
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/apphost",
  "wzzc-dev/moui/backend" @backend_host,
  ${hostBackend.importLine},
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/services",
  "wzzc-dev/moui_devtools/publish" @devtools_publish,
  "wzzc-dev/moui_devtools/socket" @devtools_socket,
  "wzzc-dev/moui_skia_renderer" @render_skia,
  "wzzc-dev/moui_devhost/host" @devhost,
${platformViewPluginModule ? `  "${platformViewPluginModule}" @platform_view_plugin,\n` : ""}}

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
  Tick(@core.Frame)
  Input
}

///|
let host_event_sources_ref : Ref[@apphost.HostPlatformEventSources?] = Ref(None)

///|
fn host_event_sources() -> @apphost.HostPlatformEventSources {
  match host_event_sources_ref.val {
    Some(sources) => sources
    None => {
      let sources = @apphost.HostPlatformEventSources::new()
      host_event_sources_ref.val = Some(sources)
      sources
    }
  }
}

///|
fn subscriptions(_model : HostModel) -> @core.Subscription[HostMsg] {
${subscriptionsExpr}
}

///|
fn update(model : HostModel, message : HostMsg) -> HostModel {
  match message {
    Poll => {
      @devhost.poll_injected_events()
      if @devhost.poll_reload() {
        { revision: model.revision + 1 }
      } else {
        model
      }
    }
    Tick(frame) => {
      // The host owns platform time; the plugin receives the same frame so app
      // timers and animations advance in hot mode.
      ignore(
        @devhost.dispatch_event(@core.AppEvent::FrameTick(frame)),
      )
      { revision: model.revision + 1 }
    }
    Input => { revision: model.revision + 1 }
  }
}

///|
fn view(model : HostModel) -> @core.View[HostMsg] {
  @core.View::from_node(
    @devhost.DevBridgeView::new(model.revision),
    // Input is forwarded from HostPlatformEventSources' subscription instead:
    // that stream carries IME, focus and window events the host view tree never
    // sees, and forwarding here too would duplicate pointer/keyboard delivery.
    event=(_node, _context) => @core.ViewEventResult::ignored(),
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
  let sources = host_event_sources()
  let options = ${hostBackend.optionsExpr}
  let runtime = @runtime.new_program_with_dimensions(
    program=host_program(),
    width=${width.toFixed(1)},
    height=${height.toFixed(1)},
  )
  // The plugin runtime needs the same viewport size as the host window; the
  // host owns resize delivery and forwards it over the bridge.
  runtime.set_event_observer(event => {
    match event {
      @core.AppEvent::Resize(size) => @devhost.resize(size.width, size.height)
      _ => ()
    }
  })
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
${backendPrelude}  @apphost.run_app("${title}", runtime)
  .render_all(
    @render_skia.from_env(
      platform=${hostBackend.rendererPlatform},
      // The renderer lives in this host across plugin swaps, so its
      // path-keyed caches must be reset when the generation changes.
      on_session_bound=session =>
        @devhost.install_renderer_cache_reset(
          Some(() => ignore(session.reset_caches())),
        ),
    ),
  )
  .backend(${backendRef})
  .run()
  @devhost.shutdown()
}
`,
);

writeFileSync(
  join(staging, "manifest.json"),
  `${JSON.stringify(
    {
      schemaVersion: DEV_HOT_MANIFEST_SCHEMA_VERSION,
      // The standalone module layout plus this marker. Older generators wrote
      // only `schemaVersion: 1`, so a missing/mismatched marker is what tells
      // the pre-Moon diagnostic that the tree predates the module split.
      generatorFormat: DEV_HOT_GENERATOR_FORMAT,
      module: DEV_HOT_MODULE_NAME,
      app: `${appModule}/${appPackage}`,
      appModule,
      appPackage,
      program: programFn,
      width,
      height,
      frameIntervalMs,
      platform: hostPlatform,
      host: "host",
      plugin: "plugin",
    },
    null,
    2,
  )}\n`,
);

rmSync(out, { recursive: true, force: true });
renameSync(staging, out);
console.log(`moui-dev-hot: wrote ${out} (app ${appModule}/${appPackage}, program ${programFn})`);
