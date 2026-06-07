#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";

const usage = () => {
  console.error(
    "Usage: node scripts/record-web-renderer-proof-manifest.mjs --web-presentation-manifest <web-runtime-presentation.json> --output <renderer-proof.json> [--require-passed]",
  );
  process.exit(2);
};

const args = process.argv.slice(2);
let webManifestPath = "";
let output = "artifacts/conformance/renderer-proof/webgpu-wasm-web.json";
let requirePassed = false;

for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--web-presentation-manifest") webManifestPath = args[++index] ?? "";
  else if (arg === "--output") output = args[++index] ?? "";
  else if (arg === "--require-passed") requirePassed = true;
  else usage();
}

if (!webManifestPath || !output) usage();

const readJson = path => JSON.parse(readFileSync(path, "utf8"));
const webManifest = readJson(webManifestPath);
const showcase = (webManifest.targets || []).find(target => target.name === "showcase-web-wasm");
const artifactDir = dirname(output);
const logPath = join(artifactDir, "webgpu-wasm-web.log");
mkdirSync(artifactDir, { recursive: true });

const proofKeys = [
  "radialGradient",
  "transformPixels",
  "colorEmojiPixels",
  "zwjGrapheme",
  "bidiLayout",
  "paragraphWrapping",
  "asyncImageSecondFrame",
];

const markerLines = [];
const addMarker = (condition, line) => {
  if (condition) markerLines.push(line);
};

const colorEmoji = showcase?.screenshot?.colorEmojiPixels;
const colorEmojiMetadata = colorEmoji?.metadata;
const colorEmojiFont = colorEmojiMetadata?.font;
const colorEmojiGlyph = colorEmojiMetadata?.glyph;
const colorEmojiMetadataReady =
  colorEmoji?.passed === true &&
  typeof colorEmojiFont?.family === "string" &&
  colorEmojiFont.family.trim() !== "" &&
  typeof colorEmojiFont?.source === "string" &&
  colorEmojiFont.source.trim() !== "" &&
  typeof colorEmojiFont?.textSystem === "string" &&
  colorEmojiFont.textSystem.trim() !== "" &&
  colorEmojiGlyph?.format === "rgba" &&
  Number(colorEmojiGlyph?.glyphCount) >= 1 &&
  Number(colorEmojiGlyph?.clusterCount) >= 1 &&
  Number(colorEmojiGlyph?.highSaturationPixels) >= 8 &&
  Number(colorEmojiGlyph?.alphaPixels ?? colorEmoji.glyphAlphaPixels ?? 0) > 0 &&
  typeof colorEmojiGlyph?.key === "string" &&
  colorEmojiGlyph.key.trim() !== "" &&
  Number(colorEmojiGlyph?.width) > 0 &&
  Number(colorEmojiGlyph?.height) > 0;

const metadataTokenValue = value => `${value ?? ""}`.replace(/\s+/g, "_");

addMarker(
  showcase?.observations?.radialGradient === "yes",
  "MoUI renderer proof radialGradient passed center-mid-edge-pixels shader-payload",
);
addMarker(
  showcase?.observations?.transformPixels === "yes",
  "MoUI renderer proof transformPixels passed pixel-markers",
);
addMarker(
  showcase?.observations?.colorEmojiPixels === "yes" && colorEmojiMetadataReady,
  "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata",
);
if (showcase?.observations?.colorEmojiPixels === "yes" && colorEmojiMetadataReady) {
  markerLines.push(
    [
      "MoUI renderer proof colorEmojiPixels metadata",
      `font_family=${metadataTokenValue(colorEmojiFont.family)}`,
      `font_source=${metadataTokenValue(colorEmojiFont.source)}`,
      `text_system=${metadataTokenValue(colorEmojiFont.textSystem)}`,
      `shaper=${metadataTokenValue(colorEmojiFont.shaper || "browser-canvas")}`,
      `glyph_format=${metadataTokenValue(colorEmojiGlyph.format)}`,
      `glyph_count=${Number(colorEmojiGlyph.glyphCount)}`,
      `cluster_count=${Number(colorEmojiGlyph.clusterCount)}`,
      `high_saturation_pixels=${Number(colorEmojiGlyph.highSaturationPixels)}`,
      `alpha_pixels=${Number(colorEmojiGlyph.alphaPixels ?? colorEmoji.glyphAlphaPixels ?? 0)}`,
      `glyph_key=${metadataTokenValue(colorEmojiGlyph.key || "")}`,
      `glyph_width=${Number(colorEmojiGlyph.width ?? 0)}`,
      `glyph_height=${Number(colorEmojiGlyph.height ?? 0)}`,
    ].join(" "),
  );
}
addMarker(
  showcase?.observations?.zwjGrapheme === "yes",
  "MoUI renderer proof zwjGrapheme passed single-grapheme-cluster no-interior-caret",
);
addMarker(
  showcase?.observations?.bidiLayout === "yes",
  "MoUI renderer proof bidiLayout passed visual-order",
);
addMarker(
  showcase?.observations?.paragraphWrapping === "yes",
  "MoUI renderer proof paragraphWrapping passed line-metrics later-line-pixels",
);
addMarker(
  showcase?.observations?.asyncImageSecondFrame === "yes",
  "MoUI renderer proof asyncImageSecondFrame passed late-completion repaint-request second-frame-pixels",
);

const notes = [
  `webPresentationManifest=${webManifestPath}`,
  `webPresentationStatus=${webManifest.overallStatus || "unknown"}`,
  `showcaseStatus=${showcase?.status || "missing"}`,
  `showcaseObservations=${JSON.stringify(showcase?.observations || {})}`,
];
writeFileSync(logPath, `${notes.concat(markerLines).join("\n")}\n`);

const missingProofs = proofKeys.filter(key => showcase?.observations?.[key] !== "yes");
if ((webManifest.overallStatus || "failed") !== "passed" || missingProofs.length > 0) {
  console.error("web renderer proof failed summary:");
  console.error(`  webPresentationStatus=${webManifest.overallStatus || "unknown"}`);
  console.error(`  showcaseStatus=${showcase?.status || "missing"}`);
  console.error(
    `  missingProofs=${missingProofs.length > 0 ? missingProofs.join(",") : "(none)"}`,
  );
  console.error(`  log=${logPath}`);
}

const recorderArgs = [
  "scripts/record-renderer-proof-manifest.mjs",
  "--backend",
  "webgpu-wasm",
  "--platform",
  "web",
  "--artifact-name",
  process.env.WEB_RUNTIME_PRESENTATION_ARTIFACT_NAME || "moui-web-runtime-presentation",
  "--output",
  output,
  "--log",
  logPath,
];
if (requirePassed) recorderArgs.push("--require-passed");

const result = spawnSync(process.execPath, recorderArgs, { encoding: "utf8" });
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.status !== 0) process.exit(result.status ?? 1);
