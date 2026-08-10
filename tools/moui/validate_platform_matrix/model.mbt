///|
struct PlatformRoute {
  id : String
  label : String
  tier : Int
  platform : String
  renderer : String
  target : String
  entrypoint_kind : String
  showcase_package : String
  line_budget : Int
  release_gate : String
  release_blocking : Bool
  evidence_required : String
  evidence_file : String
  product_class : String
  ready : Bool
  coverage : Array[String]
}

///|
struct ArchitectureVariant {
  id : String
  base_route : String
  platform : String
  renderer : String
  target : String
  architecture : String
  abi : String
  renderer_modes : Array[String]
  tier : Int
  release_gate : String
  release_blocking : Bool
  evidence_required : String
  evidence_file : String
  product_class : String
  ready : Bool
  coverage : Array[String]
}

///|
struct PlatformMatrix {
  required_profiles : Array[String]
  routes : Array[PlatformRoute]
  architecture_variants : Array[ArchitectureVariant]
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn required_string(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> String {
  match fields.get(key) {
    Some(String(value)) if value.trim().to_owned() != "" => value
    _ => {
      failures.push(label + "." + key + " must be a non-empty string")
      ""
    }
  }
}

///|
fn required_int(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> Int {
  match fields.get(key) {
    Some(Number(value, repr=_)) => value.to_int()
    _ => {
      failures.push(label + "." + key + " must be an integer")
      0
    }
  }
}

///|
fn required_bool(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> Bool {
  match fields.get(key) {
    Some(True) => true
    Some(False) => false
    _ => {
      failures.push(label + "." + key + " must be a boolean")
      false
    }
  }
}

///|
fn required_string_array(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> Array[String] {
  let values = match fields.get(key) {
    Some(Array(values)) => values
    _ => {
      failures.push(label + "." + key + " must be a non-empty string array")
      return []
    }
  }
  let result : Array[String] = []
  for value in values {
    match value {
      String(text) if text != "" => result.push(text)
      _ => failures.push(label + "." + key + " must contain only strings")
    }
  }
  if result.is_empty() {
    failures.push(label + "." + key + " must not be empty")
  }
  result
}

///|
fn parse_route(
  value : Json,
  index : Int,
  failures : Array[String],
) -> PlatformRoute? {
  let label = "routes[" + index.to_string() + "]"
  let fields = match json_object(value) {
    Some(fields) => fields
    None => {
      failures.push(label + " must be an object")
      return None
    }
  }
  Some({
    id: required_string(fields, "id", label, failures),
    label: required_string(fields, "label", label, failures),
    tier: required_int(fields, "tier", label, failures),
    platform: required_string(fields, "platform", label, failures),
    renderer: required_string(fields, "renderer", label, failures),
    target: required_string(fields, "target", label, failures),
    entrypoint_kind: required_string(fields, "entrypointKind", label, failures),
    showcase_package: required_string(
      fields, "showcasePackage", label, failures,
    ),
    line_budget: required_int(fields, "lineBudget", label, failures),
    release_gate: required_string(fields, "releaseGate", label, failures),
    release_blocking: required_bool(fields, "releaseBlocking", label, failures),
    evidence_required: required_string(
      fields, "evidenceRequired", label, failures,
    ),
    evidence_file: required_string(fields, "evidenceFile", label, failures),
    product_class: required_string(fields, "productClass", label, failures),
    ready: required_bool(fields, "ready", label, failures),
    coverage: required_string_array(fields, "coverage", label, failures),
  })
}

///|
fn parse_architecture_variant(
  value : Json,
  index : Int,
  failures : Array[String],
) -> ArchitectureVariant? {
  let label = "architectureVariants[" + index.to_string() + "]"
  let fields = match json_object(value) {
    Some(fields) => fields
    None => {
      failures.push(label + " must be an object")
      return None
    }
  }
  Some({
    id: required_string(fields, "id", label, failures),
    base_route: required_string(fields, "baseRoute", label, failures),
    platform: required_string(fields, "platform", label, failures),
    renderer: required_string(fields, "renderer", label, failures),
    target: required_string(fields, "target", label, failures),
    architecture: required_string(fields, "architecture", label, failures),
    abi: required_string(fields, "abi", label, failures),
    renderer_modes: required_string_array(
      fields, "rendererModes", label, failures,
    ),
    tier: required_int(fields, "tier", label, failures),
    release_gate: required_string(fields, "releaseGate", label, failures),
    release_blocking: required_bool(fields, "releaseBlocking", label, failures),
    evidence_required: required_string(
      fields, "evidenceRequired", label, failures,
    ),
    evidence_file: required_string(fields, "evidenceFile", label, failures),
    product_class: required_string(fields, "productClass", label, failures),
    ready: required_bool(fields, "ready", label, failures),
    coverage: required_string_array(fields, "coverage", label, failures),
  })
}

///|
fn parse_platform_matrix(
  text : String,
) -> Result[PlatformMatrix, Array[String]] {
  let failures : Array[String] = []
  let parsed = @json.parse(text) catch {
    _ => return Err(["checks/platform-matrix.json: invalid JSON"])
  }
  let root = match json_object(parsed) {
    Some(fields) => fields
    None => return Err(["checks/platform-matrix.json must be an object"])
  }
  match root.get("schemaVersion") {
    Some(Number(value, repr=_)) if value == 1.0 => ()
    _ => failures.push("schemaVersion must be 1")
  }
  let required_profiles = required_string_array(
    root, "requiredCheckProfiles", "matrix", failures,
  )
  let route_values = match root.get("routes") {
    Some(Array(values)) => values
    _ => {
      failures.push("routes must be an array")
      []
    }
  }
  let routes : Array[PlatformRoute] = []
  for index, value in route_values {
    match parse_route(value, index, failures) {
      Some(route) => routes.push(route)
      None => ()
    }
  }
  let variant_values = match root.get("architectureVariants") {
    Some(Array(values)) => values
    Some(_) => {
      failures.push("architectureVariants must be an array")
      []
    }
    None => []
  }
  let architecture_variants : Array[ArchitectureVariant] = []
  for index, value in variant_values {
    match parse_architecture_variant(value, index, failures) {
      Some(variant) => architecture_variants.push(variant)
      None => ()
    }
  }
  if failures.is_empty() {
    Ok({ required_profiles, routes, architecture_variants })
  } else {
    Err(failures)
  }
}

///|
fn count_tier(routes : Array[PlatformRoute], tier : Int) -> Int {
  let mut count = 0
  for route in routes {
    if route.tier == tier {
      count += 1
    }
  }
  count
}

///|
fn unique_route_keys(routes : Array[PlatformRoute]) -> Array[String] {
  let values : Array[String] = []
  for route in routes {
    let key = route.platform + "/" + route.renderer
    if values.contains(key) {
      values.push("duplicate:" + key)
    } else {
      values.push(key)
    }
  }
  values
}

///|
fn expected_route_keys() -> Array[String] {
  [
    "macos/skia", "web/webgpu", "windows/skia", "linux/skia", "macos/wgpu", "windows/wgpu",
    "linux/wgpu", "android/skia", "ios/skia", "harmonyos/skia", "macos/sun", "windows/sun",
    "linux/sun", "wechat/canvas2d",
  ]
}

///|
fn contains_all(values : Array[String], required : Array[String]) -> Bool {
  required.all(value => values.contains(value))
}

///|
fn find_route(routes : Array[PlatformRoute], id : String) -> PlatformRoute? {
  for route in routes {
    if route.id == id {
      return Some(route)
    }
  }
  None
}

///|
fn validate_architecture_evidence_text(
  path : String,
  text : String,
  variant : ArchitectureVariant,
  failures : Array[String],
) -> Unit {
  let parsed = @json.parse(text) catch {
    _ => {
      failures.push(path + ": invalid JSON")
      return
    }
  }
  let fields = match json_object(parsed) {
    Some(fields) => fields
    None => {
      failures.push(path + ": evidence must be an object")
      return
    }
  }
  match fields.get("schemaVersion") {
    Some(Number(value, repr=_)) if value == 1.0 => ()
    _ => failures.push(path + ".schemaVersion must be 1")
  }
  let identity_keys = [
    "id", "baseRoute", "platform", "renderer", "architecture", "abi",
  ]
  let identity_values = [
    variant.id,
    variant.base_route,
    variant.platform,
    variant.renderer,
    variant.architecture,
    variant.abi,
  ]
  for index in 0..<identity_keys.length() {
    let key = identity_keys[index]
    let expected = identity_values[index]
    match fields.get(key) {
      Some(String(value)) if value == expected => ()
      _ =>
        failures.push(path + "." + key + " does not match the matrix variant")
    }
  }
  match fields.get("rendererModes") {
    Some(Array([String(value)])) if value == "skia-raster" => ()
    _ => failures.push(path + ".rendererModes must be [skia-raster]")
  }
  match fields.get("evidenceRequired") {
    Some(String(value)) if value == variant.evidence_required => ()
    _ => failures.push(path + ".evidenceRequired does not match the matrix")
  }
  for key in ["sourceBuild", "protocolL1", "rendererL2", "runtimeL3"] {
    match fields.get(key) {
      Some(Object(section)) =>
        match section.get("status") {
          Some(String(status)) if ["pending", "passed", "partial", "failed"].contains(
              status,
            ) => ()
          _ => failures.push(path + "." + key + ".status is invalid")
        }
      _ => failures.push(path + "." + key + " must be an object with status")
    }
  }
  match fields.get("sourceBuild") {
    Some(Object(section)) =>
      match section.get("command") {
        Some(String("scripts/linux-riscv64-cross-build.sh --sysroot PATH")) =>
          ()
        _ =>
          failures.push(
            path + ".sourceBuild.command must use the cross-build helper",
          )
      }
    _ => ()
  }
  for key in ["protocolL1", "rendererL2", "runtimeL3"] {
    match fields.get(key) {
      Some(Object(section)) =>
        match section.get("evidence") {
          Some(String(value)) if value.trim().to_owned() != "" => ()
          _ => failures.push(path + "." + key + ".evidence must be non-empty")
        }
      _ => ()
    }
  }
  match fields.get("rendererL2") {
    Some(Object(section)) =>
      match section.get("presenterRoute") {
        Some(String("offscreen-raster")) => ()
        _ =>
          failures.push(
            path + ".rendererL2.presenterRoute must be offscreen-raster",
          )
      }
    _ => ()
  }
  match fields.get("runtimeL3") {
    Some(Object(section)) =>
      match section.get("status") {
        Some(String("pending")) => ()
        _ => failures.push(path + ".runtimeL3.status must remain pending")
      }
    _ => ()
  }
  match fields.get("ready") {
    Some(False) => ()
    _ =>
      failures.push(path + ".ready must remain false for experimental RISC-V64")
  }
  match fields.get("productClass") {
    Some(String("experimental")) => ()
    _ => failures.push(path + ".productClass must remain experimental")
  }
}

///|
fn validate_architecture_evidence(
  repo_root : String,
  variant : ArchitectureVariant,
  failures : Array[String],
) -> Unit {
  let path = variant.evidence_file
  let absolute = @tools.resolve_path(repo_root, path)
  if !@tools.file_exists(absolute) {
    failures.push(variant.id + ": missing evidence file " + path)
    return
  }
  let text = match @tools.read_required_text(absolute, path) {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      return
    }
  }
  validate_architecture_evidence_text(path, text, variant, failures)
}

///|
fn validate_architecture_variant_policy(
  routes : Array[PlatformRoute],
  variants : Array[ArchitectureVariant],
  failures : Array[String],
) -> Unit {
  if variants.length() != 1 {
    failures.push(
      "architectureVariants must contain exactly one experimental RISC-V64 variant",
    )
  }
  let ids : Array[String] = []
  for variant in variants {
    if ids.contains(variant.id) {
      failures.push("duplicate architecture variant id: " + variant.id)
    } else {
      ids.push(variant.id)
    }
    if variant.id == "linux-skia-riscv64" &&
      (
        variant.base_route != "linux-skia" ||
        variant.platform != "linux" ||
        variant.renderer != "skia" ||
        variant.target != "native"
      ) {
      failures.push(
        variant.id + ": must reuse the canonical native linux-skia route",
      )
    }
    match find_route(routes, variant.base_route) {
      Some(route) => {
        if variant.platform != route.platform ||
          variant.renderer != route.renderer {
          failures.push(variant.id + ": platform/renderer must match baseRoute")
        }
        if variant.target != route.target {
          failures.push(variant.id + ": target must match baseRoute")
        }
      }
      None =>
        failures.push(
          variant.id + ": baseRoute does not exist: " + variant.base_route,
        )
    }
    if variant.architecture != "riscv64" {
      failures.push(variant.id + ": architecture must be riscv64")
    }
    if variant.abi != "gnu" {
      failures.push(variant.id + ": abi must be gnu")
    }
    if variant.renderer_modes != ["skia-raster"] {
      failures.push(variant.id + ": rendererModes must be exactly skia-raster")
    }
    if variant.evidence_required != "L0-L2" {
      failures.push(variant.id + ": evidenceRequired must be L0-L2")
    }
    if variant.tier != 3 ||
      variant.release_gate != "non-blocking" ||
      variant.release_blocking {
      failures.push(
        variant.id + ": architecture variants must remain non-blocking Tier 3",
      )
    }
    if variant.product_class != "experimental" || variant.ready {
      failures.push(
        variant.id + ": variant must be experimental and ready=false",
      )
    }
    if variant.coverage != ["scheduled", "manual"] {
      failures.push(variant.id + ": coverage must be exactly scheduled/manual")
    }
    if !variant.evidence_file.has_prefix("checks/architecture-evidence/") ||
      variant.evidence_file.has_prefix("checks/platforms/") ||
      variant.evidence_file.contains("..") {
      failures.push(
        variant.id + ": evidenceFile must be independent architecture evidence",
      )
    }
    if variant.id == "linux-skia-riscv64" &&
      variant.evidence_file !=
      "checks/architecture-evidence/linux-skia-riscv64.json" {
      failures.push(
        variant.id + ": evidenceFile must use the locked RISC-V64 evidence path",
      )
    }
  }
  if !ids.contains("linux-skia-riscv64") {
    failures.push("architectureVariants must register linux-skia-riscv64")
  }
}

///|
fn validate_architecture_variants(
  repo_root : String,
  routes : Array[PlatformRoute],
  variants : Array[ArchitectureVariant],
  failures : Array[String],
) -> Unit {
  validate_architecture_variant_policy(routes, variants, failures)
  for variant in variants {
    validate_architecture_evidence(repo_root, variant, failures)
  }
}

///|
fn validate_route_policy(
  route : PlatformRoute,
  failures : Array[String],
) -> Unit {
  let label = route.id
  if route.tier < 1 || route.tier > 3 {
    failures.push(label + ": tier must be 1, 2, or 3")
  }
  let expected_budget = if route.entrypoint_kind == "web" ||
    route.entrypoint_kind == "wechat" {
    40
  } else {
    24
  }
  if route.line_budget != expected_budget {
    failures.push(
      label + ": invalid lineBudget " + route.line_budget.to_string(),
    )
  }
  if route.target != "native" && route.target != "wasm-gc" {
    failures.push(label + ": target must be native or wasm-gc")
  }
  if route.evidence_required == "" {
    failures.push(label + ": evidenceRequired must not be empty")
  }
  match route.tier {
    1 => {
      if route.release_gate != "release" || !route.release_blocking {
        failures.push(label + ": Tier 1 must block release")
      }
      if !contains_all(route.coverage, ["pr", "daily", "release"]) {
        failures.push(label + ": Tier 1 coverage must include pr/daily/release")
      }
    }
    2 => {
      if route.release_gate != "release-l2-first-frame" ||
        !route.release_blocking {
        failures.push(label + ": Tier 2 must block on L2 and first frame")
      }
      if !contains_all(route.coverage, ["platform", "release"]) {
        failures.push(label + ": Tier 2 coverage must include platform/release")
      }
    }
    3 => {
      if route.release_gate != "non-blocking" || route.release_blocking {
        failures.push(label + ": Tier 3 must remain non-blocking")
      }
      if !contains_all(route.coverage, ["scheduled", "manual"]) {
        failures.push(label + ": Tier 3 coverage must include scheduled/manual")
      }
    }
    _ => ()
  }
  let expected_ready = route.product_class == "committed" ||
    route.product_class == "committed_with_gaps"
  if route.ready != expected_ready {
    failures.push(label + ": ready conflicts with productClass")
  }
  match route.renderer {
    "wgpu" =>
      if route.product_class != "diagnostic" {
        failures.push(label + ": WGPU routes must remain diagnostic")
      }
    "sun" =>
      if route.product_class != "experimental" {
        failures.push(label + ": Sun routes must remain experimental")
      }
    _ => ()
  }
}

///|
fn validate_platform_matrix(
  repo_root : String,
  matrix : PlatformMatrix,
) -> Array[String] {
  let failures : Array[String] = []
  if matrix.routes.length() != 14 {
    failures.push("platform matrix must contain exactly 14 routes")
  }
  let tier1_count = count_tier(matrix.routes, 1)
  let tier2_count = count_tier(matrix.routes, 2)
  let tier3_count = count_tier(matrix.routes, 3)
  if tier1_count != 2 {
    failures.push(
      "Tier 1 route count is " + tier1_count.to_string() + "; expected 2",
    )
  }
  if tier2_count != 2 {
    failures.push(
      "Tier 2 route count is " + tier2_count.to_string() + "; expected 2",
    )
  }
  if tier3_count != 10 {
    failures.push(
      "Tier 3 route count is " + tier3_count.to_string() + "; expected 10",
    )
  }
  let ids : Array[String] = []
  let packages : Array[String] = []
  for route in matrix.routes {
    if ids.contains(route.id) {
      failures.push("duplicate route id: " + route.id)
    } else {
      ids.push(route.id)
    }
    if packages.contains(route.showcase_package) {
      failures.push("duplicate Showcase package: " + route.showcase_package)
    } else {
      packages.push(route.showcase_package)
    }
    validate_route_policy(route, failures)
    for suffix in ["", "/moon.pkg", "/main.mbt"] {
      let path = route.showcase_package + suffix
      let absolute = @tools.resolve_path(repo_root, path)
      let exists = if suffix == "" {
        @tools.directory_exists(absolute)
      } else {
        @tools.file_exists(absolute)
      }
      if !exists {
        failures.push(route.id + ": missing " + path)
      }
    }
    if !@tools.file_exists(@tools.resolve_path(repo_root, route.evidence_file)) {
      failures.push(route.id + ": missing evidence file " + route.evidence_file)
    }
  }
  let actual_keys = unique_route_keys(matrix.routes)
  for key in expected_route_keys() {
    if !actual_keys.contains(key) {
      failures.push("missing canonical route: " + key)
    }
  }
  for key in actual_keys {
    if key.has_prefix("duplicate:") {
      failures.push("duplicate canonical route: " + key[10:].to_owned())
    } else if !expected_route_keys().contains(key) {
      failures.push("route outside RFC 0002 matrix: " + key)
    }
  }
  if matrix.required_profiles != ["pr", "daily", "platform", "theme"] {
    failures.push("requiredCheckProfiles must be pr, daily, platform, theme")
  }
  validate_architecture_variants(
    repo_root,
    matrix.routes,
    matrix.architecture_variants,
    failures,
  )
  failures
}
