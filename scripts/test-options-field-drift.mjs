#!/usr/bin/env node

/**
 * Spec test for validate-options-field-drift.mjs (ADR 0019 acceptance:
 * the drift gate ships with lost/intact fixtures — a tree with a declared-
 * but-never-read option field must fail, a fully-consumed one must pass).
 */

import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { analyzeOptionsFieldDrift } from "./validate-options-field-drift.mjs";

const intactBackend = join("moui", "backend", "fixture");
const intactSource = `///|
pub struct FixtureAppOptions {
  priv title_prefix : String
}

///|
pub fn FixtureAppOptions::new(title_prefix? : String = "MoUI") -> FixtureAppOptions {
  { title_prefix, }
}

///|
pub fn fixture_launch(options? : FixtureAppOptions = FixtureAppOptions::new()) -> Int {
  // Consumes the field through the options value (a genuine read).
  ignore(options.title_prefix)
  0
}
`;

const lostSource = `///|
pub struct FixtureAppOptions {
  priv title_prefix : String
  priv lost_field : Bool
}

///|
pub fn FixtureAppOptions::new(title_prefix? : String = "MoUI", lost_field? : Bool = false) -> FixtureAppOptions {
  { title_prefix, lost_field, }
}

///|
pub fn fixture_launch(options? : FixtureAppOptions = FixtureAppOptions::new()) -> Int {
  ignore(options.title_prefix)
  0
}
`;

function runFixture(name, source, expectLost) {
  const root = mkdtempSync(join(tmpdir(), `options-drift-${name}-`));
  try {
    mkdirSync(join(root, intactBackend), { recursive: true });
    writeFileSync(join(root, intactBackend, "fixture_backend.mbt"), source);
    const { structs, lost } = analyzeOptionsFieldDrift(root);
    if (structs.length !== 1 || structs[0].fields.length === 0) {
      throw new Error(`${name}: analyzer found no fixture struct`);
    }
    const hasLostField = lost.some((entry) => entry.field === "lost_field");
    if (expectLost && !hasLostField) {
      throw new Error(`${name}: expected lost_field to be reported as drift`);
    }
    if (!expectLost && lost.length !== 0) {
      throw new Error(`${name}: expected zero drift, got ${JSON.stringify(lost)}`);
    }
    console.log(`  fixture ${name}: ${expectLost ? "fail (drift detected)" : "pass (no drift)"} ✓`);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

runFixture("intact", intactSource, false);
runFixture("lost", lostSource, true);
console.log("options field drift spec test: ok");
