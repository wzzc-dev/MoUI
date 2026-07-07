import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";

export const readCheckCatalog = catalogPath => JSON.parse(readFileSync(catalogPath, "utf8"));

export const deletedEntrypointToken = value =>
  value.includes("dev-check.sh") ||
  value.includes("dev_check.ps1") ||
  value.includes("conformance-check.sh");

export const findDeletedEntrypointReferences = catalog => {
  const failures = [];
  for (const [profileName, profile] of Object.entries(catalog.profiles ?? {})) {
    for (const [stepIndex, step] of (profile.steps ?? []).entries()) {
      for (const arg of step.argv ?? []) {
        if (typeof arg === "string" && deletedEntrypointToken(arg)) {
          failures.push(`${profileName}.steps[${stepIndex}].argv references deleted entrypoint: ${arg}`);
        }
      }
    }
  }
  return failures;
};

export const assertNoDeletedEntrypointReferences = catalog => {
  const failures = findDeletedEntrypointReferences(catalog);
  if (failures.length > 0) {
    throw new Error(failures.join("\n"));
  }
};

export const hostName = (platform = process.platform) => {
  if (platform === "darwin") return "darwin";
  if (platform === "linux") return "linux";
  if (platform === "win32") return "windows";
  return platform;
};

export const hostMatches = (host, platform = process.platform) => {
  if (!host || host === "any") return true;
  if (host === "non-windows") return hostName(platform) !== "windows";
  return host === hostName(platform);
};

export const expandProfile = (profiles, name, seen = []) => {
  const selected = profiles[name];
  if (!selected) {
    throw new Error(`Unknown profile: ${name}`);
  }
  if (seen.includes(name)) {
    throw new Error(`Profile include cycle: ${[...seen, name].join(" -> ")}`);
  }
  const steps = [];
  for (const included of selected.includes ?? []) {
    steps.push(...expandProfile(profiles, included, [...seen, name]));
  }
  for (const step of selected.steps ?? []) {
    steps.push(step);
  }
  return steps;
};

export const planProfile = ({ catalog, profile, platform = process.platform }) => {
  assertNoDeletedEntrypointReferences(catalog);
  const profiles = catalog.profiles ?? {};
  const selectedSteps = expandProfile(profiles, profile);
  const plannedSteps = selectedSteps.map(step => ({
    name: step.name,
    host: step.host ?? "any",
    argv: step.argv,
    skipped: !hostMatches(step.host, platform),
  }));
  return {
    profile,
    host: hostName(platform),
    stepCount: plannedSteps.length,
    steps: plannedSteps,
  };
};

export const formatPlanList = plan => {
  const lines = [`${plan.profile} (${plan.host})`];
  for (const step of plan.steps) {
    const marker = step.skipped ? "skip" : "run";
    lines.push(`${marker}: ${step.name}: ${step.argv.join(" ")}`);
  }
  return lines;
};

export const ensureWindowSubmodule = repoRoot => {
  const windowMod = resolve(repoRoot, "window/moon.mod");
  if (existsSync(windowMod)) return;
  console.log("\n==> Initializing window submodule...");
  const result = spawnSync("git", ["submodule", "update", "--init", "window"], {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (result.status !== 0 || result.error) {
    if (result.error) console.error(result.error.message);
    process.exit(result.status ?? 1);
  }
};

export const defaultCheckEnv = (env = process.env) => ({
  ...env,
  MOUI_SKIA_DISABLE_PREBUILD_SKIA: env.MOUI_SKIA_DISABLE_PREBUILD_SKIA ?? "1",
});
