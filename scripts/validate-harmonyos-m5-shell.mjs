#!/usr/bin/env node
/**
 * docs/invariants.md#M5 — HarmonyOS managed shell static contract.
 *
 * XComponent (native callbacks) is the only pointer/surface/resize/detach source.
 * ArkTS must not restore .onTouch / onAreaChange surface paths on the root shell.
 *
 * Richer suite: node --test moui/mobile/harmonyos/tests/validate-managed-shell.mjs
 */

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const repoRoot = process.cwd();
const templateRoot = join(repoRoot, "moui/mobile/harmonyos/template");
const bridgePath = "moui/mobile/harmonyos/src/main/cpp/moui_mobile_harmonyos_napi.cpp";
const rootEtsPath =
  "moui/mobile/harmonyos/template/entry/src/main/ets/moui/MoUIRoot.ets";

const FORBIDDEN_IN_TEMPLATE_ETS = [
  ".onTouch",
  "onAreaChange",
  "attachSurface",
  "dispatchPointer",
  "detachSurface",
];

const REQUIRED_IN_ROOT = [
  "libraryname: 'moui_mobile_harmonyos'",
  "XComponent",
  "displaySync",
];

const REQUIRED_IN_BRIDGE = [
  "OH_NativeXComponent_RegisterCallback",
  "source=native-xcomponent",
];

const FORBIDDEN_IN_BRIDGE = [
  "napi_attach_surface",
  "napi_dispatch_pointer",
  "napi_resize",
  "MOUI_MOBILE_ATTACH_SURFACE",
];

function walkFiles(dir, suffix, out = []) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return out;
  }
  for (const name of entries) {
    const full = join(dir, name);
    let st;
    try {
      st = statSync(full);
    } catch {
      continue;
    }
    if (st.isDirectory()) {
      walkFiles(full, suffix, out);
    } else if (name.endsWith(suffix)) {
      out.push(full);
    }
  }
  return out;
}

function readRepo(rel) {
  return readFileSync(join(repoRoot, rel), "utf8");
}

function main() {
  const failures = [];
  const json = process.argv.includes("--json");

  let root;
  try {
    root = readRepo(rootEtsPath);
  } catch (error) {
    failures.push({
      rule: "M5",
      ok: false,
      path: rootEtsPath,
      hint: `missing canonical shell root: ${error.message}. Fix: restore managed shell template. See docs/invariants.md#M5`,
    });
  }

  if (root !== undefined) {
    for (const token of REQUIRED_IN_ROOT) {
      if (!root.includes(token)) {
        failures.push({
          rule: "M5",
          ok: false,
          path: rootEtsPath,
          hint: `missing required token ${JSON.stringify(token)}. Fix: keep XComponent + displaySync managed shell. See docs/invariants.md#M5`,
        });
      }
    }
  }

  const etsFiles = walkFiles(templateRoot, ".ets");
  if (etsFiles.length === 0) {
    failures.push({
      rule: "M5",
      ok: false,
      path: "moui/mobile/harmonyos/template",
      hint: "no .ets files under managed shell template. Fix: restore moui/mobile/harmonyos/template. See docs/invariants.md#M5",
    });
  }

  for (const full of etsFiles) {
    const rel = relative(repoRoot, full).split("\\").join("/");
    const text = readFileSync(full, "utf8");
    for (const token of FORBIDDEN_IN_TEMPLATE_ETS) {
      if (text.includes(token)) {
        failures.push({
          rule: "M5",
          ok: false,
          path: rel,
          hint: `forbidden ${JSON.stringify(token)}. Fix: use native XComponent callbacks only for surface/pointer/resize/detach; do not restore ArkTS .onTouch paths. See docs/invariants.md#M5`,
        });
      }
    }
  }

  let bridge;
  try {
    bridge = readRepo(bridgePath);
  } catch (error) {
    failures.push({
      rule: "M5",
      ok: false,
      path: bridgePath,
      hint: `missing NAPI bridge: ${error.message}. See docs/invariants.md#M5`,
    });
  }

  if (bridge !== undefined) {
    for (const token of REQUIRED_IN_BRIDGE) {
      if (!bridge.includes(token)) {
        failures.push({
          rule: "M5",
          ok: false,
          path: bridgePath,
          hint: `missing required token ${JSON.stringify(token)}. Fix: register OH_NativeXComponent callbacks and log source=native-xcomponent. See docs/invariants.md#M5`,
        });
      }
    }
    for (const token of FORBIDDEN_IN_BRIDGE) {
      if (bridge.includes(token)) {
        failures.push({
          rule: "M5",
          ok: false,
          path: bridgePath,
          hint: `forbidden ${JSON.stringify(token)}. Fix: do not reintroduce JS-driven attach/pointer/resize NAPI entrypoints. See docs/invariants.md#M5`,
        });
      }
    }
  }

  if (json) {
    const report = failures.length === 0
      ? [{ rule: "M5", ok: true, path: "moui/mobile/harmonyos", hint: "" }]
      : failures;
    process.stdout.write(`${JSON.stringify({ schemaVersion: 1, failures: report.filter(r => !r.ok), results: report }, null, 2)}\n`);
  } else if (failures.length === 0) {
    console.log(
      `validate-harmonyos-m5-shell: OK (scanned ${etsFiles.length} template .ets file(s); XComponent-only contract)`,
    );
  } else {
    console.error("validate-harmonyos-m5-shell: FAIL");
    for (const item of failures) {
      console.error(`\n[${item.rule}] ${item.path}\n  ${item.hint}`);
    }
  }

  process.exit(failures.length === 0 ? 0 : 1);
}

main();
