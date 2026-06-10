///|
struct CliOptions {
  repo_root : String
  acceptance_log : String
  revision_file : String
  skip_if_unpinned : Bool
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_skia_revision_pin ACCEPTANCE_LOG [options]
    #|
    #|Checks that skia-revision.txt is pinned to the same 40-character Skia
    #|commit recorded by a passing real Skia acceptance log.
    #|
    #|Options:
    #|  --repo-root PATH      Repository root used to resolve relative paths. Defaults to cwd.
    #|  --revision-file PATH  File containing the pinned Skia revision.
    #|                        Default: skia-revision.txt.
    #|  --skip-if-unpinned    Exit successfully when the revision file is not pinned.
    #|  -h, --help            Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let acceptance_log = Ref("")
  let revision_file = Ref("skia-revision.txt")
  let skip_if_unpinned = Ref(false)
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "--revision-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --revision-file")
        }
        revision_file.val = args[index + 1]
        index += 2
      }
      "--skip-if-unpinned" => {
        skip_if_unpinned.val = true
        index += 1
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if value.has_prefix("-") {
          return Err("unknown argument: " + value)
        }
        if acceptance_log.val != "" {
          return Err("unexpected argument: " + value)
        }
        acceptance_log.val = value
        index += 1
      }
    }
  }
  if !help.val && acceptance_log.val == "" {
    return Err("missing ACCEPTANCE_LOG")
  }
  Ok({
    repo_root: repo_root.val,
    acceptance_log: acceptance_log.val,
    revision_file: revision_file.val,
    skip_if_unpinned: skip_if_unpinned.val,
    help: help.val,
  })
}

///|
fn verify_skia_revision_pin(options : CliOptions) -> Result[String, String] {
  let resolved_revision_file = @tools.resolve_path(
    options.repo_root,
    options.revision_file,
  )
  let revision_text = match
    @tools.read_required_text(resolved_revision_file, "Skia revision file") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pinned_revision = @skia_acceptance.first_pinned_revision(revision_text)
  if !@skia_acceptance.full_hex_hash(pinned_revision) {
    if options.skip_if_unpinned {
      return Ok(
        "Skipping Skia revision pin check because revision is not pinned: " +
        @skia_acceptance.display_revision(pinned_revision),
      )
    }
    return Err(
      "Skia revision is not pinned to a full 40-character commit: " +
      @skia_acceptance.display_revision(pinned_revision),
    )
  }
  let resolved_acceptance_log = @tools.resolve_path(
    options.repo_root,
    options.acceptance_log,
  )
  let acceptance_text = match
    @tools.read_required_text(resolved_acceptance_log, "acceptance log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  @skia_acceptance.verify_revision_texts(
    revision_text,
    acceptance_text,
    options.skip_if_unpinned,
  )
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_skia_revision_pin(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(message) => {
          println(message)
          1
        }
      }
    Err(message) => {
      println(message)
      println(usage())
      2
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
