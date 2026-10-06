#!/usr/bin/env node

// Regenerates moui/backend/macos/macos_branding_icon.mbt from the MoUI brand
// asset resource/branding/moonbud-mascot-100.png. The PNG is embedded as a
// MoonBit bytes literal so unbundled macOS binaries (moon run output) can
// apply the MoUI Dock icon without shipping an icon file next to the binary.
//
// Usage: node scripts/generate-macos-branding-icon.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const sourcePath = join(repoRoot, "resource/branding/moonbud-mascot-100.png");
const outputPath = join(repoRoot, "moui/backend/macos/macos_branding_icon.mbt");

const png = readFileSync(sourcePath);
const literal = [...png].map((byte) => `\\x${byte.toString(16).padStart(2, "0")}`).join("");

// PNG signature check so a bad source asset fails loudly here instead of
// silently embedding garbage.
const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
if (png.length < pngSignature.length || !png.subarray(0, 8).equals(pngSignature)) {
  throw new Error(`${sourcePath} is not a PNG file`);
}

const header = `///|
// GENERATED FILE — do not edit by hand.
//
// Embedded MoUI branding icon for the macOS Dock, generated from
// resource/branding/moonbud-mascot-100.png (100x100 RGBA PNG) by
// scripts/generate-macos-branding-icon.mjs. Regenerate with:
//
//   node scripts/generate-macos-branding-icon.mjs
//
// Unbundled macOS binaries apply these bytes as the default Dock icon; see
// docs/platform-notes-macos.md.

///|
/// Embedded default macOS Dock icon (moonbud-mascot-100.png).
let macos_default_dock_icon_png : Bytes = b"${literal}"
`;

writeFileSync(outputPath, header);
console.log(`wrote ${outputPath} (${png.length} PNG bytes)`);
