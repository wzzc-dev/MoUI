const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

function readJsonFromStdin() {
  try {
    const input = fs.readFileSync(0, "utf8").trim();
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
  return !enabled || !falsy(enabled);
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

function main() {
  const config = readJsonFromStdin();
  const skiaVars = shouldConfigureSkia(config) ? mouiSkiaPrebuildVars(config) : {};
  const stubFlags = configEnvValue(config, "MOUI_SKIA_STUB_CC_FLAGS") ||
    skiaVars.MOUI_SKIA_STUB_CC_FLAGS || "";
  const linkFlags = configEnvValue(config, "MOUI_SKIA_CC_LINK_FLAGS") ||
    skiaVars.MOUI_SKIA_CC_LINK_FLAGS || "";
  console.log(
    JSON.stringify({
      vars: {
        MOUI_SKIA_STUB_CC_FLAGS: shouldConfigureSkia(config) ? stubFlags : "",
        MOUI_SKIA_CC_LINK_FLAGS: shouldConfigureSkia(config) ? linkFlags : "",
      },
      // Package cc-link-flags cover binding-local tests but do not propagate
      // through the renderer to final is-main links.
      link_configs: linkFlags
        ? [{ package: "wzzc-dev/moui_skia_renderer", link_flags: linkFlags }]
        : [],
    }),
  );
}

main();
