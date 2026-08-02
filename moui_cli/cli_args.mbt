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
