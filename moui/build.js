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

// `backend/linux` drives the GLib main loop and the AT-SPI GDBus host from the
// same C stub set, so gio-2.0 must join glib-2.0 in both flag sets. gio-2.0
// pulls gobject-2.0 and glib-2.0 into `--libs`, and its `--cflags` is a
// superset of the glib-2.0 include path.
const linuxGlibPackages = ["glib-2.0", "gio-2.0"];

function linuxGlibFlags(config) {
  const explicitStub = configEnvValue(config, "MOUI_LINUX_GLIB_STUB_CC_FLAGS");
  const explicitLink = configEnvValue(config, "MOUI_LINUX_GLIB_CC_LINK_FLAGS");
  if (explicitStub || explicitLink) {
    return { stubCcFlags: explicitStub, linkFlags: explicitLink };
  }
  return {
    stubCcFlags: runPkgConfig(linuxGlibPackages, "--cflags"),
    linkFlags: runPkgConfig(linuxGlibPackages, "--libs"),
  };
}

const macosBackendHostFlags =
  "-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -framework CoreGraphics -framework CoreFoundation -lz";
const linuxBackendHostFlags = "-lz";
const androidBackendHostFlags = "-landroid -llog";
const windowsBackendHostLibs = [
  "comdlg32",
  "shell32",
  "ole32",
  "oleaut32",
  "uiautomationcore",
  "user32",
  "gdi32",
  "kernel32",
  "advapi32",
  "dwmapi",
  "imm32",
  "shcore",
];
const windowsBackendUsesMsvc =
  Boolean(process.env.VSCMD_VER || process.env.VCINSTALLDIR) ||
  (process.env.CC || "").toLowerCase().endsWith("cl.exe") ||
  (process.env.CC || "").toLowerCase() === "cl" ||
  process.platform === "win32";
const windowsBackendHostFlags = windowsBackendUsesMsvc
  ? windowsBackendHostLibs.map((lib) => `${lib}.lib`).join(" ")
  : windowsBackendHostLibs.map((lib) => `-l${lib}`).join(" ");

function appendLinkFlags(base, extra) {
  if (!extra) return base || "";
  if (!base) return extra;
  return `${base} ${extra}`;
}

function pushLinkConfig(configs, packageName, linkFlags) {
  if (packageName && linkFlags) {
    configs.push({ package: packageName, link_flags: linkFlags });
  }
}

function main() {
  const config = readJsonFromStdin();
  const linuxGlib = linuxGlibFlags(config);
  const linkConfigs = [];
  if (process.platform === "darwin") {
    pushLinkConfig(
      linkConfigs,
      "wzzc-dev/moui/backend/macos",
      macosBackendHostFlags,
    );
  }
  if (process.platform === "win32") {
    pushLinkConfig(
      linkConfigs,
      "wzzc-dev/moui/backend/windows",
      windowsBackendHostFlags,
    );
  }
  pushLinkConfig(
    linkConfigs,
    "wzzc-dev/moui/backend/linux",
    appendLinkFlags(linuxBackendHostFlags, linuxGlib.linkFlags),
  );
  console.log(
    JSON.stringify({
      vars: {
        MOUI_LINUX_GLIB_STUB_CC_FLAGS: linuxGlib.stubCcFlags,
        MOUI_LINUX_GLIB_CC_LINK_FLAGS: linuxGlib.linkFlags,
        MOUI_ANDROID_HOST_LINK_FLAGS:
          configEnvValue(config, "MOUI_SKIA_PLATFORM") === "android"
            ? androidBackendHostFlags
            : "",
        MOUI_MACOS_BACKEND_HOST_LINK_FLAGS: macosBackendHostFlags,
        MOUI_LINUX_BACKEND_HOST_LINK_FLAGS: appendLinkFlags(
          linuxBackendHostFlags,
          linuxGlib.linkFlags,
        ),
        MOUI_WINDOWS_BACKEND_HOST_LINK_FLAGS: windowsBackendHostFlags,
      },
      link_configs: linkConfigs,
    }),
  );
}

main();
