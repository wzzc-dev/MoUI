#!/usr/bin/env node
/**
 * Harness batch-1 structural invariants (docs/plans/active/harness-mechanize-invariants-batch1.md).
 *
 * Rules:
 *   P1  Thin platform entrypoints (examples/<name>/web_wasm and <platform>_skia)
 *   P2  No app-control constructors / View-enum creep in moui/core
 *   R3  Renderer mode selection via MOUI_SKIA_RENDERER / mobile configure / --renderer
 *   G1  Skills do not re-list full invariant tables
 *   G2  This tool supports --json {rule,ok,path,hint}[]
 *
 * A6/M5 are enforced by validate-window-dependency.mjs and validate-harmonyos-m5-shell.mjs.
 */

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const repoRoot = process.cwd();
const wantJson = process.argv.includes("--json");

const ENTRY_SUFFIXES = [
  "web_wasm",
  "macos_skia",
  "windows_skia",
  "linux_skia",
  "android_skia",
  "ios_skia",
  "harmonyos_skia",
];

const MOBILE_SUFFIXES = new Set(["android_skia", "ios_skia", "harmonyos_skia"]);

// Desktop/web boot wiring stays small; mobile embedded sessions need more ABI surface.
const MAX_LINES_DESKTOP = 320;
const MAX_LINES_MOBILE = 500;
const MAX_NON_TEST_MBT = 3;

const PRODUCT_LOGIC_PATTERNS = [
  { re: /^(?:pub\s+)?fn\s+update\b/m, label: "fn update" },
  { re: /^(?:pub\s+)?fn\s+view\b/m, label: "fn view" },
  { re: /^(?:pub\s+)?(?:struct|enum)\s+Model\b/m, label: "Model type" },
  { re: /^(?:pub\s+)?enum\s+Msg\b/m, label: "enum Msg" },
  { re: /^(?:pub\s+)?struct\s+Msg\b/m, label: "struct Msg" },
];

// Control-like public constructors that must live in moui/views, not moui/core.
const CORE_CONTROL_FNS = [
  "button",
  "checkbox",
  "toggle",
  "switch",
  "slider",
  "text_field",
  "textfield",
  "text_input",
  "radio",
  "picker",
  "menu_bar",
  "menu_item",
  "dialog",
  "alert",
  "sheet",
  "tab_view",
  "tabs",
  "navigation_stack",
  "navigation_view",
  "list_row",
  "table_view",
  "progress_bar",
  "progress_view",
  "scroll_view",
  "form",
  "section",
  "label",
  "image_view",
  "webview",
];

const DESKTOP_SKIA_PROVIDERS = [
  "moui/backend/macos/skia/macos_skia_provider.mbt",
  "moui/backend/windows/skia/windows_skia_provider.mbt",
  "moui/backend/linux/skia/linux_skia_provider.mbt",
];

const results = [];

function rel(path) {
  return path.split("\\").join("/");
}

function pushResult(rule, ok, path, hint) {
  results.push({ rule, ok, path: rel(path), hint: hint || "" });
}

function read(path) {
  return readFileSync(join(repoRoot, path), "utf8");
}

function listExampleEntrypoints() {
  const examplesRoot = join(repoRoot, "examples");
  const found = [];
  let examples;
  try {
    examples = readdirSync(examplesRoot);
  } catch {
    return found;
  }
  for (const name of examples) {
    const exDir = join(examplesRoot, name);
    try {
      if (!statSync(exDir).isDirectory()) continue;
    } catch {
      continue;
    }
    for (const suffix of ENTRY_SUFFIXES) {
      const entryDir = join(exDir, suffix);
      if (existsSync(entryDir) && statSync(entryDir).isDirectory()) {
        found.push({
          example: name,
          suffix,
          path: rel(join("examples", name, suffix)),
          abs: entryDir,
          mobile: MOBILE_SUFFIXES.has(suffix),
        });
      }
    }
  }
  return found;
}

function nonTestMbtFiles(entryAbs) {
  const files = [];
  const stack = [entryAbs];
  while (stack.length) {
    const dir = stack.pop();
    let entries;
    try {
      entries = readdirSync(dir);
    } catch {
      continue;
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
        if (name === "_build") continue;
        stack.push(full);
      } else if (
        name.endsWith(".mbt") &&
        !name.endsWith("_test.mbt") &&
        !name.endsWith("_wbtest.mbt")
      ) {
        files.push(full);
      }
    }
  }
  return files;
}

function checkP1() {
  const entries = listExampleEntrypoints();
  if (entries.length === 0) {
    pushResult(
      "P1",
      false,
      "examples",
      "no platform entry packages found. Fix: restore examples/*/app + thin entrypoints. See docs/invariants.md#P1",
    );
    return;
  }

  for (const entry of entries) {
    let failed = false;
    const appDir = join(repoRoot, "examples", entry.example, "app");
    const appFile = join(repoRoot, "examples", entry.example, "app.mbt");
    // Canonical: examples/<name>/app package. Allowed legacy/demo: root app.mbt
    // (e.g. agent_counter) when shared logic still lives outside the entrypoint.
    if (!existsSync(appDir) && !existsSync(appFile)) {
      failed = true;
      pushResult(
        "P1",
        false,
        entry.path,
        `missing examples/${entry.example}/app (or root app.mbt). Fix: keep product logic out of platform entrypoints. See docs/invariants.md#P1`,
      );
    }

    const mbtFiles = nonTestMbtFiles(entry.abs);
    if (mbtFiles.length === 0) {
      pushResult(
        "P1",
        false,
        entry.path,
        "entrypoint package has no non-test .mbt files. See docs/invariants.md#P1",
      );
      continue;
    }
    if (mbtFiles.length > MAX_NON_TEST_MBT) {
      failed = true;
      pushResult(
        "P1",
        false,
        entry.path,
        `too many non-test .mbt files (${mbtFiles.length} > ${MAX_NON_TEST_MBT}). Fix: move logic to examples/${entry.example}/app. See docs/invariants.md#P1`,
      );
    }

    let totalLines = 0;
    for (const file of mbtFiles) {
      const text = readFileSync(file, "utf8");
      totalLines += text.split(/\r?\n/).length;
      const fileRel = rel(relative(repoRoot, file));
      for (const pattern of PRODUCT_LOGIC_PATTERNS) {
        if (pattern.re.test(text)) {
          failed = true;
          pushResult(
            "P1",
            false,
            fileRel,
            `product logic pattern ${pattern.label} in platform entrypoint. Fix: move to examples/${entry.example}/app. See docs/invariants.md#P1`,
          );
        }
      }
    }

    const maxLines = entry.mobile ? MAX_LINES_MOBILE : MAX_LINES_DESKTOP;
    if (totalLines > maxLines) {
      failed = true;
      pushResult(
        "P1",
        false,
        entry.path,
        `entrypoint non-test lines ${totalLines} exceed ${maxLines} (${entry.mobile ? "mobile" : "desktop/web"} budget). Fix: move logic to examples/${entry.example}/app. See docs/invariants.md#P1`,
      );
    }
    if (!failed) {
      pushResult("P1", true, entry.path, "");
    }
  }
}

function checkP2() {
  const coreMbti = "moui/core/pkg.generated.mbti";
  const coreRoot = join(repoRoot, "moui/core");
  if (!existsSync(join(repoRoot, coreMbti))) {
    pushResult(
      "P2",
      false,
      coreMbti,
      "missing generated interface. Fix: run moon info for moui/core. See docs/invariants.md#P2",
    );
    return;
  }

  const mbti = read(coreMbti);
  if (/^(?:pub(?:\(all\))?\s+)?enum\s+View\b/m.test(mbti)) {
    pushResult(
      "P2",
      false,
      coreMbti,
      "public enum View in core is forbidden for app controls. Fix: keep opaque View + View::node; put controls in moui/views. See docs/invariants.md#P2",
    );
  }

  for (const name of CORE_CONTROL_FNS) {
    const re = new RegExp(String.raw`^pub\s+fn(?:\[[^\]]*\])?\s+${name}\b`, "m");
    if (re.test(mbti)) {
      pushResult(
        "P2",
        false,
        coreMbti,
        `core public control constructor pub fn ${name}. Fix: move control to moui/views via @core.View::node. See docs/invariants.md#P2`,
      );
    }
  }

  // Source-level belt: pub fn control names in core packages.
  const coreFiles = [];
  const stack = [coreRoot];
  while (stack.length) {
    const dir = stack.pop();
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      const st = statSync(full);
      if (st.isDirectory()) {
        if (name === "_build") continue;
        stack.push(full);
      } else if (name.endsWith(".mbt") && !name.includes("_test") && !name.includes("_wbtest")) {
        coreFiles.push(full);
      }
    }
  }

  for (const file of coreFiles) {
    const text = readFileSync(file, "utf8");
    const fileRel = rel(relative(repoRoot, file));
    if (/^pub(?:\(all\))?\s+enum\s+View\b/m.test(text)) {
      pushResult(
        "P2",
        false,
        fileRel,
        "pub enum View in core source. Fix: controls belong in moui/views. See docs/invariants.md#P2",
      );
    }
    for (const name of CORE_CONTROL_FNS) {
      const re = new RegExp(String.raw`^pub\s+fn(?:\[[^\]]*\])?\s+${name}\b`, "m");
      if (re.test(text)) {
        pushResult(
          "P2",
          false,
          fileRel,
          `pub fn ${name} in core. Fix: implement in moui/views with @core.View::node. See docs/invariants.md#P2`,
        );
      }
    }
  }

  if (!results.some(r => r.rule === "P2" && !r.ok)) {
    pushResult("P2", true, "moui/core", "");
  }
}

function checkR3() {
  for (const path of DESKTOP_SKIA_PROVIDERS) {
    if (!existsSync(join(repoRoot, path))) {
      pushResult(
        "R3",
        false,
        path,
        "missing desktop Skia provider. Fix: restore provider that reads MOUI_SKIA_RENDERER. See docs/invariants.md#R3",
      );
      continue;
    }
    const text = read(path);
    const hasEnv = text.includes("MOUI_SKIA_RENDERER");
    const hasParse =
      text.includes("NativeRendererMode::parse") || text.includes("select_native_renderer");
    if (!hasEnv || !hasParse) {
      pushResult(
        "R3",
        false,
        path,
        "desktop Skia provider must honor MOUI_SKIA_RENDERER (auto|skia-gpu|skia-raster) via NativeRendererMode/select_native_renderer. Fix: restore env-driven selection. See docs/invariants.md#R3",
      );
    } else {
      pushResult("R3", true, path, "");
    }
  }

  const mobileEntries = listExampleEntrypoints().filter(e => e.mobile);
  for (const entry of mobileEntries) {
    const mainPath = join(entry.path, "main.mbt");
    if (!existsSync(join(repoRoot, mainPath))) {
      pushResult(
        "R3",
        false,
        entry.path,
        "mobile entry missing main.mbt. See docs/invariants.md#R3",
      );
      continue;
    }
    const text = read(mainPath);
    const hasSelection =
      text.includes("mobile_renderer_selection") || text.includes("mobile_renderer_configure");
    const hasConfigure = text.includes("moui_mobile_renderer_configure");
    if (!hasSelection || !hasConfigure) {
      pushResult(
        "R3",
        false,
        mainPath,
        "mobile entry must expose renderer selection/configure (auto|skia-gpu|skia-raster path). Fix: wire @host.mobile_renderer_selection / moui_mobile_renderer_configure. See docs/invariants.md#R3",
      );
    } else {
      pushResult("R3", true, mainPath, "");
    }
  }

  const prepare = "moui/scripts/mobile/prepare-native-build.mjs";
  if (existsSync(join(repoRoot, prepare))) {
    const text = read(prepare);
    const ok =
      text.includes("--renderer") &&
      text.includes("auto") &&
      text.includes("skia-gpu") &&
      text.includes("skia-raster");
    pushResult(
      "R3",
      ok,
      prepare,
      ok
        ? ""
        : "prepare-native-build must accept --renderer auto|skia-gpu|skia-raster. See docs/invariants.md#R3",
    );
  } else {
    pushResult(
      "R3",
      false,
      prepare,
      "missing mobile prepare-native-build helper. See docs/invariants.md#R3",
    );
  }
}

function checkG1() {
  const skillRoots = ["skills", ".agents/skills"].map(p => join(repoRoot, p));
  const mdFiles = [];
  for (const root of skillRoots) {
    if (!existsSync(root)) continue;
    const stack = [root];
    while (stack.length) {
      const dir = stack.pop();
      let entries;
      try {
        entries = readdirSync(dir);
      } catch {
        continue;
      }
      for (const name of entries) {
        if (name === "node_modules" || name === ".git" || name === "_build") continue;
        const full = join(dir, name);
        let st;
        try {
          st = statSync(full);
        } catch {
          continue;
        }
        if (st.isDirectory()) stack.push(full);
        else if (name.endsWith(".md")) mdFiles.push(full);
      }
    }
  }

  const rowRe = /^\|\s*P[1-9]\s*\|/gm;
  let bad = 0;
  for (const file of mdFiles) {
    const text = readFileSync(file, "utf8");
    const fileRel = rel(relative(repoRoot, file));
    // Count P-rows; a single mention is ok, a table of ownership constraints is not.
    const matches = text.match(rowRe) || [];
    if (matches.length >= 3) {
      bad += 1;
      pushResult(
        "G1",
        false,
        fileRel,
        "skill re-lists invariant P-rows. Fix: link docs/invariants.md instead of copying the table. See docs/golden-principles.md",
      );
    }
  }
  if (bad === 0) {
    pushResult("G1", true, "skills/", `scanned ${mdFiles.length} skill markdown file(s)`);
  }
}

function main() {
  checkP1();
  checkP2();
  checkR3();
  checkG1();

  const failures = results.filter(r => !r.ok);
  // G2: always emit machine-readable shape when requested.
  if (wantJson) {
    process.stdout.write(
      `${JSON.stringify(
        {
          schemaVersion: 1,
          tool: "validate-harness-batch1",
          rules: ["P1", "P2", "R3", "G1"],
          results,
          failures,
        },
        null,
        2,
      )}\n`,
    );
  } else if (failures.length === 0) {
    const okCounts = results.filter(r => r.ok).length;
    console.log(
      `validate-harness-batch1: OK (${okCounts} checks; rules P1/P2/R3/G1; JSON via --json)`,
    );
  } else {
    console.error("validate-harness-batch1: FAIL");
    for (const item of failures) {
      console.error(`\n[${item.rule}] ${item.path}\n  ${item.hint}`);
    }
  }

  process.exit(failures.length === 0 ? 0 : 1);
}

main();
