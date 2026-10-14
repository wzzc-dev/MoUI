///|
/// CLI 侧的选项记录（落盘/打包动作的入参）。计划面类型（`@plan.ProjectOptions` /
/// `@plan.PlannedFile` / `@plan.ProjectManifest` / `@plan.HostPlatform`）住在 `scaffold_plan`。

///|
priv struct AddPlatformOptions {
  project_root : String
  platforms : Array[String]
  bundle_id : String?
}

///|
priv struct PackageReportOptions {
  project_root : String
  platforms : Array[String]
  version : String?
  output_dir : String?
  manifest_path : String?
  build : Bool
  dry_run : Bool
}
