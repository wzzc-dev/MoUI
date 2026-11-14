///|
/// `moui screenshot` — render an app to a PNG without opening a window.
///
/// The command resolves the project module and its shared app package, writes a
/// temporary offscreen render package beside the app, runs it through `moon`,
/// reads the captured RGBA frame, and encodes a PNG. The temporary package is
/// removed afterwards unless `--keep-temp` is passed.
///
/// The app package must expose `pub fn program() -> @moui.Program[Model, Msg]`
/// (the `moui new` template does) and its module must already depend on the
/// selected renderer package.

///|
priv struct ScreenshotOptions {
  project_root : String
  app_package : String
  out : String
  width : Int32
  height : Int32
  scale : Double
  scheme : String
  renderer : String
  keep_temp : Bool
}

///|
priv struct ScreenshotResult {
  out : String
  width : Int32
  height : Int32
  renderer : String
  scheme : String
}

///|
priv struct ParsedScreenshot {
  help : Bool
  json : Bool
  options : ScreenshotOptions
}

///|
fn screenshot_usage() -> String {
  (
    #|Usage: moui screenshot [project] [options]
    #|
    #|Render an app to a PNG with an offscreen renderer (no window, no display).
    #|The app package must expose `pub fn program()` and the project module must
    #|depend on the selected renderer package (`moui new` desktop projects do).
    #|
    #|Options:
    #|  --app PACKAGE       App package under the project root. Defaults to `app`.
    #|  --out PATH          Output PNG path (or directory). Defaults to
    #|                      `moui-screenshot.png`.
    #|  --width N           Logical width in DIPs. Defaults to 1080.
    #|  --height N          Logical height in DIPs. Defaults to 720.
    #|  --scale FACTOR      Device scale factor. Defaults to 2.0.
    #|  --scheme SCHEME     Runtime environment scheme: light, dark, or system.
    #|                      Defaults to light. Apps that pin their own theme
    #|                      ignore this; it only feeds environment-aware views.
    #|  --renderer NAME     Renderer: skia (default) or sun.
    #|  --keep-temp         Keep the generated render package for debugging.
    #|  --json              Emit machine-readable output.
    #|  -h, --help          Show this help.
  )
}

///|
fn screenshot_parse_int(value : StringView) -> Int32? {
  try @strconv.parse_int(value) catch {
    _ => None
  } noraise {
    parsed => Some(parsed)
  }
}

///|
fn screenshot_parse_double(value : StringView) -> Double? {
  try @strconv.parse_double(value) catch {
    _ => None
  } noraise {
    parsed => Some(parsed)
  }
}

///|
fn parse_screenshot_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedScreenshot, String] {
  let project : Ref[String?] = Ref(None)
  let app_package = Ref("app")
  let out = Ref("moui-screenshot.png")
  let width = Ref(1080)
  let height = Ref(720)
  let scale = Ref(2.0)
  let scheme = Ref("light")
  let renderer = Ref("skia")
  let keep_temp = Ref(false)
  let help = Ref(false)
  let json = Ref(false)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--app"
      | "--out"
      | "--width"
      | "--height"
      | "--scale"
      | "--scheme"
      | "--renderer" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        match name {
          "--app" => app_package.val = value
          "--out" => out.val = value
          "--width" =>
            match screenshot_parse_int(value) {
              Some(parsed) => {
                if parsed <= 0 {
                  return Err("--width must be a positive integer")
                }
                width.val = parsed
              }
              None => return Err("invalid --width: " + value)
            }
          "--height" =>
            match screenshot_parse_int(value) {
              Some(parsed) => {
                if parsed <= 0 {
                  return Err("--height must be a positive integer")
                }
                height.val = parsed
              }
              None => return Err("invalid --height: " + value)
            }
          "--scale" =>
            match screenshot_parse_double(value) {
              Some(parsed) => {
                if parsed <= 0.0 || parsed > 8.0 {
                  return Err("--scale must be in (0, 8]")
                }
                scale.val = parsed
              }
              None => return Err("invalid --scale: " + value)
            }
          "--scheme" => {
            let normalized = value.to_lower()
            if normalized != "light" &&
              normalized != "dark" &&
              normalized != "system" {
              return Err("--scheme must be light, dark, or system")
            }
            scheme.val = normalized
          }
          "--renderer" => {
            let normalized = value.to_lower()
            if normalized != "skia" && normalized != "sun" {
              return Err("--renderer must be skia or sun")
            }
            renderer.val = normalized
          }
          _ => ()
        }
        index = next
      }
      "--keep-temp" | "--json" | "-h" | "--help" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        match name {
          "--keep-temp" => keep_temp.val = true
          "--json" => json.val = true
          "-h" | "--help" => help.val = true
          _ => ()
        }
        index += 1
      }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui screenshot: " + name)
      _ => {
        match project.val {
          None => project.val = Some(argument)
          Some(_) =>
            return Err("moui screenshot accepts at most one project path")
        }
        index += 1
      }
    }
  }
  let resolved_project = match project.val {
    Some(value) => resolve_path(cwd, value)
    None => cwd
  }
  Ok({
    help: help.val,
    json: json.val,
    options: {
      project_root: resolved_project,
      app_package: app_package.val,
      out: resolve_path(cwd, out.val),
      width: width.val,
      height: height.val,
      scale: scale.val,
      scheme: scheme.val,
      renderer: renderer.val,
      keep_temp: keep_temp.val,
    },
  })
}

///|
/// Module root and app import path resolved from a project/app directory.
priv struct ScreenshotTarget {
  module_root : String
  module_name : String
  app_dir : String
  app_relative : String
  app_import : String
}

///|
fn screenshot_module_name(moon_mod_text : String) -> String? {
  for line in moon_mod_text.split("\n") {
    let trimmed = line.trim()
    if trimmed.has_prefix("name") {
      match trimmed.find("\"") {
        Some(start) =>
          match trimmed[start + 1:].find("\"") {
            Some(end) =>
              return Some(trimmed[start + 1:start + 1 + end].to_owned())
            None => ()
          }
        None => ()
      }
    }
  }
  None
}

///|
/// Walk up from `start` until a directory containing `moon.mod` is found.
fn screenshot_find_module_root(start : String) -> String? {
  let mut current = normalized_path(start)
  while current != "" {
    if path_is_file(join_path(current, "moon.mod")) {
      return Some(current)
    }
    let parent = parent_dir(current)
    if parent == current {
      return None
    }
    current = parent
  }
  None
}

///|
fn screenshot_resolve_target(
  project_root : String,
  app_package : String,
) -> Result[ScreenshotTarget, String] {
  let project_path = normalized_path(project_root)
  let module_root = match screenshot_find_module_root(project_path) {
    Some(value) => value
    None =>
      return Err(
        "no moon.mod found at or above " +
        project_path +
        "; run moui screenshot from a project directory",
      )
  }
  let is_module_root = normalized_path(project_path) == module_root
  let app_dir = if !is_module_root &&
    path_is_file(join_path(project_path, "moon.pkg")) {
    project_path
  } else {
    normalized_path(join_path(module_root, app_package))
  }
  let app_dir = if path_is_file(join_path(app_dir, "moon.pkg")) {
    app_dir
  } else if is_module_root && path_is_file(join_path(module_root, "moon.pkg")) {
    // The module root package itself may be the app.
    module_root
  } else {
    return Err(
      "app package not found: " +
      app_dir +
      " (pass --app PACKAGE or point at a package directory)",
    )
  }
  let moon_mod_text = match
    read_file_string_optional(join_path(module_root, "moon.mod")) {
    Some(value) => value
    None => return Err("could not read moon.mod under " + module_root)
  }
  let module_name = match screenshot_module_name(moon_mod_text) {
    Some(value) => value
    None => return Err("moon.mod under " + module_root + " has no module name")
  }
  let app_relative = relative_path_under(module_root, app_dir)
  let app_import = if app_relative == "." || app_relative == "" {
    module_name
  } else {
    module_name + "/" + app_relative
  }
  Ok({ module_root, module_name, app_dir, app_relative, app_import, })
}

///|
/// The app package must expose a zero-argument program constructor; the
/// generated render package calls it as `@app.program()`.
fn screenshot_app_exposes_program(app_dir : String) -> Result[Bool, String] {
  let entries = @fs.read_dir(app_dir) catch {
    _ => return Err("could not read app package: " + app_dir)
  }
  for name in entries {
    if name.has_suffix(".mbt") {
      match read_file_string_optional(join_path(app_dir, name)) {
        Some(text) => if text.contains("pub fn program(") { return Ok(true) }
        None => ()
      }
    }
  }
  Ok(false)
}

///|
fn screenshot_has_dependency(
  moon_mod_text : String,
  module_name : String,
) -> Bool {
  moon_mod_text.contains("\"" + module_name)
}

///|
fn screenshot_package_dir(module_root : String) -> String {
  join_path(module_root, "moui_screenshot_tmp")
}

///|
let screenshot_package_marker : String = "MOUI_SCREENSHOT_PACKAGE"

///|
fn screenshot_package_moon_pkg(renderer : String) -> String {
  let renderer_import = if renderer == "sun" {
    "wzzc-dev/moui_sun_renderer"
  } else {
    "wzzc-dev/moui_skia_renderer"
  }
  (
    #|import {
    #|  "moonbitlang/core/encoding/utf8",
    #|  "moonbitlang/core/env",
    #|  "moonbitlang/core/string" @strings,
    #|  "wzzc-dev/moui/core",
    #|  "wzzc-dev/moui/runtime",
    #|  "__RENDERER_IMPORT__" @render,
    #|  "__APP_IMPORT__" @app,
    #|}
    #|
    #|supported_targets = "+native"
    #|
    #|pkgtype(kind: "executable")
    #|
    #|options(
    #|  "native-stub": [ "screenshot_io.c" ],
    #|  targets: { "main.mbt": [ "native" ] },
    #|)
  ).replace_all(old="__RENDERER_IMPORT__", new=renderer_import)
}

///|
fn screenshot_package_main(renderer : String) -> String {
  let renderer_block = if renderer == "sun" {
    (
      #|  let target = @render.SunPresentTarget::new(
      #|    description="moui-screenshot",
      #|    present=frame => {
      #|      captured.val = Some({
      #|        width: frame.width(),
      #|        height: frame.height(),
      #|        row_bytes: frame.row_bytes(),
      #|        pixels: frame.bytes(),
      #|      })
      #|      true
      #|    },
      #|  )
      #|  let renderer = @render.create_with_present_target(metrics, target) catch {
      #|    _ => abort("moui screenshot: could not create the sun renderer")
      #|  } noraise {
      #|    renderer => renderer
      #|  }
      #|  ignore(renderer.render_frame(runtime.draw_frame()))
    )
  } else {
    (
      #|  let target = @render.SkiaPresentTarget::new(
      #|    description="moui-screenshot",
      #|    present=frame => {
      #|      captured.val = Some({
      #|        width: frame.width(),
      #|        height: frame.height(),
      #|        row_bytes: frame.row_bytes(),
      #|        pixels: frame.pixels(),
      #|      })
      #|      true
      #|    },
      #|  )
      #|  let renderer = @render.create_with_present_target(metrics, target) catch {
      #|    _ => abort("moui screenshot: could not create the skia renderer")
      #|  } noraise {
      #|    renderer => renderer
      #|  }
      #|  ignore(renderer.render_frame(runtime.draw_frame()))
    )
  }
  let template =
    #|///|
    #|#borrow(path, data)
    #|extern "C" fn screenshot_write(path : Bytes, data : Bytes) -> Int32 = "moui_screenshot_write"
    #|
    #|///|
    #|struct Shot {
    #|  width : Int32
    #|  height : Int32
    #|  row_bytes : Int32
    #|  pixels : Bytes
    #|}
    #|
    #|///|
    #|fn arg_value(args : Array[String], flag : String) -> String? {
    #|  let mut index = 0
    #|  while index < args.length() {
    #|    if args[index] == flag && index + 1 < args.length() {
    #|      return Some(args[index + 1])
    #|    }
    #|    index = index + 1
    #|  }
    #|  None
    #|}
    #|
    #|///|
    #|fn write_or_abort(path : String, data : Bytes) -> Unit {
    #|  if screenshot_write(@utf8.encode(path[:], bom=false) + b"\x00", data) != 0 {
    #|    abort("moui screenshot: could not write " + path)
    #|  }
    #|}
    #|
    #|///|
    #|fn parse_double_or(value : String?, fallback : Double) -> Double {
    #|  match value {
    #|    Some(text) =>
    #|      try @strings.parse_double(text) catch {
    #|        _ => fallback
    #|      } noraise {
    #|        parsed => parsed
    #|      }
    #|    None => fallback
    #|  }
    #|}
    #|
    #|fn main {
    #|  let args = @env.args()
    #|  let out = arg_value(args, "--out").unwrap_or(".")
    #|  let width = parse_double_or(arg_value(args, "--width"), 1080.0)
    #|  let height = parse_double_or(arg_value(args, "--height"), 720.0)
    #|  let scale = parse_double_or(arg_value(args, "--scale"), 2.0)
    #|  let scheme = arg_value(args, "--scheme").unwrap_or("light")
    #|  let environment = match scheme {
    #|    "dark" => @core.Environment::neutral().with_system_scheme(@core.Dark)
    #|    "system" => @core.Environment::neutral()
    #|    _ => @core.Environment::neutral().with_system_scheme(@core.Light)
    #|  }
    #|  let runtime = @runtime.new_program_with_dimensions(
    #|    program=@app.program(),
    #|    width~,
    #|    height~,
    #|    environment~,
    #|  )
    #|  let captured : Ref[Shot?] = Ref(None)
    #|  let metrics = @core.SurfaceMetrics::from_logical(
    #|    size=@core.Size::new(width~, height~),
    #|    scale_factor=scale,
    #|  )
    #|__RENDERER_BLOCK__
    #|  let shot = match captured.val {
    #|    Some(value) => value
    #|    None => abort("moui screenshot: the renderer presented no frame")
    #|  }
    #|  write_or_abort(out + "/shot.rgba", shot.pixels)
    #|  let meta : String = "width=" + shot.width.to_string() +
    #|    "\nheight=" + shot.height.to_string() +
    #|    "\nrowBytes=" + shot.row_bytes.to_string() + "\n"
    #|  write_or_abort(out + "/shot.meta", @utf8.encode(meta[:], bom=false))
    #|}
  template.replace_all(old="__RENDERER_BLOCK__", new=renderer_block)
}

///|
fn screenshot_package_c_stub() -> String {
  (
    #|#include <moonbit.h>
    #|#include <stdint.h>
    #|#include <stdio.h>
    #|
    #|MOONBIT_FFI_EXPORT int32_t moui_screenshot_write(
    #|    moonbit_bytes_t path,
    #|    moonbit_bytes_t data) {
    #|  FILE *file = fopen((const char *)path, "wb");
    #|  if (file == NULL) {
    #|    return 1;
    #|  }
    #|  int32_t length = (int32_t)Moonbit_array_length(data);
    #|  size_t written = fwrite(data, 1, (size_t)length, file);
    #|  int close_status = fclose(file);
    #|  if (written != (size_t)length || close_status != 0) {
    #|    return 2;
    #|  }
    #|  return 0;
    #|}
  )
}

///|
fn screenshot_write_package(
  target : ScreenshotTarget,
  renderer : String,
) -> Result[String, String] {
  let package_dir = screenshot_package_dir(target.module_root)
  let has_marker = path_is_file(
    join_path(package_dir, screenshot_package_marker),
  )
  let package_exists = @fs.is_dir(package_dir) catch { _ => false }
  if has_marker {
    remove_tree(package_dir)
  } else if package_exists {
    return Err(
      "refusing to overwrite " +
      package_dir +
      ": it exists but is not a moui screenshot package",
    )
  }
  match create_dir_if_missing(package_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let pkg_text = screenshot_package_moon_pkg(renderer).replace_all(
    old="__APP_IMPORT__",
    new=target.app_import,
  )
  let files : Array[(String, String)] = [
    ("moon.pkg", pkg_text),
    ("main.mbt", screenshot_package_main(renderer)),
    ("screenshot_io.c", screenshot_package_c_stub()),
    (
      screenshot_package_marker,
      "schemaVersion=1\nmodule=" +
      target.module_name +
      "\napp=" +
      target.app_import +
      "\n",
    ),
  ]
  for entry in files {
    match
      write_file_bytes_result(
        join_path(package_dir, entry.0),
        @utf8.encode(entry.1[:], bom=false),
      ) {
      Ok(_) => ()
      Err(message) => {
        remove_tree(package_dir)
        return Err(message)
      }
    }
  }
  Ok(package_dir)
}

///|
fn screenshot_read_meta(path : String) -> Result[(Int32, Int32, Int32), String] {
  let text = match read_file_string_optional(path) {
    Some(value) => value
    None => return Err("could not read screenshot metadata: " + path)
  }
  let mut width = 0
  let mut height = 0
  let mut row_bytes = 0
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.has_prefix("width=") {
      width = screenshot_parse_int(trimmed[6:]).unwrap_or(0)
    } else if trimmed.has_prefix("height=") {
      height = screenshot_parse_int(trimmed[7:]).unwrap_or(0)
    } else if trimmed.has_prefix("rowBytes=") {
      row_bytes = screenshot_parse_int(trimmed[9:]).unwrap_or(0)
    }
  }
  if width <= 0 || height <= 0 || row_bytes <= 0 {
    return Err("screenshot metadata is incomplete: " + path)
  }
  Ok((width, height, row_bytes))
}

///|
fn screenshot_output_png_path(out : String) -> String {
  if out.has_suffix(".png") {
    return out
  }
  let is_directory = @fs.is_dir(out) catch { _ => false }
  if is_directory || out.has_suffix("/") {
    join_path(out, "screenshot.png")
  } else {
    out + ".png"
  }
}

///|
fn screenshot_cleanup(package_dir : String, keep_temp : Bool) -> Unit {
  if !keep_temp {
    remove_tree(package_dir)
  }
}

///|
fn run_screenshot(args : Array[String], cwd : String) -> CliOutcome {
  let parsed = match parse_screenshot_args(args, cwd) {
    Ok(value) => value
    Err(message) =>
      return failed_outcome(message, json_requested(args), screenshot_usage())
  }
  if parsed.help {
    return stdout_outcome(screenshot_usage())
  }
  let options = parsed.options
  let target = match
    screenshot_resolve_target(options.project_root, options.app_package) {
    Ok(value) => value
    Err(message) =>
      return failed_outcome(message, parsed.json, screenshot_usage())
  }
  match screenshot_app_exposes_program(target.app_dir) {
    Ok(true) => ()
    Ok(false) =>
      return failed_outcome(
        "app package " +
        target.app_import +
        " must expose `pub fn program() -> @moui.Program[Model, Msg]`",
        parsed.json,
        screenshot_usage(),
      )
    Err(message) =>
      return failed_outcome(message, parsed.json, screenshot_usage())
  }
  let moon_mod_text = read_file_string_optional(
    join_path(target.module_root, "moon.mod"),
  ).unwrap_or("")
  let renderer_module = if options.renderer == "sun" {
    "wzzc-dev/moui_sun_renderer"
  } else {
    "wzzc-dev/moui_skia_renderer"
  }
  if !screenshot_has_dependency(moon_mod_text, renderer_module) {
    return failed_outcome(
      "project module " +
      target.module_name +
      " does not depend on " +
      renderer_module +
      "; add it to moon.mod (generated desktop projects include it)",
      parsed.json,
      screenshot_usage(),
    )
  }
  let package_dir = match screenshot_write_package(target, options.renderer) {
    Ok(value) => value
    Err(message) =>
      return failed_outcome(message, parsed.json, screenshot_usage())
  }
  let temp_out = join_path(
    process_tmp_dir(),
    "moui-screenshot-" + @env.now().to_string(),
  )
  let cleanup = fn() { screenshot_cleanup(package_dir, options.keep_temp) }
  let render_result = match create_dir_if_missing(temp_out) {
    Ok(_) =>
      process_exec_argv(
        [
          "moon",
          "run",
          "moui_screenshot_tmp",
          "--target",
          "native",
          "--",
          "--out",
          temp_out,
          "--width",
          options.width.to_string(),
          "--height",
          options.height.to_string(),
          "--scale",
          options.scale.to_string(),
          "--scheme",
          options.scheme,
        ],
        cwd=target.module_root,
        capture=true,
        timeout_ms=600000,
      )
    Err(message) => Err(message)
  }
  let outcome = match render_result {
    Ok(result) =>
      if result.exit_code != 0 {
        cleanup()
        remove_tree(temp_out)
        return failed_outcome(
          "offscreen render failed (moon exit " +
          result.exit_code.to_string() +
          "):\n" +
          result.stderr,
          parsed.json,
          "",
        )
      } else {
        let meta_path = join_path(temp_out, "shot.meta")
        let rgba_path = join_path(temp_out, "shot.rgba")
        let meta = screenshot_read_meta(meta_path)
        let png = match meta {
          Err(message) => Err(message)
          Ok((width, height, row_bytes)) =>
            match read_file_bytes_optional(rgba_path) {
              None => Err("could not read screenshot pixels: " + rgba_path)
              Some(pixels) => {
                let encoded = try
                  png_encode_rgba(width, height, row_bytes, pixels)
                catch {
                  _ => None
                } noraise {
                  value => Some(value)
                }
                match encoded {
                  Some(bytes) => Ok((bytes, width, height))
                  None => Err("could not encode the screenshot as PNG")
                }
              }
            }
        }
        match png {
          Ok((bytes, width, height)) => {
            let out_path = screenshot_output_png_path(options.out)
            let parent = parent_dir(out_path)
            if parent != "" && parent != "." {
              match mkdir_p(parent) {
                Ok(_) => ()
                Err(message) => {
                  cleanup()
                  remove_tree(temp_out)
                  return failed_outcome(message, parsed.json, "")
                }
              }
            }
            match write_file_bytes_result(out_path, bytes) {
              Ok(_) =>
                Ok(ScreenshotResult::{
                  out: out_path,
                  width,
                  height,
                  renderer: options.renderer,
                  scheme: options.scheme,
                })
              Err(message) => Err(message)
            }
          }
          Err(message) => Err(message)
        }
      }
    Err(message) => Err(message)
  }
  cleanup()
  remove_tree(temp_out)
  match outcome {
    Ok(value) =>
      if parsed.json {
        let json_value : Json = {
          "schemaVersion": 1,
          "ok": true,
          "command": "screenshot",
          "out": value.out,
          "width": value.width,
          "height": value.height,
          "renderer": value.renderer,
          "scheme": value.scheme,
          "module": target.module_name,
          "package": target.app_relative,
        }
        stdout_outcome(json_value.stringify(indent=2) + "\n")
      } else {
        stdout_outcome(
          "[screenshot] wrote " +
          value.out +
          " (" +
          value.width.to_string() +
          "x" +
          value.height.to_string() +
          ", " +
          value.renderer +
          ", " +
          value.scheme +
          ")\n",
        )
      }
    Err(message) => failed_outcome(message, parsed.json, "")
  }
}
