#!/usr/bin/env node

import fs from "node:fs";
import http from "node:http";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import {
  hotFastStepMatches,
  hotLinkArgs,
  hotPlatformForNodePlatform,
  hotPluginFileName,
  picRuntimeCompile,
} from "./moui-dev-hot-plan.mjs";

const root = process.cwd();
const args = process.argv.slice(2);
const valueOf = (name, fallback) => {
  const index = args.findIndex((arg) => arg === name || arg.startsWith(`${name}=`));
  if (index < 0) return fallback;
  const arg = args[index];
  if (arg.includes("=")) return arg.slice(arg.indexOf("=") + 1);
  return args[index + 1] ?? fallback;
};
const has = (name) => args.includes(name) || args.some((arg) => arg.startsWith(`${name}=`));
const projectRoot = path.resolve(valueOf("--project-root", root));
const packageName = valueOf("--package", "");
const target = valueOf("--target", "");
const intervalMs = Math.max(150, Number(valueOf("--interval-ms", "500")) || 500);
const port = Math.max(1, Number(valueOf("--port", "3000")) || 3000);
const once = has("--once") || has("--build-only");
const web = has("--web") || (target || "").startsWith("wasm") || packageName.endsWith("web_wasm");
const json = has("--json");
const inspect = has("--inspect");
const devtoolsFile = path.join(projectRoot, ".moui", "devtools.json");
const devtoolsPortFile = path.join(projectRoot, ".moui", "devtools.port");
const stateFile = valueOf("--state", path.join(projectRoot, ".moui", "dev-state.json"));
const transientFile = stateFile.endsWith(".json")
  ? `${stateFile.slice(0, -5)}-transient.json`
  : `${stateFile}-transient`;
const statusFile = path.join(projectRoot, ".moui", "dev-status.json");
const hot = has("--hot");
const webHot = hot && web;
const workspaceRoot = findWorkspaceRoot(projectRoot);

const status = { ok: true, phase: "starting", generation: 0, package: packageName, target, hot, error: "", updatedAt: Date.now() };
const writeStatus = (patch = {}) => {
  Object.assign(status, patch, { updatedAt: Date.now() });
  const dir = path.dirname(statusFile);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(statusFile, JSON.stringify({ schemaVersion: 1, ...status }, null, 2));
};
const log = (message) => {
  if (json) process.stdout.write(`${JSON.stringify({ type: "dev", ...status, message })}\n`);
  else process.stdout.write(`[moui dev] ${message}\n`);
};
const run = (command, commandArgs, options = {}) => new Promise((resolve) => {
  const child = spawn(command, commandArgs, {
    cwd: options.cwd || projectRoot,
    env: { ...process.env, ...options.env },
    stdio: ["ignore", "pipe", "pipe"],
    shell: false,
    windowsVerbatimArguments: options.windowsVerbatimArguments ?? false,
  });
  let output = "";
  child.stdout.on("data", (chunk) => { if (!options.quiet) process.stdout.write(chunk); output += chunk; });
  child.stderr.on("data", (chunk) => { if (!options.quiet) process.stderr.write(chunk); output += chunk; });
  child.once("error", (error) => resolve({ code: 1, error }));
  child.once("exit", (code, signal) => resolve({ code: code ?? 1, signal, output }));
});
const moon = process.env.MOON ?? "moon";
// `HOME` is not set by default on Windows; the MoonBit toolchain lives under
// the user profile there.
const moonHome = () => process.env.MOON_HOME || path.join(os.homedir(), ".moon");
const windows = process.platform === "win32";
// Replay `moon --dry-run` commands through the platform shell. Windows uses
// `cmd /c` with verbatim arguments: the dry-run line is already a complete
// command line, and cmd treats everything after `/c` as that line.
const runShellStep = (step) => windows
  ? run(process.env.ComSpec ?? "cmd.exe", ["/d", "/s", "/c", step], { windowsVerbatimArguments: true })
  : run("sh", ["-c", step]);

function listFiles(dir, result = []) {
  if (!fs.existsSync(dir)) return result;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if ([".git", ".moui", "_build", "node_modules"].includes(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) listFiles(full, result);
    else if (/\.(mbt|mbti|json|md|html|css|js|mjs|toml)$/.test(entry.name)) {
      const stat = fs.statSync(full);
      result.push(`${full}:${stat.mtimeMs}:${stat.size}`);
    }
  }
  return result.sort().join("\n");
}

function discoverPackage() {
  if (packageName) return packageName;
  if (web && fs.existsSync(path.join(projectRoot, "web_wasm", "moon.pkg"))) return "web_wasm";
  const platform = process.platform === "darwin" ? "macos" : process.platform === "win32" ? "windows" : "linux";
  const candidate = `${platform}_skia`;
  if (fs.existsSync(path.join(projectRoot, candidate, "moon.pkg"))) return candidate;
  return web ? "web_wasm" : "app";
}

function discoverTarget(pkg) {
  if (target) return target;
  return pkg === "web_wasm" || pkg.endsWith("/web_wasm") ? "wasm-gc" : "native";
}

function buildArgs(pkg, buildTarget) {
  return ["build", pkg, "--target", buildTarget];
}

let child = null;
let stopping = false;
const stopChild = async () => {
  if (!child || child.exitCode !== null) return;
  const current = child;
  current.kill("SIGTERM");
  await new Promise((resolve) => {
    const timer = setTimeout(() => { current.kill("SIGKILL"); resolve(); }, 1500);
    current.once("exit", () => { clearTimeout(timer); resolve(); });
  });
  child = null;
};

async function build(pkg, buildTarget) {
  writeStatus({ ok: true, phase: "building", package: pkg, target: buildTarget, error: "" });
  log(`building ${pkg} (${buildTarget})`);
  const result = await run(moon, buildArgs(pkg, buildTarget));
  if (result.code !== 0) {
    const error = result.output.trim() || `build failed with exit code ${result.code}`;
    writeStatus({ ok: false, phase: "error", error });
    log(error);
    return false;
  }
  status.generation += 1;
  writeStatus({ ok: true, phase: web ? "ready" : "built", error: "" });
  log(`build ready (generation ${status.generation})`);
  return true;
}

async function startNative(pkg, buildTarget) {
  await stopChild();
  writeStatus({ phase: "running", ok: true, error: "" });
  const env = {
    MOUI_DEV_STATE_FILE: stateFile,
    MOUI_DEV_TRANSIENT_FILE: transientFile,
    MOUI_DEV_GENERATION: String(status.generation),
  };
  if (inspect) {
    env.MOUI_DEVTOOLS_FILE = devtoolsFile;
    env.MOUI_DEVTOOLS_PORT = "0";
    env.MOUI_DEVTOOLS_PORT_FILE = devtoolsPortFile;
  }
  child = spawn(moon, ["run", pkg, "--target", buildTarget], { cwd: projectRoot, env: { ...process.env, ...env }, stdio: "inherit" });
  child.once("exit", (code, signal) => {
    if (!stopping) log(`app exited (code=${code ?? "null"}, signal=${signal ?? "none"})`);
  });
}

// Native hot mode keeps the window and swaps only the app plugin. The host is
// generated once; each successful plugin build publishes a new, uniquely named
// dylib and advances the marker the host polls.
const hotRoot = workspaceRoot ? path.join(workspaceRoot, "moui_devhost", "dev_hot") : "";
const hotOut = hotRoot ? path.join(hotRoot, "out") : "";
const hotMarker = hotOut ? path.join(hotOut, "current") : "";
const hotPicDir = hotRoot ? path.join(hotRoot, "pic") : "";
const hotHost = path.join(hotRoot, "_build", "native", "debug", "build", "wzzc-dev", "moui_dev_hot", "host", "host.exe");
const hotPlatform = hotPlatformForNodePlatform(process.platform);
// Web hot mode keeps the page and swaps the wasm app module by refreshing it.
// Model/transient state crosses the refresh through the same opt-in
// ProgramStateTransport seam the native plugin uses (localStorage in the
// browser), so production web entrypoints stay untouched.
const webHotRoot = workspaceRoot ? path.join(workspaceRoot, "moui_devhost", "dev_web") : "";
const webHotOut = webHotRoot ? path.join(webHotRoot, "out", "app.wasm") : "";
const webHotWasm = path.join(workspaceRoot ?? "", "_build", "wasm-gc", "debug", "build", "wzzc-dev", "moui_devhost", "dev_web", "dev_web.wasm");
const webHotGenerator = path.join(workspaceRoot ?? "", "scripts", "moui-dev-web-generate.mjs");
const webHotPackage = "moui_devhost/dev_web";
// MSVC's archive tooling produces `.lib`; the POSIX hosts produce `.a`.
const hotPluginArchiveName = hotPlatform === "windows" ? "plugin.lib" : "plugin.a";
const hotPluginArchive = path.join(hotRoot, "_build", "native", "debug", "build", "wzzc-dev", "moui_dev_hot", "plugin", hotPluginArchiveName);
const hotGenerator = path.join(workspaceRoot ?? "", "scripts", "moui-dev-hot-generate.mjs");
const hotPluginName = hotPluginFileName(hotPlatform ?? "macos");
const hotArchiveFragment = `moui_dev_hot/plugin/${hotPluginArchiveName}`;
const hotAppModule = (() => {
  const relativeProject = workspaceRoot
    ? path.relative(workspaceRoot, projectRoot).split(path.sep).join("/")
    : "";
  const projectIsApp =
    relativeProject &&
    !relativeProject.startsWith("..") &&
    fs.existsSync(path.join(projectRoot, "app", "moon.pkg"));
  if (packageName) {
    // `--package` names either the app module (native --hot) or its Web page
    // package (`web_wasm` / `<app>/web_wasm`); the generated root imports the
    // app module in both cases.
    if (packageName === "web_wasm" || packageName.endsWith("/web_wasm")) {
      return projectIsApp
        ? relativeProject
        : packageName.slice(0, -"web_wasm".length).replace(/\/$/, "");
    }
    return packageName;
  }
  if (projectIsApp) return relativeProject;
  return workspaceRoot === projectRoot ? "examples/counter" : "";
})();
const hotProject = hotAppModule ? path.join(workspaceRoot, hotAppModule) : projectRoot;
// Generated imports use the MoonBit module name plus the package path inside
// that module, which can differ from the workspace directory layout
// (moui_tests/web_hot_fixture/app => wzzc-dev/moui_tests/web_hot_fixture/app).
const hotAppModuleRoot = (() => {
  if (!hotAppModule || !workspaceRoot) return "";
  let dir = path.join(workspaceRoot, hotAppModule);
  for (let i = 0; i < 32; i += 1) {
    if (fs.existsSync(path.join(dir, "moon.mod"))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return "";
})();
const hotAppModuleName = (() => {
  if (!hotAppModuleRoot) return "";
  try {
    return fs.readFileSync(path.join(hotAppModuleRoot, "moon.mod"), "utf8").match(/^\s*name\s*=\s*"([^"]*)"/m)?.[1] ?? "";
  } catch (_) {
    return "";
  }
})();
const hotAppImport = (() => {
  if (!hotAppModuleName) return hotAppModule;
  const pkg = path
    .relative(hotAppModuleRoot, path.join(workspaceRoot, hotAppModule, "app"))
    .split(path.sep)
    .join("/");
  return `${hotAppModuleName}/${pkg}`;
})();
let hotChild = null;
let hotFastPlan = null;
let hotWatchRoots = [hotProject];

// Resolve the app's local dependency closure so an edit to an imported package
// outside the app folder still triggers a rebuild. Registry dependencies are
// not watched; repository workspace members are.
function localWorkspaceModules() {
  const modules = new Map();
  if (!workspaceRoot || !fs.existsSync(path.join(workspaceRoot, "moon.work"))) return modules;
  const text = fs.readFileSync(path.join(workspaceRoot, "moon.work"), "utf8");
  const block = text.match(/members\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  for (const match of block.matchAll(/"([^"]+)"/g)) {
    const dir = path.resolve(workspaceRoot, match[1]);
    if (!fs.existsSync(path.join(dir, "moon.mod"))) continue;
    const name = fs
      .readFileSync(path.join(dir, "moon.mod"), "utf8")
      .match(/^\s*name\s*=\s*"([^"]+)"/m)?.[1];
    if (name) modules.set(name, dir);
  }
  return modules;
}

function packageImports(packageDir) {
  const pkgFile = path.join(packageDir, "moon.pkg");
  if (!fs.existsSync(pkgFile)) return [];
  const text = fs.readFileSync(pkgFile, "utf8");
  const block = text.match(/import\s*\{([\s\S]*?)\}/)?.[1] ?? "";
  return [...block.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

function hotDependencyRoots() {
  if (!hotAppModule || !workspaceRoot) return [hotProject];
  const modules = localWorkspaceModules();
  const roots = [hotProject];
  const seen = new Set();
  const queue = [path.join(hotProject, "app")];
  while (queue.length > 0) {
    const packageDir = queue.shift();
    if (seen.has(packageDir)) continue;
    seen.add(packageDir);
    for (const importPath of packageImports(packageDir)) {
      const parts = importPath.split("/");
      if (parts.length < 3) continue;
      const moduleName = `${parts[0]}/${parts[1]}`;
      const moduleDir = modules.get(moduleName);
      if (!moduleDir) continue;
      const importedDir = path.join(moduleDir, ...parts.slice(2));
      if (
        importedDir !== hotProject &&
        !importedDir.startsWith(`${hotProject}${path.sep}`) &&
        !roots.includes(importedDir)
      ) {
        roots.push(importedDir);
      }
      queue.push(importedDir);
    }
  }
  return roots;
}

function hotSourceShape() {
  return hotWatchRoots
    .flatMap((dir) => listFiles(dir).split("\n"))
    .filter(Boolean)
    .map((line) => line.replace(/:\d+(?:\.\d+)?:\d+$/, ""))
    .sort()
    .join("\n");
}

// The fast-plan shape ignores mtimes so a content edit can reuse the cached
// compile/link steps. Change detection needs the opposite: keep mtime and size
// so editing a watched file in place still rebuilds.
function hotSourceStamp() {
  return hotWatchRoots.map((dir) => listFiles(dir)).join("\n");
}

async function captureHotPlan() {
  const dry = await run(moon, [
    "build", "plugin",
    "--target", "native", "-v", "--dry-run",
  ], { quiet: true, cwd: hotRoot });
  if (dry.code !== 0) return null;
  const home = moonHome();
  const steps = dry.output
    .split("\n")
    .map((line) => line.replace(/\r$/, "").replace(/\$MOON_HOME/g, home))
    .filter((line) => hotFastStepMatches(line, { appModule: hotAppModule, archiveFragment: hotArchiveFragment }));
  if (steps.length < 2) return null;
  return { shape: hotSourceShape(), steps };
}

// MoonBit's native backend does not emit shared-library objects, and the
// runtime C sources are compiled without `-fPIC`. On Linux the runner links a
// copied archive whose runtime members are recompiled PIC; `cc-flags` in the
// generated plugin package already makes the app-side object PIC.
let hotPicObjects = null;

async function prepareRuntimePicObjects() {
  if (hotPlatform !== "linux") return null;
  if (hotPicObjects) return hotPicObjects;
  fs.mkdirSync(hotPicDir, { recursive: true });
  const dry = await run(moon, [
    "build", "plugin",
    "--target", "native", "-v", "--dry-run",
  ], { quiet: true, cwd: hotRoot });
  if (dry.code !== 0) return null;
  const objects = [];
  for (const raw of dry.output.split("\n")) {
    const line = raw.replace(/\r$/, "").replace(/\$MOON_HOME/g, moonHome());
    const output = line.match(/(?:^|\s)-o\s+(\S+)/);
    if (!output) continue;
    const object = path.join(hotPicDir, path.basename(output[1]));
    const picStep = picRuntimeCompile(line, object);
    if (!picStep) continue;
    const compiled = await run("sh", ["-c", picStep], { quiet: true });
    if (compiled.code !== 0) {
      log(`hot PIC runtime compile failed: ${object}`);
      return null;
    }
    objects.push(object);
  }
  if (objects.length === 0) return null;
  hotPicObjects = objects;
  return objects;
}

async function linkHotPlugin(dylib) {
  if (hotPlatform === "windows") {
    // Generated `dev_*` wrappers carry no `__declspec(dllexport)`; the link
    // recipe supplies `/EXPORT` for each and `/WHOLEARCHIVE` so no app or
    // runtime member is dropped. Requires a Developer Command Prompt (vcvars)
    // so moon, cl.exe/lib.exe, and link.exe share one MSVC environment.
    const args = hotLinkArgs({
      platform: "windows",
      pluginArchive: hotPluginArchive,
      output: dylib,
    });
    return run(process.env.MOUI_HOT_LINKER ?? "link.exe", args);
  }
  let args;
  if (hotPlatform === "linux") {
    const picObjects = await prepareRuntimePicObjects();
    if (!picObjects) return { code: 1, output: "hot PIC runtime objects unavailable" };
    const picArchive = path.join(hotPicDir, "plugin.pic.a");
    fs.copyFileSync(hotPluginArchive, picArchive);
    const archived = await run(process.env.AR ?? "ar", ["r", picArchive, ...picObjects], { quiet: true });
    if (archived.code !== 0) return archived;
    args = hotLinkArgs({
      platform: "linux",
      pluginArchive: hotPluginArchive,
      picArchive,
      moonHome: moonHome(),
      output: dylib,
    });
  } else {
    args = hotLinkArgs({
      platform: "macos",
      pluginArchive: hotPluginArchive,
      moonHome: moonHome(),
      output: dylib,
    });
  }
  return run(process.env.CC ?? "cc", args);
}

async function runHotSteps(steps) {
  for (const step of steps) {
    const result = await runShellStep(step);
    if (result.code !== 0) return false;
  }
  return true;
}

function hotAvailable() {
  return Boolean(
    workspaceRoot &&
      hotAppModule &&
      fs.existsSync(path.join(workspaceRoot, "moui_devhost", "moon.mod")) &&
      fs.existsSync(path.join(workspaceRoot, "moui_devhost", "protocol", "moon.pkg")) &&
      fs.existsSync(hotGenerator),
  );
}

async function prepareHot() {
  const generated = await run("node", [
    hotGenerator,
    "--root", workspaceRoot,
    "--out", path.relative(workspaceRoot, hotRoot),
    "--app", hotAppModule,
    "--app-package", "app",
    "--platform", hotPlatform,
    "--frame-interval-ms", String(Number(valueOf("--frame-interval-ms", "16")) || 16),
  ]);
  if (generated.code !== 0) return false;
  hotWatchRoots = hotDependencyRoots();
  const hostBuild = await run(moon, ["build", "host", "--target", "native"], { cwd: hotRoot });
  return hostBuild.code === 0;
}

async function publishHotPlugin() {
  const startedAt = Date.now();
  writeStatus({ ok: true, phase: "building", hot: true, error: "" });
  log(`building hot plugin (${hotAppModule})`);
  const shape = hotSourceShape();
  let compiled = false;
  if (hotFastPlan && hotFastPlan.shape === shape) {
    compiled = await runHotSteps(hotFastPlan.steps);
    if (!compiled) log("hot fast build failed; falling back to moon build");
  }
  if (!compiled) {
    const built = await run(moon, ["build", "plugin", "--target", "native"], { cwd: hotRoot });
    if (built.code !== 0) {
      const error = built.output.trim() || `plugin build failed with exit code ${built.code}`;
      writeStatus({ ok: false, phase: "error", hot: true, error });
      log(error);
      return false;
    }
    // Cache the warm compile/link steps so a same-shape edit avoids moon's
    // workspace planning cost; the next shape change refreshes the plan.
    hotFastPlan = await captureHotPlan();
  }
  if (!fs.existsSync(hotPluginArchive)) {
    const error = `plugin archive missing: ${hotPluginArchive}`;
    writeStatus({ ok: false, phase: "error", hot: true, error });
    log(error);
    return false;
  }
  const generation = status.generation + 1;
  const generationDir = path.join(hotOut, `gen-${generation}`);
  fs.mkdirSync(generationDir, { recursive: true });
  const dylib = path.join(generationDir, hotPluginName);
  const linked = await linkHotPlugin(dylib);
  if (linked.code !== 0) {
    const error = linked.output.trim() || `plugin link failed with exit code ${linked.code}`;
    writeStatus({ ok: false, phase: "error", hot: true, error });
    log(error);
    return false;
  }
  // Publish atomically: the host never observes a half-written dylib or marker.
  const markerTemp = `${hotMarker}.tmp`;
  fs.writeFileSync(markerTemp, dylib);
  fs.renameSync(markerTemp, hotMarker);
  status.generation = generation;
  hotWatchRoots = hotDependencyRoots();
  writeStatus({ ok: true, phase: "running", hot: true, error: "" });
  log(`hot plugin ready (generation ${generation}, ${(fs.statSync(dylib).size / 1024 / 1024).toFixed(1)} MiB, ${Date.now() - startedAt}ms)`);
  return true;
}

async function startHotHost(pluginPath) {
  if (!fs.existsSync(hotHost)) {
    const error = `hot host missing: ${hotHost}`;
    writeStatus({ ok: false, phase: "error", hot: true, error });
    log(error);
    return false;
  }
  writeStatus({ ok: true, phase: "running", hot: true, error: "" });
  const env = {
    MOUI_HOT_PLUGIN: pluginPath,
    MOUI_HOT_GENERATION: hotMarker,
    // macOS dyld retains MoonBit images after dlclose, so the host re-execs
    // after 32 swaps. Linux dlclose unmaps the image (measured: images=1 on
    // every swap), so no periodic re-exec is needed; RSS still creeps with
    // allocator/state churn (~0.26 MB/swap over 20 reloads). Windows FreeLibrary
    // behaviour is not yet measured on a real host, so keep the conservative
    // 32-swap re-exec budget.
    MOUI_HOT_RELOAD_LIMIT: hotPlatform === "linux" ? "0" : "32",
    MOUI_DEV_STATE_FILE: stateFile,
    MOUI_DEV_TRANSIENT_FILE: transientFile,
  };
  if (inspect) {
    env.MOUI_DEVTOOLS_FILE = devtoolsFile;
    env.MOUI_DEVTOOLS_PORT = "0";
    env.MOUI_DEVTOOLS_PORT_FILE = devtoolsPortFile;
  }
  hotChild = spawn(hotHost, [], { cwd: workspaceRoot, env: { ...process.env, ...env }, stdio: "inherit" });
  hotChild.once("exit", (code, signal) => {
    if (!stopping) log(`hot host exited (code=${code ?? "null"}, signal=${signal ?? "none"})`);
    hotChild = null;
  });
  return true;
}

function webHotAvailable() {
  return Boolean(
    workspaceRoot &&
      hotAppModule &&
      fs.existsSync(path.join(workspaceRoot, "moui_devhost", "moon.mod")) &&
      fs.existsSync(webHotGenerator),
  );
}

async function prepareWebHot() {
  const generated = await run("node", [
    webHotGenerator,
    "--root", workspaceRoot,
    "--out", path.relative(workspaceRoot, webHotRoot),
    "--app", hotAppModule,
    "--app-import", hotAppImport,
    "--app-package", "app",
  ]);
  return generated.code === 0;
}

// Publish the built wasm as an immutable copy: a failed build keeps the last
// good generation served and interactive, exactly like the native marker file.
async function publishWebHot() {
  const startedAt = Date.now();
  writeStatus({ ok: true, phase: "building", hot: true, error: "" });
  log(`building web dev module (${hotAppModule})`);
  const built = await run(moon, ["build", webHotPackage, "--target", "wasm-gc", "--frozen"]);
  if (built.code !== 0) {
    const error = built.output.trim() || `web dev build failed with exit code ${built.code}`;
    writeStatus({ ok: false, phase: "error", hot: true, error });
    log(error);
    return false;
  }
  if (!fs.existsSync(webHotWasm)) {
    const error = `web dev wasm missing: ${webHotWasm}`;
    writeStatus({ ok: false, phase: "error", hot: true, error });
    log(error);
    return false;
  }
  fs.mkdirSync(path.dirname(webHotOut), { recursive: true });
  const temporary = `${webHotOut}.tmp`;
  fs.copyFileSync(webHotWasm, temporary);
  fs.renameSync(temporary, webHotOut);
  status.generation += 1;
  writeStatus({ ok: true, phase: "running", hot: true, error: "" });
  log(`web build ready (generation ${status.generation}, ${Date.now() - startedAt}ms)`);
  return true;
}

let webHotPageWarned = false;

const clientScript = `(() => { let generation = null; let delay = 300; let error = null; const box = document.createElement('pre'); box.id = '__moui_dev_error'; Object.assign(box.style, { position: 'fixed', inset: '12px', zIndex: 2147483647, margin: 0, padding: '16px', background: '#2b1111', color: '#ffd6d6', font: '13px/1.5 monospace', whiteSpace: 'pre-wrap', display: 'none' }); document.body.appendChild(box); async function poll() { try { const response = await fetch('/__moui/status', { cache: 'no-store' }); const status = await response.json(); delay = status.hot ? 250 : 700; if (generation !== null && status.generation !== generation && status.ok) location.reload(); generation = status.generation; if (globalThis.__mouiDevHost) globalThis.__mouiDevHost.generation = status.generation; error = status.error || null; box.textContent = error ? '[moui dev] ' + error + '\\n\\nFix the source and save to retry.' : ''; box.style.display = error ? 'block' : 'none'; } catch (_) {} setTimeout(poll, delay); } poll(); })();`;

function findWorkspaceRoot(start) {
  let dir = start;
  for (let i = 0; i < 64; i += 1) {
    if (fs.existsSync(path.join(dir, "moon.work"))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
  return null;
}

function serve() {
  const defaultPage = /(^|\/)web_wasm$/.test(pkg) ? `${pkg}/index.html` : "web_wasm/index.html";
  const staticRoots = [projectRoot];
  const workspaceRoot = findWorkspaceRoot(projectRoot);
  if (workspaceRoot && workspaceRoot !== projectRoot) staticRoots.push(workspaceRoot);
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, "http://localhost");
    if (url.pathname === "/__moui/status") {
      response.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
      response.end(JSON.stringify(status));
      return;
    }
    if (url.pathname === "/__moui/client.js") {
      response.writeHead(200, { "content-type": "text/javascript", "cache-control": "no-store" });
      response.end(clientScript);
      return;
    }
    if (webHot && url.pathname === "/__moui/app.wasm") {
      if (!fs.existsSync(webHotOut)) {
        response.writeHead(404, { "content-type": "text/plain", "cache-control": "no-store" });
        response.end("web dev build not ready");
        return;
      }
      response.writeHead(200, { "content-type": "application/wasm", "cache-control": "no-store" });
      response.end(fs.readFileSync(webHotOut));
      return;
    }
    if (url.pathname === "/__moui/devtools.json") {
      const fallback = () => {
        if (!fs.existsSync(devtoolsFile)) {
          response.writeHead(404, { "content-type": "application/json", "cache-control": "no-store" });
          response.end(JSON.stringify({ error: "devtools snapshot not yet available" }));
          return;
        }
        response.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
        response.end(fs.readFileSync(devtoolsFile));
      };
      let port = 0;
      try {
        if (fs.existsSync(devtoolsPortFile)) {
          port = Number(fs.readFileSync(devtoolsPortFile, "utf8").trim()) || 0;
        }
      } catch (_) {
        port = 0;
      }
      if (port <= 0) {
        fallback();
        return;
      }
      let sent = false;
      const socket = net.connect(port, "127.0.0.1", () => {
        socket.write('{"id":1,"method":"all"}\n');
      });
      socket.setEncoding("utf8");
      socket.setTimeout(2000, () => socket.destroy());
      socket.on("data", (chunk) => {
        if (sent) return;
        if (!chunk.includes("\n")) return;
        sent = true;
        socket.end();
        response.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
        response.end(chunk.trim());
      });
      socket.on("error", () => {
        if (!sent) {
          sent = true;
          fallback();
        }
      });
      socket.on("close", () => {
        if (!sent) {
          sent = true;
          fallback();
        }
      });
      return;
    }
    if (url.pathname === "/__moui/devtools") {
      response.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
      response.end(`<!doctype html><meta charset="utf-8"><title>MoUI DevTools</title><style>body{margin:0;padding:16px;background:#101418;color:#d7e0ea;font:13px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}pre{white-space:pre-wrap}</style><pre id="out">waiting for the first DevTools sample...</pre><script>async function poll(){const out=document.getElementById('out');try{const response=await fetch('/__moui/devtools.json',{cache:'no-store'});if(!response.ok){out.textContent='waiting for the first DevTools sample...';}else{const doc=await response.json();out.textContent=(doc.reportText||'')+'\\n\\n'+(doc.traceText||'')+'\\n\\ndiagnostics: '+((doc.diagnostics||[]).length);}}catch(error){out.textContent=String(error);}setTimeout(poll,1000)}poll();</script>`);
      return;
    }
    let relative = decodeURIComponent(url.pathname).replace(/^\/+/, "") || defaultPage;
    for (const staticRoot of staticRoots) {
      const requested = path.resolve(staticRoot, relative);
      if ((requested !== staticRoot && !requested.startsWith(staticRoot + path.sep)) || !fs.existsSync(requested) || fs.statSync(requested).isDirectory()) continue;
      let content = fs.readFileSync(requested);
      if (path.extname(requested) === ".html") {
        // Inject at the end of <body>: the client appends an error overlay and
        // must run after the document body exists.
        let html = content.toString();
        const clientTag = '<script src="/__moui/client.js"></script>';
        html = /<\/body>/i.test(html)
          ? html.replace(/<\/body>/i, `${clientTag}</body>`)
          : `${html}${clientTag}`;
        if (webHot) {
          const before = html;
          html = html.replace(/[^"'\s]*_build\/wasm-gc\/[^"'\s]*\/web_wasm\.wasm/g, "/__moui/app.wasm");
          if (html === before && !webHotPageWarned) {
            webHotPageWarned = true;
            log("page does not reference a web_wasm.wasm build; wire /__moui/app.wasm manually");
          }
        }
        content = Buffer.from(html);
        response.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
      } else {
        const types = { ".wasm": "application/wasm", ".js": "text/javascript", ".mjs": "text/javascript", ".css": "text/css", ".json": "application/json" };
        response.writeHead(200, { "content-type": types[path.extname(requested)] || "application/octet-stream", "cache-control": "no-store" });
      }
      response.end(content);
      return;
    }
    response.writeHead(404); response.end("Not found");
  });
  server.listen(port, "127.0.0.1", () => {
    status.port = server.address()?.port ?? port;
    writeStatus({});
    log(`web server listening at http://127.0.0.1:${status.port}/`);
    if (inspect) log(`devtools: http://127.0.0.1:${port}/__moui/devtools`);
  });
  return server;
}

const pkg = discoverPackage();
const buildTarget = discoverTarget(pkg);
writeStatus({ package: pkg, target: buildTarget });
if (has("--help")) {
  process.stdout.write("Usage: moui dev [--package PATH] [--target TARGET] [--once|--build-only] [--web] [--hot] [--inspect] [--port PORT] [--interval-ms MS] [--state PATH]\\n");
  process.stdout.write("Watches MoonBit inputs, rebuilds incrementally, restarts native apps, and serves Web errors with refresh.\\n");
  process.stdout.write("--hot (macOS/Linux/Windows native) keeps the window and swaps the app plugin instead of restarting.\\n");
  process.stdout.write("--web --hot keeps the page and refreshes it after a rebuild, carrying model/focus/scroll state over.\\n");
  process.exit(0);
}

let server = null;
let timer = null;
let hotTimer = null;

const devhostHasAppImport = () =>
  Boolean(workspaceRoot && hotAppModuleName) &&
  fs.readFileSync(path.join(workspaceRoot, "moui_devhost", "moon.mod"), "utf8").includes(`"${hotAppModuleName}@`);

if (webHot) {
  if (!webHotAvailable()) {
    writeStatus({
      ok: false,
      phase: "error",
      hot: true,
      error: "--web --hot needs the MoUI workspace dev module moui_devhost and scripts/moui-dev-web-generate.mjs",
    });
    process.exit(1);
  }
  if (!devhostHasAppImport()) {
    writeStatus({
      ok: false,
      phase: "error",
      hot: true,
      error: `--hot cannot import ${hotAppModuleName}; add "${hotAppModuleName}@<version>" to moui_devhost/moon.mod`,
    });
    process.exit(1);
  }
  const prepared = await prepareWebHot();
  if (!prepared) {
    writeStatus({ ok: false, phase: "error", hot: true, error: "web dev module generation failed" });
    process.exit(1);
  }
  // Serve before the first build so an initial compile error is visible in the
  // page instead of an empty port. A failed rebuild keeps the last published wasm.
  if (!once) server = serve();
  const published = await publishWebHot();
  if (once) process.exit(published ? 0 : 1);
  let lastWebSnapshot = listFiles(hotProject);
  let webBuilding = false;
  log(`watching ${hotProject} every ${intervalMs}ms (web hot, state: browser localStorage)`);
  hotTimer = setInterval(async () => {
    if (stopping || webBuilding) return;
    const nextSnapshot = listFiles(hotProject);
    if (nextSnapshot === lastWebSnapshot) return;
    lastWebSnapshot = nextSnapshot;
    webBuilding = true;
    try {
      await publishWebHot();
    } finally {
      webBuilding = false;
    }
  }, intervalMs);
} else if (hot) {
  if (hotPlatform === null) {
    writeStatus({
      ok: false,
      phase: "error",
      hot: true,
      error: `--hot supports native macOS, Linux, and Windows hosts; this host is ${process.platform}`,
    });
    process.exit(1);
  }
  if (!hotAvailable()) {
    writeStatus({
      ok: false,
      phase: "error",
      hot: true,
      error: "--hot requires the repository dev module moui_devhost and scripts/moui-dev-hot-generate.mjs",
    });
    process.exit(1);
  }
  const prepared = await prepareHot();
  if (!prepared) {
    writeStatus({ ok: false, phase: "error", hot: true, error: "hot host generation failed" });
    process.exit(1);
  }
  const published = await publishHotPlugin();
  if (!published || once) process.exit(published ? 0 : 1);
  const initialDylib = fs.readFileSync(hotMarker, "utf8").trim();
  if (!(await startHotHost(initialDylib))) process.exit(1);
  let lastHotSnapshot = hotSourceStamp();
  let hotBuilding = false;
  log(`watching ${hotWatchRoots.join(", ")} every ${intervalMs}ms (hot, state: ${stateFile})`);
  hotTimer = setInterval(async () => {
    if (stopping || hotBuilding) return;
    const nextSnapshot = hotSourceStamp();
    if (nextSnapshot === lastHotSnapshot) return;
    lastHotSnapshot = nextSnapshot;
    hotBuilding = true;
    try {
      // A failed build keeps the previous generation published and interactive.
      await publishHotPlugin();
      lastHotSnapshot = hotSourceStamp();
    } finally {
      hotBuilding = false;
    }
  }, intervalMs);
} else {
  server = web ? serve() : null;
  let lastSnapshot = listFiles(projectRoot);
  const initial = await build(pkg, buildTarget);
  if (once) {
    if (server) server.close();
    process.exit(initial ? 0 : 1);
  }
  if (initial && !web) await startNative(pkg, buildTarget);
  log(`watching ${projectRoot} every ${intervalMs}ms (state: ${stateFile})`);
  timer = setInterval(async () => {
    if (stopping) return;
    const nextSnapshot = listFiles(projectRoot);
    if (nextSnapshot === lastSnapshot) return;
    lastSnapshot = nextSnapshot;
    await stopChild();
    const ok = await build(pkg, buildTarget);
    if (ok && !web) await startNative(pkg, buildTarget);
  }, intervalMs);
}

const stopHotChild = async () => {
  if (!hotChild || hotChild.exitCode !== null) return;
  const current = hotChild;
  current.kill("SIGTERM");
  await new Promise((resolve) => {
    const killTimer = setTimeout(() => { current.kill("SIGKILL"); resolve(); }, 1500);
    current.once("exit", () => { clearTimeout(killTimer); resolve(); });
  });
  hotChild = null;
};
const shutdown = async () => {
  if (stopping) return;
  stopping = true;
  if (timer) clearInterval(timer);
  if (hotTimer) clearInterval(hotTimer);
  await stopChild();
  await stopHotChild();
  if (server) server.close();
  process.exit(0);
};
process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
