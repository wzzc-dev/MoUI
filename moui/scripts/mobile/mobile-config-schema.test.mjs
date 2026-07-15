import assert from "node:assert/strict";
import test from "node:test";
import { validateMobileMetadataV2 } from "./mobile-config-schema.mjs";

const validConfig = () => ({
  schemaVersion: 2,
  id: "sample",
  displayName: "Sample",
  artifactName: "sample",
  appPackage: "app",
  shellApiVersion: 1,
  runtimeAbiVersion: 1,
  mobile: {
    renderer: "auto",
    systemUi: { fullscreen: false, statusBar: "auto" },
    orientation: "any",
    resources: ["assets/icon.png"],
    permissions: [],
    plugins: ["plugins/camera/moui.plugin.json"],
  },
  android: {
    applicationId: "dev.example.sample",
    shellMode: "managed",
    minSdk: 23,
  },
});

test("schema v2 accepts a managed shell config", () => {
  const config = validConfig();
  assert.equal(validateMobileMetadataV2(config, { appId: "sample" }), config);
});

test("schema v2 rejects unknown fields", () => {
  const config = validConfig();
  config.android.native = { exports: {} };
  assert.throws(
    () => validateMobileMetadataV2(config),
    /android: unknown field "native"/,
  );
});

test("schema v2 rejects removed supportsScroll", () => {
  const config = validConfig();
  config.mobile.supportsScroll = true;
  assert.throws(
    () => validateMobileMetadataV2(config),
    /mobile: unknown field "supportsScroll"/,
  );
});

test("schema v2 enforces deployment floors", () => {
  const config = validConfig();
  config.android.minSdk = 22;
  assert.throws(() => validateMobileMetadataV2(config), /minSdk: must be at least 23/);

  delete config.android;
  config.ios = {
    bundleId: "dev.example.sample",
    productName: "Sample",
    shellMode: "managed",
    deploymentTarget: "14.4",
  };
  assert.throws(() => validateMobileMetadataV2(config), /deploymentTarget: must be at least 15.0/);
});

test("schema v2 rejects workspace path escapes", () => {
  const config = validConfig();
  config.mobile.plugins = ["../outside/moui.plugin.json"];
  assert.throws(() => validateMobileMetadataV2(config), /must not escape the workspace/);
});
