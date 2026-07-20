// `moui config` command — XDG-backed CLI configuration get/set/list/show-path/edit.
// All values are stored as JSON at `config_path(host)`. Reads gracefully
// degrade to `default_cli_config()` when the file is missing.

///|
priv struct ParsedConfig {
  help : Bool
  json : Bool
  action : String
  key : String?
  value : String?
}

///|
fn config_usage() -> String {
  (
    #|Usage: moui config <action> [args]
    #|
    #|Actions:
    #|  get <key>            Print the value of <section>.<field>.
    #|  set <key> <value>    Set <section>.<field> to <value> and persist.
    #|  list                 Print all non-empty config values.
    #|  show-path            Print the config file path.
    #|  edit                 Print the path to edit manually.
    #|
    #|Sections: harmonyos, android, ios, paths.
    #|Run `moui config list` after `read_config` to see all known fields.
    #|
    #|Options:
    #|  --json               Emit machine-readable output.
    #|  -h, --help           Show this help.
  )
}

///|
fn parse_config_args(args : Array[String]) -> Result[ParsedConfig, String] {
  let help = Ref(false)
  let json = Ref(false)
  let positional : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--json" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        json.val = true
        index += 1
      }
      "-h" | "--help" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        help.val = true
        index += 1
      }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui config: " + name)
      _ => {
        positional.push(argument)
        index += 1
      }
    }
  }
  if help.val {
    return Ok({ help: true, json: json.val, action: "", key: None, value: None })
  }
  if positional.is_empty() {
    return Err("moui config requires an action")
  }
  let action = positional[0]
  match action {
    "get" => {
      if positional.length() != 2 {
        return Err("usage: moui config get <key>")
      }
      Ok({
        help: false,
        json: json.val,
        action,
        key: Some(positional[1]),
        value: None,
      })
    }
    "set" => {
      if positional.length() != 3 {
        return Err("usage: moui config set <key> <value>")
      }
      Ok({
        help: false,
        json: json.val,
        action,
        key: Some(positional[1]),
        value: Some(positional[2]),
      })
    }
    "list" | "show-path" | "edit" =>
      if positional.length() == 1 {
        Ok({ help: false, json: json.val, action, key: None, value: None })
      } else {
        Err(action + " does not take arguments")
      }
    _ => Err("unknown moui config action: " + action)
  }
}

///|
fn run_config(parsed : ParsedConfig, host : HostPlatform) -> CliOutcome {
  if parsed.help {
    return stdout_outcome(config_usage())
  }
  match parsed.action {
    "show-path" => {
      let path = config_path(host)
      if parsed.json {
        let value : Json = {
          "schemaVersion": 1,
          "ok": true,
          "path": Json::string(path),
        }
        stdout_outcome(value.stringify(indent=2) + "\n")
      } else {
        stdout_outcome(path + "\n")
      }
    }
    "edit" => {
      let path = config_path(host)
      let message = "edit manually: " + path + "\n"
      if parsed.json {
        let value : Json = {
          "schemaVersion": 1,
          "ok": true,
          "path": Json::string(path),
        }
        stdout_outcome(value.stringify(indent=2) + "\n")
      } else {
        stdout_outcome(message)
      }
    }
    "list" =>
      match read_config(host) {
        Err(message) => failed_outcome(message, parsed.json, config_usage())
        Ok(config) => {
          let lines = config_list_lines(config)
          if parsed.json {
            let entries : Array[Json] = []
            for line in lines {
              match line.split_once(" = ") {
                Some((entry_key, entry_value)) =>
                  entries.push({
                    "key": Json::string(entry_key.to_string()),
                    "value": Json::string(entry_value.to_string()),
                  })
                None => ()
              }
            }
            let root : Json = {
              "schemaVersion": 1,
              "ok": true,
              "entries": Json::array(entries),
            }
            stdout_outcome(root.stringify(indent=2) + "\n")
          } else if lines.is_empty() {
            stdout_outcome("(no config values set)\n")
          } else {
            stdout_outcome(lines.join("\n") + "\n")
          }
        }
      }
    "get" =>
      match parsed.key {
        None => failed_outcome("missing key", parsed.json, config_usage())
        Some(key) =>
          match read_config(host) {
            Err(message) => failed_outcome(message, parsed.json, config_usage())
            Ok(config) =>
              match config_get(config, key) {
                Ok(value) =>
                  if parsed.json {
                    let root : Json = {
                      "schemaVersion": 1,
                      "ok": true,
                      "key": Json::string(key),
                      "value": Json::string(value),
                    }
                    stdout_outcome(root.stringify(indent=2) + "\n")
                  } else {
                    stdout_outcome(value + "\n")
                  }
                Err(message) =>
                  failed_outcome(message, parsed.json, config_usage())
              }
          }
      }
    "set" =>
      match (parsed.key, parsed.value) {
        (None, _) | (_, None) =>
          failed_outcome("missing key or value", parsed.json, config_usage())
        (Some(key), Some(value)) =>
          match read_config(host) {
            Err(message) => failed_outcome(message, parsed.json, config_usage())
            Ok(config) =>
              match config_set(config, key, value) {
                Ok(updated) =>
                  match write_config(updated, host) {
                    Ok(_) =>
                      if parsed.json {
                        let root : Json = {
                          "schemaVersion": 1,
                          "ok": true,
                          "key": Json::string(key),
                          "value": Json::string(value),
                        }
                        stdout_outcome(root.stringify(indent=2) + "\n")
                      } else {
                        stdout_outcome(key + " = " + value + "\n")
                      }
                    Err(message) =>
                      failed_outcome(message, parsed.json, config_usage())
                  }
                Err(message) =>
                  failed_outcome(message, parsed.json, config_usage())
              }
          }
      }
    _ => failed_outcome("unknown action", parsed.json, config_usage())
  }
}
