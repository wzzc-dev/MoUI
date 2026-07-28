#!/usr/bin/env node

/**
 * validate-renderer-provider-open-extension.mjs
 *
 * Report-only validator for the renderer provider open-extension property
 * (ADR 0019). Checks that:
 *
 * 1. No renderer identity branching exists in moui/core, moui/backend/host,
 *    or moui/runtime (non-composition-root) packages.
 * 2. Each renderer package (moui/render/skia, moui/render/wgpu, etc.)
 *    exports a create_*_provider function matching the RendererProvider
 *    contract.
 * 3. The central selection matrix (native_gpu_selection.mbt) and central
 *    capability matrix (capabilities_backend_matrix.mbt) have no NEW
 *    callers beyond the allowlist.
 *
 * Current mode: **report-only** — prints violations but does not exit
 * with an error. Switch to enforcement after Phase E migration completes.
 *
 * Usage:
 *   node scripts/validate-renderer-provider-open-extension.mjs
 *
 * Exit codes (future enforcement):
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
// Allowlist: packages that MAY reference select_native_renderer,
// NativeGpuPlatform, or RendererBackendKind in branching logic.
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
// Allowlist: packages that reference renderer_capability_backends
// ---------------------------------------------------------------------------
const CAPABILITY_ALLOWLIST_EXACT = [
  "moui/render/capabilities_test.mbt",
  "moui/render/capabilities_backend_matrix.mbt",
  "examples/showcase/app/diagnostics/components.mbt",
];

// ---------------------------------------------------------------------------
// Check 1: No renderer identity branching in core/host/runtime
// ---------------------------------------------------------------------------
function checkIdentityBranching() {
  const violations = [];
  const restrictedPatterns = [
    /select_native_renderer\b/,
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
// Check 3: No NEW callers of central matrix functions beyond allowlist
// ---------------------------------------------------------------------------
function checkCentralMatrixCallers() {
  const violations = [];

  // walk the entire repo
  const files = walkMbtFiles(".");
  for (const file of files) {
    const relPath = relative(REPO_ROOT, file);
    const isAllowed = CAPABILITY_ALLOWLIST_EXACT.some((a) => relPath === a);
    if (isAllowed) continue;

    const content = readFileSync(file, "utf-8");
    if (content.includes("renderer_capability_backends")) {
      violations.push(
        `  ${relPath}: references renderer_capability_backends outside allowlist`
      );
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  console.log("# validate-renderer-provider-open-extension.mjs (report-only)");
  console.log();

  const identityViolations = checkIdentityBranching();
  const factoryViolations = checkProviderFactoryExports();
  const matrixViolations = checkCentralMatrixCallers();

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
    console.log("## [3] New central matrix callers outside allowlist:");
    for (const v of matrixViolations) console.log(v);
    console.log();
    hasViolations = true;
  } else {
    console.log("✅ No new central matrix callers outside allowlist");
    console.log();
  }

  if (hasViolations) {
    console.log("⚠️  Violations found (report-only mode — not enforcing).");
    process.exit(0);
  } else {
    console.log("✅ All checks passed.");
    process.exit(0);
  }
}

main();
