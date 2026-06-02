#!/usr/bin/env node

import { readFileSync } from "node:fs";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-platform-evidence-manifest.mjs <manifest.json> [--platform web|macos|windows|linux]",
  );
};

const args = process.argv.slice(2);
if (args.length < 1 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 1 ? 2 : 0);
}

const manifestPath = args[0];
let expectedPlatform = "";

for (let i = 1; i < args.length; i += 1) {
  if (args[i] === "--platform") {
    expectedPlatform = args[i + 1] ?? "";
    i += 1;
  } else {
    console.error(`Unknown argument: ${args[i]}`);
    usage();
    process.exit(2);
  }
}

const platforms = new Map([
  [
    "web",
    {
      hostPattern: /(Web|browser|wasm-gc)/i,
      exampleTargets: [
        "examples/showcase/web_wasm",
        "examples/markdown_editor/web_wasm",
      ],
      routineTokens: [
        "moon test moui/backend/web --target wasm-gc",
        "moon build examples/showcase/web_wasm --target wasm-gc",
        "moon build examples/markdown_editor/web_wasm --target wasm-gc",
      ],
      runtimeTokens: [
        "record-web-runtime-presentation.mjs",
        "examples/showcase/web_wasm",
        "examples/markdown_editor/web_wasm",
        "--web-presentation-manifest",
      ],
    },
  ],
  [
    "macos",
    {
      hostPattern: /(macOS|Darwin)/,
      exampleTargets: [
        "examples/showcase/macos",
        "examples/showcase/macos_skia",
        "examples/markdown_editor/macos",
      ],
      routineTokens: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/macos --target native",
        "moon build examples/markdown_editor/macos --target native",
      ],
      runtimeTokens: [
        "moon run examples/showcase/macos --target native",
        "moon run examples/markdown_editor/macos --target native",
      ],
    },
  ],
  [
    "windows",
    {
      hostPattern: /(Windows|MSVC)/,
      exampleTargets: [
        "examples/showcase/windows",
        "examples/showcase/windows_skia",
        "examples/markdown_editor/windows",
      ],
      routineTokens: [
        "moon test moui/backend/windows --target native",
        "build_windows_msvc.ps1",
        "package_windows_app_msvc.ps1",
      ],
      runtimeTokens: [
        "moon run examples/showcase/windows --target native",
        "moon run examples/markdown_editor/windows --target native",
      ],
    },
  ],
  [
    "linux",
    {
      hostPattern: /(Linux|Wayland)/,
      exampleTargets: [
        "examples/showcase/linux",
        "examples/showcase/linux_cosmic",
        "examples/showcase/linux_skia",
      ],
      routineTokens: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/linux --target native",
        "moon build examples/showcase/linux_skia --target native",
      ],
      runtimeTokens: [
        "moon run examples/showcase/linux --target native",
        "moon run examples/showcase/linux_skia --target native",
      ],
    },
  ],
]);

const observationKeys = [
  "windowOpened",
  "resizeRedraw",
  "representativeInput",
  "cleanExit",
  "surface",
  "redraw",
  "resizeScale",
  "consumerInput",
  "textInput",
  "rendererHandle",
  "monitorCursor",
  "cleanShutdown",
];

const consumerObservationKeys = [
  "surface",
  "redraw",
  "resizeScale",
  "consumerInput",
  "textInput",
  "rendererHandle",
  "monitorCursor",
  "cleanShutdown",
];

if (expectedPlatform && !platforms.has(expectedPlatform)) {
  console.error(`Unknown platform: ${expectedPlatform}`);
  usage();
  process.exit(2);
}

let failed = false;

const fail = message => {
  console.error(`${manifestPath}: ${message}`);
  failed = true;
};

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch (error) {
  console.error(`${manifestPath}: failed to read JSON: ${error.message}`);
  process.exit(1);
}

const requireString = (object, field, label = field) => {
  const value = object?.[field];
  if (typeof value !== "string" || value.trim() === "") {
    fail(`missing non-empty string field '${label}'`);
    return "";
  }
  return value;
};

const requireArray = (object, field, label = field) => {
  const value = object?.[field];
  if (!Array.isArray(value)) {
    fail(`field '${label}' must be an array`);
    return [];
  }
  return value;
};

const assertStringArray = (values, label) => {
  values.forEach((value, index) => {
    if (typeof value !== "string" || value.trim() === "") {
      fail(`${label}[${index}] must be a non-empty string`);
    }
  });
};

const assertIncludesAll = (values, expected, label) => {
  for (const value of expected) {
    if (!values.includes(value)) {
      fail(`${label} must include '${value}'`);
    }
  }
};

const assertContainsTokens = (values, tokens, label) => {
  for (const token of tokens) {
    if (!values.some(value => value.includes(token))) {
      fail(`${label} must contain an entry mentioning '${token}'`);
    }
  }
};

if (manifest.schemaVersion !== 2) {
  fail("schemaVersion must be 2");
}

const mode = requireString(manifest, "mode");
if (mode !== "platform-runtime-evidence") {
  fail("mode must be 'platform-runtime-evidence'");
}

requireString(manifest, "generatedBy");
const windowEvidenceSource = requireString(manifest, "windowEvidenceSource");
if (windowEvidenceSource !== ".local_repos/window/scripts/record_moui_evidence.sh") {
  fail("windowEvidenceSource must point at .local_repos/window/scripts/record_moui_evidence.sh");
}

const entries = requireArray(manifest, "platforms");
const seen = new Set();

entries.forEach((entry, index) => {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    fail(`platforms[${index}] must be an object`);
    return;
  }

  const label = `platforms[${index}]`;
  const name = requireString(entry, "name", `${label}.name`);
  if (seen.has(name)) {
    fail(`duplicate platform '${name}'`);
  }
  seen.add(name);

  const expected = platforms.get(name);
  if (!expected) {
    fail(`${label}.name must be one of web, macos, windows, linux`);
    return;
  }

  const status = requireString(entry, "status", `${label}.status`);
  if (!["passed", "failed", "pending"].includes(status)) {
    fail(`${label}.status must be passed, failed, or pending`);
  }

  const host = requireString(entry, "host", `${label}.host`);
  if (status === "passed" && !expected.hostPattern.test(host)) {
    fail(`${label}.host must name a matching ${name} host when status is passed`);
  }

  const routineCommands = requireArray(
    entry,
    "routineCommands",
    `${label}.routineCommands`,
  );
  const runtimeEvidenceCommands = requireArray(
    entry,
    "runtimeEvidenceCommands",
    `${label}.runtimeEvidenceCommands`,
  );
  const exampleTargets = requireArray(entry, "exampleTargets", `${label}.exampleTargets`);
  const artifacts = requireArray(entry, "artifacts", `${label}.artifacts`);
  const notes = requireArray(entry, "notes", `${label}.notes`);

  assertStringArray(routineCommands, `${label}.routineCommands`);
  assertStringArray(runtimeEvidenceCommands, `${label}.runtimeEvidenceCommands`);
  assertStringArray(exampleTargets, `${label}.exampleTargets`);
  assertStringArray(artifacts, `${label}.artifacts`);
  assertStringArray(notes, `${label}.notes`);
  if (notes.length === 0) {
    fail(`${label}.notes must include at least one note`);
  }

  assertIncludesAll(exampleTargets, expected.exampleTargets, `${label}.exampleTargets`);
  assertContainsTokens(routineCommands, expected.routineTokens, `${label}.routineCommands`);
  assertContainsTokens(
    runtimeEvidenceCommands,
    expected.runtimeTokens,
    `${label}.runtimeEvidenceCommands`,
  );

  const windowEvidenceCommand = requireString(
    entry,
    "windowEvidenceCommand",
    `${label}.windowEvidenceCommand`,
  );
  if (!windowEvidenceCommand.includes(`.local_repos/window/scripts/record_moui_evidence.sh ${name}`)) {
    fail(`${label}.windowEvidenceCommand must use the window fork recorder for ${name}`);
  }

  if (!entry.observations || typeof entry.observations !== "object" || Array.isArray(entry.observations)) {
    fail(`${label}.observations must be an object`);
    return;
  }

  const observedValues = [];
  for (const key of observationKeys) {
    const value = entry.observations[key];
    if (!["yes", "no", "pending"].includes(value)) {
      fail(`${label}.observations.${key} must be yes, no, or pending`);
    }
    observedValues.push(value);
  }

  for (const key of Object.keys(entry.observations)) {
    if (!observationKeys.includes(key)) {
      fail(`${label}.observations contains unknown key '${key}'`);
    }
  }

  const consumerCommand = requireString(entry, "consumerCommand", `${label}.consumerCommand`);
  const hasConsumerObservation = consumerObservationKeys.some(
    key => entry.observations[key] !== "pending",
  );
  if (hasConsumerObservation && consumerCommand === "pending") {
    fail(`${label}.consumerCommand must name the MoUI consumer run when consumer observations are recorded`);
  }

  if (status === "passed") {
    const requiredPassedObservationKeys = name === "web"
      ? observationKeys.filter(key => key !== "monitorCursor")
      : observationKeys;
    const incompleteObservation = requiredPassedObservationKeys.find(
      key => entry.observations[key] !== "yes",
    );
    if (incompleteObservation) {
      fail(`${label}.observations.${incompleteObservation} must be yes when status is passed`);
    }
    if (consumerCommand === "pending") {
      fail(`${label}.consumerCommand must not be pending when status is passed`);
    }
  }

  if (status === "failed" && !observedValues.includes("no")) {
    fail(`${label}.observations must include at least one no when status is failed`);
  }

  artifacts.forEach((artifact, artifactIndex) => {
    if (!artifact.startsWith(`artifacts/platform-evidence/${name}/`)) {
      fail(`${label}.artifacts[${artifactIndex}] must stay under artifacts/platform-evidence/${name}/`);
    }
  });
});

const requiredPlatforms = expectedPlatform ? [expectedPlatform] : [...platforms.keys()];
for (const name of requiredPlatforms) {
  if (!seen.has(name)) {
    fail(`platforms must include '${name}'`);
  }
}

if (failed) {
  process.exit(1);
}

console.log(`${manifestPath}: ok (platform runtime evidence manifest)`);
