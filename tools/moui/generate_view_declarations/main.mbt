///|
struct CliOptions {
  _repo_root : String
  manifest : String
  output_root : String
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/generate_view_declarations
    #|  [--repo-root PATH] [--manifest PATH] [--output-root PATH]
    #|
    #|Emits one `declarations.generated.mbt` per `moui/views` pkg from the
    #|declarative manifest `checks/viewnode-declarations.json` (ADR 0034
    #|Option B). Each generated file carries the `ViewNode.declaration` impl
    #|blocks for that pkg's nodes; the P17 coverage gate reads them like
    #|hand-written declarations.
    #|
    #|Defaults: manifest `<repo-root>/checks/viewnode-declarations.json`,
    #|output root `<repo-root>`. Drift checking is orchestrated by
    #|scripts/generate-view-declarations.mjs (--check), which formats fresh
    #|output with moonfmt before byte-comparing against the committed files.
    #|
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut repo_root = "."
  let mut manifest = ""
  let mut output_root = ""
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--help" | "-h" => {
        help = true
        index += 1
      }
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      "--manifest" => {
        if index + 1 >= args.length() {
          return Err("missing value for --manifest")
        }
        manifest = args[index + 1]
        index += 2
      }
      "--output-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --output-root")
        }
        output_root = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  if manifest == "" {
    manifest = @tools.resolve_path(
      repo_root, "checks/viewnode-declarations.json",
    )
  }
  if output_root == "" {
    output_root = repo_root
  }
  Ok({ _repo_root: repo_root, manifest, output_root, help, })
}

///|
/// Create a directory chain level by level (`@fs.create_dir` does not nest).
fn ensure_directory(path : String) -> Result[Unit, String] {
  if @tools.directory_exists(path) {
    return Ok(())
  }
  let segments : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index <= path.length() {
    if index == path.length() || path[index] == '/' {
      if index > start {
        segments.push(path[start:index].to_owned())
      }
      start = index + 1
    }
    index += 1
  }
  let absolute = path.has_prefix("/")
  let mut built = ""
  for segment in segments {
    built = if built == "" {
      if absolute {
        "/" + segment
      } else {
        segment
      }
    } else {
      built + "/" + segment
    }
    if @tools.directory_exists(built) {
      continue
    }
    @fs.create_dir(built) catch {
      _ =>
        if !@tools.directory_exists(built) {
          return Err("could not create directory: " + built)
        }
    }
  }
  Ok(())
}

///|
fn run(args : Array[String]) -> Int32 {
  let options = match parse_cli(args) {
    Ok(value) => value
    Err(message) => {
      println(message)
      println(usage())
      return 2
    }
  }
  if options.help {
    println(usage())
    return 0
  }
  let text = match @tools.read_required_text(options.manifest, "manifest") {
    Ok(value) => value
    Err(message) => {
      println("generate-view-declarations: ERROR " + message)
      return 1
    }
  }
  let manifest = match parse_manifest(text) {
    Ok(value) => value
    Err(message) => {
      println("generate-view-declarations: ERROR " + message)
      return 1
    }
  }
  for node in manifest.nodes {
    match validate_node(node) {
      Ok(_) => ()
      Err(message) => {
        println("generate-view-declarations: ERROR " + message)
        return 1
      }
    }
  }
  // Group nodes by pkg, preserving manifest order of both levels.
  let packages : Array[String] = []
  let grouped : Map[String, Array[NodeSpec]] = Map([])
  for node in manifest.nodes {
    match grouped.get(node.pkg) {
      Some(bucket) => bucket.push(node)
      None => {
        grouped[node.pkg] = [node]
        packages.push(node.pkg)
      }
    }
  }
  for pkg in packages {
    let nodes = match grouped.get(pkg) {
      Some(bucket) => bucket
      None => continue
    }
    let directory = @tools.resolve_path(options.output_root, pkg)
    match ensure_directory(directory) {
      Ok(_) => ()
      Err(message) => {
        println("generate-view-declarations: ERROR " + message)
        return 1
      }
    }
    let path = directory + "/declarations.generated.mbt"
    let content = emit_package_file(pkg, nodes)
    match @tools.write_text_file(path, content, path) {
      Ok(_) => println("wrote " + path)
      Err(message) => {
        println("generate-view-declarations: ERROR " + message)
        return 1
      }
    }
  }
  0
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
