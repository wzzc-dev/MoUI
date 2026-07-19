import assert from "node:assert/strict";
import test from "node:test";

import { validateShellMetadataV1 } from "./shell-config-schema.mjs";

const validConfig = () => ({
  schemaVersion: 1,
  id: "sample",
  displayName: "Sample",
  artifactName: "sample",
  appPackage: "app",
  shellApiVersion: 1,
  embeddingApiVersion: 1,
  shell: {
    profile: "handheld",
    renderer: "auto",
    systemUi: { fullscreen: false, statusBar: "auto" },
    orientation: "any",
    resources: ["assets/icon.png"],
    permissions: [],
    plugins: ["plugins/camera/moui.plugin.json"],
  },
  android: { applicationId: "dev.example.sample", runnerMode: "managed", minSdk: 23 },
});

test("schema v1 accepts a handheld managed shell", () => {
  const config = validConfig();
  assert.equal(validateShellMetadataV1(config, { appId: "sample" }), config);
});

test("schema v1 rejects former mobile fields and unsupported profiles", () => {
  const config = validConfig();
  config.mobile = {};
  assert.throws(() => validateShellMetadataV1(config), /unknown field "mobile"/);
  delete config.mobile;
  config.shell.profile = "desktop";
  assert.throws(() => validateShellMetadataV1(config), /profile: must be handheld/);
});

test("schema v1 enforces runner modes, platform floors, and safe paths", () => {
  const config = validConfig();
  config.android.runnerMode = "unsupported";
  assert.throws(() => validateShellMetadataV1(config), /runnerMode: must be one of managed, ejected/);
  config.android.runnerMode = "managed";
  config.android.minSdk = 22;
  assert.throws(() => validateShellMetadataV1(config), /minSdk: must be at least 23/);
  config.android.minSdk = 23;
  config.shell.plugins = ["../outside/moui.plugin.json"];
  assert.throws(() => validateShellMetadataV1(config), /must not escape the workspace/);
});
