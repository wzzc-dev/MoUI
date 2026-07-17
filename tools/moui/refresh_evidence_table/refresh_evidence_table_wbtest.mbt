///|
test "generates markdown evidence table row" {
  let run = {
    id: "123",
    head_sha: "abcdef",
    created_at: "2026-07-16T00:00:00Z",
    html_url: "https://github.com/wzzc-dev/MoUI/actions/runs/123",
  }
  let details = {
    successful_jobs: ["pr-profile", "api-surface"],
    artifacts: ["renderer-proof"],
  }
  let row = generate_table_row(run, details)
  debug_inspect(row.workflow, content="\"MoUI CI\"")
  debug_inspect(
    row.run,
    content="\"[123](https://github.com/wzzc-dev/MoUI/actions/runs/123)\"",
  )
  debug_inspect(row.key_successful_jobs, content="\"pr-profile, api-surface\"")
  debug_inspect(row.uploaded_artifact_names, content="\"renderer-proof\"")
  debug_inspect(
    row.evidence_boundary,
    content="\"Proves CI run 123 for head SHA `abcdef`.\"",
  )
  debug_inspect(row.markdown.contains("| MoUI CI | [123]("), content="true")
}

///|
test "dry-run template includes manual review boundary" {
  let json = dry_run_template("dry-run").stringify()
  debug_inspect(json.contains("\"mode\":\"dry-run\""), content="true")
  debug_inspect(
    json.contains("Manual review required. Replace with current-head evidence."),
    content="true",
  )
}

///|
test "filters successful jobs and artifact names" {
  let jobs = (
    {
      "jobs": [
        { "name": "pr-profile", "conclusion": "success" },
        { "name": "failed-job", "conclusion": "failure" },
        { "name": "api-surface", "conclusion": "success" },
      ],
    } : Json)
  let artifacts = (
    { "artifacts": [{ "name": "renderer-proof" }, { "name": "logs" }] } : Json)
  let expected_jobs =
    #|["pr-profile", "api-surface"]
  let expected_artifacts =
    #|["renderer-proof", "logs"]
  debug_inspect(successful_job_names(jobs), content=expected_jobs)
  debug_inspect(artifact_names(artifacts), content=expected_artifacts)
}

///|
test "parses payload and builds live report" {
  let payload =
    #|{
    #|  "mode": "gh-cli",
    #|  "run_id": "99",
    #|  "head_sha": "deadbeef",
    #|  "date": "2026-07-16T12:00:00Z",
    #|  "html_url": "https://example.test/run/99",
    #|  "successful_jobs": ["pr-profile"],
    #|  "artifacts": ["proof"]
    #|}
    #|
  match parse_run_payload(payload) {
    Ok((run, details, mode)) => {
      debug_inspect(mode, content="\"gh-cli\"")
      debug_inspect(run.id, content="\"99\"")
      let report = live_report_json(mode, run, details).stringify()
      debug_inspect(report.contains("\"run_id\":\"99\""), content="true")
      debug_inspect(report.contains("Proves CI run 99"), content="true")
      debug_inspect(details.successful_jobs.length(), content="1")
    }
    Err(message) => fail(message)
  }
}
