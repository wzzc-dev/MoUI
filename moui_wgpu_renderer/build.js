const { spawnSync } = require("child_process");

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

function linuxFontconfigCflags() {
  if (process.platform !== "linux") {
    return "";
  }
  return runPkgConfig(["fontconfig", "freetype2", "harfbuzz"], "--cflags");
}

function main() {
  const linkConfigs = [
    {
      package: "wzzc-dev/moui_wgpu_renderer/directwrite",
      link_flags: "-lz",
    },
  ];
  if (process.platform === "linux") {
    linkConfigs.push({
      package: "wzzc-dev/moui_wgpu_renderer/fontconfig",
      link_flags: "-lfontconfig -lharfbuzz -lfreetype -lz",
    });
  }
  console.log(
    JSON.stringify({
      vars: {
        MOUI_LINUX_FONTCONFIG_STUB_CC_FLAGS: linuxFontconfigCflags(),
      },
      link_configs: linkConfigs,
    }),
  );
}

main();
