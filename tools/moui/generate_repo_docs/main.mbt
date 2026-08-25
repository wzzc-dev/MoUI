///|
suberror RepoDocsError {
  Invalid(String)
} derive(Eq, Debug)

///|
fn[T] Result::or_raise(self : Result[T, String]) -> T raise RepoDocsError {
  match self {
    Ok(value) => value
    Err(message) => raise RepoDocsError::Invalid(message)
  }
}

///|
struct CliOptions {
  repo_root : String
  api_report : String
  mode : String
  help : Bool
}

///|
struct ApiRow {
  label : String
  path : String
  lines : Int
  public_declarations : Int
  pub_all_declarations : Int
}

///|
struct ExampleRow {
  id : String
  path : String
  title : String
  featured : Bool
}

///|
struct PlatformRow {
  platform : String
  source_status : String
  renderer_status : String
  runtime_status : String
  host_kind : String
  deployment_floor : String
  toolchain_floor : String
  declared_presenter_route : String
  actual_presenter_route : String
}

///|
struct MobilePlatformContractFacts {
  platform : String
  source_status : String
  source_fact_statuses : Array[String]
  source_verified_on : String
  source_matrix_command : String
  renderer_status : String
  runtime_status : String
  host_kind : String
  declared_presenter_route : String
  actual_presenter_route : String
  presenter_evidence_status : String
  presenter_evidence_kind : String
  presenter_evidence_reference : String
}

///|
struct DocsGroupRow {
  id : String
  title : String
  entry_count : Int
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/generate_repo_docs --write|--check [options]
    #|
    #|Generates docs/repository-facts.md from the API validator report,
    #|moon.work, examples/catalog.json, checks/platforms, and the website docs
    #|catalog.
    #|
    #|Options:
    #|  --write              Write generated documentation.
    #|  --check              Fail when generated documentation is stale.
    #|  --repo-root PATH     Repository root. Defaults to cwd.
    #|  --api-report PATH    Structured validator report.
    #|  -h, --help           Show this help.
    #|
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let api_report = Ref("checks/api-surface-report.json")
  let mode = Ref("")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--write" | "--check" as selected => {
        if mode.val != "" {
          return Err("choose exactly one of --write or --check")
        }
        mode.val = selected
        index += 1
      }
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "--api-report" => {
        if index + 1 >= args.length() {
          return Err("missing value for --api-report")
        }
        api_report.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  if !help.val && mode.val == "" {
    return Err("choose exactly one of --write or --check")
  }
  Ok({
    repo_root: repo_root.val,
    api_report: api_report.val,
    mode: mode.val,
    help: help.val,
  })
}

///|
fn json_object(
  value : Json,
  label : String,
) -> Result[Map[String, Json], String] {
  match value {
    Json::Object(fields) => Ok(fields)
    _ => Err(label + " must be an object")
  }
}

///|
fn json_array(value : Json?, label : String) -> Result[Array[Json], String] {
  match value {
    Some(Json::Array(values)) => Ok(values)
    _ => Err(label + " must be an array")
  }
}

///|
fn json_string(value : Json?, label : String) -> Result[String, String] {
  match value {
    Some(Json::String(text)) if text.trim().to_owned() != "" => Ok(text)
    _ => Err(label + " must be a non-empty string")
  }
}

///|
fn json_int(value : Json?, label : String) -> Result[Int, String] {
  match value {
    Some(Json::Number(number, repr=_)) => Ok(number.to_int())
    _ => Err(label + " must be a number")
  }
}

///|
fn json_bool(value : Json?, label : String) -> Result[Bool, String] {
  match value {
    Some(Json::True) => Ok(true)
    Some(Json::False) => Ok(false)
    _ => Err(label + " must be a boolean")
  }
}

///|
fn read_json(repo_root : String, path : String) -> Result[Json, String] {
  let text = match
    @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(path + " contains invalid JSON")
  }
  Ok(parsed)
}

///|
fn read_api_rows(
  repo_root : String,
  path : String,
) -> Result[Array[ApiRow], String] raise RepoDocsError {
  let root = match json_object(read_json(repo_root, path).or_raise(), path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if json_int(root.get("schemaVersion"), path + ".schemaVersion").or_raise() !=
    1 {
    return Err(path + ".schemaVersion must be 1")
  }
  let values = json_array(root.get("packages"), path + ".packages").or_raise()
  let rows : Array[ApiRow] = []
  for index, value in values {
    let label = path + ".packages[\{index}]"
    let fields = json_object(value, label).or_raise()
    rows.push({
      label: json_string(fields.get("label"), label + ".label").or_raise(),
      path: json_string(fields.get("path"), label + ".path").or_raise(),
      lines: json_int(fields.get("lines"), label + ".lines").or_raise(),
      public_declarations: json_int(
        fields.get("public_declarations"),
        label + ".public_declarations",
      ).or_raise(),
      pub_all_declarations: json_int(
        fields.get("pub_all_declarations"),
        label + ".pub_all_declarations",
      ).or_raise(),
    })
  }
  Ok(rows)
}

///|
fn workspace_members(text : String) -> Result[Array[String], String] {
  let members : Array[String] = []
  let mut in_members = false
  for line_view in text.split("\n") {
    let line = line_view.trim().to_owned()
    if !in_members {
      if line == "members = [" {
        in_members = true
      }
      continue
    }
    if line == "]" {
      return Ok(members)
    }
    let item = if line.has_suffix(",") {
      line[:line.length() - 1].trim().to_owned()
    } else {
      line
    }
    if item == "" || item.has_prefix("#") {
      continue
    }
    if !item.has_prefix("\"") || !item.has_suffix("\"") || item.length() < 2 {
      return Err("moon.work contains an invalid members entry: " + item)
    }
    members.push(item[1:item.length() - 1].to_owned())
  }
  if in_members {
    Err("moon.work members array is not closed")
  } else {
    Err("moon.work members array is missing")
  }
}

///|
fn catalog_example_path(path : String) -> Bool {
  path.has_prefix("examples/") &&
  !path.contains("\\") &&
  !path.contains(":") &&
  !path.contains("/../") &&
  !path.has_suffix("/..")
}

///|
fn read_example_catalog(
  repo_root : String,
) -> Result[Array[ExampleRow], String] raise RepoDocsError {
  let path = "examples/catalog.json"
  let root = json_object(read_json(repo_root, path).or_raise(), path).or_raise()
  if json_int(root.get("schemaVersion"), path + ".schemaVersion").or_raise() !=
    1 {
    return Err(path + ".schemaVersion must be 1")
  }
  let values = json_array(root.get("examples"), path + ".examples").or_raise()
  let rows : Array[ExampleRow] = []
  for index, value in values {
    let label = path + ".examples[\{index}]"
    let fields = json_object(value, label).or_raise()
    let id = json_string(fields.get("id"), label + ".id").or_raise()
    let example_path = json_string(fields.get("path"), label + ".path").or_raise()
    if rows.any(row => row.id == id) {
      return Err(label + ".id is duplicated: " + id)
    }
    if rows.any(row => row.path == example_path) {
      return Err(label + ".path is duplicated: " + example_path)
    }
    if !catalog_example_path(example_path) {
      return Err(label + ".path must stay under examples/")
    }
    if !@tools.directory_exists(@tools.resolve_path(repo_root, example_path)) {
      return Err(label + ".path does not exist: " + example_path)
    }
    rows.push({
      id,
      path: example_path,
      title: json_string(fields.get("title"), label + ".title").or_raise(),
      featured: json_bool(fields.get("featured"), label + ".featured").or_raise(),
    })
  }
  Ok(rows)
}

///|
fn workspace_examples(
  members : Array[String],
  catalog : Array[ExampleRow],
) -> Result[Array[ExampleRow], String] {
  let rows : Array[ExampleRow] = []
  for workspace_path in members {
    let normalized = if workspace_path.has_prefix("./") {
      workspace_path[2:].to_owned()
    } else {
      workspace_path
    }
    if normalized.has_prefix("examples/") {
      let mut found = false
      for example in catalog {
        if example.path == normalized {
          rows.push(example)
          found = true
        }
      }
      if !found {
        return Err(
          "moon.work example is missing from examples/catalog.json: " +
          normalized,
        )
      }
    }
  }
  Ok(rows)
}

///|
fn nested_status(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[String, String] raise RepoDocsError {
  let nested = match fields.get(key) {
    Some(value) => json_object(value, label + "." + key).or_raise()
    None => return Err(label + "." + key + " is missing")
  }
  let status = json_string(nested.get("status"), label + "." + key + ".status").or_raise()
  if status != "passed" && status != "partial" && status != "failed" {
    Err(label + "." + key + ".status must be passed, partial, or failed")
  } else {
    Ok(status)
  }
}

///|
fn nested_string(
  fields : Map[String, Json],
  key : String,
  nested_key : String,
  label : String,
) -> Result[String, String] raise RepoDocsError {
  let nested = match fields.get(key) {
    Some(value) => json_object(value, label + "." + key).or_raise()
    None => return Err(label + "." + key + " is missing")
  }
  json_string(nested.get(nested_key), label + "." + key + "." + nested_key)
}

///|
fn platform_fact_status(
  value : Json?,
  label : String,
) -> Result[String, String] {
  let status = match json_string(value, label) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if status != "passed" && status != "partial" && status != "failed" {
    Err(label + " must be passed, partial, or failed")
  } else {
    Ok(status)
  }
}

///|
fn embedded_runtime_host_kind(platform : String) -> String? {
  match platform {
    "android" => Some("window-hosted-android")
    "ios" => Some("window-hosted-ios")
    "harmonyos" => Some("window-hosted-harmonyos")
    _ => None
  }
}

///|
fn validate_mobile_platform_contract(
  facts : MobilePlatformContractFacts,
  label : String,
) -> Result[Unit, String] {
  let expected_host_kind = match embedded_runtime_host_kind(facts.platform) {
    Some(value) => value
    None => return Ok(())
  }
  if facts.host_kind != expected_host_kind {
    return Err(
      label +
      ".hostKind must be " +
      expected_host_kind +
      " for " +
      facts.platform,
    )
  }
  if facts.source_fact_statuses.length() != 1 {
    return Err(label + ".sourceBuild must record the windowHosted fact")
  }
  let expected_source_status = if facts.source_fact_statuses.any(status => {
      status == "failed"
    }) {
    "failed"
  } else if facts.source_fact_statuses.all(status => status == "passed") {
    "passed"
  } else {
    "partial"
  }
  if facts.source_status != expected_source_status {
    return Err(
      label +
      ".sourceBuild.status must aggregate windowHosted as " +
      expected_source_status,
    )
  }
  if facts.source_verified_on.length() != 10 ||
    !facts.source_verified_on.contains("-") {
    return Err(label + ".sourceBuild.verifiedOn must be an ISO date")
  }
  let expected_matrix_command = "moui build " + facts.platform
  if !facts.source_matrix_command.contains(expected_matrix_command) {
    return Err(
      label +
      ".sourceBuild.matrixCommand must build the " +
      facts.platform +
      " window-hosted template",
    )
  }
  if facts.actual_presenter_route == "unverified" {
    if facts.presenter_evidence_status != "unverified" ||
      facts.presenter_evidence_kind != "none" {
      return Err(
        label +
        ": an unverified actual presenter route requires unverified/none presenter evidence",
      )
    }
  } else {
    if facts.actual_presenter_route != facts.declared_presenter_route {
      return Err(
        label +
        ": actual presenter route must match the declared renderer route",
      )
    }
    if facts.presenter_evidence_status != "verified" ||
      facts.presenter_evidence_kind != "matching-device-direct-present" {
      return Err(
        label +
        ": an actual presenter route requires matching-device direct-present evidence",
      )
    }
  }
  if facts.presenter_evidence_reference.trim().to_owned() == "" {
    return Err(
      label + ".rendererL2.presenterEvidence.reference must not be empty",
    )
  }
  if facts.renderer_status == "passed" &&
    facts.actual_presenter_route == "unverified" {
    return Err(
      label +
      ": rendererL2 cannot pass with an unverified actual presenter route",
    )
  }
  if facts.runtime_status == "passed" &&
    facts.actual_presenter_route == "unverified" {
    return Err(
      label +
      ": mobile runtimeL3 cannot pass with an unverified presenter route",
    )
  }
  Ok(())
}

///|
fn read_platform_rows(
  repo_root : String,
) -> Result[Array[PlatformRow], String] raise RepoDocsError {
  let relative_dir = "checks/platforms"
  let directory = @tools.resolve_path(repo_root, relative_dir)
  let entries : Array[String] = @fs.read_dir(directory) catch {
    _ => return Err(relative_dir + " could not be read")
  }
  entries.sort_by((left, right) => left.lexical_compare(right))
  let rows : Array[PlatformRow] = []
  for entry in entries {
    if entry.has_suffix(".json") {
      let path = relative_dir + "/" + entry
      let fields = json_object(read_json(repo_root, path).or_raise(), path).or_raise()
      if json_int(fields.get("schemaVersion"), path + ".schemaVersion").or_raise() !=
        1 {
        return Err(path + ".schemaVersion must be 1")
      }
      let renderer = match fields.get("rendererL2") {
        Some(value) => json_object(value, path + ".rendererL2").or_raise()
        None => return Err(path + ".rendererL2 is missing")
      }
      let platform = json_string(fields.get("platform"), path + ".platform").or_raise()
      let expected_platform = entry[:entry.length() - 5].to_owned()
      if platform != expected_platform {
        return Err(path + ".platform must match its filename")
      }
      if rows.any(row => row.platform == platform) {
        return Err(path + ".platform is duplicated: " + platform)
      }
      let source_status = nested_status(fields, "sourceBuild", path).or_raise()
      let renderer_status = nested_status(fields, "rendererL2", path).or_raise()
      let runtime_status = nested_status(fields, "runtimeL3", path).or_raise()
      ignore(nested_string(fields, "sourceBuild", "evidence", path).or_raise())
      ignore(nested_string(fields, "runtimeL3", "evidence", path).or_raise())
      let declared_presenter_route = nested_string(
        fields, "rendererL2", "presenterRoute", path,
      ).or_raise()
      let actual_presenter_route = json_string(
        fields.get("actualPresenterRoute"),
        path + ".actualPresenterRoute",
      ).or_raise()
      let host_kind = json_string(fields.get("hostKind"), path + ".hostKind").or_raise()
      let deployment_floor = json_string(
        fields.get("deploymentFloor"),
        path + ".deploymentFloor",
      ).or_raise()
      let toolchain_floor = json_string(
        fields.get("toolchainFloor"),
        path + ".toolchainFloor",
      ).or_raise()
      if embedded_runtime_host_kind(platform) is Some(_) {
        let source = match fields.get("sourceBuild") {
          Some(value) => json_object(value, path + ".sourceBuild").or_raise()
          None => return Err(path + ".sourceBuild is missing")
        }
        let source_fact_statuses : Array[String] = []
        for key in ["windowHosted"] {
          source_fact_statuses.push(
            platform_fact_status(source.get(key), path + ".sourceBuild." + key).or_raise(),
          )
        }
        let presenter_evidence = match renderer.get("presenterEvidence") {
          Some(value) =>
            json_object(value, path + ".rendererL2.presenterEvidence").or_raise()
          None => return Err(path + ".rendererL2.presenterEvidence is missing")
        }
        validate_mobile_platform_contract(
          {
            platform,
            source_status,
            source_fact_statuses,
            source_verified_on: json_string(
              source.get("verifiedOn"),
              path + ".sourceBuild.verifiedOn",
            ).or_raise(),
            source_matrix_command: json_string(
              source.get("matrixCommand"),
              path + ".sourceBuild.matrixCommand",
            ).or_raise(),
            renderer_status,
            runtime_status,
            host_kind,
            declared_presenter_route,
            actual_presenter_route,
            presenter_evidence_status: json_string(
              presenter_evidence.get("status"),
              path + ".rendererL2.presenterEvidence.status",
            ).or_raise(),
            presenter_evidence_kind: json_string(
              presenter_evidence.get("kind"),
              path + ".rendererL2.presenterEvidence.kind",
            ).or_raise(),
            presenter_evidence_reference: json_string(
              presenter_evidence.get("reference"),
              path + ".rendererL2.presenterEvidence.reference",
            ).or_raise(),
          },
          path,
        ).or_raise()
      }
      if renderer_status == "passed" && actual_presenter_route == "unverified" {
        return Err(
          path +
          ": rendererL2 cannot pass with an unverified actual presenter route",
        )
      }
      rows.push({
        platform,
        source_status,
        renderer_status,
        runtime_status,
        host_kind,
        deployment_floor,
        toolchain_floor,
        declared_presenter_route,
        actual_presenter_route,
      })
      ignore(renderer)
    }
  }
  Ok(rows)
}

///|
fn read_docs_groups(
  repo_root : String,
) -> Result[(Int, Array[DocsGroupRow]), String] raise RepoDocsError {
  let path = "website/docs-catalog.json"
  let root = json_object(read_json(repo_root, path).or_raise(), path).or_raise()
  if json_int(root.get("schemaVersion"), path + ".schemaVersion").or_raise() !=
    1 {
    return Err(path + ".schemaVersion must be 1")
  }
  let group_values = json_array(root.get("groups"), path + ".groups").or_raise()
  let entry_values = json_array(root.get("entries"), path + ".entries").or_raise()
  let groups : Array[DocsGroupRow] = []
  for index, value in group_values {
    let label = path + ".groups[\{index}]"
    let fields = json_object(value, label).or_raise()
    let id = json_string(fields.get("id"), label + ".id").or_raise()
    let mut entry_count = 0
    for entry_index, entry_value in entry_values {
      let entry_label = path + ".entries[\{entry_index}]"
      let entry = json_object(entry_value, entry_label).or_raise()
      if json_string(entry.get("group"), entry_label + ".group").or_raise() ==
        id {
        entry_count += 1
      }
    }
    groups.push({
      id,
      title: json_string(fields.get("title"), label + ".title").or_raise(),
      entry_count,
    })
  }
  Ok((entry_values.length(), groups))
}

///|
fn markdown_line(builder : StringBuilder, value : String) -> Unit {
  builder.write_string(value)
  builder.write_char('\n')
}

///|
fn markdown_cell(value : String) -> String {
  value.replace_all(old="|", new="\\|").replace_all(old="\n", new=" ")
}

///|
fn render_repository_facts(
  api_rows : Array[ApiRow],
  workspace : Array[String],
  examples : Array[ExampleRow],
  platforms : Array[PlatformRow],
  docs_count : Int,
  docs_groups : Array[DocsGroupRow],
) -> String {
  let builder = StringBuilder()
  markdown_line(
    builder, "<!-- Generated by tools/moui/generate_repo_docs; DO NOT EDIT. -->",
  )
  markdown_line(builder, "")
  markdown_line(builder, "# Repository Facts")
  markdown_line(builder, "")
  markdown_line(
    builder, "This file is generated from repository manifests and validator reports.",
  )
  markdown_line(builder, "")
  markdown_line(builder, "## Workspace Members")
  markdown_line(builder, "")
  markdown_line(builder, "| Member |")
  markdown_line(builder, "|---|")
  for workspace_path in workspace {
    markdown_line(builder, "| " + markdown_cell(workspace_path) + " |")
  }
  markdown_line(builder, "")
  markdown_line(builder, "## API Surface")
  markdown_line(builder, "")
  markdown_line(builder, "| Package | Interface lines | Public | pub(all) |")
  markdown_line(builder, "|---|---:|---:|---:|")
  for row in api_rows {
    markdown_line(
      builder,
      "| " +
      markdown_cell(row.label) +
      " (" +
      markdown_cell(row.path) +
      ")" +
      " | \{row.lines} | \{row.public_declarations} | \{row.pub_all_declarations} |",
    )
  }
  markdown_line(builder, "")
  markdown_line(builder, "## Workspace Examples")
  markdown_line(builder, "")
  markdown_line(builder, "| Example | Path | Featured |")
  markdown_line(builder, "|---|---|---|")
  for example in examples {
    markdown_line(
      builder,
      "| " +
      markdown_cell(example.title) +
      " | " +
      markdown_cell(example.path) +
      " | " +
      (if example.featured { "yes" } else { "no" }) +
      " |",
    )
  }
  markdown_line(builder, "")
  markdown_line(builder, "## Platform Status")
  markdown_line(builder, "")
  markdown_line(
    builder, "| Platform | Build/source | Renderer L2 | Runtime L3 | Host | Deployment floor | Toolchain floor | Declared presenter | Actual presenter |",
  )
  markdown_line(builder, "|---|---|---|---|---|---|---|---|---|")
  for platform in platforms {
    markdown_line(
      builder,
      "| " +
      markdown_cell(platform.platform) +
      " | " +
      platform.source_status +
      " | " +
      platform.renderer_status +
      " | " +
      platform.runtime_status +
      " | " +
      markdown_cell(platform.host_kind) +
      " | " +
      markdown_cell(platform.deployment_floor) +
      " | " +
      markdown_cell(platform.toolchain_floor) +
      " | " +
      markdown_cell(platform.declared_presenter_route) +
      " | " +
      markdown_cell(platform.actual_presenter_route) +
      " |",
    )
  }
  markdown_line(builder, "")
  markdown_line(builder, "## Documentation Catalog")
  markdown_line(builder, "")
  markdown_line(builder, "Published documents: \{docs_count}.")
  markdown_line(builder, "")
  markdown_line(builder, "| Group | Documents |")
  markdown_line(builder, "|---|---:|")
  for group in docs_groups {
    markdown_line(
      builder,
      "| " +
      markdown_cell(group.title) +
      " (" +
      markdown_cell(group.id) +
      ") | \{group.entry_count} |",
    )
  }
  builder.to_string()
}

///|
fn generate(
  repo_root : String,
  api_report : String,
) -> Result[String, String] raise RepoDocsError {
  let api_rows = read_api_rows(repo_root, api_report).or_raise()
  let work = @tools.read_required_text(
    @tools.resolve_path(repo_root, "moon.work"),
    "moon.work",
  ).or_raise()
  let members = workspace_members(work).or_raise()
  let examples = workspace_examples(
    members,
    read_example_catalog(repo_root).or_raise(),
  ).or_raise()
  let platforms = read_platform_rows(repo_root).or_raise()
  let (docs_count, docs_groups) = read_docs_groups(repo_root).or_raise()
  Ok(
    render_repository_facts(
      api_rows, members, examples, platforms, docs_count, docs_groups,
    ),
  )
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let generated_result = generate(options.repo_root, options.api_report) catch {
        RepoDocsError::Invalid(message) => Err(message)
      }
      let generated = match generated_result {
        Ok(value) => value
        Err(message) => {
          println(message)
          return 2
        }
      }
      let path = @tools.resolve_path(
        options.repo_root,
        "docs/repository-facts.md",
      )
      if options.mode == "--write" {
        match
          @tools.write_text_file(path, generated, "generated repository facts") {
          Ok(_) => {
            println("generated docs/repository-facts.md")
            0
          }
          Err(message) => {
            println(message)
            2
          }
        }
      } else {
        match @tools.read_required_text(path, "generated repository facts") {
          Ok(current) if current == generated => {
            println("generated repository docs: current")
            0
          }
          Ok(_) => {
            println(
              "docs/repository-facts.md is stale; run generate_repo_docs --write",
            )
            1
          }
          Err(message) => {
            println(message)
            1
          }
        }
      }
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
