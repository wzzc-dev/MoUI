///|
fn usage() -> String {
  "Usage: tools/moui/conformance_capture_scaffold --mode golden|benchmark [--output PATH]"
}

///|
fn default_output(mode : String) -> String {
  if mode == "golden" {
    "artifacts/conformance/showcase-golden-capture.json"
  } else {
    "artifacts/conformance/showcase-benchmark-capture.json"
  }
}

///|
fn parent_dir(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let mut slash = -1
  for i = 0; i < normalized.length(); i = i + 1 {
    if normalized[i] == '/' {
      slash = i
    }
  }
  if slash <= 0 {
    if normalized.has_prefix("/") {
      "/"
    } else {
      "."
    }
  } else {
    normalized[:slash].to_owned()
  }
}

///|
fn create_dir_if_missing(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  @fs.create_dir(path) catch {
    _ => return Err("could not create directory: " + path)
  }
  Ok(())
}

///|
fn mkdir_p(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  let normalized = path.replace(old="\\", new="/")
  let current = Ref(if normalized.has_prefix("/") { "/" } else { "" })
  for part in normalized.split("/") {
    if part == "" {
      continue
    }
    let part = part.to_owned()
    if current.val == "" || current.val == "/" {
      current.val = current.val + part
    } else {
      current.val = current.val + "/" + part
    }
    match create_dir_if_missing(current.val) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn screenshot(name : String, viewport : String, path : String) -> Json {
  {
    "name": Json::string(name),
    "viewport": Json::string(viewport),
    "path": Json::string(path),
  }
}

///|
fn build_manifest(mode : String) -> Json {
  let counters = [
    "command_count", "text_count", "image_count", "clip_depth", "open_clip_depth",
    "layer_depth", "open_layer_depth", "filter_depth", "open_filter_depth",
    "path_count", "shader_count", "unbalanced_pop_count",
  ].map(name => Json::string(name))
  let screenshots = [
    screenshot(
      "desktop",
      "1440x900",
      "artifacts/golden/showcase-web-wasm/desktop.png",
    ),
    screenshot(
      "tablet",
      "1024x768",
      "artifacts/golden/showcase-web-wasm/tablet.png",
    ),
    screenshot(
      "mobile",
      "390x844",
      "artifacts/golden/showcase-web-wasm/mobile.png",
    ),
  ]
  let metrics = [
    "startup_ms", "frame_time_ms", "dirty_count", "draw_command_count",
    "memory_bytes", "render_inspector_counters",
  ].map(name => Json::string(name))
  let notes = [
    "This manifest connects the build scaffold to manual capture artifacts.",
    "It does not contain captured measurements or screenshots by itself.",
  ].map(note => Json::string(note))
  let object : Map[String, Json] = Map([])
  object["schemaVersion"] = Json::number(1.0, repr="1")
  object["mode"] = Json::string(mode)
  object["showcaseTarget"] = Json::string("examples/showcase/web_wasm")
  object["url"] = Json::string(
    "http://127.0.0.1:18080/examples/showcase/web_wasm/",
  )
  object["renderInspectorSource"] = Json::string(
    "Showcase Diagnostics inspector snapshot card backed by @runtime.RenderInspectorSnapshot",
  )
  object["renderInspectorCounters"] = Json::array(counters)
  object["screenshotArtifacts"] = Json::array(screenshots)
  object["benchmarkMetrics"] = Json::array(metrics)
  object["notes"] = Json::array(notes)
  if mode == "benchmark" {
    let target1 : Map[String, Json] = Map([])
    target1["name"] = Json::string("showcase-web-wasm")
    target1["target"] = Json::string("examples/showcase/web_wasm")
    target1["url"] = Json::string(
      "http://127.0.0.1:18080/examples/showcase/web_wasm/",
    )
    target1["metricsPath"] = Json::string(
      "artifacts/benchmarks/showcase-web-wasm.json",
    )
    let target2 : Map[String, Json] = Map([])
    target2["name"] = Json::string("markdown-editor-web-wasm")
    target2["target"] = Json::string("examples/markdown_editor/web_wasm")
    target2["url"] = Json::string(
      "http://127.0.0.1:18080/examples/markdown_editor/web_wasm/",
    )
    target2["metricsPath"] = Json::string(
      "artifacts/benchmarks/markdown-editor-web-wasm.json",
    )
    object["benchmarkTargets"] = Json::array(
      [Json::object(target1), Json::object(target2)],
    )
  }
  Json::object(object)
}

///|
fn parse_cli(args : Array[String]) -> Result[(String, String), String] {
  let mut mode = ""
  let mut output = ""
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => return Err("help")
      "--mode" => {
        if index + 1 >= args.length() {
          return Err("missing value for --mode")
        }
        mode = args[index + 1]
        index += 2
      }
      "--output" => {
        if index + 1 >= args.length() {
          return Err("missing value for --output")
        }
        output = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  if mode != "golden" && mode != "benchmark" {
    return Err("mode must be golden or benchmark")
  }
  if output == "" {
    output = default_output(mode)
  }
  Ok((mode, output))
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err("help") => {
      println(usage())
      0
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok((mode, output)) => {
      let manifest = build_manifest(mode)
      let text = manifest.stringify(indent=2) + "\n"
      match mkdir_p(parent_dir(output)) {
        Ok(_) => ()
        Err(message) => {
          println(message)
          return 1
        }
      }
      match @tools.write_text_file(output, text, output) {
        Ok(_) => {
          println("Wrote capture manifest: " + output)
          0
        }
        Err(message) => {
          println(message)
          1
        }
      }
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
