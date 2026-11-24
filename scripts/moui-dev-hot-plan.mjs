// Pure planning helpers for `moui dev --hot`. Kept separate from the dev runner
// so the platform gate, plugin file naming, link recipe, and fast-plan step
// filter can be tested without spawning a build.

export const HOT_PLATFORMS = ["macos", "linux"];

/** Map a Node `process.platform` value to a hot-reload host platform. */
export function hotPlatformForNodePlatform(nodePlatform) {
  if (nodePlatform === "darwin") return "macos";
  if (nodePlatform === "linux") return "linux";
  return null;
}

/** Native plugin extension. `dlopen` keys images by path, so each generation
 * must be a new file in both cases. */
export function hotPluginFileName(platform) {
  return platform === "linux" ? "plugin.so" : "plugin.dylib";
}

/**
 * Native link arguments for one plugin generation.
 *
 * macOS: `-force_load` is the Mach-O equivalent of `--whole-archive`; the
 * MoonBit runtime objects are already PIC-compatible.
 *
 * Linux: MoonBit's native backend does not emit shared-library objects, so the
 * runner first rewrites the archive with PIC runtime objects (see
 * `picRuntimeCompile`) and links with `--whole-archive` + `-Bsymbolic`. The
 * latter binds the plugin's own MoonBit symbols inside the image instead of
 * letting the host executable preempt them through the global ELF scope.
 */
export function hotLinkArgs({
  platform,
  pluginArchive,
  picArchive,
  moonHome,
  output,
}) {
  const backtrace = `${moonHome}/lib/libbacktrace.a`;
  if (platform === "linux") {
    return [
      "-shared",
      "-Wl,-Bsymbolic",
      "-Wl,--whole-archive",
      picArchive ?? pluginArchive,
      "-Wl,--no-whole-archive",
      backtrace,
      "-lm",
      "-o",
      output,
    ];
  }
  return [
    "-shared",
    `-Wl,-force_load,${pluginArchive}`,
    backtrace,
    "-lm",
    "-o",
    output,
  ];
}

/**
 * Rewrite one `moon build --dry-run` runtime C compile into a PIC copy that
 * writes to `outputPath`. Returns `null` for non-runtime or non-compile lines.
 */
export function picRuntimeCompile(line, outputPath) {
  if (!/^(\S*\/)?cc\s/.test(line)) return null;
  if (!/\/lib\/runtime\/[^/\s'"]+\.c/.test(line)) return null;
  const output = line.match(/(?:^|\s)-o\s+(\S+)/);
  if (!output) return null;
  return `${line.replace(/(^|\s)-o\s+\S+/, `$1-o ${outputPath}`)} -fPIC`;
}

/** Select the dry-run steps worth replaying for a same-shape app edit. */
export function hotFastStepMatches(line, { appModule, archiveFragment = "dev_hot/plugin/plugin.a" }) {
  if (line.startsWith("moonc build-package ")) {
    return line.includes(appModule) || line.includes("moui_devhost/dev_hot/plugin");
  }
  if (line.startsWith("moonc link-core ")) {
    return line.includes("moui_devhost/dev_hot/plugin");
  }
  // `link-core` regenerates plugin.c; the generated C must be recompiled
  // before the archive step, or the archive silently keeps the previous
  // plugin.o (and therefore the previous app code).
  if (line.includes("dev_hot/plugin/__moonbit_link_core__/plugin.o")) {
    return true;
  }
  if (line.includes(archiveFragment)) {
    // macOS emits `libtool -static`; Linux emits `moon tool archive -- ar`.
    return line.includes("libtool -static") || line.startsWith("moon tool archive ");
  }
  return false;
}
