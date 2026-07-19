///|
test "workspace member parser keeps declared paths" {
  assert_eq(
    workspace_members(
      "members = [\n  \"./moui\",\n  \"./examples/counter\",\n]\n",
    ),
    Ok(["./moui", "./examples/counter"]),
  )
}

///|
test "workspace member parser rejects incomplete input" {
  assert_eq(
    workspace_members("members = [\n  \"./moui\",\n"),
    Err("moon.work members array is not closed"),
  )
}

///|
fn platform_test_repo_root() -> String {
  let root = Ref(@env.current_dir().unwrap_or("."))
  for _ in 0..<8 {
    if @tools.file_exists(@tools.join_path(root.val, "moon.work")) &&
      @tools.directory_exists(@tools.join_path(root.val, "checks/platforms")) {
      return root.val
    }
    root.val = @tools.resolve_path(root.val, "..")
  }
  root.val
}

///|
test "mobile platform manifests keep build and runtime evidence separated" {
  let rows = match read_platform_rows(platform_test_repo_root()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let mobile_rows = rows.filter(row => {
    row.platform == "android" ||
    row.platform == "ios" ||
    row.platform == "harmonyos"
  })
  assert_eq(mobile_rows.length(), 3)
  for row in mobile_rows {
    assert_eq(row.source_status, "passed")
    assert_eq(row.renderer_status, "partial")
    assert_eq(row.runtime_status, "partial")
    assert_eq(row.shell_api, 1)
    assert_eq(row.runtime_abi, 1)
    assert_eq(row.actual_presenter_route, "unverified")
    match row.platform {
      "android" => {
        assert_eq(row.shell_kind, "managed-kotlin")
        assert_eq(row.deployment_floor, "Android 23")
        assert_true(row.toolchain_floor.contains("compile SDK 36"))
        assert_true(row.toolchain_floor.contains("target SDK 35"))
        assert_eq(row.declared_presenter_route, "vulkan-direct")
      }
      "ios" => {
        assert_eq(row.shell_kind, "managed-swiftui")
        assert_eq(row.deployment_floor, "iOS 15.0")
        assert_eq(row.toolchain_floor, "Xcode 15.4 / Swift 5")
        assert_eq(row.declared_presenter_route, "metal-direct")
      }
      "harmonyos" => {
        assert_eq(row.shell_kind, "managed-arkts-xcomponent")
        assert_eq(row.deployment_floor, "HarmonyOS API 20")
        assert_true(row.toolchain_floor.contains("target API 21"))
        assert_true(row.toolchain_floor.contains("model 6.0.1"))
        assert_eq(row.declared_presenter_route, "egl-direct")
      }
      _ => fail("unexpected mobile platform: " + row.platform)
    }
  }
}

///|
test "mobile platform validator rejects inferred presenter routes" {
  let result = validate_mobile_platform_contract(
    {
      platform: "android",
      source_status: "passed",
      source_fact_statuses: ["passed", "passed", "passed"],
      source_verified_on: "2026-07-15",
      source_matrix_command: "run-shell-matrix.sh android --fallback-skia",
      renderer_status: "partial",
      runtime_status: "partial",
      shell_kind: "managed-kotlin",
      shell_api: 1,
      runtime_abi: 1,
      declared_presenter_route: "vulkan-direct",
      actual_presenter_route: "vulkan-direct",
      presenter_evidence_status: "unverified",
      presenter_evidence_kind: "none",
      presenter_evidence_reference: "requested renderer only",
    },
    "checks/platforms/android.json",
  )
  guard result is Err(message) else {
    fail("an inferred presenter route must be rejected")
  }
  assert_true(message.contains("matching-device direct-present evidence"))
}

///|
test "mobile source build status aggregates required fixtures" {
  let result = validate_mobile_platform_contract(
    {
      platform: "ios",
      source_status: "passed",
      source_fact_statuses: ["passed", "passed", "partial"],
      source_verified_on: "2026-07-15",
      source_matrix_command: "run-shell-matrix.sh ios --fallback-skia",
      renderer_status: "partial",
      runtime_status: "partial",
      shell_kind: "managed-swiftui",
      shell_api: 1,
      runtime_abi: 1,
      declared_presenter_route: "metal-direct",
      actual_presenter_route: "unverified",
      presenter_evidence_status: "unverified",
      presenter_evidence_kind: "none",
      presenter_evidence_reference: "fresh marker pending",
    },
    "checks/platforms/ios.json",
  )
  guard result is Err(message) else {
    fail("a partial fixture must keep sourceBuild partial")
  }
  assert_true(message.contains("sourceBuild.status must aggregate"))
}

///|
test "generated repository facts has stable source sections" {
  let text = render_repository_facts(
    [
      {
        label: "root",
        path: "moui/pkg.generated.mbti",
        lines: 10,
        public_declarations: 2,
        pub_all_declarations: 0,
      },
    ],
    ["./moui", "./examples/counter"],
    [
      {
        id: "counter",
        path: "examples/counter",
        title: "Counter",
        featured: true,
      },
    ],
    [
      {
        platform: "web",
        source_status: "passed",
        renderer_status: "passed",
        runtime_status: "passed",
        shell_kind: "browser",
        shell_api: 0,
        runtime_abi: 0,
        deployment_floor: "wasm-gc",
        toolchain_floor: "MoonBit",
        declared_presenter_route: "browser-webgpu",
        actual_presenter_route: "browser-webgpu",
      },
    ],
    1,
    [{ id: "start", title: "Start", entry_count: 1 }],
  )
  assert_true(
    text.has_prefix("<!-- Generated by tools/moui/generate_repo_docs"),
  )
  assert_true(text.contains("## API Surface"))
  assert_true(text.contains("## Workspace Members"))
  assert_true(text.contains("| ./examples/counter |"))
  assert_true(text.contains("## Workspace Examples"))
  assert_true(text.contains("## Platform Status"))
  assert_true(text.contains("## Documentation Catalog"))
}
