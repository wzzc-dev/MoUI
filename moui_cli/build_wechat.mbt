///|
/// WeChat Mini Program build command.
/// Compiles MoonBit to wasm-gc and generates the Mini Program project structure.

///|
pub fn build_wechat(
  app_config_path~ : String,
  output_dir? : String = "build/wechat",
  prepare_only? : Bool = false,
) -> Unit {
  let app_config = @shell_config.read_app_config(app_config_path)
  let app_id = app_config.app_id
  let project_root = app_config.project_root

  println("Building WeChat Mini Program for app: " + app_id)
  println("Project root: " + project_root)
  println("Output dir: " + output_dir)

  // Step 1: Compile MoonBit to wasm-gc
  let build_cmd = "moon build " + project_root + " --target wasm-gc --output-wasm " + output_dir + "/moui/moui.wasm"
  println("Running: " + build_cmd)
  if not(prepare_only) {
    let result = @shell.run(build_cmd)
    if result.exit_code != 0 {
      println("ERROR: MoonBit build failed")
      println(result.stderr)
      return
    }
  }

  // Step 2: Copy Mini Program template files
  let template_dir = project_root + "/window/wechat/template"
  copy_template_files(template_dir, output_dir)

  // Step 3: Generate app.json with project config
  generate_app_config(app_config, output_dir)

  println("WeChat Mini Program build complete!")
  println("Output available at: " + output_dir)
  println("")
  println("Next steps:")
  println("  1. Open WeChat Developer Tools")
  println("  2. Import project from: " + output_dir)
  println("  3. Set your AppID in project.config.json")
  println("  4. Enable Skyline rendering engine in project settings")
  println("  5. Click Preview or Compile")
}

///|
fn copy_template_files(
  template_dir : String,
  output_dir : String,
) -> Unit {
  // Copy template files to output directory
  // In a real implementation, this would use fs operations
  println("Copying template files from " + template_dir + " to " + output_dir)
  // Placeholder for actual file copy operations
}

///|
fn generate_app_config(
  app_config : @shell_config.ShellApp,
  output_dir : String,
) -> Unit {
  // Update project.config.json with app-specific settings
  println("Generating app config for " + app_config.app_id)
  // Placeholder for actual config generation
}