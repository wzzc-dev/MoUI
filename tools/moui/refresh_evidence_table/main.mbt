///|
struct CliOptions {
  dry_run : Bool
  no_token : Bool
  mode : String
  payload : String
  payload_file : String
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/refresh_evidence_table [--dry-run|--no-token] [--mode live|gh-cli] [--payload <json>] [--payload-file <path>]
    #|
    #|Assembles MoUI CI evidence-table rows. Network/gh fetch stays in the Node shell.
    #|
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut dry_run = false
  let mut no_token = false
  let mut mode = "live"
  let mut payload = ""
  let mut payload_file = ""
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--dry-run" => {
        dry_run = true
        index += 1
      }
      "--no-token" => {
        no_token = true
        index += 1
      }
      "--mode" => {
        if index + 1 >= args.length() {
          return Err("missing value for --mode")
        }
        mode = args[index + 1]
        index += 2
      }
      "--payload" => {
        if index + 1 >= args.length() {
          return Err("missing value for --payload")
        }
        payload = args[index + 1]
        index += 2
      }
      "--payload-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --payload-file")
        }
        payload_file = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok({ dry_run, no_token, mode, payload, payload_file, help })
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(options) => {
      if options.help {
        println(usage())
        return 0
      }
      if options.dry_run || options.no_token {
        let mode = if options.dry_run { "dry-run" } else { "no-token" }
        println(dry_run_template(mode).stringify(indent=2))
        return 0
      }
      let payload_text = if options.payload_file != "" {
        match @tools.read_required_text(options.payload_file, options.payload_file) {
          Ok(text) => text
          Err(message) => {
            println(message)
            return 1
          }
        }
      } else if options.payload != "" {
        options.payload
      } else {
        println(
          "missing --payload or --payload-file for live evidence assembly",
        )
        println(usage())
        return 2
      }
      match parse_run_payload(payload_text) {
        Err(message) => {
          println(message)
          1
        }
        Ok((run, details, payload_mode)) => {
          let mode = if options.mode != "" {
            options.mode
          } else if payload_mode != "" {
            payload_mode
          } else {
            "live"
          }
          println(
            live_report_json(mode, run, details).stringify(indent=2),
          )
          0
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
