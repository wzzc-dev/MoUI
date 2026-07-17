///|
fn validate_android_managed_shell(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let kotlin_dir = "moui/mobile/android/src/main/kotlin/dev/wzzc/moui/mobile"
  let kotlin_files = [
    "MoUIActivity.kt", "MoUISurfaceView.kt", "MoUIClipboard.kt", "MoUIAccessibility.kt",
    "MoUIPlatformViews.kt", "MoUIHostServices.kt", "MoUIMobilePlugin.kt", "MoUIMobileCapabilities.kt",
    "MoUINativeBridge.kt",
  ]
  for file in kotlin_files {
    require_path(
      repo_root,
      failures,
      "managed Android " + file,
      kotlin_dir + "/" + file,
    )
  }
  let mut missing_kotlin = false
  for file in kotlin_files {
    if !@tools.file_exists(
        @tools.resolve_path(repo_root, kotlin_dir + "/" + file),
      ) {
      missing_kotlin = true
    }
  }
  if missing_kotlin {
    return
  }
  let managed_sources_parts : Array[String] = []
  for file in kotlin_files {
    match read_repo_text(repo_root, kotlin_dir + "/" + file) {
      Ok(text) => managed_sources_parts.push(text)
      Err(message) => failures.push(message)
    }
  }
  let managed_sources = managed_sources_parts.join("\n")
  let activity = match
    read_repo_text(repo_root, kotlin_dir + "/MoUIActivity.kt") {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      return
    }
  }
  require_tokens(failures, "managed Android Activity", activity, [
    "class MoUIActivity : ComponentActivity()", "MoUIGeneratedPluginRegistry.install(this, pluginCapabilities)",
    "root.addView(surfaceView", "root.addView(overlay", "Choreographer.FrameCallback",
    "detachSurface(\"destroy\")", "if (isFinishing && !isChangingConfigurations)",
    "MoUINativeBridge.destroyApplication()", "moui-mobile application destroy result=",
    "dispatchScrollPhase(phase, x, y)", "META_STATUS_BAR", "STATUS_BAR_HIDDEN -> true",
    "STATUS_BAR_VISIBLE -> false", "WindowInsetsCompat.Type.navigationBars()", "WindowInsetsCompat.Type.statusBars()",
  ])
  if index_of(activity, "root.addView(surfaceView") >
    index_of(activity, "root.addView(overlay") {
    failures.push(
      "managed Android Activity must place MoUISurfaceView below the PlatformView overlay",
    )
  }
  if index_of(activity, "loadNativeLibraryFromManifest()") >
    index_of(
      activity, "MoUIGeneratedPluginRegistry.install(this, pluginCapabilities)",
    ) {
    failures.push(
      "managed Android plugins must install after the runtime native library is loaded",
    )
  }
  if index_of(
      activity, "MoUIGeneratedPluginRegistry.install(this, pluginCapabilities)",
    ) >
    index_of(activity, "MoUINativeBridge.rendererStatusJson()") {
    failures.push(
      "managed Android plugins must install before the shell starts runtime host work",
    )
  }
  if activity.contains("supportsScroll") ||
    activity.contains("META_SUPPORTS_SCROLL") {
    failures.push(
      "managed Android Activity must negotiate scroll through runtime ABI v1 instead of manifest metadata",
    )
  }
  if activity.contains("if (") &&
    activity.contains("dispatchScrollPhase(phase, x, y)") {
    // Approximate the JS regex: if (...) dispatchScrollPhase(phase, x, y)
    // Fail when a single-line conditional guards the dispatch.
    for line in activity.split("\n") {
      let trimmed = line.trim().to_owned()
      if trimmed.has_prefix("if ") &&
        trimmed.contains("dispatchScrollPhase(phase, x, y)") {
        failures.push(
          "managed Android Activity must dispatch scroll unconditionally and let runtime ABI v1 fail closed",
        )
        break
      }
    }
  }
  for
    token in [
      "moui_a11y_smoke", "MOUI_MOBILE_A11Y_SMOKE", "MOUI_MOBILE_SERVICE_SMOKE", "service smoke",
      "service probe plan",
    ] {
    if managed_sources.contains(token) {
      failures.push(
        "managed Android production sources must not contain probe token " +
        Json::string(token).stringify(),
      )
    }
  }

  let jni = match
    read_repo_text(
      repo_root, "moui/mobile/android/src/main/cpp/moui_mobile_jni.cpp",
    ) {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      return
    }
  }
  require_tokens(failures, "managed Android JNI", jni, [
    "JNI_OnLoad", "RegisterNatives", "dev/wzzc/moui/mobile/MoUINativeBridge", "moui_mobile_get_runtime_api_v1",
    "moui_mobile_runtime_api_v1_is_compatible", "g_runtime_api->take_host_update_envelope_json",
    "g_runtime_api->dispatch_host_response_envelope", "g_runtime_api->detach_surface",
    "g_runtime_api->destroy_application",
  ])
  let native_methods : Array[(String, String)] = [
    ("attachSurface", "(Landroid/view/Surface;IID)Z"),
    ("resize", "(IID)Z"),
    ("dispatchPointer", "(IDDD)Z"),
    ("dispatchScroll", "(DDDDI)Z"),
    ("frameTick", "(D)Z"),
    ("takeHostUpdates", "()Ljava/lang/String;"),
    ("dispatchHostResponseEnvelope", "(Ljava/lang/String;)Z"),
    ("dispatchTextInput", "(ILjava/lang/String;II)Z"),
    ("dispatchCommand", "(I)Z"),
    ("dispatchAccessibility", "(IILjava/lang/String;)Z"),
    ("completeClipboard", "(IIILjava/lang/String;[B)Z"),
    ("renderFrame", "()Z"),
    ("detachSurface", "()V"),
    ("destroyApplication", "()Z"),
    ("rendererConfigure", "(Ljava/lang/String;)Z"),
    ("rendererStatusJson", "()Ljava/lang/String;"),
  ]
  let native_bridge = match
    read_repo_text(repo_root, kotlin_dir + "/MoUINativeBridge.kt") {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      ""
    }
  }
  for pair in native_methods {
    let (name, descriptor) = pair
    if !jni.contains("\"" + name + "\"") ||
      !jni.contains("\"" + descriptor + "\"") {
      failures.push(
        "managed Android JNI registration is missing " + name + " " + descriptor,
      )
    }
    if !native_bridge.contains("external fun " + name) {
      failures.push(
        "managed Android Kotlin bridge is missing native method " + name,
      )
    }
  }
  if jni.contains("Java_dev_") {
    failures.push(
      "managed Android JNI must not export name-mangled Java bindings",
    )
  }
  if jni.contains("moonbit_string_t") ||
    jni.contains("MOUI_MOBILE_ATTACH_SURFACE(") {
    failures.push(
      "managed Android JNI must consume the negotiated runtime ABI instead of MoonBit or app-specific exports",
    )
  }
  match read_repo_text(repo_root, kotlin_dir + "/MoUIClipboard.kt") {
    Ok(clipboard) =>
      require_tokens(
        failures,
        "managed Android clipboard generation routing",
        clipboard,
        [
          "sessionGeneration: Int?", "MoUINativeBridge.completeClipboard(", "clipboard update is missing Host Wire session generation",
        ],
      )
    Err(message) => failures.push(message)
  }
  let platform_views = match
    read_repo_text(repo_root, kotlin_dir + "/MoUIPlatformViews.kt") {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      ""
    }
  }
  require_tokens(
    failures,
    "managed Android PlatformView routing",
    platform_views,
    [
      "fun interface MoUIPlatformViewEventSink", "sink: MoUIPlatformViewEventSink",
      "require(!kind.startsWith(\"moui.\"))", "data class PlatformViewKey(val kind: String, val id: String)",
      "LinkedHashMap<PlatformViewKey, HostedView>", "Looper.myLooper() != Looper.getMainLooper()",
      "active.token !== token", "sessionGeneration ?: return false", "revision <= 0",
      "put(\"kind\", \"platform-view\")", "MoUINativeBridge.dispatchHostResponseEnvelope",
    ],
  )
  if platform_views.contains("LinkedHashMap<String, HostedView>") ||
    platform_views.contains("hosted[placement.id]") {
    failures.push(
      "managed Android PlatformViews must key hosted views by (kind,id), not id alone",
    )
  }
  let surface_view = match
    read_repo_text(repo_root, kotlin_dir + "/MoUISurfaceView.kt") {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      ""
    }
  }
  let host_services = match
    read_repo_text(repo_root, kotlin_dir + "/MoUIHostServices.kt") {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      ""
    }
  }
  match read_repo_text(repo_root, kotlin_dir + "/MoUIMobilePlugin.kt") {
    Ok(mobile_plugin) =>
      require_tokens(failures, "managed Android plugin API", mobile_plugin, [
        "interface MoUIMobilePlugin", "val id: String", "fun install(context: Context)",
      ])
    Err(message) => failures.push(message)
  }
  require_tokens(
    failures,
    "managed Android Host Service routing",
    surface_view,
    ["\"platform-channel\" -> MoUIHostServices.dispatch(update, generation)"],
  )
  require_tokens(
    failures,
    "managed Android Host Service registry",
    host_services,
    [
      "data class MoUIHostServiceRequest(", "enum class MoUIHostServiceStatus", "fun interface MoUIHostServiceHandler",
      "fun interface MoUIHostServiceTask", "completion: MoUIHostServiceCompletion",
      "ConcurrentHashMap<String, MoUIHostServiceHandler>", "ConcurrentHashMap<RequestKey, PendingRequest>",
      "require(!channel.startsWith(\"moui.\"))", "AtomicBoolean(false)", "compareAndSet(false, true)",
      "request.cancel()", "completion.invalidate()", "nextTask?.cancel()", "pending.putIfAbsent(key, requestState)",
      "pending.remove(key)", "Handler(Looper.getMainLooper())", "generation == null || generation <= 0",
      "completion.error(\"invalid platform channel request\")", "completion.unavailable(\"platform channel is unavailable: $channel\")",
      "put(\"kind\", \"platform-channel\")", "put(\"requestId\", requestId)", "put(\"status\", response.status.wireValue)",
      "put(\"sessionGeneration\", generation)", "MoUINativeBridge.dispatchHostResponseEnvelope",
    ],
  )
  if surface_view.contains(
      "platform channel request has no managed-shell handler",
    ) {
    failures.push(
      "managed Android Host Service requests must complete through the registry",
    )
  }
  if !surface_view.contains("MoUIHostServices.reset()") {
    failures.push(
      "managed Android host state reset must cancel pending plugin services",
    )
  }

  let legacy_root = "moui/mobile/legacy/android"
  for
    path in [
      "README.md", "src/main/java/dev/wzzc/moui/mobile/MobileActivity.java", "src/main/java/dev/wzzc/moui/mobile/MobileSurfaceView.java",
      "src/main/java/dev/wzzc/moui/mobile/MobileClipboardProvider.java", "src/main/cpp/moui_mobile_jni.cpp",
      "src/main/cpp/moui_android_compat.c", "src/main/cpp/moui_android_compat.h",
    ] {
    require_path(
      repo_root,
      failures,
      "legacy Android fixture",
      legacy_root + "/" + path,
    )
  }
  let legacy_jni_path = legacy_root + "/src/main/cpp/moui_mobile_jni.cpp"
  if @tools.file_exists(@tools.resolve_path(repo_root, legacy_jni_path)) {
    match read_repo_text(repo_root, legacy_jni_path) {
      Ok(text) =>
        if !text.contains("Java_dev_wzzc_moui_mobile_MobileActivity") {
          failures.push(
            "legacy Android fixture must retain its Release N JNI symbols",
          )
        }
      Err(message) => failures.push(message)
    }
  }

  match read_repo_text(repo_root, "moui/mobile/android/mobile-app.gradle") {
    Ok(gradle) => {
      require_tokens(failures, "managed Android Gradle glue", gradle, [
        "mouiAndroidShell", "\"managed\", \"ejected\", \"legacy\"", "modernAndroidShell",
        "ejectedAndroidShell", "file(\"${generatedRoot}/android/${androidShell}-shell\")",
        "file(\"${generatedShellRoot}/shell-config.json\")", "new JsonSlurper().parse(generatedShellConfigFile)",
        "manifest.srcFile androidManagedManifest", "res.srcDirs += androidAppResources",
        "managedShellConfig.minSdk.intValue()", "mouiMinSdk is only supported by the explicit legacy Android shell",
        "Generated ejected Android config must not claim project-owned manifest or resources",
        "kotlin.srcDirs", "file(\"${generatedRoot}/android/plugins\")", "file(\"${androidPluginRoot}/generated/kotlin\")",
        "file(\"${androidPluginRoot}/sources/kotlin\")", "file(\"${androidPluginRoot}/sources/java\")",
        "file(\"${androidPluginRoot}/res\")", "androidPluginGeneratedKotlin", "androidPluginKotlin",
        "java.srcDirs += [androidPluginJava]", "res.srcDirs += [androidPluginResources]",
        "mouiActivityClass", "mouiClipboardProviderClass", "MOUI_MOBILE_ANDROID_GLUE_ROOT",
        "MOUI_MOBILE_ANDROID_MANAGED_SHELL", "androidx.activity:activity:1.13.0",
        "mouiCompileSdk\") ?: \"36\"", "mouiTargetSdk\") ?: \"35\"", "mouiMinSdk\") ?: \"23\"",
        "28.2.13676358", "JavaVersion.VERSION_17", "version = \"3.22.1\"", "legacySupportsScroll",
        "if (modernAndroidShell)", "if (managedAndroidShell)", "throw new GradleException(\"MoUI legacy Android app ${appId} is missing exports.${key}",
        "\"--android-shell\", androidShell",
      ])
      if index_of(gradle, "new JsonSlurper().parse(metadataFile)") <
        index_of(gradle, "if (modernAndroidShell)") {
        failures.push(
          "managed/ejected Android Gradle must not parse raw mobile.json outside the legacy branch",
        )
      }
    }
    Err(message) => failures.push(message)
  }
  match
    read_repo_text(
      repo_root, "moui/mobile/android/cmake/MoUIMobileAndroid.cmake",
    ) {
    Ok(cmake) => {
      require_tokens(failures, "managed Android CMake glue", cmake, [
        "mobile/runtime/moui_mobile_runtime_v1.cpp", "mobile/include", "set(MOUI_MOBILE_MOONBIT_MAIN_ALIAS moui_mobile_moonbit_generated_main)",
        "foreach(symbol_override", "MOUI_MOBILE_DESTROY_APPLICATION_SYMBOL", "MOUI_MOBILE_DISPATCH_HOST_RESPONSE_ENVELOPE_SYMBOL",
        "managed Android shell rejects app-specific symbol override",
      ])
      if cmake.contains("MOUI_MOBILE_RUNTIME_") &&
        cmake.contains("=${") &&
        cmake.contains("_SYMBOL}") {
        // Approximate JS regex for ABI-to-app-symbol mapping.
        for line in cmake.split("\n") {
          let text = line.to_owned()
          if text.contains("MOUI_MOBILE_RUNTIME_") &&
            text.contains("=${") &&
            text.contains("_SYMBOL}") {
            failures.push(
              "managed Android CMake must not map runtime ABI operations to app-specific symbols",
            )
            break
          }
        }
      }
    }
    Err(message) => failures.push(message)
  }
  match
    read_repo_text(repo_root, "moui/scripts/mobile/prepare-native-build.mjs") {
    Ok(prepare_native) => {
      require_tokens(
        failures,
        "Android native build preparation",
        prepare_native,
        [
          "import { prepareAndroidPlugins } from \"../../mobile/android/prepare-plugins.mjs\"",
          "import { resolveAndroidManagedShell } from \"../../mobile/android/resolve-managed-shell.mjs\"",
          "--android-shell <mode>", "androidShell: \"managed\"", "\"managed\", \"ejected\", \"legacy\"",
          "validateAndroidLegacyExports", "androidShell === \"legacy\"", "legacySymbolLines",
          "...legacySymbolLines", "if (androidShell === \"legacy\") validateAndroidLegacyExports(config)",
          "prepareAndroidPlugins({", "resolveAndroidManagedShell({ app: appConfig, buildDir, workspaceRoot })",
          "appConfig.android.shellMode !== androidShell", "plugins,", "shellMode: androidShell",
          "androidShellConfig,", "androidPlugins,", "plugins: appConfig.plugins",
          "androidShell,",
        ],
      )
      if prepare_native.contains("[debug-top]") {
        failures.push(
          "Android native build preparation must not print temporary environment diagnostics",
        )
      }
    }
    Err(message) => failures.push(message)
  }

  let plugin_preparer_path = "moui/mobile/android/prepare-plugins.mjs"
  let plugin_test_path = "moui/mobile/android/prepare-plugins.test.mjs"
  let managed_resolver_path = "moui/mobile/android/resolve-managed-shell.mjs"
  let managed_resolver_test_path = "moui/mobile/android/resolve-managed-shell.test.mjs"
  let plugin_fixture_root = "moui/mobile/android/tests/fixtures/plugin"
  for
    path in [
      plugin_preparer_path,
      plugin_test_path,
      managed_resolver_path,
      managed_resolver_test_path,
      plugin_fixture_root + "/moui.plugin.json",
      plugin_fixture_root + "/android/src/dev/fixture/android/FixturePlugin.kt",
      plugin_fixture_root +
      "/android/src/dev/fixture/android/FixturePluginHelper.java",
      plugin_fixture_root + "/android/res/values/strings.xml",
    ] {
    require_path(repo_root, failures, "managed Android plugin contract", path)
  }
  if @tools.file_exists(@tools.resolve_path(repo_root, plugin_preparer_path)) {
    match read_repo_text(repo_root, plugin_preparer_path) {
      Ok(plugin_preparer) =>
        require_tokens(
          failures,
          "managed Android plugin preparer",
          plugin_preparer,
          [
            "export const validateAndroidPluginEntry", "export const prepareAndroidPlugins",
            "\"managed\", \"ejected\", \"legacy\"", "shellMode === \"legacy\"", "rmSync(root, { recursive: true, force: true })",
            "join(root, \"generated\", \"kotlin\")", "join(root, \"sources\", \"kotlin\")",
            "join(root, \"sources\", \"java\")", "join(root, \"res\")", "isolateValuesResource",
            "plugin: MoUIMobilePlugin", "context.applicationContext", "plugin.id == expectedId",
            "installedIds.add(expectedId)", "Android plugin resource target conflict",
          ],
        )
      Err(message) => failures.push(message)
    }
  }
  if @tools.file_exists(@tools.resolve_path(repo_root, plugin_test_path)) {
    match read_repo_text(repo_root, plugin_test_path) {
      Ok(plugin_test) =>
        require_tokens(failures, "managed Android plugin tests", plugin_test, [
          "stage Kotlin, Java, resources, and a direct registry", "ejected Android stages app-owned plugin inputs while legacy remains isolated",
          "safe fully qualified type names", "rejecting true resource conflicts",
          "flows from manifest parser into generated registry",
        ])
      Err(message) => failures.push(message)
    }
  }
  if @tools.file_exists(@tools.resolve_path(repo_root, managed_resolver_path)) {
    match read_repo_text(repo_root, managed_resolver_path) {
      Ok(managed_resolver) => {
        require_tokens(
          failures,
          "managed Android shell resolver",
          managed_resolver,
          [
            "readMobileApp", "resolveAndroidPermissionCapabilities", "\"camera\"",
            "\"microphone\"", "\"location\"", "\"notifications\"", "\"photos\"",
            "\"clipboard\"", "stageAppResources", "configurationOwnership: managed ? \"framework-managed\" : \"project-owned\"",
            "manifestPath = managed ?", "resourceDirs: appResources.resourceDirs",
            "eject the Android shell",
          ],
        )
        if managed_resolver.contains("dev.wzzc.moui.SUPPORTS_SCROLL") {
          failures.push(
            "managed Android generated Manifest must not restore removed supportsScroll metadata",
          )
        }
      }
      Err(message) => failures.push(message)
    }
  }
  match read_repo_text(repo_root, "gradlew") {
    Ok(wrapper) =>
      if !wrapper.contains("gradle_version=\"${MOUI_GRADLE_VERSION:-9.6.1}\"") {
        failures.push("Android build wrapper must default to Gradle 9.6.1")
      }
    Err(message) => failures.push(message)
  }
  for
    project_root in [
      "moui/mobile/android/template", "examples/counter/android_app", "examples/showcase/android_app",
    ] {
    match read_repo_text(repo_root, project_root + "/build.gradle") {
      Ok(build) =>
        if !build.contains("id \"com.android.application\" version \"9.2.1\"") {
          failures.push(project_root + "/build.gradle must pin AGP 9.2.1")
        }
      Err(message) => failures.push(message)
    }
    match read_repo_text(repo_root, project_root + "/gradle.properties") {
      Ok(properties) =>
        if !properties.contains("android.builtInKotlin=true") {
          failures.push(
            project_root +
            "/gradle.properties must enable AGP built-in Kotlin 2.2.10",
          )
        }
      Err(message) => failures.push(message)
    }
    match
      read_repo_text(
        repo_root,
        project_root + "/app/src/main/AndroidManifest.xml",
      ) {
      Ok(manifest) =>
        require_tokens(failures, project_root + " manifest", manifest, [
          "${mouiActivityClass}", "${mouiClipboardProviderClass}",
        ])
      Err(message) => failures.push(message)
    }
  }
  match read_repo_text(repo_root, "moui/scripts/mobile/build-android-apk.sh") {
    Ok(build_script) => {
      require_tokens(failures, "Android APK builder", build_script, [
        "--ejected-shell", "--legacy-java-shell", "--ejected-shell and --legacy-java-shell are mutually exclusive",
        "--ejected-shell requires a versioned .moui-shell.json", "--legacy-java-shell requires an explicit schema v1 --app-config",
        "MOUI_MOBILE_ALLOW_LEGACY_CONFIG=1", "\"code\": \"android-java-shell\"",
        "compile_sdk=\"36\"", "target_sdk=\"35\"", "mouiAndroidShell=legacy", "mouiAndroidShell=ejected",
        "prepare_args+=(\"--android-shell\" \"managed\")", "prepare_args+=(\"--android-shell\" \"ejected\")",
        "prepare_args+=(\"--android-shell\" \"legacy\")", "schema v2 android.minSdk owns managed builds",
        "gradle_args+=(\"-PmouiMinSdk=$api_level\")", "android_project=\"$build_dir/android-project\"",
        "stage_android_project=1", "template_root=\"$moui_root/mobile/android/template\"",
        ".moui-managed-android-stage", "Refusing to replace an unowned Android project",
        "Staged canonical Android shell",
      ])
      if build_script.contains(
          "android_project=\"$workspace_root/android_app\"",
        ) {
        failures.push(
          "Android APK builder must stage the package-owned template instead of defaulting to workspace android_app",
        )
      }
    }
    Err(message) => failures.push(message)
  }
  match read_repo_text(repo_root, "scripts/build-mobile-android-apk.sh") {
    Ok(repository_build_script) =>
      require_tokens(
        failures,
        "repository Android APK wrapper",
        repository_build_script,
        [
          "legacy_java_shell=0", "if [ \"$legacy_java_shell\" -eq 1 ]", "--android-project \"$repo_root/examples/$app/android_app\"",
          "--app-config \"$repo_root/moui/mobile/legacy/fixtures/$app.mobile.json\"",
        ],
      )
    Err(message) => failures.push(message)
  }
  match read_repo_text(repo_root, "scripts/record-mobile-runtime-smoke.mjs") {
    Ok(recorder) => {
      if recorder.contains(".supportsScroll") {
        failures.push(
          "runtime recorder must derive scroll evidence from its smoke contract, not schema v2 supportsScroll",
        )
      }
      require_tokens(failures, "mobile runtime scroll contract", recorder, [
        "appConfig.id === \"showcase\"", "!platformConfig.exports?.dispatchScroll",
      ])
      let android_start = index_of(recorder, "const runAndroidSmoke")
      let android_end = index_of(recorder, "const iosIdbTree")
      let android_recorder = if android_start >= 0 &&
        android_end > android_start {
        recorder[android_start:android_end].to_owned()
      } else {
        ""
      }
      require_tokens(failures, "Android runtime recorder", android_recorder, [
        "dev.wzzc.moui.mobile.MoUIActivity", "uiautomator",
      ])
      if android_recorder.contains("moui_a11y_smoke") ||
        android_recorder.contains("parseMobileServiceProbePlan") {
        failures.push(
          "Android runtime recorder must not depend on shell-side probe behavior",
        )
      }
    }
    Err(message) => failures.push(message)
  }
}
