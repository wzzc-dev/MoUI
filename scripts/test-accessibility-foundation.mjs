#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  validateEvidenceManifest,
  validateHandoff,
  validateProbeCatalog,
  validateWorkPackageCatalog,
} from "./validate-accessibility-foundation.mjs";

const readJson = path => JSON.parse(readFileSync(path, "utf8"));
const clone = value => structuredClone(value);
const probe = readJson("checks/accessibility-probe.json");
const workPackages = readJson("checks/accessibility-work-packages.json");

assert.deepEqual(validateProbeCatalog(probe), []);
assert.deepEqual(validateWorkPackageCatalog(workPackages), []);

const duplicateProbe = clone(probe);
duplicateProbe.controls.push(clone(duplicateProbe.controls[0]));
assert(
  validateProbeCatalog(duplicateProbe).some(failure => failure.includes("duplicate id")),
  "duplicate probe ids must fail",
);

const duplicateAction = clone(probe);
duplicateAction.controls[0].actions.push(duplicateAction.controls[0].actions[0]);
assert(
  validateProbeCatalog(duplicateAction).some(failure => failure.includes("duplicate value")),
  "duplicate actions on one probe must fail",
);

const incompleteEvidenceSchema = clone(probe);
incompleteEvidenceSchema.evidence.manifestSchema.required =
  incompleteEvidenceSchema.evidence.manifestSchema.required.filter(field => field !== "nativeTree");
assert(
  validateProbeCatalog(incompleteEvidenceSchema).some(failure => failure.includes("nativeTree")),
  "missing evidence fields must fail",
);

const unknownDependency = clone(workPackages);
unknownDependency.packages[1].depends_on.push("NA-99");
assert(
  validateWorkPackageCatalog(unknownDependency).some(failure => failure.includes("unknown package NA-99")),
  "unknown work-package dependencies must fail",
);

const cyclicGraph = clone(workPackages);
cyclicGraph.packages[0].depends_on.push("NA-01");
assert(
  validateWorkPackageCatalog(cyclicGraph).some(failure => failure.includes("dependency cycle")),
  "dependency cycles must fail",
);

const overlappingOwner = clone(workPackages);
overlappingOwner.packages[2].owner_paths.push("moui/core/*");
assert(
  validateWorkPackageCatalog(overlappingOwner).some(failure => failure.includes("exclusively owned by NA-01")),
  "semantics.mbt ownership outside NA-01 must fail",
);

const handoff = {
  task: "NA-02",
  changed_files: [
    "checks/accessibility-probe.json",
    "scripts/validate-accessibility-foundation.mjs",
  ],
  tests: ["node scripts/test-accessibility-foundation.mjs"],
  api_diff: false,
  evidence: [],
  known_gaps: [],
  blocked_by: [],
};
assert.deepEqual(validateHandoff(handoff, workPackages), []);

const invalidHandoff = clone(handoff);
invalidHandoff.api_diff = "false";
invalidHandoff.changed_files.push("moui/core/semantics.mbt");
const handoffFailures = validateHandoff(invalidHandoff, workPackages);
assert(handoffFailures.some(failure => failure.includes("type boolean")));
assert(handoffFailures.some(failure => failure.includes("outside NA-02 owner_paths")));

const evidence = {
  level: "L1",
  commit: "0123456789abcdef",
  host: "matching-host",
  os: "macos",
  architecture: "arm64",
  window: "showcase",
  backend: "macos",
  generations: ["1", "2"],
  semanticsCommits: [{ kind: "full", generation: "1" }, { kind: "delta", generation: "2" }],
  nativeTree: {},
  actions: [],
  keyboardFocus: [],
  accessibilityFocus: [],
  announcements: [],
  environment: {},
  result: "partial",
  failures: [],
  unverifiedCapabilities: ["voiceover"],
};
assert.deepEqual(validateEvidenceManifest(evidence, probe), []);
assert(
  validateEvidenceManifest(evidence, probe, true).some(failure =>
    failure.includes("screen-reader field screenReader"),
  ),
  "L3 evidence must include screen-reader observations",
);

const screenReaderEvidence = {
  ...evidence,
  level: "L3",
  screenReader: "VoiceOver",
  navigation: [],
  spokenOutput: [],
};
assert.deepEqual(validateEvidenceManifest(screenReaderEvidence, probe, true), []);

const nativeEvidence = {
  ...evidence,
  level: "L2",
  nativeTree: { source: "ax-api" },
  actions: [{ id: "a11y.button", action: "AXPress", result: "passed" }],
  result: "passed",
};
assert.deepEqual(validateEvidenceManifest(nativeEvidence, probe, false, true), []);
const failedNativeEvidence = clone(nativeEvidence);
failedNativeEvidence.actions[0].result = "failed";
assert(
  validateEvidenceManifest(failedNativeEvidence, probe, false, true).some(failure =>
    failure.includes("passed native-client actions"),
  ),
  "L2 evidence must reject failed native actions",
);

console.log("accessibility foundation validator tests: ok");
