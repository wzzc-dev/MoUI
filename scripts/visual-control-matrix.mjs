#!/usr/bin/env node

// Control-state matrix gate.
//
// Runs the native offscreen renderer in moui_tests/visual_matrix, encodes one
// PNG per cell for review, and fails when an expected state paints exactly
// like the resting state (`missing_states`) or a control paints nothing
// (`blank`). The report is machine-readable; PNGs land next to it.
//
// Usage:
//   node scripts/visual-control-matrix.mjs [--out DIR] [--keep-rgba]
import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { encodePng8 } from "./lib/png-rgba.mjs";
import { repoRoot } from "./lib/window-dependency.mjs";

const usage = () => {
  console.error(
    "Usage: node scripts/visual-control-matrix.mjs [--out DIR] [--keep-rgba] [--renderer auto|sun|skia]",
  );
};

let outDir = resolve(repoRoot, "artifacts/visual-matrix");
let keepRgba = false;
let renderer = "auto";
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--out") {
    outDir = resolve(repoRoot, args[index + 1] ?? "");
    index += 1;
  } else if (args[index] === "--keep-rgba") {
    keepRgba = true;
  } else if (args[index] === "--renderer") {
    renderer = args[index + 1] ?? "auto";
    index += 1;
  } else if (args[index] === "--help" || args[index] === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${args[index]}`);
    usage();
    process.exit(2);
  }
}

mkdirSync(outDir, { recursive: true });
for (const entry of ["report.json"]) {
  try {
    rmSync(join(outDir, entry));
  } catch {
    // first run
  }
}

const run = spawnSync(
  "moon",
  [
    "-C",
    "moui_tests",
    "run",
    "visual_matrix",
    "--target",
    "native",
    "--",
    "--out",
    outDir,
    "--renderer",
    renderer,
  ],
  { cwd: repoRoot, stdio: "inherit", shell: false },
);
if (run.error) {
  console.error(`visual-control-matrix: ${run.error.message}`);
  process.exit(1);
}
if (run.status !== 0) {
  // The tool exits non-zero when the matrix itself has missing states; the
  // report still exists, so keep validating it below for a useful message.
  if (!readFileSafe()) {
    process.exit(run.status ?? 1);
  }
}

function readFileSafe() {
  try {
    return readFileSync(join(outDir, "report.json"), "utf8");
  } catch {
    return null;
  }
}

const rawReport = readFileSafe();
if (!rawReport) {
  console.error("visual-control-matrix: report.json was not written");
  process.exit(1);
}
const report = JSON.parse(rawReport);

const problems = [];
if (report.schemaVersion !== 1) {
  problems.push(`unexpected report schemaVersion ${report.schemaVersion}`);
}
const controls = report.controls ?? [];
const states = report.states ?? [];
if (controls.length === 0 || states.length === 0) {
  problems.push("report has no controls or states");
}
const cells = new Map();
for (const entry of report.entries ?? []) {
  cells.set(`${entry.control}/${entry.scheme}/${entry.state}`, entry);
  if (entry.blank) {
    problems.push(`${entry.control}/${entry.scheme}/${entry.state} painted nothing`);
  }
}
for (const control of controls) {
  for (const scheme of ["light", "dark"]) {
    for (const state of states) {
      if (!cells.has(`${control}/${scheme}/${state}`)) {
        problems.push(`missing cell ${control}/${scheme}/${state}`);
      }
    }
  }
}
for (const id of report.missing_states ?? []) {
  problems.push(`missing state style: ${id}`);
}
const transitions = report.transitions ?? [];
for (const entry of transitions) {
  const id = `${entry.control}/${entry.scheme}/${entry.state}`;
  if (entry.expected && !entry.animated) {
    problems.push(`missing hover/press transition: ${id}`);
  }
  if (entry.expected && !entry.reducedSnaps) {
    problems.push(`reduced motion does not snap: ${id}`);
  }
}
for (const id of report.missing_transitions ?? []) {
  problems.push(`missing hover/press transition: ${id}`);
}

let encoded = 0;
for (const entry of report.entries ?? []) {
  const rgbaPath = join(outDir, entry.file);
  let pixels;
  try {
    pixels = readFileSync(rgbaPath);
  } catch (error) {
    problems.push(`cannot read ${entry.file}: ${error.message}`);
    continue;
  }
  const png = encodePng8({
    width: entry.width,
    height: entry.height,
    rowBytes: entry.rowBytes,
    pixels,
  });
  const pngPath = join(outDir, entry.file.replace(/\.rgba$/, ".png"));
  writeFileSync(pngPath, png);
  encoded += 1;
  if (!keepRgba) {
    rmSync(rgbaPath);
  }
}

if (problems.length > 0) {
  console.error("visual-control-matrix: FAIL");
  for (const problem of problems) {
    console.error(`  - ${problem}`);
  }
  console.error(`artifacts: ${outDir}`);
  process.exit(1);
}

console.log(
  `visual control matrix passed: ${controls.length} controls × ${states.length} states × 2 schemes (${encoded} PNGs); ${transitions.length} transitions`,
);
console.log(`artifacts: ${outDir}`);
