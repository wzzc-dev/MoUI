#!/usr/bin/env node

import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import {
  buildWebPackage,
  rewriteRuntimeForPackage,
  runtimeAssetPaths,
  wasmArtifactPath,
} from "./web-bundle-tools.mjs";
import { readPinnedToolchain, repoRoot, runCommand } from "./lib/moonbit-tool-runner.mjs";

const pinnedToolchain = readPinnedToolchain();
if (!pinnedToolchain.mooncWorker || !pinnedToolchain.mooncWorkerIntegrity) {
  throw new Error(".moonbit-toolchain must define moonc-worker and moonc-worker-integrity");
}
const COMPILER_VERSION = pinnedToolchain.mooncWorker;
const COMPILER_INTEGRITY = pinnedToolchain.mooncWorkerIntegrity;
const ALLOWED_IMPORTS = [
  "wzzc-dev/moui",
  "wzzc-dev/moui/views",
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/geometry",
  "wzzc-dev/moui/graphics",
  "wzzc-dev/moui/state",
  "wzzc-dev/moui/text",
];

// Every package the in-browser compiler must be able to resolve. This is the
// Playground allowlist plus the packages the fixed Runner imports directly.
// It is intentionally a superset of the Playground runner's own wasm closure:
// e.g. wzzc-dev/moui/state is allowed for user code but is not referenced by
// the runner, so its release .mi/.core would otherwise be missing after a
// clean build.
const PLAYGROUND_REQUIRE_PACKAGES = [
  ...ALLOWED_IMPORTS,
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/backend/web",
  // The fixed Runner imports the web adapter directly
  // (compiler-worker.js RUNNER_SOURCE); without its prebuilt asset the
  // in-browser compile fails with "Package asset is unavailable".
  "wzzc-dev/moui_web_renderer",
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

function buildPlaygroundReleaseDependencies() {
  // Build every required package (allowlist + Runner imports) for wasm-gc
  // release so the generator is self-contained and works right after
  // `moon clean`, without relying on leftover release .mi/.core artifacts
  // produced by unrelated website builds. Package id "wzzc-dev/<path>" maps
  // to the repo-relative directory "<path>".
  const env = {
    ...process.env,
    MOUI_SKIA_DISABLE_PREBUILD_SKIA:
      process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA || "1",
  };
  for (const id of PLAYGROUND_REQUIRE_PACKAGES) {
    if (!id.startsWith("wzzc-dev/")) continue;
    runCommand("moon", ["build", id.slice("wzzc-dev/".length), "--target", "wasm-gc", "--release", "--strip"], {
      cwd: repoRoot,
      env,
    });
  }
}

const outDir = parseOut(process.argv.slice(2));
rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });

buildWebPackage("website/playground/web_wasm");
buildPlaygroundReleaseDependencies();
const wasmPath = wasmArtifactPath("website/playground/web_wasm");
copy(wasmPath, join(outDir, "playground.wasm"));
const wasmRevision = hashFile(wasmPath).slice("sha256-".length, "sha256-".length + 16);
const compilerWorkerRevision = hashFile(
  join(repoRoot, "website/playground/host/compiler-worker.js"),
).slice("sha256-".length, "sha256-".length + 16);

let index = readFileSync(join(repoRoot, "website/playground/web_wasm/index.html"), "utf8");
index = index
  .replaceAll("../../../moui_web_renderer/runtime.js", "./runtime.js")
  .replaceAll(
    "../../../_build/wasm-gc/debug/build/website/playground/web_wasm/web_wasm.wasm",
    `./playground.wasm?v=${wasmRevision}`,
  )
  .replaceAll("../host/", "./host/")
  .replaceAll(
    "./host/compiler-worker.js",
    `./host/compiler-worker.js?v=${compilerWorkerRevision}`,
  );
writeFileSync(join(outDir, "index.html"), index);

for (const asset of runtimeAssetPaths) {
  const source = join(repoRoot, asset);
  const destination = join(outDir, basename(asset));
  if (basename(asset) === "runtime.js") {
    writeFileSync(destination, rewriteRuntimeForPackage(readFileSync(source, "utf8")));
  } else {
    copy(source, destination);
  }
}
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
const candidateGraphPaths = [
  join(repoRoot, "_build/wasm-gc/debug/build/all_pkgs.json"),
  join(repoRoot, "_build/wasm-gc/release/build/all_pkgs.json"),
  join(repoRoot, "_build/packages.json"),
];
const hasValidGraph = path => {
  if (!existsSync(path)) return false;
  try {
    const data = JSON.parse(readFileSync(path, "utf8"));
    return Array.isArray(data.packages) && data.packages.length > 0;
  } catch {
    return false;
  }
};
let packageGraphPath = candidateGraphPaths.find(hasValidGraph);
if (!packageGraphPath) {
  // Package graph is only materialized by a whole-workspace `moon check`,
  // not by per-package builds, so after `moon clean` it must be regenerated
  // explicitly. Newer Moon places it at `_build/<target>/debug/build/all_pkgs.json`.
  execFileSync("moon", ["check", "--target", "wasm-gc"], {
    cwd: repoRoot,
    stdio: "inherit",
    env: {
      ...process.env,
      MOUI_SKIA_DISABLE_PREBUILD_SKIA:
        process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA || "1",
    },
  });
  packageGraphPath = candidateGraphPaths.find(hasValidGraph);
  if (!packageGraphPath) {
    // Fallback to any existing candidate for error reporting
    packageGraphPath = candidateGraphPaths.find(path => existsSync(path));
    if (!packageGraphPath) {
      throw new Error("package graph not found after `moon check --target wasm-gc`");
    }
  }
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
for (const id of [
  ...ALLOWED_IMPORTS,
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/backend/web",
  // The fixed Runner imports the web adapter directly
  // (compiler-worker.js RUNNER_SOURCE); without it the in-browser compile
  // fails with "Package asset is unavailable for wzzc-dev/moui_web_renderer".
  "wzzc-dev/moui_web_renderer",
]) {
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
