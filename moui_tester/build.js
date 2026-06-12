const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const input = fs.readFileSync(0, "utf8");
const skiaBuild = path.join(__dirname, "..", "moui_skia", "build.js");
const result = spawnSync(process.execPath, [skiaBuild], {
  cwd: path.join(__dirname, "..", "moui_skia"),
  input,
  encoding: "utf8",
  stdio: ["pipe", "pipe", "inherit"],
});

if (result.error) {
  throw result.error;
}
if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

const config = JSON.parse(result.stdout || "{}");
process.stdout.write(JSON.stringify({ vars: config.vars || {} }));
