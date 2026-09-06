#!/usr/bin/env node

/**
 * validate-renderer-provider-open-extension.mjs
 *
 * Enforce validator for the renderer provider open-extension property
 * (ADR 0019). Checks that:
 *
 * 1. No renderer identity branching exists in moui/core, moui/backend,
 *    or moui/runtime (non-composition-root) packages.
 * 2. Each renderer package exports its public RendererProvider constructors.
 * 3. Provider capability reporting is registration-driven; removed static
 *    backend-matrix APIs may not remain in production code.
 * 4. No direct native selector remains anywhere in the repository.
 * 5. RendererProvider and RendererSession remain the only production
 *    provider/session composition contract.
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
  "moui_skia_renderer",
  "moui_wgpu_renderer",
  "moui_sun_renderer",
  "moui_web_renderer/canvas2d",
  "moui/render",
];

const SELECTION_ALLOWLIST_EXACT = [];

// ---------------------------------------------------------------------------
// Check 1: No renderer identity branching in core/host/runtime
// ---------------------------------------------------------------------------
function checkIdentityBranching() {
  const violations = [];
  const restrictedPatterns = [
    /\bNativeGpuPlatform::\w+\b/,
    // RendererBackendKind is diagnostic metadata only (docs/invariants.md):
    // core/host/runtime must not branch on it. Renderer identity and
    // selection live in RendererProvider.id / negotiate.
    /\bRendererBackendKind::\w+\b/,
  ];

  const restrictedDirs = ["moui/core", "moui/backend", "moui/runtime"];

  for (const dir of restrictedDirs) {
    const files = walkMbtFiles(dir);
    for (const file of files) {
      const relPath = relative(REPO_ROOT, file);
      if (/(?:_test|_wbtest)\.mbt$/.test(relPath)) continue;
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
// Check 2: Each catalogued renderer module exports a provider factory
// Derived from checks/release-modules.json (role "renderer") so a new
// renderer module is covered automatically — the open-extension E7 contract
// (ADR 0007): adding a renderer must not require editing this validator.
// ---------------------------------------------------------------------------
function rendererModuleDirectories() {
  const catalog = JSON.parse(
    readFileSync(join(REPO_ROOT, "checks", "release-modules.json"), "utf-8"),
  );
  return catalog.modules
    .filter((module) => module.role === "renderer")
    .map((module) => module.directory);
}

function checkProviderFactoryExports() {
  const violations = [];
  for (const dir of rendererModuleDirectories()) {
    const files = walkMbtFiles(dir);
    const allContent = files
      .map((f) => readFileSync(f, "utf-8"))
      .join("\n");
    const exportsProviderFactory =
      /pub fn\s+\w+\s*\([^)]*\)\s*->\s*[^{\n]*RendererProvider/.test(
        allContent,
      );
    if (!exportsProviderFactory) {
      violations.push(
        `  ${dir}: no pub fn returning @render.RendererProvider (every renderer module must export a provider factory)`,
      );
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
// Check 5: Provider/session contract remains the composition path
// ---------------------------------------------------------------------------
function checkBindingContract() {
  const providerContract = join(REPO_ROOT, "moui/render/provider_contract.mbt");
  const providerSelection = join(
    REPO_ROOT,
    "moui/render/common/provider_selection.mbt",
  );
  const sessionContract = join(REPO_ROOT, "moui/render/renderer_session.mbt");
  const contractContent =
    readFileSync(providerContract, "utf-8") +
    "\n" +
    readFileSync(sessionContract, "utf-8");
  const selectionContent = readFileSync(providerSelection, "utf-8");
  const contractRequired = [
    "pub(all) struct RendererProvider",
    "pub(all) enum RendererBindResult",
    "pub struct RendererSession",
  ];
  const selectionRequired = [
    "pub struct RendererProviderRegistry",
    "pub fn resolve_renderer",
  ];
  return [
    ...contractRequired
      .filter((symbol) => !contractContent.includes(symbol))
      .map((symbol) => `  moui/render/provider_contract.mbt: missing ${symbol}`),
    ...selectionRequired
      .filter((symbol) => !selectionContent.includes(symbol))
      .map(
        (symbol) =>
          `  moui/render/common/provider_selection.mbt: missing ${symbol}`,
      ),
  ];
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
    console.log("## [5] RendererProvider/RendererSession contract:");
    for (const v of bindingViolations) console.log(v);
    console.log();
    hasViolations = true;
  } else {
    console.log("✅ RendererProvider/RendererSession composition contract is present");
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
