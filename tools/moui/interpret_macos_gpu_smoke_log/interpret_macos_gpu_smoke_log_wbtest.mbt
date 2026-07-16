///|
test "detects metal short path success markers" {
  let log =
    #|surface_route=metal-gpu
    #|surface_gpu=true
    #|present_count=12
    #|MoUI Skia GPU Metal renderer smoke passed
    #|
  let result = interpret_macos_gpu_smoke_log(log)
  debug_inspect(result.metal_route, content="true")
  debug_inspect(result.surface_gpu, content="true")
  debug_inspect(result.gpu_smoke_passed, content="true")
  debug_inspect(result.present_count, content="12")
  debug_inspect(result.short_path_ok, content="true")
  debug_inspect(result.worker_owned, content="true")
}

///|
test "rejects cpu raster short path" {
  let result = interpret_macos_gpu_smoke_log("surface_route=cpu-raster")
  debug_inspect(result.metal_route, content="false")
  debug_inspect(result.short_path_ok, content="false")
  debug_inspect(result.present_count, content="0")
}
