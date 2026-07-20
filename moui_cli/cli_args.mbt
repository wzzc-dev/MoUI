///|
fn json_requested(args : Array[String]) -> Bool {
  args.any(arg => arg == "--json" || arg.has_prefix("--json="))
}

///|
fn option_parts(argument : String) -> (String, String?) {
  if argument.has_prefix("--") {
    match argument.split_once("=") {
      Some((name, value)) => (name.to_owned(), Some(value.to_owned()))
      None => (argument, None)
    }
  } else {
    (argument, None)
  }
}

///|
fn option_value(
  args : Array[String],
  index : Int,
  inline : String?,
  name : String,
) -> Result[(String, Int), String] {
  match inline {
    Some("") => Err("missing value for " + name)
    Some(value) => Ok((value, index + 1))
    None if index + 1 >= args.length() => Err("missing value for " + name)
    None => Ok((args[index + 1], index + 2))
  }
}

///|
fn flag_without_value(inline : String?, name : String) -> Result[Unit, String] {
  match inline {
    Some(_) => Err(name + " does not take a value")
    None => Ok(())
  }
}

///|
/// Collect values for a `--flag value` or `--flag=value` option that may be
/// repeated. Returns the collected values and the remaining args.
fn parse_string_list(
  args : Array[String],
  flag_name : String,
) -> (Array[String], Array[String]) {
  let values : Array[String] = []
  let rest : Array[String] = []
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    if arg == flag_name {
      if i.val + 1 < args.length() {
        values.push(args[i.val + 1])
        i.val += 2
      } else {
        i.val += 1
      }
    } else if arg.has_prefix(flag_name + "=") {
      match arg.split_once("=") {
        Some((_flag, val)) => values.push(val.to_owned())
        None => rest.push(arg)
      }
      i.val += 1
    } else {
      rest.push(arg)
      i.val += 1
    }
  }
  (values, rest)
}

///|
/// Take a single value for a `--flag value` or `--flag=value` option. The last
/// occurrence wins. Returns the parsed value (if any) and the remaining args.
fn parse_string_option(
  args : Array[String],
  flag_name : String,
) -> (String?, Array[String]) {
  let value : Ref[String?] = Ref(None)
  let rest : Array[String] = []
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    if arg == flag_name {
      if i.val + 1 < args.length() {
        value.val = Some(args[i.val + 1])
        i.val += 2
      } else {
        i.val += 1
      }
    } else if arg.has_prefix(flag_name + "=") {
      match arg.split_once("=") {
        Some((_flag, val)) => value.val = Some(val.to_owned())
        None => rest.push(arg)
      }
      i.val += 1
    } else {
      rest.push(arg)
      i.val += 1
    }
  }
  (value.val, rest)
}
