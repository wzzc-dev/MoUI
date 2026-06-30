#!/usr/bin/env node

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";

const usage = () => {
  console.error(
    "Usage: node scripts/generate-feature-proof-report.mjs --status <json> --run-url <url> --output <path>",
  );
  process.exit(2);
};

let statusJson = "";
let runUrl = "";
let output = "";

const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--status") statusJson = args[++index] ?? "";
  else if (arg === "--run-url") runUrl = args[++index] ?? "";
  else if (arg === "--output") output = args[++index] ?? "";
  else if (arg === "--help" || arg === "-h") usage();
  else usage();
}

if (!statusJson || !output) usage();

let jobStatus;
try {
  jobStatus = JSON.parse(statusJson);
} catch (e) {
  console.error(`Failed to parse --status JSON: ${e.message}`);
  process.exit(2);
}

// L1 features: each maps to a ci.yml job that must be "success"
const l1Features = [
  { feature: "Core API (View/Element/Layout/Animation)", job: "conformance" },
  { feature: "Runtime lifecycle", job: "conformance" },
  { feature: "Views controls", job: "conformance" },
  { feature: "Host services protocol", job: "conformance" },
  { feature: "Web wasm-gc build", job: "conformance" },
  { feature: "Renderer capability report consistency", job: "conformance" },
  { feature: "Text conformance", job: "conformance" },
  { feature: "API surface stability", job: "api-surface" },
  { feature: "Linux backend contracts", job: "linux-platform" },
  { feature: "Windows backend contracts", job: "windows-native" },
  { feature: "macOS packaging", job: "macos-packaging" },
  { feature: "Benchmark scaffold", job: "benchmark-scaffold" },
];

// L2 features: each maps to 3 platform jobs in moui-skia-real-skia-pr-smoke.yml
const l2FeatureNames = [
  "Rect",
  "RoundedRect",
  "Gradient",
  "Shadow",
  "Text",
  "Image",
  "Clip",
  "Transform",
  "Opacity",
  "LayerCompositing",
  "BlendMode",
  "FilterEffect",
  "PathVector",
  "ShaderEffect",
  "TextShaping",
  "EmojiText",
  "AsyncImage",
];

const l2Jobs = ["macos-real-skia", "linux-real-skia", "windows-real-skia"];

const features = [];

for (const { feature, job } of l1Features) {
  const status = jobStatus[job] ?? "missing";
  features.push({
    feature,
    level: "L1",
    proofJob: job,
    status,
    proven: status === "success",
  });
}

for (const feature of l2FeatureNames) {
  const perPlatform = {};
  let allPassed = true;
  let anyMissing = false;
  for (const job of l2Jobs) {
    const s = jobStatus[job] ?? "missing";
    perPlatform[job] = s;
    if (s !== "success") allPassed = false;
    if (s === "missing") anyMissing = true;
  }
  const status = allPassed ? "success" : anyMissing ? "missing" : "failed";
  features.push({
    feature,
    level: "L2",
    proofJobs: l2Jobs,
    status: perPlatform,
    proven: allPassed,
    platforms: ["macOS", "Linux", "Windows"],
  });
}

let proven = 0;
let gap = 0;
for (const f of features) {
  if (f.proven) {
    proven += 1;
  } else {
    gap += 1;
  }
}

const report = {
  ciRunUrl: runUrl,
  timestamp: new Date().toISOString(),
  features,
  summary: {
    totalFeatures: features.length,
    proven,
    gap,
  },
};

mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, JSON.stringify(report, null, 2) + "\n");

// Generate markdown report
const mdPath = output.replace(/\.json$/, ".md");
const lines = [
  `# Feature Proof Summary`,
  ``,
  `- **CI Run**: ${runUrl || "N/A"}`,
  `- **Timestamp**: ${report.timestamp}`,
  `- **Total features**: ${features.length}`,
  `- **Proven**: ${proven}`,
  `- **Gap**: ${gap}`,
  ``,
  `## L1 Features`,
  ``,
  `| Feature | Proof job | Status | Proven |`,
  `|---------|-----------|--------|--------|`,
];

for (const f of features.filter((f) => f.level === "L1")) {
  lines.push(
    `| ${f.feature} | ${f.proofJob} | ${f.status} | ${f.proven ? "yes" : "no"} |`,
  );
}

lines.push(``, `## L2 Features`, ``);

lines.push(
  `| Feature | macOS | Linux | Windows | Proven |`,
  `|---------|-------|-------|---------|--------|`,
);
for (const f of features.filter((f) => f.level === "L2")) {
  const s = f.status;
  lines.push(
    `| ${f.feature} | ${s["macos-real-skia"] ?? "missing"} | ${s["linux-real-skia"] ?? "missing"} | ${s["windows-real-skia"] ?? "missing"} | ${f.proven ? "yes" : "no"} |`,
  );
}

if (gap > 0) {
  lines.push(``, `## Gaps`, ``);
  for (const f of features.filter((f) => !f.proven)) {
    lines.push(`- **${f.feature}** (${f.level}): status=${typeof f.status === "object" ? JSON.stringify(f.status) : f.status}`);
  }
}

lines.push("");
writeFileSync(mdPath, lines.join("\n"));

console.log(`Feature proof report written to ${output}`);
console.log(`Markdown report written to ${mdPath}`);
console.log(`Summary: ${proven} proven, ${gap} gap`);
