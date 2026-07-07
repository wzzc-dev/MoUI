#!/usr/bin/env node

import assert from "node:assert/strict";
import {
  assertNoDeletedEntrypointReferences,
  expandProfile,
  formatPlanList,
  hostMatches,
  planProfile,
} from "./lib/check-runner.mjs";

const catalog = {
  profiles: {
    pr: {
      description: "pr",
      steps: [
        { name: "lint", argv: ["node", "scripts/lint-scripts.mjs", "--profile", "pr"] },
      ],
    },
    daily: {
      description: "daily",
      includes: ["pr"],
      steps: [
        { name: "native", argv: ["moon", "test", "moui/core", "--target", "native"] },
        { name: "mac", host: "darwin", argv: ["moon", "test", "moui/backend/macos", "--target", "native"] },
        { name: "not windows", host: "non-windows", argv: ["node", "scripts/check.mjs", "--profile", "pr"] },
      ],
    },
  },
};

{
  const steps = expandProfile(catalog.profiles, "daily");
  assert.deepEqual(steps.map(step => step.name), ["lint", "native", "mac", "not windows"]);
}

{
  assert.equal(hostMatches("darwin", "darwin"), true);
  assert.equal(hostMatches("darwin", "linux"), false);
  assert.equal(hostMatches("non-windows", "linux"), true);
  assert.equal(hostMatches("non-windows", "win32"), false);
}

{
  const plan = planProfile({ catalog, profile: "daily", platform: "linux" });
  assert.equal(plan.profile, "daily");
  assert.equal(plan.host, "linux");
  assert.equal(plan.stepCount, 4);
  assert.deepEqual(plan.steps.map(step => step.skipped), [false, false, true, false]);
  assert.match(JSON.stringify(plan), /"profile":"daily"/);
  assert.deepEqual(formatPlanList(plan), [
    "daily (linux)",
    "run: lint: node scripts/lint-scripts.mjs --profile pr",
    "run: native: moon test moui/core --target native",
    "skip: mac: moon test moui/backend/macos --target native",
    "run: not windows: node scripts/check.mjs --profile pr",
  ]);
}

{
  assert.throws(
    () => expandProfile(catalog.profiles, "missing"),
    /Unknown profile: missing/,
  );
  assert.throws(
    () => expandProfile({
      a: { includes: ["b"], steps: [{ name: "a", argv: ["true"] }] },
      b: { includes: ["a"], steps: [{ name: "b", argv: ["true"] }] },
    }, "a"),
    /Profile include cycle: a -> b -> a/,
  );
}

{
  assert.throws(
    () => assertNoDeletedEntrypointReferences({
      profiles: {
        pr: {
          steps: [
            { name: "bad", argv: ["sh", "scripts/dev-check.sh"] },
          ],
        },
      },
    }),
    /pr\.steps\[0\]\.argv references deleted entrypoint: scripts\/dev-check\.sh/,
  );
}

console.log("check runner tests: ok");
