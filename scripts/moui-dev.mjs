#!/usr/bin/env node

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { spawn } from "node:child_process";

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
const stateFile = valueOf("--state", path.join(projectRoot, ".moui", "dev-state.json"));
const statusFile = path.join(projectRoot, ".moui", "dev-status.json");

const status = { ok: true, phase: "starting", generation: 0, package: packageName, target, error: "", updatedAt: Date.now() };
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
  const child = spawn(command, commandArgs, { cwd: projectRoot, env: { ...process.env, ...options.env }, stdio: ["ignore", "pipe", "pipe"], shell: false });
  let output = "";
  child.stdout.on("data", (chunk) => { process.stdout.write(chunk); output += chunk; });
  child.stderr.on("data", (chunk) => { process.stderr.write(chunk); output += chunk; });
  child.once("error", (error) => resolve({ code: 1, error }));
  child.once("exit", (code, signal) => resolve({ code: code ?? 1, signal, output }));
});
const moon = process.env.MOON ?? "moon";

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
  const env = { MOUI_DEV_STATE_FILE: stateFile, MOUI_DEV_GENERATION: String(status.generation) };
  child = spawn(moon, ["run", pkg, "--target", buildTarget], { cwd: projectRoot, env: { ...process.env, ...env }, stdio: "inherit" });
  child.once("exit", (code, signal) => {
    if (!stopping) log(`app exited (code=${code ?? "null"}, signal=${signal ?? "none"})`);
  });
}

const clientScript = `(() => { let generation = null; let error = null; const install = () => { const box = document.createElement('pre'); box.id = '__moui_dev_error'; Object.assign(box.style, { position: 'fixed', inset: '12px', zIndex: 2147483647, margin: 0, padding: '16px', background: '#2b1111', color: '#ffd6d6', font: '13px/1.5 monospace', whiteSpace: 'pre-wrap', display: 'none' }); document.body.appendChild(box); async function poll() { try { const response = await fetch('/__moui/status', { cache: 'no-store' }); const status = await response.json(); if (generation !== null && status.generation !== generation && status.ok) location.reload(); generation = status.generation; error = status.error || null; box.textContent = error ? '[moui dev] ' + error + '\\n\\nFix the source and save to retry.' : ''; box.style.display = error ? 'block' : 'none'; } catch (_) {} setTimeout(poll, 700); } poll(); }; if (document.body) install(); else document.addEventListener('DOMContentLoaded', install, { once: true }); })();`;

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
    let relative = decodeURIComponent(url.pathname).replace(/^\/+/, "") || defaultPage;
    for (const staticRoot of staticRoots) {
      const requested = path.resolve(staticRoot, relative);
      if ((requested !== staticRoot && !requested.startsWith(staticRoot + path.sep)) || !fs.existsSync(requested) || fs.statSync(requested).isDirectory()) continue;
      let content = fs.readFileSync(requested);
      if (path.extname(requested) === ".html") {
        content = Buffer.from(content.toString().replace(/<head>/i, '<head><script src="/__moui/client.js"></script>'));
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
  server.listen(port, "127.0.0.1", () => log(`web server listening at http://127.0.0.1:${port}/`));
  return server;
}

const pkg = discoverPackage();
const buildTarget = discoverTarget(pkg);
writeStatus({ package: pkg, target: buildTarget });
if (has("--help")) {
  process.stdout.write("Usage: moui dev [--package PATH] [--target TARGET] [--once|--build-only] [--web] [--port PORT] [--interval-ms MS] [--state PATH]\\n");
  process.stdout.write("Watches MoonBit inputs, rebuilds incrementally, restarts native apps, and serves Web errors with refresh.\\n");
  process.exit(0);
}

const server = web ? serve() : null;
let lastSnapshot = listFiles(projectRoot);
const initial = await build(pkg, buildTarget);
if (once) {
  if (server) server.close();
  process.exit(initial ? 0 : 1);
}
if (initial && !web) await startNative(pkg, buildTarget);
log(`watching ${projectRoot} every ${intervalMs}ms (state: ${stateFile})`);
const timer = setInterval(async () => {
  if (stopping) return;
  const nextSnapshot = listFiles(projectRoot);
  if (nextSnapshot === lastSnapshot) return;
  lastSnapshot = nextSnapshot;
  await stopChild();
  const ok = await build(pkg, buildTarget);
  if (ok && !web) await startNative(pkg, buildTarget);
}, intervalMs);
const shutdown = async () => {
  if (stopping) return;
  stopping = true;
  clearInterval(timer);
  await stopChild();
  if (server) server.close();
  process.exit(0);
};
process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
