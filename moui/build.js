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

function shellPath(value) {
  const text = String(value || "");
  if (/^[A-Za-z0-9_./:\\-]+$/.test(text)) {
    return text;
  }
  return JSON.stringify(text);
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

function prependMissingDefine(flags, define) {
  const text = String(flags || "").trim();
  if (text.split(/\s+/).includes(define)) {
    return text;
  }
  return text ? `${define} ${text}` : define;
}

function linuxWebKitGtkFlags(config) {
  const explicitStub = configEnvValue(
    config,
    "MOUI_LINUX_WEBKITGTK_STUB_CC_FLAGS",
  );
  const explicitLink = configEnvValue(
    config,
    "MOUI_LINUX_WEBKITGTK_CC_LINK_FLAGS",
  );
  if (explicitStub || explicitLink) {
    return {
      stubCcFlags: prependMissingDefine(
        explicitStub,
        "-DMOUI_LINUX_ENABLE_WEBKITGTK",
      ),
      linkFlags: explicitLink,
    };
  }
  if (!truthy(configEnvValue(config, "MOUI_LINUX_ENABLE_WEBKITGTK"))) {
    return { stubCcFlags: "", linkFlags: "" };
  }
  for (const webkitPackage of ["webkit2gtk-4.1", "webkit2gtk-4.0"]) {
    const packages = ["gtk+-3.0", webkitPackage];
    const cflags = runPkgConfig(packages, "--cflags");
    const libs = runPkgConfig(packages, "--libs");
    if (cflags && libs) {
      return {
        stubCcFlags: `-DMOUI_LINUX_ENABLE_WEBKITGTK ${cflags}`,
        linkFlags: libs,
      };
    }
  }
  throw new Error(
    "MOUI_LINUX_ENABLE_WEBKITGTK is set, but pkg-config could not find gtk+-3.0 with webkit2gtk-4.1 or webkit2gtk-4.0.",
  );
}

function windowsWebView2Flags(config) {
  const explicitStub = configEnvValue(
    config,
    "MOUI_WINDOWS_WEBVIEW2_STUB_CC_FLAGS",
  );
  const explicitLink = configEnvValue(
    config,
    "MOUI_WINDOWS_WEBVIEW2_CC_LINK_FLAGS",
  );
  if (explicitStub || explicitLink) {
    return {
      stubCcFlags: prependMissingDefine(
        explicitStub,
        "-DMOUI_WINDOWS_ENABLE_WEBVIEW2",
      ),
      linkFlags: explicitLink,
    };
  }
  if (!truthy(configEnvValue(config, "MOUI_WINDOWS_ENABLE_WEBVIEW2"))) {
    return { stubCcFlags: "", linkFlags: "" };
  }
  const includeDir = configEnvValue(config, "MOUI_WINDOWS_WEBVIEW2_INCLUDE");
  const linkFlags = configEnvValue(config, "MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS");
  if (!includeDir || !linkFlags) {
    throw new Error(
      "MOUI_WINDOWS_ENABLE_WEBVIEW2 requires MOUI_WINDOWS_WEBVIEW2_INCLUDE and MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS, or explicit MOUI_WINDOWS_WEBVIEW2_STUB_CC_FLAGS/MOUI_WINDOWS_WEBVIEW2_CC_LINK_FLAGS.",
    );
  }
  return {
    stubCcFlags: `-DMOUI_WINDOWS_ENABLE_WEBVIEW2 -I${shellPath(includeDir)}`,
    linkFlags,
  };
}

function main() {
  const config = readJsonFromStdin();
  const windows = windowsWebView2Flags(config);
  const linux = linuxWebKitGtkFlags(config);
  const linkConfigs = [];
  if (windows.linkFlags) {
    linkConfigs.push({
      package: "wzzc-dev/moui/backend/windows",
      link_flags: windows.linkFlags,
    });
  }
  if (linux.linkFlags) {
    linkConfigs.push({
      package: "wzzc-dev/moui/backend/linux",
      link_flags: linux.linkFlags,
    });
  }
  console.log(
    JSON.stringify({
      vars: {
        MOUI_WINDOWS_WEBVIEW2_STUB_CC_FLAGS: windows.stubCcFlags,
        MOUI_WINDOWS_WEBVIEW2_CC_LINK_FLAGS: windows.linkFlags,
        MOUI_LINUX_WEBKITGTK_STUB_CC_FLAGS: linux.stubCcFlags,
        MOUI_LINUX_WEBKITGTK_CC_LINK_FLAGS: linux.linkFlags,
      },
      link_configs: linkConfigs,
    }),
  );
}

main();
