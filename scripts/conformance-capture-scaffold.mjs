#!/usr/bin/env node

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { spawnSync } from "node:child_process";
import { repoRoot } from "./lib/window-dependency.mjs";

const usage = () => {
  console.error("Usage: node scripts/conformance-capture-scaffold.mjs --mode golden|benchmark");
};

let mode = "";
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--mode") {
    mode = args[index + 1] ?? "";
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

if (!["golden", "benchmark"].includes(mode)) {
  usage();
  process.exit(2);
}

const run = argv => {
  console.log(`\n==> ${argv.join(" ")}`);
  const result = spawnSync(argv[0], argv.slice(1), {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (result.status !== 0 || result.error) {
    if (result.error) console.error(result.error.message);
    process.exit(result.status ?? 1);
  }
};

const manifestPath = mode === "golden"
  ? "artifacts/conformance/showcase-golden-capture.json"
  : "artifacts/conformance/showcase-benchmark-capture.json";

const manifest = {
  schemaVersion: 1,
  mode,
  showcaseTarget: "examples/showcase/web_wasm",
  url: "http://127.0.0.1:18080/examples/showcase/web_wasm/",
  renderInspectorSource: "Showcase Diagnostics inspector snapshot card backed by @runtime.RenderInspectorSnapshot",
  renderInspectorCounters: [
    "command_count",
    "text_count",
    "image_count",
    "clip_depth",
    "open_clip_depth",
    "layer_depth",
    "open_layer_depth",
    "filter_depth",
    "open_filter_depth",
    "path_count",
    "shader_count",
    "unbalanced_pop_count",
  ],
  screenshotArtifacts: [
    { name: "desktop", viewport: "1440x900", path: "artifacts/golden/showcase-web-wasm/desktop.png" },
    { name: "tablet", viewport: "1024x768", path: "artifacts/golden/showcase-web-wasm/tablet.png" },
    { name: "mobile", viewport: "390x844", path: "artifacts/golden/showcase-web-wasm/mobile.png" },
  ],
  benchmarkMetrics: [
    "startup_ms",
    "frame_time_ms",
    "dirty_count",
    "draw_command_count",
    "memory_bytes",
    "render_inspector_counters",
  ],
  notes: [
    "This manifest connects the build scaffold to manual capture artifacts.",
    "It does not contain captured measurements or screenshots by itself.",
  ],
};

if (mode === "benchmark") {
  manifest.benchmarkTargets = [
    {
      name: "showcase-web-wasm",
      target: "examples/showcase/web_wasm",
      url: "http://127.0.0.1:18080/examples/showcase/web_wasm/",
      metricsPath: "artifacts/benchmarks/showcase-web-wasm.json",
    },
    {
      name: "markdown-editor-web-wasm",
      target: "examples/markdown_editor/web_wasm",
      url: "http://127.0.0.1:18080/examples/markdown_editor/web_wasm/",
      metricsPath: "artifacts/benchmarks/markdown-editor-web-wasm.json",
    },
  ];
}

run(["moon", "build", "examples/showcase/web_wasm", "--target", "wasm-gc"]);
if (mode === "benchmark") {
  run(["moon", "build", "examples/markdown_editor/web_wasm", "--target", "wasm-gc"]);
  run(["node", "scripts/validate-web-runtime-handoff.mjs", "--manifest", "artifacts/conformance/web-runtime-handoff.json"]);
}

mkdirSync(dirname(manifestPath), { recursive: true });
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Wrote capture manifest: ${manifestPath}`);
run(["node", "scripts/validate-conformance-capture-manifest.mjs", manifestPath, "--mode", mode]);

console.log(`\n${mode} capture scaffold complete.`);
