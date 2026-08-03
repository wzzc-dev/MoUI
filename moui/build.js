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

function androidHostLinkFlags(config) {
  return configEnvValue(config, "MOUI_SKIA_PLATFORM") === "android"
    ? androidBackendHostFlags
    : "";
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

function skiaStubCcFlags(config, prebuildVars) {
  if (!shouldConfigureSkia(config)) {
    return "";
  }
  const explicit = configEnvValue(config, "MOUI_SKIA_STUB_CC_FLAGS");
  if (explicit) {
    return explicit;
  }
  return prebuildVars.MOUI_SKIA_STUB_CC_FLAGS || "";
}

function skiaCcLinkFlags(config, prebuildVars) {
  const explicit = configEnvValue(config, "MOUI_SKIA_CC_LINK_FLAGS");
  if (explicit) {
    return explicit;
  }
  if (!shouldConfigureSkia(config)) {
    return "";
  }
  return prebuildVars.MOUI_SKIA_CC_LINK_FLAGS || "";
}

// Final is-main links do not reliably inherit library package `cc-link-flags`.
// Expose host/renderer system libraries via prebuild link_configs (same pattern
// as window/* and moui_skia/native) so example entrypoints can stay free of
// platform boilerplate and only use an empty cc-link-flags override when the
// Moon toolchain would otherwise pick tcc -run.
const macosBackendHostFlags =
  "-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -framework CoreGraphics -framework CoreFoundation -lz -lobjc";
const linuxBackendHostFlags = "-lz";
const androidBackendHostFlags = "-landroid -llog";
const linuxFontconfigLinkFlags = "-lfontconfig -lharfbuzz -lfreetype -lz";
const windowsDirectWriteLinkFlags = "-lz";

function appendLinkFlags(base, extra) {
  if (!extra) return base || "";
  if (!base) return extra;
  return `${base} ${extra}`;
}

function pushLinkConfig(configs, packageName, linkFlags) {
  if (!packageName || !linkFlags) {
    return;
  }
  configs.push({
    package: packageName,
    link_flags: linkFlags,
  });
}

function macosLinkConfigs() {
  if (process.platform !== "darwin") {
    return [];
  }
  const configs = [];
  pushLinkConfig(configs, "wzzc-dev/moui/backend/macos", macosBackendHostFlags);
  return configs;
}

function linuxLinkConfigs(linuxGlib) {
  // Always emit the static host flags. glib libs are optional on non-Linux
  // hosts (pkg-config empty) but must be merged into backend/linux when present.
  const configs = [];
  pushLinkConfig(
    configs,
    "wzzc-dev/moui/backend/linux",
    appendLinkFlags(linuxBackendHostFlags, linuxGlib.linkFlags),
  );
  // fontconfig/FreeType are Linux-only; the C stub already no-ops off Linux, so
  // avoid requiring -lfontconfig when compiling/tests run on macOS/Windows.
  if (process.platform === "linux") {
    pushLinkConfig(
      configs,
      "wzzc-dev/moui/render/wgpu/fontconfig",
      linuxFontconfigLinkFlags,
    );
  }
  return configs;
}

function windowsLinkConfigs(skiaCcLink) {
  const configs = [];
  pushLinkConfig(configs, "wzzc-dev/moui/render/skia", skiaCcLink);
  pushLinkConfig(
    configs,
    "wzzc-dev/moui/render/wgpu/directwrite",
    windowsDirectWriteLinkFlags,
  );
  return configs;
}

function main() {
  const config = readJsonFromStdin();
  const linuxGlib = linuxGlibFlags(config);
  const skiaVars = shouldConfigureSkia(config) ? mouiSkiaPrebuildVars(config) : {};
  const skiaStub = skiaStubCcFlags(config, skiaVars);
  const skiaCcLink = skiaCcLinkFlags(config, skiaVars);
  const linkConfigs = [
    ...macosLinkConfigs(),
    ...linuxLinkConfigs(linuxGlib),
    ...windowsLinkConfigs(skiaCcLink),
  ];
  console.log(
    JSON.stringify({
      vars: {
        MOUI_LINUX_GLIB_STUB_CC_FLAGS: linuxGlib.stubCcFlags,
        MOUI_LINUX_GLIB_CC_LINK_FLAGS: linuxGlib.linkFlags,
        MOUI_SKIA_STUB_CC_FLAGS: skiaStub,
        MOUI_SKIA_CC_LINK_FLAGS: skiaCcLink,
        MOUI_ANDROID_HOST_LINK_FLAGS: androidHostLinkFlags(config),
        MOUI_MACOS_BACKEND_HOST_LINK_FLAGS: macosBackendHostFlags,
        MOUI_LINUX_BACKEND_HOST_LINK_FLAGS: appendLinkFlags(
          linuxBackendHostFlags,
          linuxGlib.linkFlags,
        ),
      },
      link_configs: linkConfigs,
    }),
  );
}

main();
