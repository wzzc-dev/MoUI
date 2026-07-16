#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { readMobileApps } from "../moui/scripts/mobile/app-config.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const validAndroidApplicationId = value => /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/.test(value);
const validBundleId = value => /^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/.test(value);
const validNativeLibrary = value => /^[A-Za-z0-9_]+$/.test(value);

const requirePath = (failures, label, path) => {
  const absolute = resolve(repoRoot, path);
  if (!existsSync(absolute)) failures.push(`${label} does not exist: ${path}`);
};

const readRepoFile = path => readFileSync(resolve(repoRoot, path), "utf8");

const requireTokens = (failures, label, source, tokens) => {
  for (const token of tokens) {
    if (!source.includes(token)) failures.push(`${label} is missing ${JSON.stringify(token)}`);
  }
};

const validateAndroidManagedShell = failures => {
  const kotlinDir = "moui/mobile/android/src/main/kotlin/dev/wzzc/moui/mobile";
  const kotlinFiles = [
    "MoUIActivity.kt",
    "MoUISurfaceView.kt",
    "MoUIClipboard.kt",
    "MoUIAccessibility.kt",
    "MoUIPlatformViews.kt",
    "MoUIHostServices.kt",
    "MoUIMobilePlugin.kt",
    "MoUIMobileCapabilities.kt",
    "MoUINativeBridge.kt",
  ];
  for (const file of kotlinFiles) requirePath(failures, `managed Android ${file}`, `${kotlinDir}/${file}`);
  if (kotlinFiles.some(file => !existsSync(resolve(repoRoot, kotlinDir, file)))) return;

  const managedSources = kotlinFiles.map(file => readRepoFile(`${kotlinDir}/${file}`)).join("\n");
  const activity = readRepoFile(`${kotlinDir}/MoUIActivity.kt`);
  requireTokens(failures, "managed Android Activity", activity, [
    "class MoUIActivity : ComponentActivity()",
    "MoUIGeneratedPluginRegistry.install(this, pluginCapabilities)",
    "root.addView(surfaceView",
    "root.addView(overlay",
    "Choreographer.FrameCallback",
    'detachSurface("destroy")',
    "if (isFinishing && !isChangingConfigurations)",
    "MoUINativeBridge.destroyApplication()",
    "moui-mobile application destroy result=",
    "dispatchScrollPhase(phase, x, y)",
    "META_STATUS_BAR",
    "STATUS_BAR_HIDDEN -> true",
    "STATUS_BAR_VISIBLE -> false",
    "WindowInsetsCompat.Type.navigationBars()",
    "WindowInsetsCompat.Type.statusBars()",
  ]);
  if (activity.indexOf("root.addView(surfaceView") > activity.indexOf("root.addView(overlay")) {
    failures.push("managed Android Activity must place MoUISurfaceView below the PlatformView overlay");
  }
  if (activity.indexOf("loadNativeLibraryFromManifest()") >
      activity.indexOf("MoUIGeneratedPluginRegistry.install(this, pluginCapabilities)")) {
    failures.push("managed Android plugins must install after the runtime native library is loaded");
  }
  if (activity.indexOf("MoUIGeneratedPluginRegistry.install(this, pluginCapabilities)") >
      activity.indexOf("MoUINativeBridge.rendererStatusJson()")) {
    failures.push("managed Android plugins must install before the shell starts runtime host work");
  }
  if (activity.includes("supportsScroll") || activity.includes("META_SUPPORTS_SCROLL")) {
    failures.push("managed Android Activity must negotiate scroll through runtime ABI v1 instead of manifest metadata");
  }
  if (/if\s*\([^)]*\)\s*dispatchScrollPhase\(phase, x, y\)/.test(activity)) {
    failures.push("managed Android Activity must dispatch scroll unconditionally and let runtime ABI v1 fail closed");
  }
  for (const token of [
    "moui_a11y_smoke",
    "MOUI_MOBILE_A11Y_SMOKE",
    "MOUI_MOBILE_SERVICE_SMOKE",
    "service smoke",
    "service probe plan",
  ]) {
    if (managedSources.includes(token)) {
      failures.push(`managed Android production sources must not contain probe token ${JSON.stringify(token)}`);
    }
  }

  const jni = readRepoFile("moui/mobile/android/src/main/cpp/moui_mobile_jni.cpp");
  requireTokens(failures, "managed Android JNI", jni, [
    "JNI_OnLoad",
    "RegisterNatives",
    "dev/wzzc/moui/mobile/MoUINativeBridge",
    "moui_mobile_get_runtime_api_v1",
    "moui_mobile_runtime_api_v1_is_compatible",
    "g_runtime_api->take_host_update_envelope_json",
    "g_runtime_api->dispatch_host_response_envelope",
    "g_runtime_api->detach_surface",
    "g_runtime_api->destroy_application",
  ]);
  const nativeMethods = [
    ["attachSurface", "(Landroid/view/Surface;IID)Z"],
    ["resize", "(IID)Z"],
    ["dispatchPointer", "(IDDD)Z"],
    ["dispatchScroll", "(DDDDI)Z"],
    ["frameTick", "(D)Z"],
    ["takeHostUpdates", "()Ljava/lang/String;"],
    ["dispatchHostResponseEnvelope", "(Ljava/lang/String;)Z"],
    ["dispatchTextInput", "(ILjava/lang/String;II)Z"],
    ["dispatchCommand", "(I)Z"],
    ["dispatchAccessibility", "(IILjava/lang/String;)Z"],
    ["completeClipboard", "(IIILjava/lang/String;[B)Z"],
    ["renderFrame", "()Z"],
    ["detachSurface", "()V"],
    ["destroyApplication", "()Z"],
    ["rendererConfigure", "(Ljava/lang/String;)Z"],
    ["rendererStatusJson", "()Ljava/lang/String;"],
  ];
  const nativeBridge = readRepoFile(`${kotlinDir}/MoUINativeBridge.kt`);
  for (const [name, descriptor] of nativeMethods) {
    if (!jni.includes(`"${name}"`) || !jni.includes(`"${descriptor}"`)) {
      failures.push(`managed Android JNI registration is missing ${name} ${descriptor}`);
    }
    if (!nativeBridge.includes(`external fun ${name}`)) {
      failures.push(`managed Android Kotlin bridge is missing native method ${name}`);
    }
  }
  if (jni.includes("Java_dev_")) failures.push("managed Android JNI must not export name-mangled Java bindings");
  if (jni.includes("moonbit_string_t") || jni.includes("MOUI_MOBILE_ATTACH_SURFACE(")) {
    failures.push("managed Android JNI must consume the negotiated runtime ABI instead of MoonBit or app-specific exports");
  }
  const clipboard = readRepoFile(`${kotlinDir}/MoUIClipboard.kt`);
  requireTokens(failures, "managed Android clipboard generation routing", clipboard, [
    "sessionGeneration: Int?",
    "MoUINativeBridge.completeClipboard(",
    "clipboard update is missing Host Wire session generation",
  ]);
  const platformViews = readRepoFile(`${kotlinDir}/MoUIPlatformViews.kt`);
  requireTokens(failures, "managed Android PlatformView routing", platformViews, [
    "fun interface MoUIPlatformViewEventSink",
    "sink: MoUIPlatformViewEventSink",
    'require(!kind.startsWith("moui."))',
    "data class PlatformViewKey(val kind: String, val id: String)",
    "LinkedHashMap<PlatformViewKey, HostedView>",
    "Looper.myLooper() != Looper.getMainLooper()",
    "active.token !== token",
    "sessionGeneration ?: return false",
    "revision <= 0",
    'put("kind", "platform-view")',
    "MoUINativeBridge.dispatchHostResponseEnvelope",
  ]);
  if (platformViews.includes("LinkedHashMap<String, HostedView>") ||
      platformViews.includes("hosted[placement.id]")) {
    failures.push("managed Android PlatformViews must key hosted views by (kind,id), not id alone");
  }

  const surfaceView = readRepoFile(`${kotlinDir}/MoUISurfaceView.kt`);
  const hostServices = readRepoFile(`${kotlinDir}/MoUIHostServices.kt`);
  const mobilePlugin = readRepoFile(`${kotlinDir}/MoUIMobilePlugin.kt`);
  requireTokens(failures, "managed Android plugin API", mobilePlugin, [
    "interface MoUIMobilePlugin",
    "val id: String",
    "fun install(context: Context)",
  ]);
  requireTokens(failures, "managed Android Host Service routing", surfaceView, [
    '"platform-channel" -> MoUIHostServices.dispatch(update, generation)',
  ]);
  requireTokens(failures, "managed Android Host Service registry", hostServices, [
    "data class MoUIHostServiceRequest(",
    "enum class MoUIHostServiceStatus",
    "fun interface MoUIHostServiceHandler",
    "fun interface MoUIHostServiceTask",
    "completion: MoUIHostServiceCompletion",
    "ConcurrentHashMap<String, MoUIHostServiceHandler>",
    "ConcurrentHashMap<RequestKey, PendingRequest>",
    'require(!channel.startsWith("moui."))',
    "AtomicBoolean(false)",
    "compareAndSet(false, true)",
    "request.cancel()",
    "completion.invalidate()",
    "nextTask?.cancel()",
    "pending.putIfAbsent(key, requestState)",
    "pending.remove(key)",
    "Handler(Looper.getMainLooper())",
    "generation == null || generation <= 0",
    'completion.error("invalid platform channel request")',
    'completion.unavailable("platform channel is unavailable: $channel")',
    'put("kind", "platform-channel")',
    'put("requestId", requestId)',
    'put("status", response.status.wireValue)',
    'put("sessionGeneration", generation)',
    "MoUINativeBridge.dispatchHostResponseEnvelope",
  ]);
  if (surfaceView.includes("platform channel request has no managed-shell handler")) {
    failures.push("managed Android Host Service requests must complete through the registry");
  }
  if (!surfaceView.includes("MoUIHostServices.reset()")) {
    failures.push("managed Android host state reset must cancel pending plugin services");
  }

  const legacyRoot = "moui/mobile/legacy/android";
  for (const path of [
    "README.md",
    "src/main/java/dev/wzzc/moui/mobile/MobileActivity.java",
    "src/main/java/dev/wzzc/moui/mobile/MobileSurfaceView.java",
    "src/main/java/dev/wzzc/moui/mobile/MobileClipboardProvider.java",
    "src/main/cpp/moui_mobile_jni.cpp",
    "src/main/cpp/moui_android_compat.c",
    "src/main/cpp/moui_android_compat.h",
  ]) requirePath(failures, "legacy Android fixture", `${legacyRoot}/${path}`);
  const legacyJniPath = `${legacyRoot}/src/main/cpp/moui_mobile_jni.cpp`;
  if (existsSync(resolve(repoRoot, legacyJniPath)) && !readRepoFile(legacyJniPath).includes("Java_dev_wzzc_moui_mobile_MobileActivity")) {
    failures.push("legacy Android fixture must retain its Release N JNI symbols");
  }

  const gradle = readRepoFile("moui/mobile/android/mobile-app.gradle");
  requireTokens(failures, "managed Android Gradle glue", gradle, [
    "mouiAndroidShell",
    '"managed", "ejected", "legacy"',
    "modernAndroidShell",
    "ejectedAndroidShell",
    'file("${generatedRoot}/android/${androidShell}-shell")',
    'file("${generatedShellRoot}/shell-config.json")',
    "new JsonSlurper().parse(generatedShellConfigFile)",
    "manifest.srcFile androidManagedManifest",
    "res.srcDirs += androidAppResources",
    "managedShellConfig.minSdk.intValue()",
    "mouiMinSdk is only supported by the explicit legacy Android shell",
    "Generated ejected Android config must not claim project-owned manifest or resources",
    "kotlin.srcDirs",
    'file("${generatedRoot}/android/plugins")',
    'file("${androidPluginRoot}/generated/kotlin")',
    'file("${androidPluginRoot}/sources/kotlin")',
    'file("${androidPluginRoot}/sources/java")',
    'file("${androidPluginRoot}/res")',
    "androidPluginGeneratedKotlin",
    "androidPluginKotlin",
    "java.srcDirs += [androidPluginJava]",
    "res.srcDirs += [androidPluginResources]",
    "mouiActivityClass",
    "mouiClipboardProviderClass",
    "MOUI_MOBILE_ANDROID_GLUE_ROOT",
    "MOUI_MOBILE_ANDROID_MANAGED_SHELL",
    'androidx.activity:activity:1.13.0',
    'mouiCompileSdk") ?: "36"',
    'mouiTargetSdk") ?: "35"',
    'mouiMinSdk") ?: "23"',
    "28.2.13676358",
    "JavaVersion.VERSION_17",
    'version = "3.22.1"',
    "legacySupportsScroll",
    "if (modernAndroidShell)",
    "if (managedAndroidShell)",
    'throw new GradleException("MoUI legacy Android app ${appId} is missing exports.${key}',
    '"--android-shell", androidShell',
  ]);
  if (gradle.indexOf("new JsonSlurper().parse(metadataFile)") < gradle.indexOf("if (modernAndroidShell)")) {
    failures.push("managed/ejected Android Gradle must not parse raw mobile.json outside the legacy branch");
  }
  const cmake = readRepoFile("moui/mobile/android/cmake/MoUIMobileAndroid.cmake");
  requireTokens(failures, "managed Android CMake glue", cmake, [
    "mobile/runtime/moui_mobile_runtime_v1.cpp",
    "mobile/include",
    "set(MOUI_MOBILE_MOONBIT_MAIN_ALIAS moui_mobile_moonbit_generated_main)",
    "foreach(symbol_override",
    "MOUI_MOBILE_DESTROY_APPLICATION_SYMBOL",
    "MOUI_MOBILE_DISPATCH_HOST_RESPONSE_ENVELOPE_SYMBOL",
    "managed Android shell rejects app-specific symbol override",
  ]);
  if (/MOUI_MOBILE_RUNTIME_[A-Z_]+\s*=\$\{[^}]*_SYMBOL\}/.test(cmake)) {
    failures.push("managed Android CMake must not map runtime ABI operations to app-specific symbols");
  }
  const prepareNative = readRepoFile("moui/scripts/mobile/prepare-native-build.mjs");
  requireTokens(failures, "Android native build preparation", prepareNative, [
    'import { prepareAndroidPlugins } from "../../mobile/android/prepare-plugins.mjs"',
    'import { resolveAndroidManagedShell } from "../../mobile/android/resolve-managed-shell.mjs"',
    "--android-shell <mode>",
    'androidShell: "managed"',
    '"managed", "ejected", "legacy"',
    "validateAndroidLegacyExports",
    'androidShell === "legacy"',
    "legacySymbolLines",
    "...legacySymbolLines",
    'if (androidShell === "legacy") validateAndroidLegacyExports(config)',
    "prepareAndroidPlugins({",
    "resolveAndroidManagedShell({ app: appConfig, buildDir, workspaceRoot })",
    "appConfig.android.shellMode !== androidShell",
    "plugins,",
    "shellMode: androidShell",
    "androidShellConfig,",
    "androidPlugins,",
    "plugins: appConfig.plugins",
    "androidShell,",
  ]);
  if (prepareNative.includes("[debug-top]")) {
    failures.push("Android native build preparation must not print temporary environment diagnostics");
  }

  const pluginPreparerPath = "moui/mobile/android/prepare-plugins.mjs";
  const pluginTestPath = "moui/mobile/android/prepare-plugins.test.mjs";
  const managedResolverPath = "moui/mobile/android/resolve-managed-shell.mjs";
  const managedResolverTestPath = "moui/mobile/android/resolve-managed-shell.test.mjs";
  const pluginFixtureRoot = "moui/mobile/android/tests/fixtures/plugin";
  for (const path of [
    pluginPreparerPath,
    pluginTestPath,
    managedResolverPath,
    managedResolverTestPath,
    `${pluginFixtureRoot}/moui.plugin.json`,
    `${pluginFixtureRoot}/android/src/dev/fixture/android/FixturePlugin.kt`,
    `${pluginFixtureRoot}/android/src/dev/fixture/android/FixturePluginHelper.java`,
    `${pluginFixtureRoot}/android/res/values/strings.xml`,
  ]) requirePath(failures, "managed Android plugin contract", path);
  if (existsSync(resolve(repoRoot, pluginPreparerPath))) {
    const pluginPreparer = readRepoFile(pluginPreparerPath);
    requireTokens(failures, "managed Android plugin preparer", pluginPreparer, [
      "export const validateAndroidPluginEntry",
      "export const prepareAndroidPlugins",
      '"managed", "ejected", "legacy"',
      'shellMode === "legacy"',
      "rmSync(root, { recursive: true, force: true })",
      'join(root, "generated", "kotlin")',
      'join(root, "sources", "kotlin")',
      'join(root, "sources", "java")',
      'join(root, "res")',
      "isolateValuesResource",
      "plugin: MoUIMobilePlugin",
      "context.applicationContext",
      "plugin.id == expectedId",
      "installedIds.add(expectedId)",
      "Android plugin resource target conflict",
    ]);
  }
  if (existsSync(resolve(repoRoot, pluginTestPath))) {
    const pluginTest = readRepoFile(pluginTestPath);
    requireTokens(failures, "managed Android plugin tests", pluginTest, [
      "stage Kotlin, Java, resources, and a direct registry",
      "ejected Android stages app-owned plugin inputs while legacy remains isolated",
      "safe fully qualified type names",
      "rejecting true resource conflicts",
      "flows from manifest parser into generated registry",
    ]);
  }
  if (existsSync(resolve(repoRoot, managedResolverPath))) {
    const managedResolver = readRepoFile(managedResolverPath);
    requireTokens(failures, "managed Android shell resolver", managedResolver, [
      "readMobileApp",
      "resolveAndroidPermissionCapabilities",
      '"camera"',
      '"microphone"',
      '"location"',
      '"notifications"',
      '"photos"',
      '"clipboard"',
      "stageAppResources",
      'configurationOwnership: managed ? "framework-managed" : "project-owned"',
      "manifestPath = managed ?",
      "resourceDirs: appResources.resourceDirs",
      "eject the Android shell",
    ]);
    if (managedResolver.includes("dev.wzzc.moui.SUPPORTS_SCROLL")) {
      failures.push("managed Android generated Manifest must not restore removed supportsScroll metadata");
    }
  }
  const wrapper = readRepoFile("gradlew");
  if (!wrapper.includes('gradle_version="${MOUI_GRADLE_VERSION:-9.6.1}"')) {
    failures.push("Android build wrapper must default to Gradle 9.6.1");
  }
  for (const projectRoot of [
    "moui/mobile/android/template",
    "examples/counter/android_app",
    "examples/showcase/android_app",
  ]) {
    const build = readRepoFile(`${projectRoot}/build.gradle`);
    if (!build.includes('id "com.android.application" version "9.2.1"')) {
      failures.push(`${projectRoot}/build.gradle must pin AGP 9.2.1`);
    }
    const properties = readRepoFile(`${projectRoot}/gradle.properties`);
    if (!properties.includes("android.builtInKotlin=true")) {
      failures.push(`${projectRoot}/gradle.properties must enable AGP built-in Kotlin 2.2.10`);
    }
    const manifest = readRepoFile(`${projectRoot}/app/src/main/AndroidManifest.xml`);
    requireTokens(failures, `${projectRoot} manifest`, manifest, [
      '${mouiActivityClass}',
      '${mouiClipboardProviderClass}',
    ]);
  }

  const buildScript = readRepoFile("moui/scripts/mobile/build-android-apk.sh");
  requireTokens(failures, "Android APK builder", buildScript, [
    '--ejected-shell',
    '--legacy-java-shell',
    '--ejected-shell and --legacy-java-shell are mutually exclusive',
    '--ejected-shell requires a versioned .moui-shell.json',
    '--legacy-java-shell requires an explicit schema v1 --app-config',
    'MOUI_MOBILE_ALLOW_LEGACY_CONFIG=1',
    '"code": "android-java-shell"',
    'compile_sdk="36"',
    'target_sdk="35"',
    'mouiAndroidShell=legacy',
    'mouiAndroidShell=ejected',
    'prepare_args+=("--android-shell" "managed")',
    'prepare_args+=("--android-shell" "ejected")',
    'prepare_args+=("--android-shell" "legacy")',
    'schema v2 android.minSdk owns managed builds',
    'gradle_args+=("-PmouiMinSdk=$api_level")',
    'android_project="$build_dir/android-project"',
    "stage_android_project=1",
    'template_root="$moui_root/mobile/android/template"',
    '.moui-managed-android-stage',
    "Refusing to replace an unowned Android project",
    "Staged canonical Android shell",
  ]);
  if (buildScript.includes('android_project="$workspace_root/android_app"')) {
    failures.push("Android APK builder must stage the package-owned template instead of defaulting to workspace android_app");
  }
  const repositoryBuildScript = readRepoFile("scripts/build-mobile-android-apk.sh");
  requireTokens(failures, "repository Android APK wrapper", repositoryBuildScript, [
    'legacy_java_shell=0',
    'if [ "$legacy_java_shell" -eq 1 ]',
    '--android-project "$repo_root/examples/$app/android_app"',
    '--app-config "$repo_root/moui/mobile/legacy/fixtures/$app.mobile.json"',
  ]);
  const recorder = readRepoFile("scripts/record-mobile-runtime-smoke.mjs");
  if (recorder.includes(".supportsScroll")) {
    failures.push("runtime recorder must derive scroll evidence from its smoke contract, not schema v2 supportsScroll");
  }
  requireTokens(failures, "mobile runtime scroll contract", recorder, [
    'appConfig.id === "showcase"',
    "!platformConfig.exports?.dispatchScroll",
  ]);
  const androidStart = recorder.indexOf("const runAndroidSmoke");
  const androidEnd = recorder.indexOf("const iosIdbTree", androidStart);
  const androidRecorder = recorder.slice(androidStart, androidEnd);
  requireTokens(failures, "Android runtime recorder", androidRecorder, [
    "dev.wzzc.moui.mobile.MoUIActivity",
    "uiautomator",
  ]);
  if (androidRecorder.includes("moui_a11y_smoke") || androidRecorder.includes("parseMobileServiceProbePlan")) {
    failures.push("Android runtime recorder must not depend on shell-side probe behavior");
  }
};

const exampleMobileAppIds = () => {
  const examplesDir = join(repoRoot, "examples");
  if (!existsSync(examplesDir)) return [];
  return readdirSync(examplesDir, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .map(entry => join(examplesDir, entry.name, "mobile.json"))
    .filter(path => existsSync(path))
    .map(path => JSON.parse(readFileSync(path, "utf8")).id)
    .sort();
};

const validate = apps => {
  const failures = [];
  for (const [appId, app] of Object.entries(apps)) {
    requirePath(failures, `${appId}.appPackage`, app.appPackage);
    if (app.android) {
      requirePath(failures, `${appId}.android.moonPackage`, app.android.moonPackage);
      requirePath(failures, `${appId}.androidShell`, "moui/mobile/android/template");
      if (!validAndroidApplicationId(app.android.applicationId)) {
        failures.push(`${appId}.android.applicationId is not a valid Android application id`);
      }
      if (!validNativeLibrary(app.android.nativeLibrary)) {
        failures.push(`${appId}.android.nativeLibrary must contain only letters, numbers, and underscores`);
      }
      if (app.android.shellMode === "managed" && app.android.minSdk < 23) {
        failures.push(`${appId}.android.minSdk must be at least 23`);
      }
    }
    if (app.ios) {
      requirePath(failures, `${appId}.ios.moonPackage`, app.ios.moonPackage);
      requirePath(failures, `${appId}.ios.infoPlist`, app.ios.infoPlist);
      requirePath(failures, `${appId}.iosShell`, "moui/mobile/ios/template");
      if (!validBundleId(app.ios.bundleId)) {
        failures.push(`${appId}.ios.bundleId is not a valid bundle id`);
      }
      if (app.ios.shellMode === "managed" && Number.parseFloat(app.ios.deploymentTarget) < 15) {
        failures.push(`${appId}.ios.deploymentTarget must be at least 15.0`);
      }
    }
    if (app.harmonyos) {
      requirePath(failures, `${appId}.harmonyos.moonPackage`, app.harmonyos.moonPackage);
      requirePath(failures, `${appId}.harmonyosShell`, "moui/mobile/harmonyos/template");
      if (!validBundleId(app.harmonyos.bundleName)) {
        failures.push(`${appId}.harmonyos.bundleName is not a valid bundle name`);
      }
      if (!validNativeLibrary(app.harmonyos.nativeLibrary)) {
        failures.push(`${appId}.harmonyos.nativeLibrary must contain only letters, numbers, and underscores`);
      }
      if (app.harmonyos.shellMode === "managed" && app.harmonyos.compatibleSdkVersion < 20) {
        failures.push(`${appId}.harmonyos.compatibleSdkVersion must be at least 20`);
      }
    }
  }
  return failures;
};

try {
  const apps = readMobileApps({
    workspaceRoot: repoRoot,
    mouiRoot: join(repoRoot, "moui"),
    skiaRoot: join(repoRoot, "moui_skia"),
    appIds: exampleMobileAppIds(),
  });
  const failures = validate(apps);
  validateAndroidManagedShell(failures);
  if (failures.length > 0) {
    for (const failure of failures) console.error(`[moui-mobile-config] ${failure}`);
    process.exit(1);
  }
  const appIds = Object.keys(apps).sort().join(", ");
  console.log(`[moui-mobile-config] validated ${Object.keys(apps).length} mobile app(s): ${appIds}`);
} catch (error) {
  console.error(`[moui-mobile-config] ${error.message}`);
  process.exit(1);
}
