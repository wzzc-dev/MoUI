import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";
import { brotliCompressSync, gzipSync } from "node:zlib";
import { repoRoot, runCommand } from "./lib/moonbit-tool-runner.mjs";

export const runtimeAssetPaths = [
  "moui_web_renderer/runtime.js",
  "moui/backend/web/browser_runtime.js",
  "moui_web_renderer/canvas2d_runtime.js",
];

export function usageAndExit(message, usage) {
  if (message) {
    console.error(message);
  }
  console.error(usage);
  process.exit(message ? 1 : 0);
}

export function parseCommonArgs(argv, usage) {
  const options = {
    packagePath: "",
    json: false,
    noBuild: false,
    outDir: "",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--json":
        options.json = true;
        break;
      case "--no-build":
        options.noBuild = true;
        break;
      case "--out":
        options.outDir = argv[++index] || "";
        break;
      case "-h":
      case "--help":
        usageAndExit("", usage);
        break;
      default:
        if (arg.startsWith("-")) {
          usageAndExit(`Unknown option: ${arg}`, usage);
        }
        if (options.packagePath) {
          usageAndExit(`Unexpected argument: ${arg}`, usage);
        }
        options.packagePath = arg;
        break;
    }
  }
  if (!options.packagePath) {
    usageAndExit("Missing web package path.", usage);
  }
  return options;
}

export function normalizePackagePath(packagePath) {
  return packagePath.replace(/^\.\/+/, "").replace(/\/+$/, "");
}

export function buildWebPackage(packagePath) {
  runCommand("moon", [
    "build",
    packagePath,
    "--target",
    "wasm-gc",
    "--release",
    "--strip",
  ], {
    env: {
      ...process.env,
      MOUI_SKIA_DISABLE_PREBUILD_SKIA:
        process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA || "1",
    },
  });
}

export function wasmArtifactPath(packagePath) {
  const normalized = normalizePackagePath(packagePath);
  return join(
    repoRoot,
    "_build",
    "wasm-gc",
    "release",
    "build",
    normalized,
    `${basename(normalized)}.wasm`,
  );
}

export function packageRoot(packagePath) {
  return join(repoRoot, normalizePackagePath(packagePath));
}

export function measureFile(filePath, { name, kind, group }) {
  const bytes = readFileSync(filePath);
  return {
    name,
    kind,
    group,
    path: relative(repoRoot, filePath),
    rawBytes: bytes.length,
    gzipBytes: gzipSync(bytes).length,
    brotliBytes: brotliCompressSync(bytes).length,
  };
}

export function collectAssetFiles(root, prefix = "") {
  if (!existsSync(root)) {
    return [];
  }
  const entries = [];
  for (const name of readdirSync(root).sort()) {
    const fullPath = join(root, name);
    const relativePath = prefix ? `${prefix}/${name}` : name;
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      entries.push(...collectAssetFiles(fullPath, relativePath));
    } else if (stat.isFile()) {
      entries.push({ fullPath, relativePath });
    }
  }
  return entries;
}

export function collectBundleSize(packagePath) {
  const normalized = normalizePackagePath(packagePath);
  const wasmPath = wasmArtifactPath(normalized);
  if (!existsSync(wasmPath)) {
    throw new Error(`Wasm artifact not found: ${relative(repoRoot, wasmPath)}`);
  }
  const runtimeAssets = runtimeAssetPaths.map(assetPath => {
    const filePath = join(repoRoot, assetPath);
    return measureFile(filePath, {
      name: basename(assetPath),
      kind: "js",
      group: "runtime",
    });
  });
  const wasmAsset = measureFile(wasmPath, {
    name: basename(wasmPath),
    kind: "wasm",
    group: "app",
  });
  const assetsRoot = join(packageRoot(normalized), "assets");
  const appAssets = collectAssetFiles(assetsRoot).map(asset => measureFile(
    asset.fullPath,
    {
      name: `assets/${asset.relativePath}`,
      kind: "asset",
      group: "assets",
    },
  ));
  const assets = [wasmAsset, ...runtimeAssets, ...appAssets];
  const groupAssets = group =>
    assets.filter(asset => asset.group === group);
  const groupTotal = (group, key) =>
    groupAssets(group).reduce((total, asset) => total + asset[key], 0);
  const sum = key => assets.reduce((total, asset) => total + asset[key], 0);
  return {
    schemaVersion: 1,
    mode: "moui-web-bundle-size",
    package: normalized,
    wasmPath: relative(repoRoot, wasmPath),
    assets,
    groupTotals: {
      app: {
        rawBytes: groupTotal("app", "rawBytes"),
        gzipBytes: groupTotal("app", "gzipBytes"),
        brotliBytes: groupTotal("app", "brotliBytes"),
      },
      runtime: {
        rawBytes: groupTotal("runtime", "rawBytes"),
        gzipBytes: groupTotal("runtime", "gzipBytes"),
        brotliBytes: groupTotal("runtime", "brotliBytes"),
      },
      assets: {
        rawBytes: groupTotal("assets", "rawBytes"),
        gzipBytes: groupTotal("assets", "gzipBytes"),
        brotliBytes: groupTotal("assets", "brotliBytes"),
      },
    },
    totals: {
      rawBytes: sum("rawBytes"),
      gzipBytes: sum("gzipBytes"),
      brotliBytes: sum("brotliBytes"),
    },
  };
}

export function printBundleTable(manifest) {
  const rows = [
    ["Asset", "Kind", "Group", "Raw", "Gzip", "Brotli"],
    ...manifest.assets.map(asset => [
      asset.name,
      asset.kind,
      asset.group,
      String(asset.rawBytes),
      String(asset.gzipBytes),
      String(asset.brotliBytes),
    ]),
    [
      "TOTAL",
      "",
      "",
      String(manifest.totals.rawBytes),
      String(manifest.totals.gzipBytes),
      String(manifest.totals.brotliBytes),
    ],
  ];
  const widths = rows[0].map((_, index) =>
    Math.max(...rows.map(row => row[index].length)),
  );
  for (const row of rows) {
    console.log(row.map((cell, index) => cell.padEnd(widths[index])).join("  "));
  }
}

export function cleanOutputDir(outDir) {
  const resolved = resolve(repoRoot, outDir);
  if (resolved === repoRoot || !relative(repoRoot, resolved)) {
    throw new Error("Refusing to use repository root as package output directory.");
  }
  rmSync(resolved, { recursive: true, force: true });
  mkdirSync(resolved, { recursive: true });
  return resolved;
}

export function copyFileEnsuringDir(source, destination) {
  mkdirSync(dirname(destination), { recursive: true });
  cpSync(source, destination);
}

export function copyDirectory(source, destination) {
  if (!existsSync(source)) {
    return false;
  }
  cpSync(source, destination, { recursive: true });
  return true;
}

export function writeCompressedSiblings(filePath) {
  const bytes = readFileSync(filePath);
  writeFileSync(`${filePath}.gz`, gzipSync(bytes));
  writeFileSync(`${filePath}.br`, brotliCompressSync(bytes));
}

export function rewriteIndexForPackage(indexHtml, wasmFileName) {
  let rewritten = indexHtml.replace(
    /from\s+["'][^"']*moui_web_renderer\/runtime\.js["']/,
    'from "./runtime.js"',
  );
  rewritten = rewritten.replace(
    /(["'])[^"']*_build\/wasm-gc\/[^"']*\.wasm\1/,
    `"./${wasmFileName}"`,
  );
  return rewritten;
}

export function rewriteRuntimeForPackage(runtimeSource) {
  return runtimeSource.replace(
    /from\s+["']\.\.\/moui\/backend\/web\/browser_runtime\.js["']/,
    'from "./browser_runtime.js"',
  );
}
