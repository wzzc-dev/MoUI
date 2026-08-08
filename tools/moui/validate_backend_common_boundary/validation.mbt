///|
struct OwnershipPackageRule {
  path : String
  required_sources : Array[String]
  required_imports : Array[String]
  forbidden_imports : Array[String]
  required_source_tokens : Array[String]
  forbidden_source_tokens : Array[String]
}

///|
struct RendererModuleRule {
  name : String
  path : String
}

///|
struct OwnershipConfig {
  package_rules : Array[OwnershipPackageRule]
  forbidden_package_manifests : Array[String]
  legacy_symbols : Array[String]
  source_roots : Array[String]
  root_render_forbidden_tokens : Array[String]
  renderer_modules : Array[RendererModuleRule]
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn json_required_string(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> String {
  match fields.get(key) {
    Some(Json::String(value)) if value.trim().to_owned() != "" => value
    _ => {
      failures.push(label + "." + key + " must be a non-empty string")
      ""
    }
  }
}

///|
fn json_string_array(
  fields : Map[String, Json],
  key : String,
  label : String,
  required : Bool,
  failures : Array[String],
) -> Array[String] {
  let values = match fields.get(key) {
    Some(Json::Array(values)) => values
    None if !required => return []
    _ => {
      failures.push(label + "." + key + " must be an array")
      return []
    }
  }
  let result : Array[String] = []
  for index, value in values {
    match value {
      Json::String(item) if item.trim().to_owned() != "" => result.push(item)
      _ =>
        failures.push(
          label +
          "." +
          key +
          "[" +
          index.to_string() +
          "] must be a non-empty string",
        )
    }
  }
  result
}

///|
fn parse_ownership_config(
  text : String,
) -> Result[OwnershipConfig, Array[String]] {
  let failures : Array[String] = []
  let parsed = @json.parse(text) catch {
    _ => return Err(["checks/backend-common-ownership.json: invalid JSON"])
  }
  let root = match parsed {
    Json::Object(fields) => fields
    _ => return Err(["checks/backend-common-ownership.json must be an object"])
  }
  match root.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) if value == 1.0 => ()
    _ =>
      failures.push(
        "checks/backend-common-ownership.json.schemaVersion must be 1",
      )
  }
  let package_rules : Array[OwnershipPackageRule] = []
  match root.get("packageRules") {
    Some(Json::Array(values)) =>
      for index, value in values {
        let label = "checks/backend-common-ownership.json.packageRules[" +
          index.to_string() +
          "]"
        let fields = match json_object(value) {
          Some(fields) => fields
          None => {
            failures.push(label + " must be an object")
            continue
          }
        }
        package_rules.push({
          path: json_required_string(fields, "path", label, failures),
          required_sources: json_string_array(
            fields, "requiredSources", label, false, failures,
          ),
          required_imports: json_string_array(
            fields, "requiredImports", label, false, failures,
          ),
          forbidden_imports: json_string_array(
            fields, "forbiddenImports", label, false, failures,
          ),
          required_source_tokens: json_string_array(
            fields, "requiredSourceTokens", label, false, failures,
          ),
          forbidden_source_tokens: json_string_array(
            fields, "forbiddenSourceTokens", label, false, failures,
          ),
        })
      }
    _ =>
      failures.push(
        "checks/backend-common-ownership.json.packageRules must be an array",
      )
  }
  let renderer_modules : Array[RendererModuleRule] = []
  match root.get("rendererModules") {
    Some(Json::Array(values)) =>
      for index, value in values {
        let label = "checks/backend-common-ownership.json.rendererModules[" +
          index.to_string() +
          "]"
        let fields = match json_object(value) {
          Some(fields) => fields
          None => {
            failures.push(label + " must be an object")
            continue
          }
        }
        renderer_modules.push({
          name: json_required_string(fields, "name", label, failures),
          path: json_required_string(fields, "path", label, failures),
        })
      }
    _ =>
      failures.push(
        "checks/backend-common-ownership.json.rendererModules must be an array",
      )
  }
  let config = {
    package_rules,
    forbidden_package_manifests: json_string_array(
      root, "forbiddenPackageManifests", "checks/backend-common-ownership.json",
      true, failures,
    ),
    legacy_symbols: json_string_array(
      root, "legacySymbols", "checks/backend-common-ownership.json", true, failures,
    ),
    source_roots: json_string_array(
      root, "sourceRoots", "checks/backend-common-ownership.json", true, failures,
    ),
    root_render_forbidden_tokens: json_string_array(
      root, "rootRenderForbiddenTokens", "checks/backend-common-ownership.json",
      true, failures,
    ),
    renderer_modules,
  }
  if failures.is_empty() {
    Ok(config)
  } else {
    Err(failures)
  }
}

///|
fn has_default_import(text : String, path : String) -> Bool {
  let package_token = "\"" + path + "\""
  let mut in_import_block = false
  let mut block_contains_package = false
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if !in_import_block {
      if line == "import {" {
        in_import_block = true
        block_contains_package = false
      }
    } else {
      if line.contains(package_token) {
        block_contains_package = true
      }
      if line.has_prefix("}") {
        if block_contains_package &&
          !line.contains("for \"test\"") &&
          !line.contains("for \"wbtest\"") {
          return true
        }
        in_import_block = false
        block_contains_package = false
      }
    }
  }
  false
}

///|
fn validate_package_rule(
  repo_root : String,
  rule : OwnershipPackageRule,
  failures : Array[String],
) -> Unit {
  let pkg_path = rule.path + "/moon.pkg"
  let pkg = match read_repo_text(repo_root, pkg_path) {
    Ok(text) => text
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for dependency in rule.required_imports {
    if !has_default_import(pkg, dependency) {
      failures.push(rule.path + " must depend on " + dependency)
    }
  }
  for dependency in rule.forbidden_imports {
    if has_default_import(pkg, dependency) {
      failures.push(rule.path + " must not depend on " + dependency)
    }
  }
  for source in rule.required_sources {
    let path = rule.path + "/" + source
    if !@tools.file_exists(@tools.resolve_path(repo_root, path)) {
      failures.push(path + " is required by backend ownership")
    }
  }
  if rule.required_source_tokens.is_empty() &&
    rule.forbidden_source_tokens.is_empty() {
    return
  }
  let files : Array[String] = []
  collect_contract_files(repo_root, rule.path, files, failures)
  for token in rule.required_source_tokens {
    let found = Ref(false)
    for path in files {
      match read_repo_text(repo_root, path) {
        Ok(text) if text.contains(token) => found.val = true
        _ => ()
      }
    }
    if !found.val {
      failures.push(rule.path + " must use source token '" + token + "'")
    }
  }
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for token in rule.forbidden_source_tokens {
      if text.contains(token) {
        failures.push(path + " contains forbidden owner token '" + token + "'")
      }
    }
  }
}

///|
fn validate_removed_packages(
  repo_root : String,
  config : OwnershipConfig,
  failures : Array[String],
) -> Unit {
  for path in config.forbidden_package_manifests {
    let manifest = path + "/moon.pkg"
    if @tools.file_exists(@tools.resolve_path(repo_root, manifest)) {
      failures.push(manifest + " must not exist after ownership migration")
    }
  }
}

///|
fn validate_legacy_symbols(
  repo_root : String,
  config : OwnershipConfig,
  failures : Array[String],
) -> Unit {
  for root in config.source_roots {
    let files : Array[String] = []
    collect_contract_files(repo_root, root, files, failures)
    for path in files {
      let text = match read_repo_text(repo_root, path) {
        Ok(text) => text
        Err(message) => {
          failures.push(message)
          continue
        }
      }
      for symbol in config.legacy_symbols {
        if text.contains(symbol) {
          failures.push(path + " contains removed contract '" + symbol + "'")
        }
      }
    }
  }
}

///|
fn validate_root_render_surface(
  repo_root : String,
  config : OwnershipConfig,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  collect_contract_files(repo_root, "moui/render", files, failures)
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for token in config.root_render_forbidden_tokens {
      if text.contains(token) {
        failures.push(
          path +
          " contains renderer-specific root surface token '" +
          token +
          "'",
        )
      }
    }
  }
}

///|
fn validate_renderer_isolation(
  repo_root : String,
  config : OwnershipConfig,
  failures : Array[String],
) -> Unit {
  for renderer in config.renderer_modules {
    let manifest_path = renderer.path + "/moon.mod"
    let manifest = match read_repo_text(repo_root, manifest_path) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for other in config.renderer_modules {
      if other.name != renderer.name && manifest.contains(other.name) {
        failures.push(
          renderer.name + " must not depend on renderer module " + other.name,
        )
      }
    }
  }
}

///|
fn validate_wechat_boundary(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  collect_contract_files(repo_root, "moui/backend/wechat", files, failures)
  for path in files {
    if path.has_suffix(".mbti") ||
      path.contains("_test.mbt") ||
      path.contains("_wbtest.mbt") {
      continue
    }
    match read_repo_text(repo_root, path) {
      Ok(text) if text.contains("WindowEvent") =>
        failures.push(path + " violates the WeChat direct-canvas boundary")
      _ => ()
    }
  }
}

///|
fn validate_repository(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  let config_text = match
    read_repo_text(repo_root, "checks/backend-common-ownership.json") {
    Ok(text) => text
    Err(message) => return [message]
  }
  let config = match parse_ownership_config(config_text) {
    Ok(config) => config
    Err(messages) => return messages
  }
  for rule in config.package_rules {
    validate_package_rule(repo_root, rule, failures)
  }
  validate_removed_packages(repo_root, config, failures)
  validate_legacy_symbols(repo_root, config, failures)
  validate_root_render_surface(repo_root, config, failures)
  validate_renderer_isolation(repo_root, config, failures)
  validate_wechat_boundary(repo_root, failures)
  failures
}

///|
test "ownership config parses package and renderer rules" {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "packageRules": [{"path":"moui/backend/common","requiredImports":["owner"]}],
    #|  "forbiddenPackageManifests": ["legacy"],
    #|  "legacySymbols": ["OldOwner"],
    #|  "sourceRoots": ["moui"],
    #|  "rootRenderForbiddenTokens": ["Metal"],
    #|  "rendererModules": [{"name":"renderer","path":"renderer"}]
    #|}
  let parsed = parse_ownership_config(text)
  guard parsed is Ok(config) else { fail("expected ownership config") }
  inspect(config.package_rules.length(), content="1")
  assert_eq(config.package_rules[0].required_imports, ["owner"])
  inspect(config.renderer_modules.length(), content="1")
}

///|
test "dependency checks distinguish production and test imports" {
  let pkg =
    #|import {
    #|  "wzzc-dev/moui/core",
    #|}
    #|
    #|import {
    #|  "wzzc-dev/moui/runtime",
    #|} for "test"
  assert_true(has_default_import(pkg, "wzzc-dev/moui/core"))
  assert_false(has_default_import(pkg, "wzzc-dev/moui/runtime"))
}
