const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// `moui_tests` owns no Skia flags. It re-emits the renderer prebuild vars so its
// own harnesses link the same Skia archives. The former implementation required
// `moui_skia_renderer/build.js`; the renderer prebuild is now `build.mbtx`.
const input = fs.readFileSync(0, "utf8");
const skiaRoot = path.join(__dirname, "..", "moui_skia_renderer");
const result = spawnSync(
  "moon",
  [
    "run",
    "build.mbtx",
    "--target",
    "native",
    "--target-dir",
    path.join(skiaRoot, ".skia-cache", "prebuild-target"),
  ],
  {
    cwd: skiaRoot,
    input,
    encoding: "utf8",
    stdio: ["pipe", "pipe", "inherit"],
  },
);

if (result.error) {
  throw result.error;
}
if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

const lines = String(result.stdout || "")
  .split("\n")
  .map((line) => line.trim())
  .filter((line) => line.startsWith("{"));
let config = {};
if (lines.length > 0) {
  try {
    config = JSON.parse(lines[lines.length - 1]);
  } catch {
    config = {};
  }
}
process.stdout.write(
  JSON.stringify({
    vars: config.vars || {},
    // The renderer module owns its own link config. Moon rejects a prebuild
    // from wzzc-dev/moui_tests that targets an external module name.
    link_configs: [],
  }),
);
