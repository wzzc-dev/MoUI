///|
/// 计划 → 落盘：CLI 侧的事务（stage 临时目录 → 真跑工具链校验 → commit，
/// 失败回滚）消费 `@plan` 的文件计划。生成器本身零 fs/env。

///|
fn generate_project_with_validator(
  options : @plan.ProjectOptions,
  validate : (String) -> Result[Unit, String],
) -> Result[Array[String], String] {
  let files = match @plan.build_project_file_plan(options, cli_version()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  write_validated_project_file_plan(options.target, files, validate)
}

///|
fn generate_project(
  options : @plan.ProjectOptions,
) -> Result[Array[String], String] {
  match generate_project_with_validator(options, validate_generated_project) {
    Ok(files) => Ok(files)
    Err(message) if options.platforms.any(@plan.is_mobile_platform) &&
      (
        message.contains("drain_host_update_envelope_json") ||
        message.contains("dispatch_host_response_envelope_json") ||
        message.contains("session_generation") ||
        message.contains("attach_surface")
      ) =>
      Err(
        "the resolved wzzc-dev/moui@" +
        options.moui_version +
        " package is incompatible with the embedded-runtime entrypoint. " +
        "Validate against a current `moon package` artifact or set MOUI_PACKAGE_ROOT " +
        "to a current package root. The target directory was rolled back.\n" +
        message,
      )
    Err(message) => Err(message)
  }
}
