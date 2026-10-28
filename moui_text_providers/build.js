const { spawnSync } = require("child_process");

const CORETEXT_DARWIN_LINK_FLAGS = [
  "-framework AppKit",
  "-framework QuartzCore",
  "-framework CoreText",
  "-framework CoreGraphics",
  "-framework Foundation",
  "-framework CoreFoundation",
  "-lz",
].join(" ");

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
      package: "wzzc-dev/moui_text_providers/directwrite",
      link_flags: "-lz",
    },
  ];
  if (process.platform === "darwin") {
    // A package's own cc-link-flags do not reach an is-main link, so the Apple
    // frameworks the CoreText stub calls travel here instead. Before this, the
    // symbols only resolved because a platform backend also linked the
    // ApplicationServices umbrella, which re-exports CoreText.
    linkConfigs.push({
      package: "wzzc-dev/moui_text_providers/coretext",
      link_flags: CORETEXT_DARWIN_LINK_FLAGS,
    });
  }
  if (process.platform === "linux") {
    linkConfigs.push({
      package: "wzzc-dev/moui_text_providers/fontconfig",
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
