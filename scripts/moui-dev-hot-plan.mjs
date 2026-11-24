// Pure planning helpers for `moui dev --hot`. Kept separate from the dev runner
// so the platform gate, plugin file naming, link recipe, and fast-plan step
// filter can be tested without spawning a build.

export const HOT_PLATFORMS = ["macos", "linux", "windows"];

/** Every generated app entry point the bridge resolves, plus `moonbit_init`
 * (already `__declspec(dllexport)` in `moonbit.h`). Generated C does not mark
 * `#export_name` functions as exported on Windows, so the MSVC link must list
 * them explicitly or `GetProcAddress` sees an empty export table. The
 * semantics entries are optional at runtime, but exporting them keeps platform
 * accessibility working in the dev loop. */
export const WINDOWS_PLUGIN_EXPORTS = [
  "dev_abi_version",
  "dev_create",
  "dev_destroy",
  "dev_event",
  "dev_frame",
  "dev_frame_len",
  "dev_frame_release",
  "dev_flush",
  "dev_resize",
  "dev_semantics_action",
  "dev_semantics_action_len",
  "dev_semantics_action_release",
];

/** Same static CRT and system libraries moon uses for a native Windows
 * executable (`/MT` toolchain policy), so the plugin does not mix CRTs with
 * the host. */
export const WINDOWS_MSVC_DEFAULT_LIBS = [
  "libcmt.lib",
  "oldnames.lib",
  "kernel32.lib",
  "shell32.lib",
  "user32.lib",
  "dbghelp.lib",
  "uuid.lib",
];

/** Map a Node `process.platform` value to a hot-reload host platform. */
export function hotPlatformForNodePlatform(nodePlatform) {
  if (nodePlatform === "darwin") return "macos";
  if (nodePlatform === "linux") return "linux";
  if (nodePlatform === "win32") return "windows";
  return null;
}

/** Native plugin extension. Loaders key images by path, so each generation
 * must be a new file on every host. */
export function hotPluginFileName(platform) {
  if (platform === "linux") return "plugin.so";
  if (platform === "windows") return "plugin.dll";
  return "plugin.dylib";
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
 *
 * Windows: `link.exe` receives the archive directly (no PIC rewrite; MSVC
 * objects are position-independent). `/WHOLEARCHIVE` keeps every runtime
 * member, `/EXPORT` publishes the generated `dev_*` entry points, and the
 * explicit default-library list mirrors moon's `/MT` native executable link.
 */
export function hotLinkArgs({
  platform,
  pluginArchive,
  picArchive,
  moonHome,
  output,
}) {
  if (platform === "windows") {
    return [
      "/NOLOGO",
      "/DLL",
      `/OUT:${output}`,
      `/WHOLEARCHIVE:${pluginArchive}`,
      ...WINDOWS_PLUGIN_EXPORTS.map((name) => `/EXPORT:${name}`),
      pluginArchive,
      ...WINDOWS_MSVC_DEFAULT_LIBS,
    ];
  }
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
export function hotFastStepMatches(line, { appModule, archiveFragment = "moui_dev_hot/plugin/plugin.a" }) {
  // Dry-run renders project paths with `/`, but an overridden toolchain can
  // still print native separators; normalize before matching.
  const text = line.replace(/\\/g, "/");
  if (text.startsWith("moonc build-package ")) {
    return (
      text.includes(appModule) ||
      text.includes("moui_dev_hot/plugin") ||
      text.includes("plugin/main.mbt")
    );
  }
  if (text.startsWith("moonc link-core ")) {
    return text.includes("moui_dev_hot/plugin");
  }
  // `link-core` regenerates plugin.c; the generated C must be recompiled
  // before the archive step, or the archive silently keeps the previous
  // plugin object (and therefore the previous app code). Windows uses `.obj`.
  if (
    text.includes("moui_dev_hot/plugin/__moonbit_link_core__/plugin.o") ||
    text.includes("moui_dev_hot/plugin/__moonbit_link_core__/plugin.obj")
  ) {
    return true;
  }
  if (text.includes(archiveFragment)) {
    // macOS emits `libtool -static`; Linux emits `moon tool archive -- ar`;
    // MSVC emits `lib.exe /Out:` (or `llvm-lib.exe`).
    return (
      text.includes("libtool -static") ||
      text.startsWith("moon tool archive ") ||
      (/(?:^|\/)(?:lib|llvm-lib)(?:\.exe)?\s/i.test(text) && /\/Out:/i.test(text))
    );
  }
  return false;
}
