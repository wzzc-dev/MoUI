///|
test "macos dev bundle components replace non-identifier characters" {
  inspect(macos_dev_bundle_component("Showcase 2"), content="Showcase-2")
  inspect(macos_dev_bundle_component("moon/UI"), content="moon-UI")
  inspect(macos_dev_bundle_component(""), content="app")
}

///|
test "macos dev bundle path stays under the build base" {
  let target : DesktopTarget = {
    platform: "macos",
    package_path: "macos_skia",
    target: "native",
  }
  let flow : DesktopFlow = {
    app_root: "/tmp/demo-app",
    build_base: "/tmp/demo-workspace",
    package_path: "macos_skia",
    target,
  }
  inspect(
    macos_dev_bundle_dir(flow, "Demo"),
    content="/tmp/demo-workspace/_build/moui-run/Demo.app",
  )
}

///|
test "macos dev bundle id falls back to the product name" {
  let target : DesktopTarget = {
    platform: "macos",
    package_path: "macos_skia",
    target: "native",
  }
  let flow : DesktopFlow = {
    app_root: "/tmp/moui-dev-bundle-id-test",
    build_base: "/tmp",
    package_path: "macos_skia",
    target,
  }
  inspect(
    macos_dev_bundle_id(flow, "Demo App"),
    content="dev.wzzc.moui.dev.demo-app.macos-skia",
  )
}
