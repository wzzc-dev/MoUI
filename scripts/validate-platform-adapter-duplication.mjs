// ---------------------------------------------------------------------------
// validate-platform-adapter-duplication.mjs — Report-only validation of
// platform adapter duplication budget (ADR 0020).
//
// Checks:
// 1. shared_adapter package exists and exposes expected public symbols
// 2. No platform backend reimplements shared helpers (warns only)
// 3. Budget baseline file is well-formed
// ---------------------------------------------------------------------------
import { readFileSync, readdirSync, existsSync, statSync } from "fs";
import { join } from "path";

const ROOT = new URL("..", import.meta.url).pathname;
const BASELINE = `${ROOT}/checks/platform-adapter-duplication-baseline.json`;
const SHARED_ADAPTER = `${ROOT}/moui/backend/shared_adapter`;

const PASS = "✓";
const WARN = "⚠";
const FAIL = "✗";

let exitCode = 0;

function fail(label, msg) {
  console.error(`  ${FAIL} ${label}: ${msg}`);
  exitCode = 1;
}

function warn(label, msg) {
  console.log(`  ${WARN} ${label}: ${msg}`);
}

function pass(label, msg) {
  console.log(`  ${PASS} ${label}: ${msg || "ok"}`);
}

// ---- Check 1: shared_adapter package exists ----
console.log("\n[Check 1] shared_adapter package presence");

if (!existsSync(SHARED_ADAPTER)) {
  fail("package", `directory not found: ${SHARED_ADAPTER}`);
} else {
  pass("package", "moui/backend/shared_adapter exists");
}

if (!existsSync(`${SHARED_ADAPTER}/moon.pkg`)) {
  fail("moon.pkg", "moon.pkg not found");
} else {
  pass("moon.pkg", "found");
}

// ---- Check 2: shared_adapter public symbols ----
console.log("\n[Check 2] shared_adapter public symbols");

const expectedSymbols = [
  { file: "window_event_transformer.mbt", symbols: ["TransformedWindowEvent", "transform_cross_platform_event", "make_surface_metrics", "normalize_pointer_position"] },
  { file: "platform_capability.mbt", symbols: ["PlatformCapabilities"] },
];

for (const mod of expectedSymbols) {
  const filePath = `${SHARED_ADAPTER}/${mod.file}`;
  if (!existsSync(filePath)) {
    fail("file", `missing: ${mod.file}`);
    continue;
  }
  const content = readFileSync(filePath, "utf-8");
  for (const sym of mod.symbols) {
    // Check for pub(all) or pub fn declarations
    const declPatterns = [`pub(all) enum ${sym}`, `pub(all) struct ${sym}`, `pub fn ${sym}`];
    if (declPatterns.some(p => content.includes(p))) {
      pass(`${mod.file} :: ${sym}`);
    } else {
      warn(`${mod.file} :: ${sym}`, `public symbol "${sym}" not found — may be private or renamed`);
    }
  }
}

// ---- Check 3: Budget baseline ----
console.log("\n[Check 3] Duplication budget baseline");

if (!existsSync(BASELINE)) {
  fail("baseline", `missing: ${BASELINE}`);
} else {
  try {
    const raw = readFileSync(BASELINE, "utf-8");
    const baseline = JSON.parse(raw);
    if (!baseline.schemaVersion || !baseline.budget) {
      fail("baseline", "malformed — missing schemaVersion or budget");
    } else {
      pass("baseline", `schemaVersion=${baseline.schemaVersion}, allowlist entries=${baseline.budget.allowlist.length}`);
      if (baseline.budget.allowlist.some(e => !e.pattern || !e.reason)) {
        warn("baseline", "some allowlist entries missing pattern or reason");
      }
      if (baseline.budget.initialExtraction) {
        pass("initialExtraction", `shared modules=${baseline.budget.initialExtraction.shared_adapter_modules.length}, lines=${baseline.budget.initialExtraction.sharedLogicLines}`);
      }
    }
  } catch (e) {
    fail("baseline", `parse error: ${e.message}`);
  }
}

// ---- Check 4: No direct reimplementations (soft) ----
console.log("\n[Check 4] Soft scan for reimplemented shared helpers in platforms");

const sharedHelpers = [
  "make_surface_metrics",
  "normalize_pointer_position",
];

const platformDirs = [
  "moui/backend/macos",
  "moui/backend/linux",
  "moui/backend/windows",
  "moui/backend/web",
  "moui/backend/android",
  "moui/backend/ios",
  "moui/backend/harmonyos",
];

let reimplFound = false;
for (const dir of platformDirs) {
  const platformPath = `${ROOT}/${dir}`;
  if (!existsSync(platformPath) || !statSync(platformPath).isDirectory()) {
    continue;
  }
  const files = readdirSync(platformPath).filter(f => f.endsWith(".mbt"));
  for (const file of files) {
    const filePath = join(platformPath, file);
    const content = readFileSync(filePath, "utf-8");
    for (const helper of sharedHelpers) {
      // Look for a def site — redefinition is `pub fn helper(...`
      if (content.includes(`pub fn ${helper}`)) {
        warn(`${dir}/${file}`, `redefines shared helper "${helper}" — should use shared_adapter version`);
        reimplFound = true;
      }
    }
  }
}

if (!reimplFound) {
  pass("reimplementations", "no platform backends redefine shared helpers");
}

// ---- Summary ----
console.log("");
if (exitCode === 0) {
  console.log("All checks passed (report-only, exit 0).");
} else {
  console.log(`Some checks failed (exit ${exitCode}).`);
}
console.log(`\nBudget baseline: ${BASELINE}`);
console.log("Note: This is a report-only validator. Failures do not block CI.");
process.exit(0); // Always exit 0 — report-only
