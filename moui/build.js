const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

function readJsonFromStdin() {
  try {
    const input = require("fs").readFileSync(0, "utf8").trim();
    return input ? JSON.parse(input) : {};
  } catch {
    return {};
  }
}

function configEnvValue(config, key) {
  return (
    process.env[key] ||
    config?.env?.[key] ||
    config?.build?.env?.[key] ||
    config?.build_info?.env?.[key] ||
    ""
  );
}

function truthy(value) {
  return /^(1|true|yes|on)$/i.test(String(value || "").trim());
}

function falsy(value) {
  return /^(0|false|no|off)$/i.test(String(value || "").trim());
}

function targetKind(config) {
  return (
    config?.build?.target?.kind ||
    config?.build_info?.target?.kind ||
    config?.target?.kind ||
    config?.target?.backend ||
    config?.env?.MOON_TARGET ||
    ""
  );
}

function shouldConfigureSkia(config) {
  const kind = targetKind(config);
  if (kind && ["wasm", "wasm32", "wasmgc", "wasm-gc", "js"].includes(kind)) {
    return false;
  }
  if (truthy(configEnvValue(config, "MOUI_SKIA_DISABLE_PREBUILD_SKIA"))) {
    return false;
  }
  const enabled = configEnvValue(config, "MOUI_SKIA_ENABLE_PREBUILD_SKIA");
  if (enabled && falsy(enabled)) {
    return false;
  }
  return true;
}

function runPkgConfig(packages, flag) {
  const result = spawnSync("pkg-config", [flag, ...packages], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.error || result.status !== 0) {
    return "";
  }
  return result.stdout.trim();
}

function linuxGlibFlags(config) {
  const explicitStub = configEnvValue(config, "MOUI_LINUX_GLIB_STUB_CC_FLAGS");
  const explicitLink = configEnvValue(config, "MOUI_LINUX_GLIB_CC_LINK_FLAGS");
  if (explicitStub || explicitLink) {
    return { stubCcFlags: explicitStub, linkFlags: explicitLink };
  }
  // glib-2.0 is a core Linux backend dependency: linux_timer_host.c drives
  // HostTimerSource subscriptions via the GLib main loop. On non-Linux hosts
  // pkg-config will not find glib-2.0 and both flags resolve to "", which is
  // fine because the C stub body is guarded by `#ifdef __linux__`.
  return {
    stubCcFlags: runPkgConfig(["glib-2.0"], "--cflags"),
    linkFlags: runPkgConfig(["glib-2.0"], "--libs"),
  };
}

function mouiSkiaPrebuildVars(config) {
  const script = path.resolve(__dirname, "..", "moui_skia", "build.js");
  if (!fs.existsSync(script)) {
    return {};
  }
  const result = spawnSync(process.execPath, [script], {
    cwd: path.dirname(script),
    encoding: "utf8",
    input: JSON.stringify(config || {}),
    stdio: ["pipe", "pipe", "pipe"],
  });
  if (result.error) {
    throw new Error(`failed to run moui_skia prebuild: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(
      `moui_skia prebuild exited with ${result.status}\n${result.stderr}`,
    );
  }
  try {
    return JSON.parse(result.stdout).vars || {};
  } catch (error) {
    throw new Error(`failed to parse moui_skia prebuild output: ${error.message}`);
  }
}

function skiaStubCcFlags(config) {
  if (!shouldConfigureSkia(config)) {
    return "";
  }
  const explicit = configEnvValue(config, "MOUI_SKIA_STUB_CC_FLAGS");
  if (explicit) {
    return explicit;
  }
  return mouiSkiaPrebuildVars(config).MOUI_SKIA_STUB_CC_FLAGS || "";
}

function main() {
  const config = readJsonFromStdin();
  const linuxGlib = linuxGlibFlags(config);
  const skiaStub = skiaStubCcFlags(config);
  const linkConfigs = [];
  if (linuxGlib.linkFlags) {
    linkConfigs.push({
      package: "wzzc-dev/moui/backend/linux",
      link_flags: linuxGlib.linkFlags,
    });
  }
  console.log(
    JSON.stringify({
      vars: {
        MOUI_LINUX_GLIB_STUB_CC_FLAGS: linuxGlib.stubCcFlags,
        MOUI_LINUX_GLIB_CC_LINK_FLAGS: linuxGlib.linkFlags,
        MOUI_SKIA_STUB_CC_FLAGS: skiaStub,
      },
      link_configs: linkConfigs,
    }),
  );
}

main();
