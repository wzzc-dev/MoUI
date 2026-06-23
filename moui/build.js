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

function main() {
  const config = readJsonFromStdin();
  const linuxGlib = linuxGlibFlags(config);
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
      },
      link_configs: linkConfigs,
    }),
  );
}

main();
