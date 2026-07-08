///|
struct CliOptions {
  repo_root : String
  scope : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_maintenance_baseline [--repo-root PATH] [--scope daily|full]
    #|
    #|Checks maintenance ratchets for file size, `pub(all)` exposure, root
    #|facade forwarding, and MoonBit-backed JS validator wrappers.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  --scope VALUE      `daily` default, or `full` for addon/tool hotspots.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let scope = Ref("daily")
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
      "--scope" => {
        if index + 1 >= args.length() {
          return Err("missing value for --scope")
        }
        match args[index + 1] {
          "daily" | "full" => scope.val = args[index + 1]
          other => return Err("unknown scope: " + other)
        }
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, scope: scope.val, help: help.val })
}
