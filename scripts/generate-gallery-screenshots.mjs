#!/usr/bin/env node

// Generate the README / website gallery screenshots.
//
// Runs the native offscreen tool in moui_tests/gallery_screenshots (Skia raster,
// 2x scale), encodes the raw RGBA frames as PNG, and writes them to
// resource/screenshots/. `--check` re-renders and compares pixels so the
// committed images cannot drift from the Desktop preset.
//
// Usage:
//   node scripts/generate-gallery-screenshots.mjs            # write PNGs
//   node scripts/generate-gallery-screenshots.mjs --check    # fail on drift
//   node scripts/generate-gallery-screenshots.mjs --website  # also write WebP
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { decodePng8, encodePng8 } from "./lib/png-rgba.mjs";
import { repoRoot } from "./lib/window-dependency.mjs";

const usage = () => {
  console.error(
    "Usage: node scripts/generate-gallery-screenshots.mjs [--check] [--website] [--out DIR]",
  );
};

let check = false;
let website = false;
let outDir = resolve(repoRoot, "resource/screenshots");
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--check") {
    check = true;
  } else if (args[index] === "--website") {
    website = true;
  } else if (args[index] === "--out") {
    outDir = resolve(repoRoot, args[index + 1] ?? "");
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

const scratch = mkdtempSync(join(tmpdir(), "moui-gallery-shots-"));
const cleanup = () => rmSync(scratch, { recursive: true, force: true });
process.on("exit", cleanup);

const renderDir = scratch;
mkdirSync(renderDir, { recursive: true });

const run = spawnSync(
  "moon",
  [
    "-C",
    "moui_tests",
    "run",
    "gallery_screenshots",
    "--target",
    "native",
    "--",
    "--out",
    renderDir,
  ],
  { cwd: repoRoot, encoding: "utf8", shell: false },
);
const output = `${run.stdout ?? ""}\n${run.stderr ?? ""}`;
const skiaUnavailable = output.includes("skia renderer unavailable");
if (run.status !== 0) {
  if (skiaUnavailable) {
    if (check) {
      // The committed PNGs are Skia-rendered. Hosts without Skia (the `visual`
      // profile disables the prebuild) cannot reproduce them; the rest of the
      // visual profile still runs, so skip instead of failing every CI run.
      console.log(
        "gallery screenshots: skipped (Skia renderer unavailable on this host)",
      );
      process.exit(0);
    }
    console.error(
      "generate-gallery-screenshots: Skia is required to write the committed PNGs",
    );
    process.exit(1);
  }
  if (run.stdout) process.stdout.write(run.stdout);
  if (run.stderr) process.stderr.write(run.stderr);
  console.error("generate-gallery-screenshots: the offscreen render failed");
  process.exit(run.status ?? 1);
}

const manifest = JSON.parse(readFileSync(join(renderDir, "manifest.json"), "utf8"));
const problems = [];
const statuses = [];
mkdirSync(outDir, { recursive: true });

for (const frame of manifest.frames) {
  const pixels = readFileSync(join(renderDir, frame.file));
  const expectedBytes = frame.width * frame.height * 4;
  if (pixels.length !== expectedBytes) {
    problems.push(
      `${frame.name}: ${pixels.length} bytes, expected ${expectedBytes}`,
    );
    continue;
  }
  const png = encodePng8({
    width: frame.width,
    height: frame.height,
    rowBytes: frame.rowBytes,
    pixels,
  });
  const path = join(outDir, `${frame.name}.png`);
  if (check) {
    if (!existsSync(path)) {
      problems.push(`${frame.name}: missing ${path}`);
      continue;
    }
    const existing = decodePng8(readFileSync(path));
    if (
      existing.width !== frame.width ||
      existing.height !== frame.height ||
      !Buffer.from(existing.data).equals(pixels)
    ) {
      problems.push(`${frame.name}: screenshot is stale (${path})`);
      continue;
    }
    statuses.push(`${frame.name}: current`);
  } else {
    writeFileSync(path, png);
    statuses.push(`${frame.name}: wrote ${path}`);
  }
}

if (check) {
  for (const status of statuses) {
    console.log(status);
  }
  if (problems.length > 0) {
    console.error("generate-gallery-screenshots: FAIL");
    for (const problem of problems) {
      console.error(`  - ${problem}`);
    }
    console.error("Run: node scripts/generate-gallery-screenshots.mjs");
    process.exit(1);
  }
  console.log("gallery screenshots are current");
  process.exit(0);
}

for (const status of statuses) {
  console.log(status);
}

if (website) {
  const webpDir = resolve(repoRoot, "resource/screenshots/website");
  mkdirSync(webpDir, { recursive: true });
  const convert = spawnSync("which", ["cwebp"], { encoding: "utf8" });
  if (convert.status !== 0) {
    console.error(
      "generate-gallery-screenshots: cwebp is required for --website (brew install webp)",
    );
    process.exit(1);
  }
  for (const frame of manifest.frames) {
    const slug = frame.name.replace(/^gallery-/, "");
    const source = join(outDir, `${frame.name}.png`);
    const target = join(webpDir, `gallery-${slug}.webp`);
    const webp = spawnSync(
      "cwebp",
      ["-quiet", "-q", "84", "-resize", "1080", "0", source, "-o", target],
      { encoding: "utf8" },
    );
    if (webp.status !== 0) {
      console.error(webp.stderr ?? "");
      console.error(`generate-gallery-screenshots: cwebp failed for ${source}`);
      process.exit(webp.status ?? 1);
    }
    console.log(`gallery-${slug}: wrote ${target}`);
  }
  console.log(
    "Next: node scripts/gen-website-showcase-assets.mjs (syncs Website assets)",
  );
}
