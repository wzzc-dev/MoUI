const ALLOWED_IMPORTS = new Set([
  "wzzc-dev/moui",
  "wzzc-dev/moui/views",
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/geometry",
  "wzzc-dev/moui/graphics",
  "wzzc-dev/moui/state",
  "wzzc-dev/moui/text",
]);

const compilerModule = { exports: {} };
self.module = compilerModule;
self.exports = compilerModule.exports;
importScripts(new URL("../assets/moonc-worker.js", self.location.href).href);
const compiler = compilerModule.exports;

let latestRevision = -1;
let manifestPromise;
const bytesCache = new Map();

const diagnostic = (message, file = "moon.pkg", line = 1, column = 1) => ({
  severity: "error",
  message,
  file,
  line,
  column,
  endLine: line,
  endColumn: column,
});

function parseMoonPkgImports(source) {
  const imports = [];
  const seen = new Set();
  for (const block of String(source || "").matchAll(/(?:^|\n)\s*import\s*\{([\s\S]*?)\}/g)) {
    for (const entry of block[1].matchAll(/"([^"]+)"\s*(?:@([A-Za-z_][A-Za-z0-9_]*))?/g)) {
      if (seen.has(entry[1])) continue;
      seen.add(entry[1]);
      imports.push({ path: entry[1], alias: entry[2] || entry[1].split("/").at(-1) });
    }
  }
  return imports;
}

function validateProject(files) {
  if (!files || typeof files !== "object") return [diagnostic("Project files are missing.")];
  const packageText = String(files["moon.pkg"] || "");
  const imports = parseMoonPkgImports(packageText);
  const invalid = imports.filter(value => !ALLOWED_IMPORTS.has(value.path));
  if (invalid.length > 0) return [diagnostic(`Package import is not allowed: ${invalid[0].path}`)];
  if (/backend\/|\/runtime|\/render/.test(packageText)) {
    return [diagnostic("Application source cannot import runtime, renderer, or platform backend packages.")];
  }
  if (/"is-main"\s*:\s*true/.test(packageText) || /native/.test(packageText)) {
    return [diagnostic("The Playground package must use the fixed wasm-gc Runner.")];
  }
  return [];
}

async function loadManifest() {
  if (!manifestPromise) {
    manifestPromise = fetch(new URL("../assets/manifest.json", self.location.href)).then(response => {
      if (!response.ok) throw new Error("Playground compiler manifest is unavailable.");
      return response.json();
    });
  }
  return manifestPromise;
}

async function fetchBytes(path) {
  const url = new URL(`../${path}`, self.location.href).href;
  if (!bytesCache.has(url)) {
    bytesCache.set(url, fetch(url).then(async response => {
      if (!response.ok) throw new Error(`Failed to load compiler asset ${path}`);
      return new Uint8Array(await response.arrayBuffer());
    }));
  }
  return bytesCache.get(url);
}

function parseDiagnostic(value) {
  let item = value;
  try { item = JSON.parse(value); } catch {}
  if (typeof item === "string") return diagnostic(item, "main.mbt");
  const match = String(item.loc || "").match(/^(\d+):(\d+)-(\d+):(\d+)$/);
  return {
    severity: item.level || "error",
    message: item.message || String(value),
    file: String(item.path || "main.mbt").replace(/^playground:\/(main|runner)\//, ""),
    line: Number(match?.[1] || 1),
    column: Number(match?.[2] || 1),
    endLine: Number(match?.[3] || match?.[1] || 1),
    endColumn: Number(match?.[4] || match?.[2] || 1),
  };
}

function normalizedDiagnostics(values) {
  const items = (values || []).map(parseDiagnostic);
  const hasError = items.some(item => item.severity !== "warning");
  return hasError ? items.filter(item => item.severity !== "warning") : items;
}

function packageSpec(id, alias) {
  const stem = id.split("/").at(-1);
  return `/packages/${id}/${stem}.mi:${alias || stem}`;
}

function coreSpec(manifest, id, alias) {
  const item = manifest.core.interfaces.find(value => value.path === id);
  if (!item) throw new Error(`Core interface is unavailable for ${id}`);
  return `${item.spec.split(":")[0]}:${alias || id.split("/").at(-1)}`;
}

async function directMiFiles(manifest, imports, extra = new Map()) {
  return Promise.all(imports.map(async dependency => {
    if (dependency.path.startsWith("moonbitlang/core/")) {
      const item = manifest.core.interfaces.find(value => value.path === dependency.path);
      return [coreSpec(manifest, dependency.path, dependency.alias), await fetchBytes(item.url)];
    }
    if (extra.has(dependency.path)) {
      return [packageSpec(dependency.path, dependency.alias), extra.get(dependency.path)];
    }
    const item = manifest.packages[dependency.path];
    if (!item) throw new Error(`Package asset is unavailable for ${dependency.path}`);
    return [packageSpec(dependency.path, dependency.alias), await fetchBytes(item.mi)];
  }));
}

async function indirectMiFiles(manifest, directPaths) {
  const files = [];
  for (const [id, item] of Object.entries(manifest.packages)) {
    if (directPaths.has(id)) continue;
    files.push([packageSpec(id, ""), await fetchBytes(item.mi)]);
  }
  return files;
}

async function stdMiFiles(manifest) {
  return Promise.all(manifest.core.interfaces.map(async item => [item.spec, await fetchBytes(item.url)]));
}

function reachablePackageIds(manifest, roots) {
  const reachable = new Set();
  const visit = id => {
    if (id.startsWith("moonbitlang/core/") || reachable.has(id)) return;
    const item = manifest.packages[id];
    if (!item) throw new Error(`Package core is unavailable for ${id}`);
    reachable.add(id);
    for (const dependency of item.deps || []) visit(dependency.path);
  };
  for (const root of roots) visit(root);
  // The linker walks package symbols recursively. A dependency-first DFS is
  // correct but exceeds the browser Worker's call stack for the Web runtime
  // closure. Keep a deterministic, shallow-friendly order for this fixed
  // release graph, then fall back to lexical ordering for future packages.
  const priority = [
    "wzzc-dev/window/web",
    "wzzc-dev/window/dpi",
    "wzzc-dev/window/core",
    "wzzc-dev/moui/views",
    "wzzc-dev/moui/runtime",
    "wzzc-dev/moui/render/webgpu_adapter",
    "wzzc-dev/moui/render",
    "wzzc-dev/moui/core/unicode",
    "wzzc-dev/moui/core",
    "wzzc-dev/moui/backend/web",
    "wzzc-dev/moui/backend/host",
    "Milky2018/moon_zeno",
  ];
  const rank = new Map(priority.map((id, index) => [id, index]));
  return [...reachable].sort((a, b) =>
    (rank.get(a) ?? priority.length) - (rank.get(b) ?? priority.length)
    || a.localeCompare(b),
  );
}

const RUNNER_SOURCE = `fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@user.program(),
    width=960.0,
    height=640.0,
  )
  @moui.run_app(
    "MoUI Playground Preview",
    runtime,
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}

pub fn web_dispatch_event(kind : Int, raw_id : Int, arg0 : Int, arg1 : Int, argd : Double, text_id : Int) -> Unit {
  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
}

pub fn web_dispatch_pointer_input(raw_id : Int, kind : Int, x_px : Double, y_px : Double, delta_x_px : Double, delta_y_px : Double, button : Int, modifiers : Int) -> Int {
  @web.web_dispatch_pointer_input(raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers)
}

pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
  @web.web_dispatch_route(source_code, text_id)
}

pub fn web_dispatch_semantics_action(raw_id : Int, node_id_text_id : Int, generation_text_id : Int, action_code : Int, value_id : Int, direction_code : Int) -> Unit {
  @web.web_dispatch_semantics_action(raw_id, node_id_text_id, generation_text_id, action_code, value_id, direction_code)
}

pub fn web_complete_async_clipboard_read(id : Int, ok : Bool, text_id : Int) -> Unit {
  @web.web_complete_async_clipboard_read(id, ok, text_id)
}

pub fn web_complete_async_file_dialog(id : Int, ok : Bool, text_id : Int) -> Unit {
  @web.web_complete_async_file_dialog(id, ok, text_id)
}

pub fn web_complete_async_text_file_read(id : Int, ok : Bool, text_id : Int) -> Unit {
  @web.web_complete_async_text_file_read(id, ok, text_id)
}`;

async function compile(request) {
  const validation = validateProject(request.files);
  if (validation.length > 0) return { revision: request.revision, status: "failed", diagnostics: validation };
  const manifest = await loadManifest();
  const imports = parseMoonPkgImports(request.files["moon.pkg"]);
  const prelude = { path: "moonbitlang/core/prelude", alias: "prelude" };
  const userImports = [...imports, prelude];
  const std = await stdMiFiles(manifest);
  const directUser = await directMiFiles(manifest, userImports);
  const user = compiler.buildPackage({
    mbtFiles: [["main.mbt", String(request.files["main.mbt"] || "")]],
    miFiles: directUser,
    indirectImportMiFiles: await indirectMiFiles(manifest, new Set(imports.map(value => value.path))),
    stdMiFiles: std,
    target: "wasm-gc",
    pkg: manifest.userPackage,
    pkgSources: manifest.pkgSources,
    isMain: false,
    errorFormat: "json",
    enableValueTracing: false,
    noOpt: false,
  });
  if (!user.core || !user.mi) {
    return { revision: request.revision, status: "failed", diagnostics: normalizedDiagnostics(user.diagnostics) };
  }

  const runnerImports = [
    { path: manifest.userPackage, alias: "user" },
    { path: "wzzc-dev/moui", alias: "moui" },
    { path: "wzzc-dev/moui/runtime", alias: "runtime" },
    { path: "wzzc-dev/moui/backend/web", alias: "web" },
    { path: "wzzc-dev/moui/render/webgpu_adapter", alias: "webgpu_adapter" },
    prelude,
  ];
  let runner;
  try {
    runner = compiler.buildPackage({
      mbtFiles: [["runner.mbt", RUNNER_SOURCE]],
      miFiles: await directMiFiles(manifest, runnerImports, new Map([[manifest.userPackage, user.mi]])),
      indirectImportMiFiles: await indirectMiFiles(manifest, new Set(runnerImports.map(value => value.path))),
      stdMiFiles: std,
      target: "wasm-gc",
      pkg: manifest.runnerPackage,
      pkgSources: manifest.pkgSources,
      isMain: true,
      errorFormat: "json",
      enableValueTracing: false,
      noOpt: true,
    });
  } catch (error) {
    throw new Error(`Runner build failed: ${error instanceof Error ? error.message : String(error)}`);
  }
  if (!runner.core || !runner.mi) {
    return { revision: request.revision, status: "failed", diagnostics: normalizedDiagnostics(runner.diagnostics) };
  }

  const roots = [...imports.map(value => value.path), "wzzc-dev/moui/runtime", "wzzc-dev/moui/backend/web"];
  const packageCores = await Promise.all(reachablePackageIds(manifest, roots).map(id => fetchBytes(manifest.packages[id].core)));
  const coreFiles = [
    ...(manifest.core.abort ? [await fetchBytes(manifest.core.abort)] : []),
    await fetchBytes(manifest.core.core),
    ...packageCores,
    user.core,
    runner.core,
  ];
  const exportedFunctions = [
    "web_dispatch_event",
    "web_dispatch_pointer_input",
    "web_dispatch_route",
    "web_dispatch_semantics_action",
    "web_complete_async_clipboard_read",
    "web_complete_async_file_dialog",
    "web_complete_async_text_file_read",
  ];
  let linked;
  try {
    linked = compiler.linkCore({
      coreFiles,
      main: manifest.runnerPackage,
      pkgSources: manifest.pkgSources,
      target: "wasm-gc",
      exportedFunctions,
      outputFormat: "wasm",
      testMode: false,
      debug: false,
      noOpt: true,
      sourceMap: false,
      sources: {},
      stopOnMain: false,
    });
  } catch (error) {
    throw new Error(`Core link failed (${packageCores.length} packages): ${error instanceof Error ? error.message : String(error)}`);
  }
  return {
    revision: request.revision,
    status: "success",
    wasmBytes: linked.result,
    diagnostics: normalizedDiagnostics(user.diagnostics),
  };
}

self.onmessage = async event => {
  const request = event.data || {};
  if (request.type !== "compile") return;
  const revision = Number(request.revision);
  if (!Number.isFinite(revision) || revision < latestRevision) return;
  latestRevision = revision;
  try {
    const result = await compile({ ...request, revision });
    if (result.revision !== latestRevision) return;
    const transfer = result.wasmBytes ? [result.wasmBytes.buffer] : [];
    self.postMessage({ type: "compile-result", result }, transfer);
  } catch (error) {
    if (revision !== latestRevision) return;
    self.postMessage({
      type: "compile-result",
      result: {
        revision,
        status: "failed",
        diagnostics: [diagnostic(error instanceof Error ? error.message : String(error))],
      },
    });
  }
};
