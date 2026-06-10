///|
let default_acceptance_log = "logs/linux-real-skia-smoke/linux-real-skia-acceptance.log"

///|
struct CliOptions {
  repo_root : String
  acceptance_log : String
  revision_file : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/pin_skia_revision [acceptance-log] [options]
    #|
    #|Verifies a Linux real Skia acceptance log, reads the last
    #|skia_commit=<hash> entry, and writes that commit to skia-revision.txt.
    #|
    #|Options:
    #|  --repo-root PATH      Repository root used to resolve relative paths. Defaults to cwd.
    #|  --revision-file PATH  File to write. Defaults to skia-revision.txt.
    #|  -h, --help            Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let acceptance_log = Ref(default_acceptance_log)
  let revision_file = Ref("skia-revision.txt")
  let help = Ref(false)
  let seen_acceptance_log = Ref(false)
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
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if value.has_prefix("-") {
          return Err("unknown argument: " + value)
        }
        if seen_acceptance_log.val {
          return Err("expected at most one acceptance log path")
        }
        acceptance_log.val = value
        seen_acceptance_log.val = true
        index += 1
      }
    }
  }
  Ok({
    repo_root: repo_root.val,
    acceptance_log: acceptance_log.val,
    revision_file: revision_file.val,
    help: help.val,
  })
}

///|
fn revision_pin_content(acceptance_text : String) -> Result[String, String] {
  match @skia_acceptance.accepted_commit_from_log_text(acceptance_text) {
    Ok(commit) => Ok(commit + "\n")
    Err(message) => Err(message)
  }
}

///|
fn pin_skia_revision(options : CliOptions) -> Result[String, String] {
  let resolved_log_path = @tools.resolve_path(
    options.repo_root,
    options.acceptance_log,
  )
  let acceptance_text = match
    @tools.read_required_text(resolved_log_path, "acceptance log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let content = match revision_pin_content(acceptance_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let resolved_revision_file = @tools.resolve_path(
    options.repo_root,
    options.revision_file,
  )
  match
    @tools.write_text_file(
      resolved_revision_file, content, "Skia revision file",
    ) {
    Ok(_) =>
      Ok(
        "Pinned " + resolved_revision_file + " to " + content.trim().to_owned(),
      )
    Err(message) => Err(message)
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match pin_skia_revision(options) {
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
