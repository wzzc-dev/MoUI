#!/usr/bin/env node

import {
  existsSync,
  readFileSync,
  readdirSync,
} from "node:fs";
import { basename, dirname, join, relative } from "node:path";

const root = process.cwd();
const backendRoot = join(root, "moui", "backend");
const ownershipConfig = JSON.parse(
  readFileSync(join(root, "checks", "backend-common-ownership.json"), "utf8"),
);
// Renderer module identities are derived from the release catalog so adding
// a renderer does not require editing this validator (open-extension E7,
// ADR 0007). Subpackage tokens that are not catalogued as their own module
// stay in the explicit extras list.
const rendererModules = JSON.parse(
  readFileSync(join(root, "checks", "release-modules.json"), "utf8"),
).modules.filter((module) => module.role === "renderer");
const rendererShortNames = rendererModules.map((module) =>
  module.name.replace(/^wzzc-dev\/moui_/, "").replace(/_renderer$/, ""),
);
const extraRendererPackageTokens = ["canvas2d"];
const rendererPackagePattern = new RegExp(
  `wzzc-dev\\/moui_(?:${rendererShortNames.join("|")})_renderer(?:\\/|"|\\s|$)`,
);
const legacyRendererPackagePattern =
  /wzzc-dev\/moui\/render\/(?:skia|sun|wgpu|canvas2d|webgpu_adapter)(?:\/|"|\s|$)/;
const rendererNativePackagePattern = new RegExp(
  `(?:wzzc-dev\\/moui_(?:${rendererShortNames.join("|")})|Milky2018\\/wgpu_mbt)`,
);
const concreteRendererDirectoryNames = new Set([
  "skia",
  "sun",
  "wgpu",
  "canvas",
  "canvas2d",
  "webgpu",
]);
const concreteSourcePatterns = [
  /\bSkia(?:Raster|Gpu|Surface|Renderer|Present|Font|Native)?\b/i,
  /\bWgpu(?:Renderer|Surface|Provider|Native)?\b/i,
  /\bWebGPU\b/i,
  /\bSunRaster\b/i,
  /\bCanvas2D(?:Renderer|Provider|Imports)?\b/i,
  /@(?:skia|skia_native|wgpu|wgpu_c|sun|canvas2d)\b/,
  new RegExp(
    `moui_(?:${[...rendererShortNames, ...extraRendererPackageTokens].join("|")})`,
    "i",
  ),
];
const productionExtensions = new Set([
  ".mbt",
  ".c",
  ".cc",
  ".cpp",
  ".h",
  ".m",
  ".mm",
  ".js",
  ".mjs",
  ".ts",
]);

function walk(dir) {
  if (!existsSync(dir)) return [];
  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (
      entry.name.startsWith(".") ||
      entry.name === "_build" ||
      entry.name === "node_modules"
    ) continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) files.push(...walk(path));
    else files.push(path);
  }
  return files;
}

function walkDirectories(dir) {
  if (!existsSync(dir)) return [];
  const directories = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (
      !entry.isDirectory() ||
      entry.name.startsWith(".") ||
      entry.name === "_build" ||
      entry.name === "node_modules"
    ) continue;
    const path = join(dir, entry.name);
    directories.push(path, ...walkDirectories(path));
  }
  return directories;
}

function extension(path) {
  const index = path.lastIndexOf(".");
  return index < 0 ? "" : path.slice(index);
}

function isTestSource(path) {
  return /(?:_test|_wbtest)\.mbt$/.test(path);
}

function productionMoonPkg(content) {
  return content.replace(
    /import\s*\{[\s\S]*?\}\s*for\s+"(?:test|wbtest)"/g,
    "",
  );
}

function lineNumber(content, offset) {
  return content.slice(0, offset).split("\n").length;
}

function findPackageFile(source) {
  let dir = dirname(source);
  while (dir.startsWith(root)) {
    const candidate = join(dir, "moon.pkg");
    if (existsSync(candidate)) return candidate;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return undefined;
}

function isExecutablePackage(content) {
  return (
    /pkgtype\s*\(\s*kind\s*:\s*"executable"\s*\)/.test(content) ||
    /"is-main"\s*:\s*true/.test(content)
  );
}

function hasPlatformBackendImport(content) {
  return /wzzc-dev\/moui\/backend\/(?:macos|windows|linux|android|ios|harmonyos|web|wechat)(?:\/|"|\s|$)/.test(content);
}

function hasCompleteBuilderChain(content) {
  return (
    /@runtime\.run_app\s*\(/.test(content) &&
    /\.(?:render|render_all)\s*\(/.test(content) &&
    /\.backend\s*\(/.test(content) &&
    /\.(?:run|run_async_pump)\s*\(/.test(content)
  );
}

const violations = [];
const backendFiles = walk(backendRoot);

for (const path of walkDirectories(backendRoot)) {
  if (concreteRendererDirectoryNames.has(basename(path))) {
    violations.push(
      `${relative(root, path)} is a concrete renderer directory under backend`,
    );
  }
}

for (const path of backendFiles.filter((file) => file.endsWith("moon.pkg"))) {
  const content = productionMoonPkg(readFileSync(path, "utf8"));
  for (const pattern of [
    rendererPackagePattern,
    legacyRendererPackagePattern,
    rendererNativePackagePattern,
  ]) {
    const match = pattern.exec(content);
    if (match) {
      violations.push(
        `${relative(root, path)}:${lineNumber(content, match.index)} imports a concrete renderer package`,
      );
    }
  }
}

for (const path of backendFiles) {
  if (!productionExtensions.has(extension(path)) || isTestSource(path)) continue;
  const content = readFileSync(path, "utf8");
  for (const pattern of concreteSourcePatterns) {
    const match = pattern.exec(content);
    if (match) {
      violations.push(
        `${relative(root, path)}:${lineNumber(content, match.index)} contains concrete renderer source: ${match[0]}`,
      );
    }
  }
}

const allFiles = walk(root);

for (const source of allFiles.filter((path) => path.endsWith(".mbt"))) {
  if (isTestSource(source) || source.includes(`${join(root, "docs")}/`)) continue;
  const content = readFileSync(source, "utf8");
  if (!/^\s*@runtime\.run_app\s*\(/m.test(content)) continue;
  const pkg = findPackageFile(source);
  if (!pkg) {
    violations.push(`${relative(root, source)} calls @runtime.run_app without moon.pkg`);
    continue;
  }
  const imports = productionMoonPkg(readFileSync(pkg, "utf8"));
  const hasBackend = hasPlatformBackendImport(imports);
  const hasRenderer = rendererPackagePattern.test(imports);
  if (!hasBackend || !hasRenderer) {
    violations.push(
      `${relative(root, pkg)} composition root must import one platform backend and one concrete renderer`,
    );
  }
  if (!hasCompleteBuilderChain(content)) {
    violations.push(
      `${relative(root, source)} composition root must call @runtime.run_app(...).render[_all](...).backend(...).run[_async_pump]()`,
    );
  }
}

for (const pkg of allFiles.filter((path) => path.endsWith("moon.pkg"))) {
  const packageContent = readFileSync(pkg, "utf8");
  if (!isExecutablePackage(packageContent)) continue;
  const imports = productionMoonPkg(packageContent);
  const hasBackend = hasPlatformBackendImport(imports);
  const hasRenderer = rendererPackagePattern.test(imports);
  if (!hasBackend) continue;
  if (!hasRenderer) {
    violations.push(
      `${relative(root, pkg)} executable platform root must import one concrete renderer`,
    );
    continue;
  }
  const packageDir = dirname(pkg);
  const roots = readdirSync(packageDir, { withFileTypes: true })
    .filter(
      (entry) =>
        entry.isFile() &&
        entry.name.endsWith(".mbt") &&
        !isTestSource(entry.name),
    )
    .map((entry) => join(packageDir, entry.name));
  if (!roots.some((source) => hasCompleteBuilderChain(readFileSync(source, "utf8")))) {
    violations.push(
      `${relative(root, pkg)} executable composition root must assemble renderer and backend through one AppBuilder chain`,
    );
  }
}

for (const sourceRoot of ownershipConfig.sourceRoots) {
  for (const path of walk(join(root, sourceRoot))) {
    if (!path.endsWith(".mbt") && !path.endsWith(".mbti")) continue;
    const content = readFileSync(path, "utf8");
    for (const symbol of ownershipConfig.legacySymbols) {
      const index = content.indexOf(symbol);
      if (index >= 0) {
        violations.push(
          `${relative(root, path)}:${lineNumber(content, index)} contains removed renderer/backend contract: ${symbol}`,
        );
      }
    }
  }
}

for (const path of walk(join(root, "moui", "render"))) {
  if (!path.endsWith(".mbt") && !path.endsWith(".mbti")) continue;
  const content = readFileSync(path, "utf8");
  for (const token of ownershipConfig.rootRenderForbiddenTokens) {
    const index = content.indexOf(token);
    if (index >= 0) {
      violations.push(
        `${relative(root, path)}:${lineNumber(content, index)} contains renderer-specific root surface token: ${token}`,
      );
    }
  }
}

if (violations.length > 0) {
  console.error("Backend-renderer boundary violations:");
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log("backend-renderer boundary: ok");
