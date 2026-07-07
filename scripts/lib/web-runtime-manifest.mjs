import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

export const writeJsonManifest = (manifestPath, manifest, label) => {
  mkdirSync(dirname(manifestPath), { recursive: true });
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`${label}: ${manifestPath}`);
};

export const validateWebRuntimeManifest = ({ manifestPath, requirePassed }) => {
  const validationArgs = ["scripts/validate-web-runtime-presentation-manifest.mjs", manifestPath];
  if (requirePassed) validationArgs.push("--require-passed");
  const validation = spawnSync(process.execPath, validationArgs, { encoding: "utf8" });
  if (validation.stdout) process.stdout.write(validation.stdout);
  if (validation.stderr) process.stderr.write(validation.stderr);
  if (validation.status !== 0) {
    process.exit(validation.status ?? 1);
  }
};
