///|
fn riscv64_variant_for_test() -> ArchitectureVariant {
  {
    id: "linux-skia-riscv64",
    base_route: "linux-skia",
    platform: "linux",
    renderer: "skia",
    target: "native",
    architecture: "riscv64",
    abi: "gnu",
    renderer_modes: ["skia-raster"],
    tier: 3,
    release_gate: "non-blocking",
    release_blocking: false,
    evidence_required: "L0-L2",
    evidence_file: "checks/architecture-evidence/linux-skia-riscv64.json",
    product_class: "experimental",
    ready: false,
    coverage: ["scheduled", "manual"],
  }
}

///|
fn valid_riscv64_evidence() -> String {
  (
    #|{
    #|  "schemaVersion": 1,
    #|  "id": "linux-skia-riscv64",
    #|  "baseRoute": "linux-skia",
    #|  "platform": "linux",
    #|  "renderer": "skia",
    #|  "architecture": "riscv64",
    #|  "abi": "gnu",
    #|  "rendererModes": ["skia-raster"],
    #|  "evidenceRequired": "L0-L2",
    #|  "sourceBuild": {"status": "pending", "command": "scripts/linux-riscv64-cross-build.sh --sysroot PATH"},
    #|  "protocolL1": {"status": "pending", "evidence": "target package checks"},
    #|  "rendererL2": {"status": "pending", "presenterRoute": "offscreen-raster", "evidence": "QEMU smokes"},
    #|  "runtimeL3": {"status": "pending", "evidence": "matching device"},
    #|  "ready": false,
    #|  "productClass": "experimental"
    #|}
  )
}

///|
test "architecture evidence accepts the independent L0-L3 schema" {
  let failures : Array[String] = []
  validate_architecture_evidence_text(
    "checks/architecture-evidence/linux-skia-riscv64.json",
    valid_riscv64_evidence(),
    riscv64_variant_for_test(),
    failures,
  )
  assert_true(failures.is_empty())
}

///|
test "architecture evidence rejects GPU modes and a passed L3" {
  let failures : Array[String] = []
  let invalid = valid_riscv64_evidence()
    .replace(old="[\"skia-raster\"]", new="[\"skia-vulkan\"]")
    .replace(
      old="\"runtimeL3\": {\"status\": \"pending\", \"evidence\": \"matching device\"}",
      new="\"runtimeL3\": {\"status\": \"passed\", \"evidence\": \"matching device\"}",
    )
  validate_architecture_evidence_text(
    "checks/architecture-evidence/linux-skia-riscv64.json",
    invalid,
    riscv64_variant_for_test(),
    failures,
  )
  assert_true(
    failures.contains(
      "checks/architecture-evidence/linux-skia-riscv64.json.rendererModes must be [skia-raster]",
    ),
  )
  assert_true(
    failures.contains(
      "checks/architecture-evidence/linux-skia-riscv64.json.runtimeL3.status must remain pending",
    ),
  )
}

///|
test "architecture variant rejects a missing canonical base route" {
  let failures : Array[String] = []
  validate_architecture_variant_policy(
    [],
    [riscv64_variant_for_test()],
    failures,
  )
  assert_true(
    failures.contains(
      "linux-skia-riscv64: baseRoute does not exist: linux-skia",
    ),
  )
}

///|
test "platform matrix parses exactly one architecture variant" {
  let matrix_text =
    #|{
    #|  "schemaVersion": 1,
    #|  "requiredCheckProfiles": ["pr"],
    #|  "routes": [],
    #|  "architectureVariants": [
    #|    {
    #|      "id": "linux-skia-riscv64",
    #|      "baseRoute": "linux-skia",
    #|      "platform": "linux",
    #|      "renderer": "skia",
    #|      "target": "native",
    #|      "architecture": "riscv64",
    #|      "abi": "gnu",
    #|      "rendererModes": ["skia-raster"],
    #|      "tier": 3,
    #|      "releaseGate": "non-blocking",
    #|      "releaseBlocking": false,
    #|      "evidenceRequired": "L0-L2",
    #|      "evidenceFile": "checks/architecture-evidence/linux-skia-riscv64.json",
    #|      "productClass": "experimental",
    #|      "ready": false,
    #|      "coverage": ["scheduled", "manual"]
    #|    }
    #|  ]
    #|}
  match parse_platform_matrix(matrix_text) {
    Ok(matrix) => {
      assert_eq(matrix.architecture_variants.length(), 1)
      assert_eq(matrix.architecture_variants[0].architecture, "riscv64")
    }
    Err(_) => fail("unexpected parse failure")
  }
}
