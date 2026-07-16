///|
test "rejects forbidden GPU worker readback tokens" {
  let failures = validate_worker_source(
    "worker.cpp",
    "void present() { read_pixels(surface); }\n",
  )
  debug_inspect(
    failures,
    content=(
      #|["worker.cpp:1: GPU worker contains forbidden Skia readback"]
    ),
  )
}

///|
test "accepts clean worker and android dynamic vulkan flags" {
  let worker =
    #|void present_gpu() {
    #|  submit_mailbox();
    #|}
    #|
  let worker_api =
    #|struct Diagnostics {
    #|  readback_count: 0L
    #|}
    #|
  let build =
    #|if (platform === "android") {
    #|  flags.push("-ldl");
    #|} else if (platform === "harmonyos") {
    #|  flags.push("-lvulkan");
    #|}
    #|
  let failures = validate_sources(
    "worker.cpp",
    worker,
    "worker_api.mbt",
    worker_api,
    "build.js",
    build,
  )
  debug_inspect(failures, content="[]")
}

///|
test "rejects android static vulkan link" {
  let build =
    #|if (platform === "android") {
    #|  flags.push("-lvulkan");
    #|} else if (platform === "harmonyos") {
    #|  flags.push("-lvulkan");
    #|}
    #|
  let failures = validate_build_flags("build.js", build)
  debug_inspect(
    failures,
    content=(
      #|["build.js: Android minSdk 23 GPU builds must dynamically load Vulkan, not link -lvulkan"]
    ),
  )
}

///|
test "requires zero readback diagnostics" {
  let failures = validate_worker_api(
    "worker_api.mbt",
    "struct Diagnostics { readback_count: 1L }",
  )
  debug_inspect(
    failures,
    content=(
      #|["worker_api.mbt: native worker diagnostics must report readback_count: 0L"]
    ),
  )
}
