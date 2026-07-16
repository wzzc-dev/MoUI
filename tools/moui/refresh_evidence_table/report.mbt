///|
struct EvidenceRun {
  id : String
  head_sha : String
  created_at : String
  html_url : String
}

///|
struct EvidenceDetails {
  successful_jobs : Array[String]
  artifacts : Array[String]
}

///|
struct EvidenceTableRow {
  workflow : String
  run : String
  key_successful_jobs : String
  uploaded_artifact_names : String
  evidence_boundary : String
  markdown : String
}

///|
fn join_comma(values : Array[String]) -> String {
  values.join(", ")
}

///|
fn generate_table_row(
  run : EvidenceRun,
  details : EvidenceDetails,
) -> EvidenceTableRow {
  let jobs = join_comma(details.successful_jobs)
  let artifacts = join_comma(details.artifacts)
  let boundary = "Proves CI run " + run.id + " for head SHA `" + run.head_sha +
    "`."
  let run_cell = "[" + run.id + "](" + run.html_url + ")"
  {
    workflow: "MoUI CI",
    run: run_cell,
    key_successful_jobs: jobs,
    uploaded_artifact_names: artifacts,
    evidence_boundary: boundary,
    markdown: "| MoUI CI | " +
    run_cell +
    " | " +
    jobs +
    " | " +
    artifacts +
    " | " +
    boundary +
    " |",
  }
}

///|
fn dry_run_template(mode : String) -> Json {
  let template : Map[String, Json] = Map([])
  template["workflow"] = Json::string("MoUI CI")
  template["run"] = Json::string("[<run-id>](<run-url>)")
  template["key_successful_jobs"] = Json::string(
    "<job-name-1>, <job-name-2>",
  )
  template["uploaded_artifact_names"] = Json::string(
    "<artifact-1>, <artifact-2>",
  )
  template["evidence_boundary"] = Json::string(
    "Manual review required. Replace with current-head evidence.",
  )
  let object : Map[String, Json] = Map([])
  object["mode"] = Json::string(mode)
  object["message"] = Json::string(
    "Provide GITHUB_TOKEN, pass --token, or pass --gh to query the GitHub API. Without it, this script returns a template row.",
  )
  object["template"] = Json::object(template)
  Json::object(object)
}

///|
fn string_array_field(fields : Map[String, Json], key : String) -> Array[String] {
  match fields.get(key) {
    Some(Json::Array(values)) => {
      let result : Array[String] = []
      for value in values {
        match value {
          Json::String(text) => result.push(text)
          _ => ()
        }
      }
      result
    }
    _ => []
  }
}

///|
fn json_string_field(
  fields : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(Json::String(text)) => Ok(text)
    Some(Json::Number(number, repr=_)) => Ok(number.to_int().to_string())
    _ => Err("missing string field '" + key + "'")
  }
}

///|
fn parse_run_payload(text : String) -> Result[(EvidenceRun, EvidenceDetails, String), String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("payload contains invalid JSON")
  }
  let root = match parsed {
    Json::Object(fields) => fields
    _ => return Err("payload must be a JSON object")
  }
  let mode = match json_string_field(root, "mode") {
    Ok(value) => value
    Err(_) => "live"
  }
  let run_id = match json_string_field(root, "run_id") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let head_sha = match json_string_field(root, "head_sha") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let created_at = match json_string_field(root, "date") {
    Ok(value) => value
    Err(_) =>
      match json_string_field(root, "created_at") {
        Ok(value) => value
        Err(_) => ""
      }
  }
  let html_url = match json_string_field(root, "html_url") {
    Ok(value) => value
    Err(_) =>
      match json_string_field(root, "url") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
  }
  let successful_jobs = string_array_field(root, "successful_jobs")
  let artifacts = string_array_field(root, "artifacts")
  let run = {
    id: run_id,
    head_sha,
    created_at,
    html_url,
  }
  let details = { successful_jobs, artifacts }
  Ok((run, details, mode))
}

///|
fn live_report_json(
  mode : String,
  run : EvidenceRun,
  details : EvidenceDetails,
) -> Json {
  let row = generate_table_row(run, details)
  let object : Map[String, Json] = Map([])
  object["mode"] = Json::string(mode)
  object["run_id"] = Json::string(run.id)
  object["head_sha"] = Json::string(run.head_sha)
  object["date"] = Json::string(run.created_at)
  object["workflow"] = Json::string(row.workflow)
  object["run"] = Json::string(row.run)
  object["key_successful_jobs"] = Json::string(row.key_successful_jobs)
  object["uploaded_artifact_names"] = Json::string(row.uploaded_artifact_names)
  object["evidence_boundary"] = Json::string(row.evidence_boundary)
  object["markdown"] = Json::string(row.markdown)
  Json::object(object)
}

///|
fn successful_job_names(jobs_json : Json) -> Array[String] {
  let jobs = match jobs_json {
    Json::Object(fields) =>
      match fields.get("jobs") {
        Some(Json::Array(values)) => values
        _ => []
      }
    Json::Array(values) => values
    _ => []
  }
  let names : Array[String] = []
  for job in jobs {
    match job {
      Json::Object(fields) => {
        let conclusion = match fields.get("conclusion") {
          Some(Json::String(text)) => text
          _ => ""
        }
        let name = match fields.get("name") {
          Some(Json::String(text)) => text
          _ => ""
        }
        if conclusion == "success" && name != "" {
          names.push(name)
        }
      }
      _ => ()
    }
  }
  names
}

///|
fn artifact_names(artifacts_json : Json) -> Array[String] {
  let artifacts = match artifacts_json {
    Json::Object(fields) =>
      match fields.get("artifacts") {
        Some(Json::Array(values)) => values
        _ => []
      }
    Json::Array(values) => values
    _ => []
  }
  let names : Array[String] = []
  for artifact in artifacts {
    match artifact {
      Json::Object(fields) =>
        match fields.get("name") {
          Some(Json::String(text)) => names.push(text)
          _ => ()
        }
      _ => ()
    }
  }
  names
}
