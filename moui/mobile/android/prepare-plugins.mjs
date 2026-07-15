import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, extname, isAbsolute, join, relative, resolve, sep } from "node:path";

const entrySegment = /^[A-Za-z_][A-Za-z0-9_]*$/;
const reservedEntrySegments = new Set([
  "as", "break", "class", "continue", "do", "else", "false", "for", "fun",
  "if", "in", "interface", "is", "null", "object", "package", "return", "super",
  "this", "throw", "true", "try", "typealias", "typeof", "val", "var", "when", "while",
]);
const androidResourceDirectory = /^(anim|animator|color|drawable|font|interpolator|layout|menu|mipmap|navigation|raw|transition|values|xml)(-[A-Za-z0-9_+.-]+)?$/;

const ensureDir = path => mkdirSync(path, { recursive: true });

const isInside = (root, candidate) => {
  const path = relative(root, candidate);
  return path === "" || (!path.startsWith(`..${sep}`) && path !== ".." && !isAbsolute(path));
};

const portable = path => path.split(sep).join("/");

const copyTo = (source, target) => {
  ensureDir(dirname(target));
  copyFileSync(source, target);
};

const collectFiles = (path, root) => {
  const files = [];
  const visited = new Set();
  const visit = current => {
    const real = realpathSync(current);
    if (!isInside(root, real)) throw new Error(`Android plugin path escapes plugin root: ${current}`);
    const info = statSync(real);
    if (!info.isDirectory()) {
      files.push(real);
      return;
    }
    if (visited.has(real)) return;
    visited.add(real);
    for (const name of readdirSync(real).sort()) visit(join(real, name));
  };
  visit(path);
  return files;
};

const kotlinString = value => {
  const encoded = JSON.stringify(String(value)).slice(1, -1).replace(/\$/g, "\\$");
  return `"${encoded}"`;
};

export const validateAndroidPluginEntry = (entry, manifestPath = "Android plugin manifest") => {
  if (typeof entry !== "string") {
    throw new Error(`${manifestPath}: Android entry must be a fully qualified public type name`);
  }
  const segments = entry.split(".");
  if (segments.length < 2 || segments.some(segment =>
    !entrySegment.test(segment) || reservedEntrySegments.has(segment))) {
    throw new Error(`${manifestPath}: unsafe Android plugin entry ${JSON.stringify(entry)}`);
  }
  return entry;
};

const resourceTargetForFile = (pluginRoot, declaredResource, file) => {
  const declaredInfo = statSync(declaredResource);
  if (declaredInfo.isDirectory()) {
    const declaredName = basename(declaredResource);
    const child = relative(declaredResource, file);
    return androidResourceDirectory.test(declaredName) ? join(declaredName, child) : child;
  }
  const parts = relative(pluginRoot, file).split(sep);
  const resIndex = parts.lastIndexOf("res");
  if (resIndex >= 0) return join(...parts.slice(resIndex + 1));
  const typeIndex = parts.findIndex(part => androidResourceDirectory.test(part));
  return typeIndex >= 0 ? join(...parts.slice(typeIndex)) : basename(file);
};

const validateResourceTarget = (target, source) => {
  const parts = target.split(sep).filter(Boolean);
  if (parts.length < 2 || !androidResourceDirectory.test(parts[0])) {
    throw new Error(
      `Android plugin resource must resolve under a resource type directory: ${source} -> ${portable(target)}`,
    );
  }
  if (parts.some(part => part === "." || part === "..")) {
    throw new Error(`unsafe Android plugin resource target: ${portable(target)}`);
  }
};

const isolateValuesResource = (target, pluginDirectory) => {
  const parts = target.split(sep);
  if (parts.length === 2 && parts[0].startsWith("values") && extname(parts[1]) === ".xml") {
    return join(parts[0], `${pluginDirectory}-${parts[1]}`);
  }
  return target;
};

const generatedRegistry = plugins => {
  const installs = plugins.map(plugin =>
    `        installPlugin(applicationContext, ${kotlinString(plugin.id)}, ${plugin.entry}(), capabilities)`);
  const installBody = installs.length > 0 ? [
    "    @Synchronized",
    "    fun install(context: Context, capabilities: MoUIMobilePluginCapabilities) {",
    "        val applicationContext = context.applicationContext",
    ...installs,
    "    }",
  ] : [
    "    @Suppress(\"UNUSED_PARAMETER\")",
    "    fun install(context: Context, capabilities: MoUIMobilePluginCapabilities) = Unit",
  ];
  return [
    "package dev.wzzc.moui.mobile",
    "",
    "import android.content.Context",
    "",
    "internal object MoUIGeneratedPluginRegistry {",
    "    private val installedIds = mutableSetOf<String>()",
    "",
    ...installBody,
    "",
    "    private fun installPlugin(",
    "        applicationContext: Context,",
    "        expectedId: String,",
    "        plugin: MoUIMobilePlugin,",
    "        capabilities: MoUIMobilePluginCapabilities,",
    "    ) {",
    "        require(plugin.id == expectedId) {",
    "            \"Android plugin id mismatch: manifest=$expectedId entry=${plugin.id}\"",
    "        }",
    "        if (!installedIds.add(expectedId)) return",
    "        plugin.install(applicationContext, capabilities)",
    "    }",
    "}",
    "",
  ].join("\n");
};

export const prepareAndroidPlugins = ({ plugins = [], buildDir, shellMode }) => {
  if (!isAbsolute(buildDir)) throw new Error("Android plugin buildDir must be absolute");
  if (!["managed", "legacy"].includes(shellMode)) {
    throw new Error(`Android plugin shell mode must be managed or legacy: ${shellMode}`);
  }
  const root = join(buildDir, "android", "plugins");
  rmSync(root, { recursive: true, force: true });
  if (shellMode === "legacy") {
    return {
      enabled: false,
      root,
      generatedKotlinDir: "",
      kotlinSourceDir: "",
      javaSourceDir: "",
      resourceDir: "",
      registryFile: "",
      plugins: [],
    };
  }

  const generatedKotlinDir = join(root, "generated", "kotlin");
  const kotlinSourceDir = join(root, "sources", "kotlin");
  const javaSourceDir = join(root, "sources", "java");
  const resourceDir = join(root, "res");
  for (const path of [generatedKotlinDir, kotlinSourceDir, javaSourceDir, resourceDir]) ensureDir(path);

  const stagedPlugins = [];
  const resourceTargets = new Map();
  plugins.forEach((plugin, pluginIndex) => {
    const platform = plugin.platforms?.android;
    if (!platform) return;
    const entry = validateAndroidPluginEntry(platform.entry, plugin.path);
    const pluginRoot = realpathSync(plugin.root);
    const pluginDirectory = `plugin-${String(pluginIndex).padStart(3, "0")}`;
    const stagedSources = [];
    const seenSources = new Set();
    for (const source of platform.sources) {
      const declaredSource = resolve(pluginRoot, source);
      for (const file of collectFiles(declaredSource, pluginRoot)) {
        const extension = extname(file);
        if (extension !== ".kt" && extension !== ".java") {
          throw new Error(`${plugin.path}: unsupported Android plugin source ${file}`);
        }
        const targetRoot = extension === ".kt" ? kotlinSourceDir : javaSourceDir;
        const target = join(targetRoot, pluginDirectory, relative(pluginRoot, file));
        const key = resolve(target);
        if (seenSources.has(key)) continue;
        seenSources.add(key);
        copyTo(file, target);
        stagedSources.push(target);
      }
    }

    const stagedResources = [];
    for (const resource of platform.resources) {
      const declaredResource = realpathSync(resolve(pluginRoot, resource));
      for (const file of collectFiles(declaredResource, pluginRoot)) {
        const targetRelative = isolateValuesResource(
          resourceTargetForFile(pluginRoot, declaredResource, file),
          pluginDirectory,
        );
        validateResourceTarget(targetRelative, file);
        const conflictKey = portable(targetRelative).toLowerCase();
        const owner = resourceTargets.get(conflictKey);
        if (owner && owner !== file) {
          throw new Error(
            `Android plugin resource target conflict ${portable(targetRelative)}: ${owner} and ${file}`,
          );
        }
        if (owner === file) continue;
        resourceTargets.set(conflictKey, file);
        const target = join(resourceDir, targetRelative);
        copyTo(file, target);
        stagedResources.push(target);
      }
    }
    stagedPlugins.push({
      id: plugin.id,
      entry,
      sources: stagedSources,
      resources: stagedResources,
    });
  });

  const registryFile = join(
    generatedKotlinDir,
    "dev", "wzzc", "moui", "mobile", "MoUIGeneratedPluginRegistry.kt",
  );
  ensureDir(dirname(registryFile));
  writeFileSync(registryFile, generatedRegistry(stagedPlugins));
  if (!existsSync(registryFile)) throw new Error("generated Android plugin registry was not written");

  return {
    enabled: true,
    root,
    generatedKotlinDir,
    kotlinSourceDir,
    javaSourceDir,
    resourceDir,
    registryFile,
    plugins: stagedPlugins,
  };
};
