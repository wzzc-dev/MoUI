#!/usr/bin/env node

/// validate-host-import-baseline.mjs
///
/// Enforces ADR 0018: `moui/backend` imports only platform-neutral host
/// contracts. The package must NOT import `moui/runtime` or `moui/render` in
/// its production (non-test) import section.
///
/// Mechanizable: scans `moui/backend/moon.pkg` for forbidden dependency
/// lines in the production import block.

import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const hostPkgPath = resolve(repoRoot, "moui/backend/moon.pkg");

if (!existsSync(hostPkgPath)) {
  console.error(
    `validate-host-import-baseline: missing ${hostPkgPath}`,
  );
  process.exit(1);
}

const content = readFileSync(hostPkgPath, "utf8");

/// Parse the moon.pkg file into import blocks. Each `import { ... }` block
/// optionally carries a `for "test"` / `for "wbtest"` suffix. Only blocks
/// WITHOUT such a suffix are production imports; `for "test"`/`for "wbtest"`
/// blocks are test-only and allowed to import runtime/render.
///
/// Block-level regex: captures the body of each import block and its optional
/// `for "..."` target. This avoids the line-scan bug where `import {` lines
/// inside a `for "test"` block get misclassified as production imports.
const blockRegex = /import\s+\{([^}]*)\}(?:\s+for\s+"(test|wbtest)")?/g;
let productionBlock = "";
let match;
while ((match = blockRegex.exec(content)) !== null) {
  const body = match[1];
  const target = match[2]; // undefined | "test" | "wbtest"
  if (target === undefined) {
    productionBlock += body + "\n";
  }
}

const forbiddenPatterns = [
  { pattern: /wzzc-dev\/moui\/runtime/, name: "moui/runtime" },
  { pattern: /wzzc-dev\/moui\/render/, name: "moui/render" },
];

const violations = [];
for (const { pattern, name } of forbiddenPatterns) {
  if (pattern.test(productionBlock)) {
    violations.push(name);
  }
}

if (violations.length > 0) {
  console.error(
    `\nvalidate-host-import-baseline: moui/backend/moon.pkg production section imports forbidden packages (ADR 0018):`,
  );
  for (const name of violations) {
    console.error(`  - ${name}`);
  }
  console.error(
    `\nHost contracts must not depend on runtime or render implementation.` +
    `\nMove runtime orchestration to moui/runtime and render glue to moui/render.` +
    `\nTest-only imports are OK (for "test" / for "wbtest").`,
  );
  process.exit(1);
}

console.log(
  `validate-host-import-baseline: ok (backend production imports are host-contract-safe)`,
);
