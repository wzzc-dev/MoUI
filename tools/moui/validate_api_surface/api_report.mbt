///|
struct ApiPackageReport {
  label : String
  path : String
  lines : Int
  public_declarations : Int
  pub_all_declarations : Int
} derive(ToJson)

///|
fn write_api_package_report(
  repo_root : String,
  report_path : String,
  reports : Array[ApiPackageReport],
) -> Result[Unit, String] {
  if report_path == "" {
    return Ok(())
  }
  let path = @tools.resolve_path(repo_root, report_path)
  let text = ({ "schemaVersion": 1, "packages": reports.to_json() } : Json).stringify(
      indent=2,
    ) +
    "\n"
  @tools.write_text_file(path, text, "API surface report")
}
