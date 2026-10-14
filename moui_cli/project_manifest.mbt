///|
/// 读盘侧的清单入口：渲染/解析/校验这些纯口径住在
/// `@plan`（`scaffold_plan/manifest.mbt`），这里只做「路径 → 文本」。

///|
fn read_project_manifest(
  project_root : String,
) -> Result[@plan.ProjectManifest, String] {
  let path = join_path(project_root, "moui.project.json")
  if !@fs.path_exists(path) {
    return Err("project manifest not found: " + path)
  }
  let text = @fs.read_file_to_string(path) catch {
    _ => return Err("could not read project manifest: " + path)
  }
  @plan.parse_project_manifest(text)
}
