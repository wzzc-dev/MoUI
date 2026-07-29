#!/usr/bin/env node

/**
 * validate-renderer-provider-open-extension.mjs
 *
 * Enforce validator for the renderer provider open-extension property
 * (ADR 0019). Checks that:
 *
 * 1. No renderer identity branching exists in moui/core, moui/backend/host,
 *    or moui/runtime (non-composition-root) packages.
 * 2. Each renderer package (moui/render/skia, moui/render/wgpu, etc.)
 *    exports a create_*_provider function matching the RendererProvider
 *    contract.
 * 3. Provider capability reporting is registration-driven; removed static
 *    backend-matrix APIs may not remain in production code.
 * 4. No direct native selector remains anywhere in the repository.
 * 5. RendererProviderBinding remains the production composition contract.
 *
 * Current mode: **enforce** — exits with error 1 on violations.
 *
 * Usage:
 *   node scripts/validate-renderer-provider-open-extension.mjs
 *
 * Exit codes:
 *   0 = no violations
 *   1 = violations found
 */

import { existsSync, readFileSync, readdirSync, statSync } from "fs";
import { join, relative, resolve } from "path";

const REPO_ROOT = resolve(new URL(".", import.meta.url).pathname, "..");

// ---------------------------------------------------------------------------
// Utility: walk directory recursively, return .mbt file paths
// ---------------------------------------------------------------------------
function walkMbtFiles(dir, relativeTo = REPO_ROOT) {
  const results = [];
  const absDir = resolve(REPO_ROOT, dir);
  if (!existsSync(absDir)) return results;

  function walk(current) {
    const entries = readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(current, entry.name);
      if (entry.isDirectory()) {
        // skip hidden dirs and common build artifacts
        if (!entry.name.startsWith(".") && entry.name !== "_build" && entry.name !== "node_modules") {
          walk(fullPath);
        }
      } else if (entry.name.endsWith(".mbt")) {
        results.push(fullPath);
      }
    }
  }

  walk(absDir);
  return results;
}

// ---------------------------------------------------------------------------
// Allowlist: packages that MAY reference NativeGpuPlatform or
// RendererBackendKind in branching logic.
// ---------------------------------------------------------------------------
const SELECTION_ALLOWLIST_PREFIXES = [
  "moui/backend/macos/skia",
  "moui/backend/linux/skia",
  "moui/backend/windows/skia",
  "moui/backend/android/skia",
  "moui/backend/ios/skia",
  "moui/backend/harmonyos/skia",
  "moui/backend/macos/wgpu",
  "moui/backend/linux/wgpu",
  "moui/backend/windows/wgpu",
  "moui/backend/macos/sun",
  "moui/backend/linux/sun",
  "moui/backend/windows/sun",
  "moui/render/skia",
  "moui/render/wgpu",
  "moui/render/sun",
  "moui/render/canvas2d",
  "moui/render",
];

const SELECTION_ALLOWLIST_EXACT = [
  "moui/backend/host/host_rendering_test.mbt",
  "moui/render/native_gpu_selection_test.mbt",
];

// ---------------------------------------------------------------------------
// Check 1: No renderer identity branching in core/host/runtime
// ---------------------------------------------------------------------------
function checkIdentityBranching() {
  const violations = [];
  const restrictedPatterns = [
    /\bNativeGpuPlatform::\w+\b/,
  ];

  const restrictedDirs = ["moui/core", "moui/backend/host", "moui/runtime"];

  for (const dir of restrictedDirs) {
    const files = walkMbtFiles(dir);
    for (const file of files) {
      const relPath = relative(REPO_ROOT, file);
      const isAllowed =
        SELECTION_ALLOWLIST_PREFIXES.some((p) => relPath.startsWith(p)) ||
        SELECTION_ALLOWLIST_EXACT.some((a) => relPath === a);
      if (isAllowed) continue;

      const content = readFileSync(file, "utf-8");
      for (const pattern of restrictedPatterns) {
        if (pattern.test(content)) {
          const lines = content.split("\n");
          for (let i = 0; i < lines.length; i++) {
            if (pattern.test(lines[i])) {
              violations.push(
                `  ${relPath}:${i + 1}: found pattern ${pattern}`
              );
            }
          }
        }
      }
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// Check 2: Each renderer package exports create_*_provider
// ---------------------------------------------------------------------------
function checkProviderFactoryExports() {
  const violations = [];
  const rendererPackages = [
    {
      dir: "moui/render/skia",
      expected: ["create_skia_raster_provider", "create_skia_hybrid_provider"],
    },
    { dir: "moui/render/wgpu", expected: ["create_wgpu_provider"] },
    { dir: "moui/render/sun", expected: ["create_sun_provider"] },
    { dir: "moui/render/canvas2d", expected: ["create_canvas2d_provider"] },
    { dir: "moui/render/webgpu_adapter", expected: ["create_webgpu_provider"] },
  ];

  for (const pkg of rendererPackages) {
    const files = walkMbtFiles(pkg.dir);
    const allContent = files
      .map((f) => readFileSync(f, "utf-8"))
      .join("\n");

    for (const factoryName of pkg.expected) {
      if (!allContent.includes(factoryName)) {
        violations.push(`  ${pkg.dir}: missing pub fn ${factoryName}`);
      }
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// Check 3: No static capability matrix API remains in production code
// ---------------------------------------------------------------------------
function checkCentralMatrixCallers() {
  const violations = [];
  const forbidden = ["renderer_capability_backends", "renderer_backend_capabilities"];

  const files = walkMbtFiles(".");
  for (const file of files) {
    const relPath = relative(REPO_ROOT, file);
    const content = readFileSync(file, "utf-8");
    for (const symbol of forbidden) {
      if (content.includes(symbol)) {
        violations.push(`  ${relPath}: references removed static report API ${symbol}`);
      }
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// Check 4: No direct native selector references anywhere (functions deleted)
// ---------------------------------------------------------------------------
function checkPlatformSkiaProviderMigration() {
  const violations = [];
  const files = walkMbtFiles(".");
  const forbidden = ["select_native_renderer", "RendererProviderRegistry::select_native"];

  for (const file of files) {
    const relPath = relative(REPO_ROOT, file);
    const content = readFileSync(file, "utf-8");
    for (const symbol of forbidden) {
      if (content.includes(symbol)) {
        violations.push(`  ${relPath}: references removed selector ${symbol}`);
      }
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// Check 5: Binding contract remains the composition path
// ---------------------------------------------------------------------------
function checkBindingContract() {
  const providerContract = join(REPO_ROOT, "moui/render/provider_contract.mbt");
  const content = readFileSync(providerContract, "utf-8");
  const required = [
    "pub(all) struct RendererProviderBinding",
    "pub fn select_renderer_provider_binding",
    "pub fn renderer_provider_binding_providers",
  ];
  return required
    .filter((symbol) => !content.includes(symbol))
    .map((symbol) => `  moui/render/provider_contract.mbt: missing ${symbol}`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  console.log("# validate-renderer-provider-open-extension.mjs (enforce)");
  console.log();

  const identityViolations = checkIdentityBranching();
  const factoryViolations = checkProviderFactoryExports();
  const matrixViolations = checkCentralMatrixCallers();
  const migrationViolations = checkPlatformSkiaProviderMigration();
  const bindingViolations = checkBindingContract();

  let hasViolations = false;

  if (identityViolations.length > 0) {
    console.log("## [1] Renderer identity branching in core/host/runtime:");
    for (const v of identityViolations) console.log(v);
    console.log();
    hasViolations = true;
  } else {
    console.log("✅ No renderer identity branching in core/host/runtime");
    console.log();
  }

  if (factoryViolations.length > 0) {
    console.log("## [2] Missing RendererProvider factory exports:");
    for (const v of factoryViolations) console.log(v);
    console.log();
    hasViolations = true;
  } else {
    console.log("✅ All renderer packages export expected provider factories");
    console.log();
  }

  if (matrixViolations.length > 0) {
    console.log("## [3] Removed static capability report APIs:");
    for (const v of matrixViolations) console.log(v);
    console.log();
    hasViolations = true;
  } else {
    console.log("✅ No static capability report APIs remain");
    console.log();
  }

  if (migrationViolations.length > 0) {
    console.log("## [4] Removed native selector references:");
    for (const v of migrationViolations) console.log(v);
    console.log();
    hasViolations = true;
  } else {
    console.log("✅ No removed native selector references remain");
    console.log();
  }

  if (bindingViolations.length > 0) {
    console.log("## [5] RendererProviderBinding contract:");
    for (const v of bindingViolations) console.log(v);
    console.log();
    hasViolations = true;
  } else {
    console.log("✅ RendererProviderBinding composition contract is present");
    console.log();
  }

  if (hasViolations) {
    console.log("❌ Violations found (enforce mode).");
    process.exit(1);
  } else {
    console.log("✅ All checks passed.");
    process.exit(0);
  }
}

main();
