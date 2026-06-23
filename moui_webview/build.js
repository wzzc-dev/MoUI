const { spawnSync } = require("child_process");
const path = require("path");
const fs = require("fs");

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
  // WebKitGTK not available via pkg-config — compile without it
  return { stubCcFlags: "", linkFlags: "" };
}

function autoDetectWindowsWebView2() {
  // Auto-detect WebView2 SDK from the well-known .tools/webview2/ location,
  // matching the pattern used by scripts/windows/webview2_sdk.ps1.
  // build.js lives at <repo>/moui_webview/build.js, so __dirname/.. is the repo root.
  const repoRoot = path.resolve(__dirname, "..");
  const toolsDir = path.join(repoRoot, ".tools", "webview2");
  let foundDir = null;
  try {
    if (fs.existsSync(toolsDir)) {
      const entries = fs.readdirSync(toolsDir);
      const wvDir = entries.find(function (e) {
        return e.startsWith("Microsoft.Web.WebView2.");
      });
      if (wvDir) {
        foundDir = path.join(toolsDir, wvDir);
      }
    }
  } catch (_) {
    // ignore any filesystem errors and fall through
  }
  if (!foundDir) {
    return null;
  }
  const header = path.join(foundDir, "build", "native", "include", "WebView2.h");
  const staticLib = path.join(
    foundDir,
    "build",
    "native",
    "x64",
    "WebView2LoaderStatic.lib",
  );
  if (!fs.existsSync(header) || !fs.existsSync(staticLib)) {
    return null;
  }
  // Forward-slash paths (consistent with Convert-WebView2BuildPath).
  // MSVC link.exe accepts forward slashes, and this avoids backslash
  // escaping issues in JSON serialization and shell processing.
  const includeDir = path
    .join(foundDir, "build", "native", "include")
    .replace(/\\/g, "/");
  const libPath = staticLib.replace(/\\/g, "/");
  return {
    stubCcFlags:
      "-DMOUI_WINDOWS_ENABLE_WEBVIEW2 -I" + shellPath(includeDir),
    linkFlags: shellPath(libPath) + " version.lib",
  };
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
  if (truthy(configEnvValue(config, "MOUI_WINDOWS_ENABLE_WEBVIEW2"))) {
    const includeDir = configEnvValue(
      config,
      "MOUI_WINDOWS_WEBVIEW2_INCLUDE",
    );
    const linkFlags = configEnvValue(
      config,
      "MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS",
    );
    if (!includeDir || !linkFlags) {
      throw new Error(
        "MOUI_WINDOWS_ENABLE_WEBVIEW2 requires MOUI_WINDOWS_WEBVIEW2_INCLUDE and MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS, or explicit MOUI_WINDOWS_WEBVIEW2_STUB_CC_FLAGS/MOUI_WINDOWS_WEBVIEW2_CC_LINK_FLAGS.",
      );
    }
    return {
      stubCcFlags:
        "-DMOUI_WINDOWS_ENABLE_WEBVIEW2 -I" + shellPath(includeDir),
      linkFlags,
    };
  }
  // No explicit env vars — try auto-detect from .tools/webview2/
  var auto = autoDetectWindowsWebView2();
  if (auto) {
    return auto;
  }
  // WebView2 SDK not found — compile without it
  return { stubCcFlags: "", linkFlags: "" };
}

function main() {
  const config = readJsonFromStdin();
  const windows = windowsWebView2Flags(config);
  const linux = linuxWebKitGtkFlags(config);
  const linkConfigs = [];
  if (windows.linkFlags) {
    linkConfigs.push({
      package: "wzzc-dev/moui_webview/backend/windows",
      link_flags: windows.linkFlags,
    });
  }
  if (linux.linkFlags) {
    linkConfigs.push({
      package: "wzzc-dev/moui_webview/backend/linux",
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
