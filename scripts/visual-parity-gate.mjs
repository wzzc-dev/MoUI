#!/usr/bin/env node

// Sun ↔ Skia visual parity gate.
//
// Compares the two control-state matrices produced by
// `scripts/visual-control-matrix.mjs --renderer sun|skia` cell by cell.
//
// Metric (perceptual, fixed 2026-11-19): for every pixel take the maximum
// absolute difference over the R/G/B channels, average that over all pixels of
// the cell, then normalize by 255 into a percentage. Pixel-exact parity is
// explicitly out of scope: anti-aliasing/hinting differences are expected.
// A second column reports the share of pixels with any non-zero channel
// difference; it is diagnostic only and never a threshold.
//
// Baseline measured on Linux 2026-11-19, `sun` at cb7287a, same fixtures:
//   60 cells, avg 7.93%, worst 19.72% (checkbox/dark/focused)
//   diagnostic changed-pixel share 20.89%
// Target: avg ≤3%, worst ≤10%.
//
// Usage:
//   node scripts/visual-parity-gate.mjs [--sun DIR] [--skia DIR]
//     [--max-avg 3] [--max-worst 10] [--report-only] [--generate] [--json]
//   node scripts/visual-parity-gate.mjs --self-test
//
// `--generate` first runs the control-state matrix for both renderers into the
// given directories (so CI can regenerate and compare in one step).
// `--report-only` prints every number but exits 0 even when cells are missing,
// artifacts cannot be generated, or thresholds are exceeded — used while Sun
// parity work is in flight. Without it any invalidity or threshold breach
// exits 1.
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { decodePng8, encodePng8 } from "./lib/png-rgba.mjs";
import { repoRoot } from "./lib/window-dependency.mjs";

const SCHEMES = ["light", "dark"];
const DEFAULT_CELLS = 60;

const usage = () => {
  console.error(
    "Usage: node scripts/visual-parity-gate.mjs [--sun DIR] [--skia DIR] [--max-avg PCT] [--max-worst PCT] [--report-only] [--generate] [--json] [--self-test]",
  );
};

const absFromRepo = path => resolve(repoRoot, path);

const parseArgs = argv => {
  const options = {
    sunDir: absFromRepo("artifacts/vm-sun"),
    skiaDir: absFromRepo("artifacts/vm-skia"),
    maxAvg: 3,
    maxWorst: 10,
    reportOnly: false,
    generate: false,
    json: false,
    selfTest: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--sun":
        options.sunDir = absFromRepo(argv[++index] ?? "");
        break;
      case "--skia":
        options.skiaDir = absFromRepo(argv[++index] ?? "");
        break;
      case "--max-avg":
        options.maxAvg = Number(argv[++index]);
        break;
      case "--max-worst":
        options.maxWorst = Number(argv[++index]);
        break;
      case "--report-only":
        options.reportOnly = true;
        break;
      case "--generate":
        options.generate = true;
        break;
      case "--json":
        options.json = true;
        break;
      case "--self-test":
        options.selfTest = true;
        break;
      case "--help":
      case "-h":
        usage();
        process.exit(0);
      default:
        console.error(`Unknown argument: ${arg}`);
        usage();
        process.exit(2);
    }
  }
  for (const [name, value] of [
    ["--max-avg", options.maxAvg],
    ["--max-worst", options.maxWorst],
  ]) {
    if (!Number.isFinite(value) || value < 0) {
      console.error(`${name} must be a non-negative number`);
      process.exit(2);
    }
  }
  return options;
};

const cellKey = entry => `${entry.control}/${entry.scheme}/${entry.state}`;

const readReport = dir => {
  const path = join(dir, "report.json");
  if (!existsSync(path)) {
    return { problem: `missing report: ${path}` };
  }
  try {
    return { report: JSON.parse(readFileSync(path, "utf8")) };
  } catch (error) {
    return { problem: `cannot parse ${path}: ${error.message}` };
  }
};

// Expected cell keys are the cartesian product of the report's own declared
// controls × schemes × states, so the matrix stays the single source of truth
// for which cells must exist.
const expectedKeys = (report, schemes = SCHEMES) => {
  const keys = [];
  for (const control of report.controls ?? []) {
    for (const scheme of schemes) {
      for (const state of report.states ?? []) {
        keys.push(`${control}/${scheme}/${state}`);
      }
    }
  }
  return keys;
};

const reportProblems = (report, label, schemes = SCHEMES) => {
  const problems = [];
  if (report.schemaVersion !== 1) {
    problems.push(`${label}: unexpected report schemaVersion ${report.schemaVersion}`);
  }
  if (!Array.isArray(report.controls) || report.controls.length === 0) {
    problems.push(`${label}: report has no controls`);
  }
  if (!Array.isArray(report.states) || report.states.length === 0) {
    problems.push(`${label}: report has no states`);
  }
  const entries = report.entries ?? [];
  const seen = new Set();
  for (const entry of entries) {
    const key = cellKey(entry);
    if (seen.has(key)) {
      problems.push(`${label}: duplicate cell ${key}`);
    }
    seen.add(key);
    if (entry.blank) {
      problems.push(`${label}: cell ${key} painted nothing (blank)`);
    }
    if (entry.missing) {
      problems.push(`${label}: cell ${key} is missing`);
    }
  }
  for (const id of report.missing_states ?? []) {
    problems.push(`${label}: missing state style ${id}`);
  }
  for (const key of expectedKeys(report, schemes)) {
    if (!seen.has(key)) {
      problems.push(`${label}: missing cell ${key}`);
    }
  }
  return problems;
};

const indexReport = report => {
  const map = new Map();
  for (const entry of report.entries ?? []) {
    map.set(cellKey(entry), entry);
  }
  return map;
};

// Pixels come from the raw `.rgba` dump when the producer kept it, otherwise
// from the sibling `.png` (the matrix deletes `.rgba` unless `--keep-rgba`).
const loadCell = (dir, entry) => {
  const rgbaPath = join(dir, entry.file);
  if (existsSync(rgbaPath)) {
    const pixels = readFileSync(rgbaPath);
    const rowBytes = entry.rowBytes ?? entry.width * 4;
    if (rowBytes < entry.width * 4) {
      return { problem: `${rgbaPath}: rowBytes ${rowBytes} < ${entry.width * 4}` };
    }
    if (pixels.length !== rowBytes * entry.height) {
      return {
        problem: `${rgbaPath}: ${pixels.length} bytes, expected ${rowBytes * entry.height}`,
      };
    }
    return { pixels, rowBytes, source: "rgba" };
  }
  const pngPath = join(dir, entry.file.replace(/\.rgba$/, ".png"));
  if (!existsSync(pngPath)) {
    return { problem: `missing pixels for ${entry.file}: neither .rgba nor .png exists` };
  }
  try {
    const { width, height, data } = decodePng8(readFileSync(pngPath));
    if (width !== entry.width || height !== entry.height) {
      return {
        problem: `${pngPath}: ${width}x${height}, expected ${entry.width}x${entry.height}`,
      };
    }
    return { pixels: data, rowBytes: width * 4, source: "png" };
  } catch (error) {
    return { problem: `${pngPath}: ${error.message}` };
  }
};

const comparePixels = (a, b) => {
  const rowBytes = a.rowBytes === b.rowBytes ? a.rowBytes : Math.min(a.rowBytes, b.rowBytes);
  const width = Math.min(a.rowBytes, b.rowBytes) / 4;
  const height = Math.min(a.pixels.length / a.rowBytes, b.pixels.length / b.rowBytes);
  let sum = 0;
  let changed = 0;
  let count = 0;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const offsetA = y * a.rowBytes + x * 4;
      const offsetB = y * b.rowBytes + x * 4;
      const maxDiff = Math.max(
        Math.abs(a.pixels[offsetA] - b.pixels[offsetB]),
        Math.abs(a.pixels[offsetA + 1] - b.pixels[offsetB + 1]),
        Math.abs(a.pixels[offsetA + 2] - b.pixels[offsetB + 2]),
      );
      sum += maxDiff;
      if (maxDiff > 0) changed += 1;
      count += 1;
    }
  }
  if (count === 0) {
    return { problem: `cannot compare pixel rows (rowBytes ${rowBytes})` };
  }
  return {
    avgPct: (sum / count / 255) * 100,
    changedPct: (changed / count) * 100,
  };
};

const runGate = ({
  sunDir,
  skiaDir,
  expectedCells = DEFAULT_CELLS,
  maxAvg = 3,
  maxWorst = 10,
  reportOnly = false,
  schemes = SCHEMES,
}) => {
  const problems = [];
  const sun = readReport(sunDir);
  const skia = readReport(skiaDir);
  if (sun.problem) problems.push(`sun ${sun.problem}`);
  if (skia.problem) problems.push(`skia ${skia.problem}`);

  let rows = [];
  let avgPct = 0;
  let worst = null;
  if (!sun.problem && !skia.problem) {
    problems.push(...reportProblems(sun.report, "sun", schemes));
    problems.push(...reportProblems(skia.report, "skia", schemes));

    const sunCells = indexReport(sun.report);
    const skiaCells = indexReport(skia.report);
    const keys = expectedKeys(sun.report, schemes);
    if (keys.length !== expectedCells) {
      problems.push(
        `sun report declares ${keys.length} cells, expected ${expectedCells}; pass the updated cell count to the gate before changing the matrix`,
      );
    }
    for (const key of keys) {
      const a = sunCells.get(key);
      const b = skiaCells.get(key);
      if (!a || !b) {
        problems.push(`cell ${key} is missing from ${!a ? "sun" : "skia"}`);
        continue;
      }
      if (a.width !== b.width || a.height !== b.height) {
        problems.push(
          `cell ${key} size mismatch: sun ${a.width}x${a.height}, skia ${b.width}x${b.height}`,
        );
        continue;
      }
      const pixelsA = loadCell(sunDir, a);
      const pixelsB = loadCell(skiaDir, b);
      if (pixelsA.problem) problems.push(`sun ${pixelsA.problem}`);
      if (pixelsB.problem) problems.push(`skia ${pixelsB.problem}`);
      if (pixelsA.problem || pixelsB.problem) continue;
      const comparison = comparePixels(pixelsA, pixelsB);
      if (comparison.problem) {
        problems.push(`cell ${key}: ${comparison.problem}`);
        continue;
      }
      rows.push({
        key,
        width: a.width,
        height: a.height,
        source: pixelsA.source === pixelsB.source ? pixelsA.source : "mixed",
        avgPct: comparison.avgPct,
        changedPct: comparison.changedPct,
      });
    }
    if (rows.length > 0) {
      avgPct = rows.reduce((sum, row) => sum + row.avgPct, 0) / rows.length;
      worst = rows.reduce((best, row) =>
        row.avgPct > best.avgPct || (row.avgPct === best.avgPct && row.key < best.key) ? row : best,
      );
    }
  }

  let status = "pass";
  if (problems.length > 0) {
    status = "invalid";
  } else if (!rows.length || avgPct > maxAvg || (worst && worst.avgPct > maxWorst)) {
    status = "fail";
  }
  const exitCode = status === "pass" || reportOnly ? 0 : 1;
  return {
    status,
    exitCode,
    problems,
    rows,
    avgPct,
    worst,
    maxAvg,
    maxWorst,
    expectedCells,
    sunDir,
    skiaDir,
  };
};

const fmt = value => `${value.toFixed(2)}%`;

const printResult = result => {
  const { status, rows, avgPct, worst, maxAvg, maxWorst } = result;
  console.log(`visual parity: ${rows.length} cells (sun ${result.sunDir})`);
  if (rows.length > 0) {
    const width = Math.max(...rows.map(row => row.key.length));
    for (const row of rows) {
      console.log(
        `  ${row.key.padEnd(width)}  ${fmt(row.avgPct).padStart(8)}  changed ${fmt(row.changedPct).padStart(8)}  ${row.source}`,
      );
    }
    console.log("");
    console.log(
      `avg ${fmt(avgPct)} (limit ${fmt(maxAvg)}) | worst ${fmt(worst.avgPct)} ${worst.key} (limit ${fmt(maxWorst)})`,
    );
    const diagnostic =
      rows.reduce((sum, row) => sum + row.changedPct, 0) / rows.length;
    console.log(
      `diagnostic (never a threshold): mean changed-pixel share ${fmt(diagnostic)}`,
    );
  }
  if (result.problems.length > 0) {
    console.error("visual parity: INVALID");
    for (const problem of result.problems) console.error(`  - ${problem}`);
  } else if (status === "pass") {
    console.log("visual parity: PASS");
  } else {
    console.error("visual parity: FAIL (thresholds)");
  }
  console.log(`skia: ${result.skiaDir}`);
};

const generateMatrices = options => {
  // Skia is generated first: on hosts without a Skia build this fails fast
  // before the Sun matrix spends a full render, and the host then skips the
  // comparison the same way the control-preview/gallery-screenshot steps do.
  for (const [renderer, dir] of [
    ["skia", options.skiaDir],
    ["sun", options.sunDir],
  ]) {
    rmSync(join(dir, "report.json"), { force: true });
    mkdirSync(dir, { recursive: true });
    const run = spawnSync(
      process.execPath,
      [
        "scripts/visual-control-matrix.mjs",
        "--renderer",
        renderer,
        "--out",
        dir,
      ],
      { cwd: repoRoot, encoding: "utf8", shell: false },
    );
    const output = `${run.stdout ?? ""}\n${run.stderr ?? ""}`;
    if (run.error) {
      return { problem: `${renderer} matrix: ${run.error.message}` };
    }
    if (run.status !== 0) {
      // The `visual` profile disables the Skia prebuild, so a Skia-capable
      // developer machine can compare while CI hosts skip. Match the existing
      // control-preview/gallery-screenshot convention instead of failing.
      if (output.includes("skia renderer unavailable")) {
        return { skiaUnavailable: true };
      }
      if (run.stdout) process.stdout.write(run.stdout);
      if (run.stderr) process.stderr.write(run.stderr);
      return { problem: `${renderer} matrix exited ${run.status}` };
    }
  }
  return {};
};

const makeFixture = (dir, cells, declared = {}) => {
  mkdirSync(dir, { recursive: true });
  const entries = cells.map((cell, index) => ({
    control: cell.control ?? `control${index}`,
    scheme: cell.scheme ?? "light",
    state: cell.state ?? "default",
    file: `${cell.control ?? `control${index}`}-${cell.scheme ?? "light"}-${cell.state ?? "default"}.rgba`,
    width: cell.width,
    height: cell.height,
    rowBytes: cell.width * 4,
    blank: cell.blank ?? false,
    missing: false,
  }));
  const report = {
    schemaVersion: 1,
    renderer: "fixture",
    controls: declared.controls ?? [...new Set(entries.map(entry => entry.control))],
    states: declared.states ?? [...new Set(entries.map(entry => entry.state))],
    entries,
  };
  writeFileSync(join(dir, "report.json"), JSON.stringify(report));
  cells.forEach((cell, index) => {
    const entry = entries[index];
    if (cell.png) {
      writeFileSync(
        join(dir, entry.file.replace(/\.rgba$/, ".png")),
        encodePng8({
          width: entry.width,
          height: entry.height,
          rowBytes: entry.rowBytes,
          pixels: cell.pixels,
        }),
      );
    } else {
      writeFileSync(join(dir, entry.file), cell.pixels);
    }
  });
};

const selfTest = () => {
  const root = mkdtempSync(join(repoRoot, "artifacts/parity-gate-selftest-"));
  const checks = [];
  const check = (name, condition) => {
    checks.push({ name, ok: Boolean(condition) });
    if (!condition) console.error(`self-test FAIL: ${name}`);
  };
  const gate = options => runGate({ schemes: ["light"], ...options });
  const solid = (width, height, value) => Buffer.alloc(width * height * 4, value);
  const rgba = (width, height, pixels) => {
    const buffer = Buffer.alloc(width * height * 4);
    pixels.forEach((pixel, index) => {
      buffer[index * 4] = pixel[0];
      buffer[index * 4 + 1] = pixel[1];
      buffer[index * 4 + 2] = pixel[2];
      buffer[index * 4 + 3] = 255;
    });
    return buffer;
  };
  try {
    const same = [{ width: 2, height: 2, pixels: solid(2, 2, 0) }];
    makeFixture(join(root, "same-sun"), same);
    makeFixture(join(root, "same-skia"), same);
    const identical = gate({
      sunDir: join(root, "same-sun"),
      skiaDir: join(root, "same-skia"),
      expectedCells: 1,
    });
    check("identical cells pass with 0% avg", identical.exitCode === 0 && identical.avgPct === 0);
    check("identical cells keep worst at 0%", identical.worst.avgPct === 0);

    // One pixel of four differs by 255 in a single channel: 255/4/255 = 25%.
    const shifted = [
      {
        width: 2,
        height: 2,
        pixels: rgba(2, 2, [
          [255, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
        ]),
      },
    ];
    makeFixture(join(root, "diff-sun"), shifted);
    makeFixture(join(root, "diff-skia"), same);
    const quarter = gate({
      sunDir: join(root, "diff-sun"),
      skiaDir: join(root, "diff-skia"),
      expectedCells: 1,
      maxAvg: 30,
      maxWorst: 30,
    });
    check("single channel diff computes 25%", Math.abs(quarter.avgPct - 25) < 1e-9);
    check("diagnostic share computes 25%", Math.abs(quarter.rows[0].changedPct - 25) < 1e-9);
    check("thresholds under limit pass", quarter.exitCode === 0);

    const strict = gate({
      sunDir: join(root, "diff-sun"),
      skiaDir: join(root, "diff-skia"),
      expectedCells: 1,
      maxAvg: 10,
    });
    check("avg breach fails", strict.exitCode === 1 && strict.status === "fail");
    const strictReportOnly = gate({
      sunDir: join(root, "diff-sun"),
      skiaDir: join(root, "diff-skia"),
      expectedCells: 1,
      maxAvg: 10,
      reportOnly: true,
    });
    check("report-only never blocks", strictReportOnly.exitCode === 0);

    makeFixture(join(root, "missing-skia"), [], {
      controls: ["control0"],
      states: ["default"],
    });
    const missing = gate({
      sunDir: join(root, "diff-sun"),
      skiaDir: join(root, "missing-skia"),
      expectedCells: 1,
    });
    check(
      "missing cell is invalid",
      missing.exitCode === 1 && missing.problems.some(problem => problem.includes("missing cell")),
    );
    const missingReportOnly = gate({
      sunDir: join(root, "diff-sun"),
      skiaDir: join(root, "missing-skia"),
      expectedCells: 1,
      reportOnly: true,
    });
    check("report-only tolerates invalid reports", missingReportOnly.exitCode === 0);

    makeFixture(join(root, "size-skia"), [{ width: 4, height: 2, pixels: solid(4, 2, 0) }]);
    const sized = gate({
      sunDir: join(root, "diff-sun"),
      skiaDir: join(root, "size-skia"),
      expectedCells: 1,
    });
    check(
      "size mismatch is invalid",
      sized.problems.some(problem => problem.includes("size mismatch")),
    );

    makeFixture(join(root, "blank-sun"), [
      { width: 2, height: 2, pixels: solid(2, 2, 0), blank: true },
    ]);
    const blank = gate({
      sunDir: join(root, "blank-sun"),
      skiaDir: join(root, "same-skia"),
      expectedCells: 1,
    });
    check(
      "blank cell is invalid",
      blank.problems.some(problem => problem.includes("painted nothing")),
    );

    makeFixture(join(root, "cellcount-sun"), [...same, ...same]);
    makeFixture(join(root, "cellcount-skia"), [...same, ...same]);
    const cellCount = gate({
      sunDir: join(root, "cellcount-sun"),
      skiaDir: join(root, "cellcount-skia"),
      expectedCells: 1,
    });
    check(
      "declared cell count must match",
      cellCount.problems.some(problem => problem.includes("declares 2 cells")),
    );

    makeFixture(join(root, "png-sun"), [{ ...same[0], png: true }]);
    makeFixture(join(root, "png-skia"), [{ ...same[0], png: true }]);
    const png = gate({
      sunDir: join(root, "png-sun"),
      skiaDir: join(root, "png-skia"),
      expectedCells: 1,
    });
    check("png fallback reads identical cells", png.exitCode === 0 && png.rows[0].source === "png");

    const missingReport = gate({
      sunDir: join(root, "nope"),
      skiaDir: join(root, "nope"),
      expectedCells: 1,
      reportOnly: true,
    });
    check(
      "absent reports are reported",
      missingReport.problems.some(problem => problem.includes("missing report")),
    );
    check("report-only tolerates absent reports", missingReport.exitCode === 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
  const failed = checks.filter(entry => !entry.ok);
  if (failed.length > 0) {
    console.error(`visual parity self-test: FAIL (${failed.length}/${checks.length})`);
    process.exit(1);
  }
  console.log(`visual parity self-test: PASS (${checks.length} checks)`);
};

const main = () => {
  const options = parseArgs(process.argv.slice(2));
  if (options.selfTest) {
    selfTest();
    return;
  }
  if (options.generate) {
    const generation = generateMatrices(options);
    if (generation.skiaUnavailable) {
      console.log(
        "visual parity: skipped (Skia renderer unavailable on this host)",
      );
      process.exit(0);
    }
    if (generation.problem) {
      console.error(`visual parity: cannot generate matrices: ${generation.problem}`);
      if (options.reportOnly) {
        console.log("visual parity: report-only, not blocking");
        process.exit(0);
      }
      process.exit(1);
    }
  }
  const result = runGate({
    sunDir: options.sunDir,
    skiaDir: options.skiaDir,
    maxAvg: options.maxAvg,
    maxWorst: options.maxWorst,
    reportOnly: options.reportOnly,
  });
  printResult(result);
  if (options.json) {
    console.log(
      JSON.stringify({
        status: result.status,
        avgPct: Number(result.avgPct.toFixed(4)),
        worstPct: Number((result.worst?.avgPct ?? 0).toFixed(4)),
        worstCell: result.worst?.key ?? null,
        cells: result.rows.length,
        problems: result.problems.length,
      }),
    );
  }
  if (options.reportOnly && result.status !== "pass") {
    console.log("visual parity: report-only, not blocking");
  }
  process.exit(result.exitCode);
};

main();
