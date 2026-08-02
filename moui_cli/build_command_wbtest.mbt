///|
test "build parser accepts embedded-runtime options" {
  let parsed = parse_build_args(
    [
      "android", "demo", "--mobile-config", "/tmp/moui.mobile.json", "--prepare-only",
      "--renderer", "skia-raster", "--abi", "x86_64",
    ],
    "/workspace",
    Linux,
  )
  guard parsed is Ok({ platform: "android", options: Some(options), .. }) else {
    fail("expected build arguments to parse")
  }
  debug_inspect(
    options.app_config_path,
    content="Some(\"/tmp/moui.mobile.json\")",
  )
  debug_inspect(options.renderer, content="Some(\"skia-raster\")")
  debug_inspect(options.abi, content="Some(\"x86_64\")")
  inspect(options.prepare_only, content="true")
}

///|
test "build parser rejects removed ejected-shell option" {
  match
    parse_build_args(
      ["android", "demo", "--ejected-shell"],
      "/workspace",
      Linux,
    ) {
    Err(message) =>
      inspect(message, content="unknown option for moui build: --ejected-shell")
    Ok(_) => fail("expected removed option to be rejected")
  }
}
