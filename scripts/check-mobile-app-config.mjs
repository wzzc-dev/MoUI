#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { readMobileApps } from "../moui/scripts/mobile/app-config.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const validAndroidApplicationId = value => /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/.test(value);
const validBundleId = value => /^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/.test(value);
const validNativeLibrary = value => /^[A-Za-z0-9_]+$/.test(value);

const requirePath = (failures, label, path) => {
  const absolute = resolve(repoRoot, path);
  if (!existsSync(absolute)) failures.push(`${label} does not exist: ${path}`);
};

const exampleMobileAppIds = () => {
  const examplesDir = join(repoRoot, "examples");
  if (!existsSync(examplesDir)) return [];
  return readdirSync(examplesDir, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .map(entry => join(examplesDir, entry.name, "mobile.json"))
    .filter(path => existsSync(path))
    .map(path => JSON.parse(readFileSync(path, "utf8")).id)
    .sort();
};

const validate = apps => {
  const failures = [];
  for (const [appId, app] of Object.entries(apps)) {
    requirePath(failures, `${appId}.appPackage`, app.appPackage);
    if (app.android) {
      requirePath(failures, `${appId}.android.moonPackage`, app.android.moonPackage);
      requirePath(failures, `${appId}.androidApp`, join("examples", appId, "android_app"));
      if (!validAndroidApplicationId(app.android.applicationId)) {
        failures.push(`${appId}.android.applicationId is not a valid Android application id`);
      }
      if (!validNativeLibrary(app.android.nativeLibrary)) {
        failures.push(`${appId}.android.nativeLibrary must contain only letters, numbers, and underscores`);
      }
      if (!app.mobile.supportsScroll && app.android.exports.dispatchScroll) {
        failures.push(`${appId}.android.exports.dispatchScroll is internal-only and should be omitted when supportsScroll is false`);
      }
    }
    if (app.ios) {
      requirePath(failures, `${appId}.ios.moonPackage`, app.ios.moonPackage);
      requirePath(failures, `${appId}.ios.infoPlist`, app.ios.infoPlist);
      requirePath(failures, `${appId}.iosApp`, join("examples", appId, "ios_app"));
      if (!validBundleId(app.ios.bundleId)) {
        failures.push(`${appId}.ios.bundleId is not a valid bundle id`);
      }
      if (!app.mobile.supportsScroll && app.ios.exports.dispatchScroll) {
        failures.push(`${appId}.ios.exports.dispatchScroll is internal-only and should be omitted when supportsScroll is false`);
      }
    }
    if (app.harmonyos) {
      requirePath(failures, `${appId}.harmonyos.moonPackage`, app.harmonyos.moonPackage);
      requirePath(failures, `${appId}.harmonyosApp`, join("examples", appId, "harmonyos_app"));
      if (!validBundleId(app.harmonyos.bundleName)) {
        failures.push(`${appId}.harmonyos.bundleName is not a valid bundle name`);
      }
      if (!validNativeLibrary(app.harmonyos.nativeLibrary)) {
        failures.push(`${appId}.harmonyos.nativeLibrary must contain only letters, numbers, and underscores`);
      }
      if (!app.mobile.supportsScroll && app.harmonyos.exports.dispatchScroll) {
        failures.push(`${appId}.harmonyos.exports.dispatchScroll is internal-only and should be omitted when supportsScroll is false`);
      }
    }
  }
  return failures;
};

try {
  const apps = readMobileApps({
    workspaceRoot: repoRoot,
    mouiRoot: join(repoRoot, "moui"),
    skiaRoot: join(repoRoot, "moui_skia"),
    appIds: exampleMobileAppIds(),
  });
  const failures = validate(apps);
  if (failures.length > 0) {
    for (const failure of failures) console.error(`[moui-mobile-config] ${failure}`);
    process.exit(1);
  }
  const appIds = Object.keys(apps).sort().join(", ");
  console.log(`[moui-mobile-config] validated ${Object.keys(apps).length} mobile app(s): ${appIds}`);
} catch (error) {
  console.error(`[moui-mobile-config] ${error.message}`);
  process.exit(1);
}
