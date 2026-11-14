#!/usr/bin/env node

// Per-control preview sheets for `docs/view-catalog.md`.
//
// Reuses the control-state matrix (artifacts/visual-matrix/report.json + the
// raw RGBA cells), composes one sheet per control (top row: light, bottom row:
// dark; left-to-right: default, hover, pressed, focused, disabled), and writes
// it to docs/assets/controls/<control>.png.
//
// Usage:
//   node scripts/generate-control-previews.mjs            # write the sheets
//   node scripts/generate-control-previews.mjs --check    # fail on drift
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { decodePng8, encodePng8 } from "./lib/png-rgba.mjs";
import { repoRoot } from "./lib/window-dependency.mjs";

const usage = () => {
  console.error(
    "Usage: node scripts/generate-control-previews.mjs [--check] [--out DIR] [--matrix-out DIR] [--renderer skia|sun]",
  );
};

let check = false;
let renderer = "skia";
let outDir = resolve(repoRoot, "docs/assets/controls");
let matrixOut = resolve(repoRoot, "artifacts/visual-matrix");
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--check") {
    check = true;
  } else if (args[index] === "--out") {
    outDir = resolve(repoRoot, args[index + 1] ?? "");
    index += 1;
  } else if (args[index] === "--renderer") {
    renderer = args[index + 1] ?? "skia";
    index += 1;
  } else if (args[index] === "--matrix-out") {
    matrixOut = resolve(repoRoot, args[index + 1] ?? "");
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

const matrix = spawnSync(
  process.execPath,
  [
    join(repoRoot, "scripts/visual-control-matrix.mjs"),
    "--out",
    matrixOut,
    "--keep-rgba",
    "--renderer",
    renderer,
  ],
  { cwd: repoRoot, encoding: "utf8", shell: false },
);
const matrixOutput = `${matrix.stdout ?? ""}\n${matrix.stderr ?? ""}`;
const skiaUnavailable = matrixOutput.includes("skia renderer unavailable");
if (matrix.status !== 0) {
  if (skiaUnavailable) {
    if (check) {
      // Committed sheets are Skia-rendered. Hosts without Skia (the `visual`
      // profile disables the prebuild) cannot reproduce them; the matrix gate
      // still runs separately, so skip the preview comparison instead of
      // failing every CI run.
      console.log(
        "control previews: skipped (Skia renderer unavailable on this host)",
      );
      process.exit(0);
    }
    console.error(
      "generate-control-previews: Skia is required to write the committed sheets",
    );
    process.exit(1);
  }
  if (matrix.stdout) process.stdout.write(matrix.stdout);
  if (matrix.stderr) process.stderr.write(matrix.stderr);
  console.error(
    "generate-control-previews: the control-state matrix is not green",
  );
  process.exit(matrix.status ?? 1);
}
if (matrix.stdout) process.stdout.write(matrix.stdout);
if (matrix.stderr) process.stderr.write(matrix.stderr);

const report = JSON.parse(readFileSync(join(matrixOut, "report.json"), "utf8"));
const schemes = ["light", "dark"];
const states = report.states;
const backgrounds = report.backgrounds ?? { light: "#FFFFFF", dark: "#161616" };
const cellGap = 16;
const padding = 16;

const hexToRgb = hex => {
  const value = hex.replace("#", "");
  return [
    parseInt(value.slice(0, 2), 16),
    parseInt(value.slice(2, 4), 16),
    parseInt(value.slice(4, 6), 16),
  ];
};

const entriesByControl = new Map();
for (const entry of report.entries) {
  const key = `${entry.control}/${entry.scheme}/${entry.state}`;
  entriesByControl.set(key, entry);
}

const cellFor = (control, scheme, state) => {
  const entry = entriesByControl.get(`${control}/${scheme}/${state}`);
  if (!entry) {
    throw new Error(`missing matrix cell ${control}/${scheme}/${state}`);
  }
  const rgba = readFileSync(join(matrixOut, entry.file));
  return { entry, rgba };
};

const composeSheet = control => {
  const first = cellFor(control, "light", states[0]);
  const cellWidth = first.entry.width;
  const cellHeight = first.entry.height;
  const sheetWidth =
    padding * 2 + cellWidth * states.length + cellGap * (states.length - 1);
  const sheetHeight = padding * 2 + cellHeight * schemes.length + cellGap;
  const pixels = Buffer.alloc(sheetWidth * sheetHeight * 4);
  // Fill the whole sheet, including padding and the inter-row gap, so the PNG
  // has no transparent bands: the top half uses the light background, the
  // bottom half the dark one, and the gap splits at its midpoint.
  const split = padding + cellHeight + cellGap / 2;
  for (let y = 0; y < sheetHeight; y += 1) {
    const scheme = y < split ? schemes[0] : schemes[1];
    const [br, bg, bb] = hexToRgb(backgrounds[scheme]);
    for (let x = 0; x < sheetWidth; x += 1) {
      const dst = (y * sheetWidth + x) * 4;
      pixels[dst] = br;
      pixels[dst + 1] = bg;
      pixels[dst + 2] = bb;
      pixels[dst + 3] = 255;
    }
  }
  for (let row = 0; row < schemes.length; row += 1) {
    const scheme = schemes[row];
    const [br, bg, bb] = hexToRgb(backgrounds[scheme]);
    const rowTop = padding + row * (cellHeight + cellGap);
    for (let column = 0; column < states.length; column += 1) {
      const { entry, rgba } = cellFor(control, scheme, states[column]);
      const left = padding + column * (cellWidth + cellGap);
      for (let y = 0; y < cellHeight; y += 1) {
        for (let x = 0; x < cellWidth; x += 1) {
          const src = y * entry.rowBytes + x * 4;
          const alpha = rgba[src + 3] / 255;
          const dst = ((rowTop + y) * sheetWidth + (left + x)) * 4;
          pixels[dst] = Math.round(rgba[src] * alpha + br * (1 - alpha));
          pixels[dst + 1] = Math.round(rgba[src + 1] * alpha + bg * (1 - alpha));
          pixels[dst + 2] = Math.round(rgba[src + 2] * alpha + bb * (1 - alpha));
          pixels[dst + 3] = 255;
        }
      }
    }
  }
  return { width: sheetWidth, height: sheetHeight, pixels };
};

const writeStatus = [];
const problems = [];
for (const control of report.controls) {
  const sheet = composeSheet(control);
  const png = encodePng8({
    width: sheet.width,
    height: sheet.height,
    rowBytes: sheet.width * 4,
    pixels: sheet.pixels,
  });
  const path = join(outDir, `${control}.png`);
  if (check) {
    if (!existsSync(path)) {
      problems.push(`${control}: missing ${path}`);
      continue;
    }
    const existing = decodePng8(readFileSync(path));
    if (existing.width !== sheet.width || existing.height !== sheet.height) {
      problems.push(
        `${control}: sheet size ${existing.width}x${existing.height} != ${sheet.width}x${sheet.height}`,
      );
      continue;
    }
    if (!Buffer.from(existing.data).equals(sheet.pixels)) {
      problems.push(`${control}: preview is stale (${path})`);
      continue;
    }
    writeStatus.push(`${control}: current`);
  } else {
    mkdirSync(outDir, { recursive: true });
    writeFileSync(path, png);
    writeStatus.push(`${control}: wrote ${path}`);
  }
}

for (const status of writeStatus) {
  console.log(status);
}
if (problems.length > 0) {
  console.error("generate-control-previews: FAIL");
  for (const problem of problems) {
    console.error(`  - ${problem}`);
  }
  console.error("Run: node scripts/generate-control-previews.mjs");
  process.exit(1);
}
console.log(
  check
    ? "control previews are current"
    : `control previews written to ${outDir}`,
);
