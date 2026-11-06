///|
struct PortfolioRoute {
  id : String
  owner : String
  intent : String
  review_date : String
  review_trigger : String
  graduation : String
  retirement : String
}

///|
struct PortfolioModule {
  name : String
  owner : String
  intent : String
  review_date : String
  review_trigger : String
  evidence : String
  graduation : String
  retirement : String
}

///|
struct ReleaseCoupling {
  mode : String
  line : String
  adr : String
  base_only_patch : String
  compatibility_matrix : String
  evidence : String
}

///|
struct PortfolioCatalog {
  reviewed_on : String
  release_coupling : ReleaseCoupling
  routes : Array[PortfolioRoute]
  modules : Array[PortfolioModule]
}

///|
struct PlatformRouteFacts {
  id : String
  product_class : String
  ready : Bool
  evidence_file : String
  architecture_variant : Bool
}

///|
struct PlatformFacts {
  routes : Array[PlatformRouteFacts]
}

///|
struct ReleaseModuleFacts {
  name : String
  directory : String
  publication : String
  release_stage : String
}

///|
struct ReleaseFacts {
  release_stages : Array[String]
  modules : Array[ReleaseModuleFacts]
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
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
    Some(Json::String(value)) if value.trim().to_owned() != "" => value
    _ => {
      failures.push(label + "." + key + " must be a non-empty string")
      ""
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
    Some(Json::True) => true
    Some(Json::False) => false
    _ => {
      failures.push(label + "." + key + " must be a boolean")
      false
    }
  }
}

///|
fn required_array(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> Array[Json] {
  match fields.get(key) {
    Some(Json::Array(values)) => values
    _ => {
      failures.push(label + "." + key + " must be an array")
      []
    }
  }
}

///|
fn parse_portfolio_route(
  value : Json,
  index : Int32,
  failures : Array[String],
) -> PortfolioRoute? {
  let label = "checks/portfolio-governance.json.routes[" +
    index.to_string() +
    "]"
  let fields = match json_object(value) {
    Some(fields) => fields
    None => {
      failures.push(label + " must be an object")
      return None
    }
  }
  Some({
    id: required_string(fields, "id", label, failures),
    owner: required_string(fields, "owner", label, failures),
    intent: required_string(fields, "intent", label, failures),
    review_date: required_string(fields, "reviewDate", label, failures),
    review_trigger: required_string(fields, "reviewTrigger", label, failures),
    graduation: required_string(fields, "graduation", label, failures),
    retirement: required_string(fields, "retirement", label, failures),
  })
}

///|
fn parse_portfolio_module(
  value : Json,
  index : Int32,
  failures : Array[String],
) -> PortfolioModule? {
  let label = "checks/portfolio-governance.json.modules[" +
    index.to_string() +
    "]"
  let fields = match json_object(value) {
    Some(fields) => fields
    None => {
      failures.push(label + " must be an object")
      return None
    }
  }
  Some({
    name: required_string(fields, "name", label, failures),
    owner: required_string(fields, "owner", label, failures),
    intent: required_string(fields, "intent", label, failures),
    review_date: required_string(fields, "reviewDate", label, failures),
    review_trigger: required_string(fields, "reviewTrigger", label, failures),
    evidence: required_string(fields, "evidence", label, failures),
    graduation: required_string(fields, "graduation", label, failures),
    retirement: required_string(fields, "retirement", label, failures),
  })
}

///|
fn parse_release_coupling(
  value : Json,
  failures : Array[String],
) -> ReleaseCoupling {
  let label = "checks/portfolio-governance.json.releaseCoupling"
  let fields = match json_object(value) {
    Some(fields) => fields
    None => {
      failures.push(label + " must be an object")
      return {
        mode: "",
        line: "",
        adr: "",
        base_only_patch: "",
        compatibility_matrix: "",
        evidence: "",
      }
    }
  }
  {
    mode: required_string(fields, "mode", label, failures),
    line: required_string(fields, "line", label, failures),
    adr: required_string(fields, "adr", label, failures),
    base_only_patch: required_string(fields, "baseOnlyPatch", label, failures),
    compatibility_matrix: required_string(
      fields, "compatibilityMatrix", label, failures,
    ),
    evidence: required_string(fields, "evidence", label, failures),
  }
}

///|
fn parse_portfolio_catalog(
  text : String,
) -> Result[PortfolioCatalog, Array[String]] {
  let failures : Array[String] = []
  let parsed = @json.parse(text) catch {
    _ => return Err(["checks/portfolio-governance.json: invalid JSON"])
  }
  let root = match json_object(parsed) {
    Some(fields) => fields
    None => return Err(["checks/portfolio-governance.json must be an object"])
  }
  match root.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) if value == 1.0 => ()
    _ =>
      failures.push("checks/portfolio-governance.json.schemaVersion must be 1")
  }
  let route_values = required_array(
    root, "routes", "checks/portfolio-governance.json", failures,
  )
  let routes : Array[PortfolioRoute] = []
  for index, value in route_values {
    match parse_portfolio_route(value, index, failures) {
      Some(route) => routes.push(route)
      None => ()
    }
  }
  let module_values = required_array(
    root, "modules", "checks/portfolio-governance.json", failures,
  )
  let modules : Array[PortfolioModule] = []
  for index, value in module_values {
    match parse_portfolio_module(value, index, failures) {
      Some(entry) => modules.push(entry)
      None => ()
    }
  }
  let release_coupling = match root.get("releaseCoupling") {
    Some(value) => parse_release_coupling(value, failures)
    None => {
      failures.push(
        "checks/portfolio-governance.json.releaseCoupling must be an object",
      )
      {
        mode: "",
        line: "",
        adr: "",
        base_only_patch: "",
        compatibility_matrix: "",
        evidence: "",
      }
    }
  }
  let catalog = {
    reviewed_on: required_string(
      root, "reviewedOn", "checks/portfolio-governance.json", failures,
    ),
    release_coupling,
    routes,
    modules,
  }
  if failures.is_empty() {
    Ok(catalog)
  } else {
    Err(failures)
  }
}

///|
fn parse_platform_facts(text : String) -> Result[PlatformFacts, Array[String]] {
  let failures : Array[String] = []
  let parsed = @json.parse(text) catch {
    _ => return Err(["checks/platform-matrix.json: invalid JSON"])
  }
  let root = match json_object(parsed) {
    Some(fields) => fields
    None => return Err(["checks/platform-matrix.json must be an object"])
  }
  match root.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) if value == 1.0 => ()
    _ => failures.push("checks/platform-matrix.json.schemaVersion must be 1")
  }
  let routes : Array[PlatformRouteFacts] = []
  for
    index, value in required_array(
      root, "routes", "checks/platform-matrix.json", failures,
    ) {
    let label = "checks/platform-matrix.json.routes[" + index.to_string() + "]"
    let fields = match json_object(value) {
      Some(fields) => fields
      None => {
        failures.push(label + " must be an object")
        continue
      }
    }
    routes.push({
      id: required_string(fields, "id", label, failures),
      product_class: required_string(fields, "productClass", label, failures),
      ready: required_bool(fields, "ready", label, failures),
      evidence_file: required_string(fields, "evidenceFile", label, failures),
      architecture_variant: false,
    })
  }
  let variant_values = match root.get("architectureVariants") {
    Some(Json::Array(values)) => values
    Some(_) => {
      failures.push(
        "checks/platform-matrix.json.architectureVariants must be an array",
      )
      []
    }
    None => []
  }
  for index, value in variant_values {
    let label = "checks/platform-matrix.json.architectureVariants[" +
      index.to_string() +
      "]"
    let fields = match json_object(value) {
      Some(fields) => fields
      None => {
        failures.push(label + " must be an object")
        continue
      }
    }
    routes.push({
      id: required_string(fields, "id", label, failures),
      product_class: required_string(fields, "productClass", label, failures),
      ready: required_bool(fields, "ready", label, failures),
      evidence_file: required_string(fields, "evidenceFile", label, failures),
      architecture_variant: true,
    })
  }
  if failures.is_empty() {
    Ok({ routes, })
  } else {
    Err(failures)
  }
}

///|
fn parse_release_facts(text : String) -> Result[ReleaseFacts, Array[String]] {
  let failures : Array[String] = []
  let parsed = @json.parse(text) catch {
    _ => return Err(["checks/release-modules.json: invalid JSON"])
  }
  let root = match json_object(parsed) {
    Some(fields) => fields
    None => return Err(["checks/release-modules.json must be an object"])
  }
  match root.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) if value == 1.0 => ()
    _ => failures.push("checks/release-modules.json.schemaVersion must be 1")
  }
  let release_stages : Array[String] = []
  for
    index, value in required_array(
      root, "releaseStages", "checks/release-modules.json", failures,
    ) {
    match value {
      Json::String(stage) if stage.trim().to_owned() != "" =>
        release_stages.push(stage)
      _ =>
        failures.push(
          "checks/release-modules.json.releaseStages[" +
          index.to_string() +
          "] must be a non-empty string",
        )
    }
  }
  let modules : Array[ReleaseModuleFacts] = []
  for
    index, value in required_array(
      root, "modules", "checks/release-modules.json", failures,
    ) {
    let label = "checks/release-modules.json.modules[" + index.to_string() + "]"
    let fields = match json_object(value) {
      Some(fields) => fields
      None => {
        failures.push(label + " must be an object")
        continue
      }
    }
    let release_stage = match fields.get("releaseStage") {
      Some(Json::String(value)) => value
      _ => ""
    }
    modules.push({
      name: required_string(fields, "name", label, failures),
      directory: required_string(fields, "directory", label, failures),
      publication: required_string(fields, "publication", label, failures),
      release_stage,
    })
  }
  if failures.is_empty() {
    Ok({ release_stages, modules, })
  } else {
    Err(failures)
  }
}

///|
fn first_quoted(line : String) -> String? {
  match line.find("\"") {
    Some(start) => {
      let rest = line[start + 1:]
      match rest.find("\"") {
        Some(end) => Some(rest[:end].to_owned())
        None => None
      }
    }
    None => None
  }
}

///|
fn manifest_field(text : String, key : String) -> String {
  let prefix = key + " ="
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line.has_prefix(prefix) {
      match first_quoted(line) {
        Some(value) => return value
        None => return ""
      }
    }
  }
  ""
}
