#!/usr/bin/env node

import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-capture-manifest-"));
const validator = "scripts/validate-conformance-capture-manifest.mjs";

const validManifest = {
  schemaVersion: 1,
  mode: "golden",
  showcaseTarget: "examples/showcase/web_wasm",
  url: "http://127.0.0.1:18080/examples/showcase/web_wasm/",
  renderInspectorSource:
    "Showcase Diagnostics inspector snapshot card backed by @core.RenderInspectorSnapshot",
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
    {
      name: "desktop",
      viewport: "1440x900",
      path: "artifacts/golden/showcase-web-wasm/desktop.png",
    },
    {
      name: "tablet",
      viewport: "1024x768",
      path: "artifacts/golden/showcase-web-wasm/tablet.png",
    },
    {
      name: "mobile",
      viewport: "390x844",
      path: "artifacts/golden/showcase-web-wasm/mobile.png",
    },
  ],
  benchmarkMetrics: [
    "startup_ms",
    "frame_time_ms",
    "dirty_count",
    "draw_command_count",
    "memory_bytes",
    "render_inspector_counters",
  ],
  notes: ["test fixture"],
};

const benchmarkTargets = [
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

const writeFixture = (name, manifest) => {
  const path = join(tmp, name);
  writeFileSync(path, JSON.stringify(manifest, null, 2));
  return path;
};

const runValidator = (path, mode = "golden") =>
  spawnSync(process.execPath, [validator, path, "--mode", mode], {
    encoding: "utf8",
  });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected validator to pass`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, expectedMessage) => {
  if (result.status === 0) {
    console.error(`${label}: expected validator to fail`);
    process.exit(1);
  }
  if (!result.stderr.includes(expectedMessage)) {
    console.error(`${label}: expected stderr to include '${expectedMessage}'`);
    console.error(result.stderr);
    process.exit(1);
  }
};

expectPass("valid golden manifest", runValidator(writeFixture("valid.json", validManifest)));

const wrongMode = { ...validManifest, mode: "benchmark" };
expectFail(
  "mode mismatch",
  runValidator(writeFixture("wrong-mode.json", wrongMode)),
  "mode must be 'golden'",
);

const missingCounter = {
  ...validManifest,
  renderInspectorCounters: validManifest.renderInspectorCounters.filter(
    counter => counter !== "unbalanced_pop_count",
  ),
};
expectFail(
  "missing inspector counter",
  runValidator(writeFixture("missing-counter.json", missingCounter)),
  "renderInspectorCounters must include 'unbalanced_pop_count'",
);

const wrongViewport = {
  ...validManifest,
  screenshotArtifacts: validManifest.screenshotArtifacts.map(artifact =>
    artifact.name === "mobile" ? { ...artifact, viewport: "430x932" } : artifact,
  ),
};
expectFail(
  "wrong viewport",
  runValidator(writeFixture("wrong-viewport.json", wrongViewport)),
  "viewport must be '390x844'",
);

const benchmarkManifest = {
  ...validManifest,
  mode: "benchmark",
  benchmarkTargets,
};
expectPass(
  "valid benchmark manifest",
  runValidator(writeFixture("valid-benchmark.json", benchmarkManifest), "benchmark"),
);

expectFail(
  "missing benchmark targets field",
  runValidator(
    writeFixture("missing-benchmark-targets.json", {
      ...validManifest,
      mode: "benchmark",
    }),
    "benchmark",
  ),
  "field 'benchmarkTargets' must be an array",
);

const missingMarkdownBenchmark = {
  ...benchmarkManifest,
  benchmarkTargets: benchmarkManifest.benchmarkTargets.filter(
    target => target.name !== "markdown-editor-web-wasm",
  ),
};
expectFail(
  "missing markdown benchmark target",
  runValidator(
    writeFixture("missing-markdown-benchmark.json", missingMarkdownBenchmark),
    "benchmark",
  ),
  "benchmarkTargets must include 'markdown-editor-web-wasm'",
);

const wrongBenchmarkMetricsPath = {
  ...benchmarkManifest,
  benchmarkTargets: benchmarkManifest.benchmarkTargets.map(target =>
    target.name === "markdown-editor-web-wasm"
      ? { ...target, metricsPath: "artifacts/conformance/markdown.json" }
      : target,
  ),
};
expectFail(
  "wrong benchmark metrics path",
  runValidator(
    writeFixture("wrong-benchmark-metrics-path.json", wrongBenchmarkMetricsPath),
    "benchmark",
  ),
  "metricsPath must be 'artifacts/benchmarks/markdown-editor-web-wasm.json'",
);

console.log("conformance capture manifest validator tests: ok");
