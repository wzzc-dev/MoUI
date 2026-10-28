// Prebuild hook for the direct Metal renderer.
//
// MoonBit applies a package's `cc-link-flags` only when that package is the
// is-main link unit (its own tests), never when a dependency links it into an
// executable. `link_configs` is the carrier that reaches is-main links, so the
// Apple framework list travels with this module instead of being repeated by
// every composition root. Same mechanism as `moui_skia/build.js` and
// `moui_text_providers/build.js`.

const APPLE_LINK_FLAGS = [
  "-framework Metal",
  "-framework QuartzCore",
  "-framework CoreGraphics",
  "-framework ImageIO",
  "-framework Foundation",
  "-framework CoreFoundation"

].join(" ");

function main() {
  const linkConfigs = [];
  if (process.platform === "darwin") {
    linkConfigs.push({
      package: "wzzc-dev/moui_metal_renderer",
      link_flags: APPLE_LINK_FLAGS,
    });
  }
  console.log(
    JSON.stringify({
      vars: {},
      link_configs: linkConfigs,
    }),
  );
}

main();
