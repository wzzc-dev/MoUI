#!/usr/bin/env node

import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const testDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(testDir, "../../../..");
const read = path => readFileSync(resolve(repoRoot, path), "utf8");
const contains = (source, value, path) => assert.ok(source.includes(value), `${path} must contain ${value}`);
const excludes = (source, value, path) => assert.ok(!source.includes(value), `${path} must not contain ${value}`);
const escapeRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const requiresRuntimeCallLock = (source, functionName, path) => {
  const pattern = new RegExp(
    `\\b${escapeRegExp(functionName)}\\s*\\([^)]*\\)\\s*\\{\\s*` +
      "RuntimeCallLock\\s+runtime_call_lock\\(g_runtime_call_mutex\\);",
  );
  assert.match(source, pattern, `${path}: ${functionName} must serialize Mobile Runtime ABI calls`);
};

test("canonical HarmonyOS shell owns ABI, XComponent, Host Wire, and plugin invariants", () => {
  const indexPath = "moui/mobile/harmonyos/template/entry/src/main/ets/pages/Index.ets";
  const rootPath = "moui/mobile/harmonyos/template/entry/src/main/ets/moui/MoUIRoot.ets";
  const pluginsPath = "moui/mobile/harmonyos/template/entry/src/main/ets/moui/MoUIPlugins.ets";
  const bridgePath = "moui/mobile/harmonyos/src/main/cpp/moui_mobile_harmonyos_napi.cpp";
  const cmakePath = "moui/mobile/harmonyos/cmake/MoUIMobileHarmonyOS.cmake";
  const buildPath = "moui/scripts/mobile/build-harmonyos-hap.sh";
  const repositoryBuildPath = "scripts/build-mobile-harmonyos-hap.sh";
  const index = read(indexPath);
  const root = read(rootPath);
  const plugins = read(pluginsPath);
  const bridge = read(bridgePath);
  const cmake = read(cmakePath);
  const build = read(buildPath);
  const repositoryBuild = read(repositoryBuildPath);

  contains(index, "MoUIRoot()", indexPath);
  contains(root, "libraryname: 'moui_mobile_harmonyos'", rootPath);
  contains(root, "sessionGeneration", rootPath);
  contains(root, "platform-views", rootPath);
  contains(root, "platform-channel", rootPath);
  for (const forbidden of ["onAreaChange", ".onTouch", "attachSurface", "dispatchPointer", "detachSurface"]) {
    excludes(root, forbidden, rootPath);
  }
  for (const forbidden of ["a11ySmoke", "serviceSmoke", "MOUI_MOBILE_A11Y_SMOKE"]) {
    excludes(root, forbidden, rootPath);
    excludes(bridge, forbidden, bridgePath);
  }

  contains(plugins, "`${kind.length}:${kind}${id}`", pluginsPath);
  contains(plugins, "Math.max(left, clip.origin.x)", pluginsPath);
  contains(plugins, "payload.placements.forEach", pluginsPath);
  contains(root, ".zIndex(hosted.zIndex)", rootPath);
  contains(plugins, "kind: 'platform-view'", pluginsPath);
  contains(plugins, "completion.invalidate()", pluginsPath);
  contains(plugins, "task.cancel()", pluginsPath);
  contains(plugins, "this.pending.delete(key)", pluginsPath);
  contains(plugins, "late/rejected PlatformChannel completion", pluginsPath);

  contains(bridge, "moui_mobile_get_runtime_api_v1()", bridgePath);
  contains(bridge, "moui_mobile_runtime_api_v1_is_compatible", bridgePath);
  contains(bridge, "OwnedUtf8Buffer", bridgePath);
  contains(bridge, "value_.release(value_.release_context, value_.data, value_.length)", bridgePath);
  contains(bridge, "std::recursive_mutex g_runtime_call_mutex", bridgePath);
  contains(bridge, "using RuntimeCallLock = std::lock_guard<std::recursive_mutex>", bridgePath);
  for (const functionName of [
    "ensure_runtime_initialized",
    "attach_or_resize",
    "on_surface_destroyed",
    "dispatch_touch_event",
    "napi_frame_tick",
    "napi_take_host_updates",
    "napi_renderer_configure",
    "napi_renderer_status",
    "napi_dispatch_host_response",
    "napi_dispatch_text_input",
    "napi_dispatch_command",
    "napi_dispatch_accessibility",
    "napi_complete_clipboard",
    "napi_destroy_application",
    "MOUI_MOBILE_SMOKE_RENDER_FRAME",
  ]) {
    requiresRuntimeCallLock(bridge, functionName, bridgePath);
  }
  contains(bridge, "OH_NativeXComponent_RegisterCallback", bridgePath);
  contains(bridge, "source=native-xcomponent", bridgePath);
  for (const forbidden of ["moonbit_string_t", "moonbit_runtime_init", "MOUI_MOBILE_ATTACH_SURFACE", "napi_attach_surface", "napi_dispatch_pointer", "napi_resize"]) {
    excludes(bridge, forbidden, bridgePath);
  }
  contains(cmake, "mobile/runtime/moui_mobile_runtime_v1.cpp", cmakePath);
  contains(cmake, '"${MOUI_ROOT}/mobile/include"', cmakePath);
  contains(build, "resolve-managed-shell.mjs", buildPath);
  contains(build, "--ejected-shell", buildPath);
  contains(build, "--ejected-shell and --legacy-shell are mutually exclusive", buildPath);
  contains(build, "--ejected-shell requires a versioned .moui-shell.json", buildPath);
  contains(build, "--legacy-shell", buildPath);
  contains(build, "harmonyos-app-owned-shell", buildPath);
  contains(repositoryBuild, 'legacy_shell=0', repositoryBuildPath);
  contains(repositoryBuild, 'if [ "$legacy_shell" -eq 1 ]', repositoryBuildPath);
  contains(repositoryBuild, '--harmonyos-project "$harmonyos_project"', repositoryBuildPath);
  contains(repositoryBuild,
    '--app-config "$repo_root/moui/mobile/legacy/fixtures/$app.mobile.json"',
    repositoryBuildPath);

  const profile = read("moui/mobile/harmonyos/template/build-profile.json5");
  contains(profile, '"targetSdkVersion": "6.0.1(21)"', "build-profile.json5");
  contains(profile, '"compatibleSdkVersion": "6.0.0(20)"', "build-profile.json5");
  const packageJson = read("moui/mobile/harmonyos/template/oh-package.json5");
  contains(packageJson, '"modelVersion": "6.0.1"', "oh-package.json5");
});

test("legacy fixture honors the mobile shell CI artifact root", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-legacy-root-"));
  const helper = resolve(repoRoot, "moui/mobile/harmonyos/tests/build-legacy-fixture.sh");
  try {
    const result = spawnSync("bash", ["-x", helper, "--help"], {
      encoding: "utf8",
      env: {
        ...process.env,
        MOUI_MOBILE_SHELL_CI_ROOT: tempRoot,
      },
    });
    assert.equal(result.status, 0, result.stderr);
    const trace = `${result.stdout}\n${result.stderr}`;
    const legacyRoot = join(tempRoot, "harmonyos/legacy");
    contains(trace, `--build-dir ${legacyRoot}`, "legacy fixture trace");
    contains(
      trace,
      `--output ${join(legacyRoot, "MoUIShowcase.hap")}`,
      "legacy fixture trace",
    );
    excludes(
      trace,
      join(repoRoot, "artifacts/harmonyos/showcase-legacy-fixture"),
      "legacy fixture trace",
    );
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

test("managed resolver stages identity, resources, and generated plugin registry", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-managed-"));
  const sourceConfigPath = resolve(repoRoot, "examples/showcase/mobile.json");
  const configPath = resolve(
    repoRoot,
    `examples/showcase/.mobile-harmonyos-managed-test-${process.pid}.json`,
  );
  try {
    const config = JSON.parse(readFileSync(sourceConfigPath, "utf8"));
    config.mobile.plugins = ["moui/mobile/test-probe/moui.plugin.json"];
    writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
    const output = join(tempRoot, "shell");
    execFileSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", repoRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", configPath,
      "--renderer", "skia-gpu",
      "--output", output,
    ], { stdio: "pipe" });

    const appScope = JSON.parse(readFileSync(join(output, "AppScope/app.json5"), "utf8"));
    assert.equal(appScope.app.bundleName, "dev.wzzc.moui.showcase");
    const generatedConfig = readFileSync(
      join(output, "entry/src/main/ets/moui/MoUIGeneratedConfig.ets"),
      "utf8",
    );
    contains(generatedConfig, 'renderer: "skia-gpu"', "generated config");
    contains(generatedConfig, "fullscreen: true", "generated config");
    const generatedPlugins = readFileSync(
      join(output, "entry/src/main/ets/moui/MoUIGeneratedPlugins.ets"),
      "utf8",
    );
    contains(generatedPlugins, "MoUIMobileTestProbePlugin as MoUIGeneratedPlugin0", "generated plugins");
    contains(generatedPlugins, "new MoUIGeneratedPlugin0()", "generated plugins");
    const managed = JSON.parse(readFileSync(join(output, ".moui-managed-shell.json"), "utf8"));
    assert.equal(managed.shellApiVersion, 1);
    assert.equal(managed.runtimeAbiVersion, 1);
    assert.equal(managed.targetSdkVersion, 21);
    assert.deepEqual(managed.plugins.map(plugin => plugin.id), ["dev.wzzc.moui.mobile.test-probe"]);
    assert.equal(managed.plugins[0].sources.length, 1);
    assert.ok(
      readFileSync(join(output, managed.plugins[0].sources[0]), "utf8")
        .includes("class MoUIMobileTestProbePlugin"),
    );
    assert.equal(managed.plugins[0].resources.length, 1);
    assert.ok(
      readFileSync(join(output, managed.plugins[0].resources[0], "test-probe.json"), "utf8")
        .includes("MoUI test probe"),
    );
  } finally {
    rmSync(configPath, { force: true });
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

test("managed resolver maps permission capabilities to HarmonyOS declarations", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-permissions-"));
  const config = JSON.parse(read("examples/showcase/mobile.json"));
  config.mobile.permissions = [
    "camera",
    "microphone",
    "location",
    "photos",
    "notifications",
    "clipboard",
  ];
  const configPath = join(tempRoot, "mobile.json");
  const output = join(tempRoot, "shell");
  try {
    writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
    execFileSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", tempRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", configPath,
      "--renderer", "auto",
      "--output", output,
    ], { stdio: "pipe" });

    const module = JSON.parse(readFileSync(join(output, "entry/src/main/module.json5"), "utf8"));
    const permissions = module.module.requestPermissions;
    assert.deepEqual(permissions.map(permission => permission.name), [
      "ohos.permission.APPROXIMATELY_LOCATION",
      "ohos.permission.CAMERA",
      "ohos.permission.LOCATION",
      "ohos.permission.MICROPHONE",
      "ohos.permission.READ_IMAGEVIDEO",
      "ohos.permission.READ_PASTEBOARD",
    ]);
    for (const capability of config.mobile.permissions) {
      assert.ok(
        !permissions.some(permission => permission.name === capability),
        `managed module must not contain raw capability id ${capability}`,
      );
    }
    for (const permission of permissions) {
      assert.match(permission.reason, /^\$string:permission_/);
      assert.deepEqual(permission.usedScene, {
        abilities: ["EntryAbility"],
        when: "inuse",
      });
    }
    const canonicalModule = JSON.parse(read(
      "moui/mobile/harmonyos/template/entry/src/main/module.json5",
    ));
    assert.deepEqual(
      permissions.find(permission => permission.name === "ohos.permission.READ_PASTEBOARD"),
      canonicalModule.module.requestPermissions.find(
        permission => permission.name === "ohos.permission.READ_PASTEBOARD",
      ),
    );

    const strings = JSON.parse(readFileSync(
      join(output, "entry/src/main/resources/base/element/string.json"),
      "utf8",
    ));
    const stringNames = new Set(strings.string.map(item => item.name));
    for (const permission of permissions) {
      assert.ok(stringNames.has(permission.reason.slice("$string:".length)));
    }
    assert.ok(!permissions.some(permission => permission.name.includes("NOTIFICATION")));
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

test("managed resolver rejects unsupported permission capabilities before staging", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-unknown-permission-"));
  const config = JSON.parse(read("examples/showcase/mobile.json"));
  config.mobile.permissions = ["bluetooth"];
  const configPath = join(tempRoot, "mobile.json");
  const output = join(tempRoot, "shell");
  try {
    writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
    const result = spawnSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", tempRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", configPath,
      "--renderer", "auto",
      "--output", output,
    ], { encoding: "utf8" });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /does not support mobile\.permissions capability "bluetooth"/);
    assert.match(result.stderr, /eject the HarmonyOS shell/);
    assert.equal(readFileSync(configPath, "utf8"), `${JSON.stringify(config, null, 2)}\n`);
    assert.equal(existsSync(output), false);
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

test("plugin permissions require an app grant and stage through the managed target", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-plugin-permission-"));
  const pluginRoot = join(tempRoot, "plugin");
  const pluginSource = join(pluginRoot, "CameraPlugin.ets");
  const pluginManifest = {
    schemaVersion: 1,
    id: "dev.wzzc.camera-plugin",
    shellApi: 1,
    platforms: {
      harmonyos: {
        sources: ["CameraPlugin.ets"],
        resources: [],
        entry: "CameraPlugin",
      },
    },
    platformViewKinds: [],
    hostChannels: [],
    permissions: ["camera"],
  };
  const config = JSON.parse(read("examples/showcase/mobile.json"));
  config.mobile.plugins = ["plugin/moui.plugin.json"];
  const configPath = join(tempRoot, "mobile.json");
  const output = join(tempRoot, "shell");
  try {
    mkdirSync(pluginRoot, { recursive: true });
    writeFileSync(pluginSource, "export class CameraPlugin {}\n");
    writeFileSync(
      join(pluginRoot, "moui.plugin.json"),
      `${JSON.stringify(pluginManifest, null, 2)}\n`,
    );

    config.mobile.permissions = [];
    writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
    const denied = spawnSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", tempRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", configPath,
      "--renderer", "auto",
      "--output", output,
    ], { encoding: "utf8" });
    assert.notEqual(denied.status, 0);
    assert.match(denied.stderr, /requires undeclared permission "camera"/);

    config.mobile.permissions = ["camera"];
    writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
    execFileSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", tempRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", configPath,
      "--renderer", "auto",
      "--output", output,
    ], { stdio: "pipe" });
    const module = JSON.parse(readFileSync(join(output, "entry/src/main/module.json5"), "utf8"));
    assert.ok(module.module.requestPermissions.some(
      permission => permission.name === "ohos.permission.CAMERA",
    ));
    assert.match(
      readFileSync(join(output, "entry/src/main/ets/plugins/0-dev_wzzc_camera_plugin/CameraPlugin.ets"), "utf8"),
      /class CameraPlugin/,
    );
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

test("managed resolver leaves ejected permission declarations app-owned", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-ejected-permissions-"));
  const config = JSON.parse(read("examples/showcase/mobile.json"));
  config.harmonyos.shellMode = "ejected";
  const configPath = join(tempRoot, "mobile.json");
  const output = join(tempRoot, "ejected-shell");
  const modulePath = join(output, "entry/src/main/module.json5");
  const appOwnedModule = `${JSON.stringify({
    module: {
      requestPermissions: [{
        name: "vendor.permission.CUSTOM",
        reason: "$string:app_owned_reason",
      }],
    },
  }, null, 2)}\n`;
  try {
    mkdirSync(dirname(modulePath), { recursive: true });
    writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
    writeFileSync(modulePath, appOwnedModule);
    const result = spawnSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", tempRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", configPath,
      "--renderer", "auto",
      "--output", output,
    ], { encoding: "utf8" });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /shellMode=ejected; managed shell required/);
    assert.equal(readFileSync(modulePath, "utf8"), appOwnedModule);
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

test("managed resolver isolates plugin ids that normalize to the same directory", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-plugin-collision-"));
  const sourceConfigPath = resolve(repoRoot, "examples/showcase/mobile.json");
  const configPath = resolve(
    repoRoot,
    `examples/showcase/.mobile-harmonyos-plugin-collision-${process.pid}.json`,
  );
  try {
    const config = JSON.parse(readFileSync(sourceConfigPath, "utf8"));
    config.mobile.plugins = [
      "moui/mobile/harmonyos/tests/fixtures/plugin-collision/dash/moui.plugin.json",
      "moui/mobile/harmonyos/tests/fixtures/plugin-collision/underscore/moui.plugin.json",
    ];
    writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
    const output = join(tempRoot, "shell");
    execFileSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", repoRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", configPath,
      "--renderer", "auto",
      "--output", output,
    ], { stdio: "pipe" });

    const dashSource = readFileSync(
      join(output, "entry/src/main/ets/plugins/0-dev_fixture_a_b/DashPlugin.ets"),
      "utf8",
    );
    const underscoreSource = readFileSync(
      join(output, "entry/src/main/ets/plugins/1-dev_fixture_a_b/UnderscorePlugin.ets"),
      "utf8",
    );
    contains(dashSource, "plugin-id-with-dash", "dash collision fixture");
    contains(underscoreSource, "plugin-id-with-underscore", "underscore collision fixture");
    assert.equal(
      readFileSync(
        join(output, "entry/src/main/resources/rawfile/moui_plugins/0-dev_fixture_a_b/dash.txt"),
        "utf8",
      ),
      "resource-with-dash\n",
    );
    assert.equal(
      readFileSync(
        join(output, "entry/src/main/resources/rawfile/moui_plugins/1-dev_fixture_a_b/underscore.txt"),
        "utf8",
      ),
      "resource-with-underscore\n",
    );
    const managed = JSON.parse(readFileSync(join(output, ".moui-managed-shell.json"), "utf8"));
    assert.deepEqual(managed.plugins.map(plugin => plugin.id), [
      "dev.fixture.a-b",
      "dev.fixture.a_b",
    ]);
    assert.match(managed.plugins[0].sources[0], /plugins\/0-dev_fixture_a_b\//);
    assert.match(managed.plugins[1].sources[0], /plugins\/1-dev_fixture_a_b\//);
    assert.match(managed.plugins[0].resources[0], /moui_plugins\/0-dev_fixture_a_b\//);
    assert.match(managed.plugins[1].resources[0], /moui_plugins\/1-dev_fixture_a_b\//);
  } finally {
    rmSync(configPath, { force: true });
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

test("managed resolver refuses to replace an unowned output directory", () => {
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-harmonyos-output-guard-"));
  const output = join(tempRoot, "existing");
  const sentinel = join(output, "keep.txt");
  try {
    mkdirSync(output, { recursive: true });
    writeFileSync(sentinel, "owned by caller\n");
    const result = spawnSync("node", [
      resolve(repoRoot, "moui/mobile/harmonyos/resolve-managed-shell.mjs"),
      "--workspace-root", repoRoot,
      "--moui-root", resolve(repoRoot, "moui"),
      "--app", "showcase",
      "--app-config", resolve(repoRoot, "examples/showcase/mobile.json"),
      "--renderer", "auto",
      "--output", output,
    ], { encoding: "utf8" });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /refusing to replace non-managed HarmonyOS shell directory/);
    assert.equal(readFileSync(sentinel, "utf8"), "owned by caller\n");
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});
