#!/usr/bin/env node

/**
 * test-validate-architecture-validators.mjs
 *
 * Minimal self-tests for the three architecture validators that were
 * previously orphaned (documented as daily steps but present in no profile
 * and covered by no tests):
 *
 *   1. scripts/validate-core-theme-no-control-surface.mjs
 *   2. scripts/validate-host-import-baseline.mjs
 *   3. scripts/validate-renderer-provider-open-extension.mjs
 *
 * Each test runs a copy of the validator from inside a scratch repo fixture
 * (validators resolve the repo root from import.meta.url, so the script must
 * live under the fixture's scripts/ dir), asserts pass on the clean fixture
 * and fail on a controlled mutation, then restores.
 */

import { cpSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..");
const tmpRoot = mkdtempSync(join(tmpdir(), "moui-arch-validators-"));

const fixtureDir = "moui";
const copyDir = (dir) => {
  cpSync(join(repoRoot, dir), join(tmpRoot, dir), { recursive: true });
};

// Minimal repo skeleton the validators read.
copyDir("moui/core");
copyDir("moui/backend/host");
copyDir("moui/render");
copyDir("moui/runtime");
// host baseline only reads host/moon.pkg; provider validator walks render.
mkdirSync(join(tmpRoot, "scripts"), { recursive: true });
for (const script of [
  "validate-core-theme-no-control-surface.mjs",
  "validate-host-import-baseline.mjs",
  "validate-renderer-provider-open-extension.mjs",
]) {
  cpSync(join(repoRoot, "scripts", script), join(tmpRoot, "scripts", script));
}

const runValidator = (script) =>
  spawnSync(process.execPath, [join(tmpRoot, "scripts", script)], {
    encoding: "utf8",
  });

const expectPass = (label, script) => {
  const r = runValidator(script);
  if (r.status !== 0) {
    console.error(`${label}: expected validator to pass`);
    console.error(r.stderr || r.stdout);
    process.exit(1);
  }
};

const expectFail = (label, script, expectedMessage) => {
  const r = runValidator(script);
  if (r.status === 0) {
    console.error(`${label}: expected validator to fail`);
    process.exit(1);
  }
  if (expectedMessage && !`${r.stderr}${r.stdout}`.includes(expectedMessage)) {
    console.error(
      `${label}: expected output to include '${expectedMessage}'`,
    );
    console.error(r.stderr || r.stdout);
    process.exit(1);
  }
};

// --- 1. core theme no-control-surface -------------------------------------
expectPass("core-theme: clean fixture passes", "validate-core-theme-no-control-surface.mjs");

const coreMbti = join(tmpRoot, "moui/core/pkg.generated.mbti");
const coreText = readFileSync(coreMbti, "utf8");
writeFileSync(coreMbti, coreText + "\npub(all) struct ButtonTheme { }\n");
expectFail(
  "core-theme: injected ButtonTheme fails",
  "validate-core-theme-no-control-surface.mjs",
  "ButtonTheme",
);
writeFileSync(coreMbti, coreText);

// --- 2. host import baseline ----------------------------------------------
expectPass("host-import: clean fixture passes", "validate-host-import-baseline.mjs");

const hostPkg = join(tmpRoot, "moui/backend/host/moon.pkg");
const hostText = readFileSync(hostPkg, "utf8");
writeFileSync(
  hostPkg,
  hostText.replace(
    "import {\n",
    'import {\n  "wzzc-dev/moui/runtime",\n',
  ),
);
expectFail(
  "host-import: injected runtime import fails",
  "validate-host-import-baseline.mjs",
  "moui/runtime",
);
writeFileSync(hostPkg, hostText);

// --- 3. renderer provider open-extension ----------------------------------
expectPass("provider-open-extension: clean fixture passes", "validate-renderer-provider-open-extension.mjs");

// Inject a direct native selector reference into runtime (forbidden).
const runtimeMbt = join(tmpRoot, "moui/runtime/runtime.mbt");
const runtimeText = readFileSync(runtimeMbt, "utf8");
writeFileSync(runtimeMbt, runtimeText + "\n// select_native_renderer\n");
expectFail(
  "provider-open-extension: injected native selector fails",
  "validate-renderer-provider-open-extension.mjs",
  "select_native_renderer",
);

console.log("architecture validator tests: ok");
