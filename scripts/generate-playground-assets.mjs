#!/usr/bin/env node

import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import { buildWebPackage, runtimeAssetPaths, wasmArtifactPath } from "./web-bundle-tools.mjs";
import { repoRoot } from "./lib/moonbit-tool-runner.mjs";

const COMPILER_VERSION = "0.1.202607062";
const COMPILER_INTEGRITY = "sha512-+HsW7BZ7Oevx43ZuflZDb0j5+zFtu/AQa4Wgl/FEQOLSJJQ/U++BkFdnraTogUVNQJWWvecTDb/oMT5dn/jKzA==";
const ALLOWED_IMPORTS = [
  "wzzc-dev/moui",
  "wzzc-dev/moui/views",
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/geometry",
  "wzzc-dev/moui/graphics",
  "wzzc-dev/moui/state",
  "wzzc-dev/moui/text",
];

function parseOut(argv) {
  const index = argv.indexOf("--out");
  if (index < 0 || !argv[index + 1]) throw new Error("Usage: node scripts/generate-playground-assets.mjs --out <dir>");
  return resolve(repoRoot, argv[index + 1]);
}

function hashFile(filePath) {
  return `sha256-${createHash("sha256").update(readFileSync(filePath)).digest("hex")}`;
}

function copy(source, destination) {
  mkdirSync(dirname(destination), { recursive: true });
  cpSync(source, destination);
}

function collectFiles(root, prefix = "") {
  const result = [];
  for (const name of readdirSync(root).sort()) {
    const full = join(root, name);
    const rel = prefix ? join(prefix, name) : name;
    if (statSync(full).isDirectory()) result.push(...collectFiles(full, rel));
    else result.push({ full, rel });
  }
  return result;
}

const outDir = parseOut(process.argv.slice(2));
rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });

buildWebPackage("website/playground/web_wasm");
const wasmPath = wasmArtifactPath("website/playground/web_wasm");
copy(wasmPath, join(outDir, "playground.wasm"));
const wasmRevision = hashFile(wasmPath).slice("sha256-".length, "sha256-".length + 16);

let index = readFileSync(join(repoRoot, "website/playground/web_wasm/index.html"), "utf8");
index = index
  .replaceAll("../../../moui/backend/web/runtime.js", "./runtime.js")
  .replaceAll(
    "../../../_build/wasm-gc/debug/build/website/playground/web_wasm/web_wasm.wasm",
    `./playground.wasm?v=${wasmRevision}`,
  )
  .replaceAll("../host/", "./host/");
writeFileSync(join(outDir, "index.html"), index);

for (const asset of runtimeAssetPaths) copy(join(repoRoot, asset), join(outDir, basename(asset)));
for (const name of ["compiler-worker.js", "playground-bridge.js", "preview-host.js"]) {
  copy(join(repoRoot, "website/playground/host", name), join(outDir, "host", name));
}

const localMooncCandidates = [
  process.env.MOONBIT_PLAYGROUND_MOONC,
  join(repoRoot, "dist/playground/assets/moonc-web.cjs"),
  join(repoRoot, "dist/pages/playground/assets/moonc-web.cjs"),
].filter(Boolean);
const localMoonc = localMooncCandidates.find(path => existsSync(path));
if (localMoonc) {
  copy(localMoonc, join(outDir, "assets", "moonc-web.cjs"));
  copy(localMoonc, join(outDir, "assets", "moonc-worker.js"));
} else {
  const npmTemp = join(outDir, ".npm-tmp");
  mkdirSync(npmTemp, { recursive: true });
  execFileSync("npm", ["pack", `@moonbit/moonc-worker@${COMPILER_VERSION}`, "--pack-destination", npmTemp], {
    cwd: repoRoot,
    stdio: "ignore",
  });
  const tarball = join(npmTemp, readdirSync(npmTemp).find(name => name.endsWith(".tgz")));
  execFileSync("tar", ["-xzf", tarball, "-C", npmTemp], { cwd: repoRoot, stdio: "ignore" });
  copy(join(npmTemp, "package", "moonc-web.cjs"), join(outDir, "assets", "moonc-web.cjs"));
  copy(join(npmTemp, "package", "moonc-web.cjs"), join(outDir, "assets", "moonc-worker.js"));
  rmSync(npmTemp, { recursive: true, force: true });
}

const lessonRoot = join(repoRoot, "website/tutorial/lessons");
copy(join(lessonRoot, "catalog.json"), join(outDir, "lessons", "catalog.json"));
for (const lesson of readdirSync(lessonRoot).sort()) {
  const sourceRoot = join(lessonRoot, lesson);
  if (!statSync(sourceRoot).isDirectory()) continue;
  for (const file of collectFiles(sourceRoot)) copy(file.full, join(outDir, "lessons", lesson, file.rel));
}

const releaseRoot = join(repoRoot, "_build/wasm-gc/release/build");
const packageGraphPath = join(repoRoot, "_build/packages.json");
if (!existsSync(packageGraphPath)) {
  // `moon build --target wasm-gc --release` for the playground package may not
  // materialize the workspace package graph on every CI image. Force a cheap
  // check first so packages.json exists for dependency collection.
  execFileSync("moon", ["check", "website/playground/web_wasm", "--target", "wasm-gc"], {
    cwd: repoRoot,
    stdio: "inherit",
    env: {
      ...process.env,
      MOUI_SKIA_DISABLE_PREBUILD_SKIA:
        process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA || "1",
    },
  });
}
const dependencyFiles = existsSync(releaseRoot)
  ? collectFiles(releaseRoot).filter(file => file.rel.endsWith(".mi") || file.rel.endsWith(".core"))
  : [];
for (const file of dependencyFiles) copy(file.full, join(outDir, "assets/core", file.rel));

const packageGraph = JSON.parse(readFileSync(packageGraphPath, "utf8"));
const allPackages = {};
for (const pkg of packageGraph.packages) {
  const id = pkg.rel ? `${pkg.root}/${pkg.rel}` : pkg.root;
  const stem = id.split("/").at(-1);
  const mi = join(releaseRoot, id, `${stem}.mi`);
  const core = join(releaseRoot, id, `${stem}.core`);
  if (!existsSync(mi) || !existsSync(core)) continue;
  allPackages[id] = {
    deps: (pkg.deps || []).map(dep => ({ path: dep.path, alias: dep.alias })),
    mi: `assets/core/${id}/${stem}.mi`,
    core: `assets/core/${id}/${stem}.core`,
  };
}

const packageIds = new Set();
const collectPackage = id => {
  if (id.startsWith("moonbitlang/core/") || packageIds.has(id)) return;
  const item = allPackages[id];
  if (!item) throw new Error(`Missing prebuilt Playground dependency: ${id}`);
  packageIds.add(id);
  for (const dependency of item.deps) collectPackage(dependency.path);
};
for (const id of [...ALLOWED_IMPORTS, "wzzc-dev/moui/runtime", "wzzc-dev/moui/backend/web"]) {
  collectPackage(id);
}
const packages = Object.fromEntries([...packageIds].sort().map(id => [id, allPackages[id]]));

const coreModuleRoot = process.env.MOONBIT_PLAYGROUND_CORE_ROOT || join(homedir(), ".moon/lib/core");
const coreBundleRoot = join(coreModuleRoot, "_build/wasm-gc/release/bundle");
if (!existsSync(join(coreBundleRoot, "core.core"))) {
  execFileSync("moon", ["bundle", "--target", "wasm-gc", "--release", "--strip"], {
    cwd: coreModuleRoot,
    stdio: "inherit",
  });
}
copy(join(coreBundleRoot, "core.core"), join(outDir, "assets/moonbit-core/core.core"));
const abortCore = join(coreBundleRoot, "abort/abort.core");
if (existsSync(abortCore)) copy(abortCore, join(outDir, "assets/moonbit-core/abort/abort.core"));
const coreInterfaces = [];
for (const file of collectFiles(coreBundleRoot).filter(file => file.rel.endsWith(".mi"))) {
  copy(file.full, join(outDir, "assets/moonbit-core", file.rel));
  const packagePath = dirname(file.rel).replaceAll("\\", "/");
  coreInterfaces.push({
    path: `moonbitlang/core/${packagePath}`,
    spec: `/lib/core/${packagePath}:${packagePath.split("/").at(-1)}`,
    url: `assets/moonbit-core/${file.rel.replaceAll("\\", "/")}`,
  });
}

const pkgSources = [
  "moonbitlang/core:moonbit-core:/lib/core",
  ...Object.keys(packages).sort().map(id => `${id}:moui:/packages/${id}`),
  "wzzc-dev/moui_playground/user:playground:/main",
  "wzzc-dev/moui_playground/runner:playground:/runner",
];

const trackedAssets = collectFiles(outDir)
  .filter(file => !file.rel.startsWith(".npm-tmp/"))
  .map(file => ({ path: file.rel, hash: hashFile(file.full), bytes: statSync(file.full).size }));
const manifest = {
  schemaVersion: 1,
  target: "wasm-gc",
  compiler: { package: "@moonbit/moonc-worker", version: COMPILER_VERSION, integrity: COMPILER_INTEGRITY },
  userPackage: "wzzc-dev/moui_playground/user",
  runnerPackage: "wzzc-dev/moui_playground/runner",
  pkgSources,
  core: {
    core: "assets/moonbit-core/core.core",
    abort: existsSync(abortCore) ? "assets/moonbit-core/abort/abort.core" : null,
    interfaces: coreInterfaces,
  },
  packages,
  allowedImports: ALLOWED_IMPORTS,
  lessons: JSON.parse(readFileSync(join(lessonRoot, "catalog.json"), "utf8")),
  assets: trackedAssets,
};
mkdirSync(join(outDir, "assets"), { recursive: true });
writeFileSync(join(outDir, "assets", "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Playground assets written to ${relative(repoRoot, outDir)}`);
