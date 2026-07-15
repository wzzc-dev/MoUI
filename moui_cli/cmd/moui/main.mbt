///|
#borrow(text)
extern "C" fn write_output_native(stream : Int, text : Bytes) -> Unit = "moui_cli_write_output"

///|
fn write_output(stream : Int, text : String) -> Unit {
  let text = if text.has_suffix("\n") { text } else { text + "\n" }
  write_output_native(stream, @utf8.encode(text[:], bom=false) + b"\x00")
}

///|
fn main {
  let raw_args = @env.args()
  let args = if raw_args.is_empty() { [] } else { raw_args[1:].to_owned() }
  let outcome = @cli.run_cli(args, @env.current_dir().unwrap_or("."))
  if outcome.stdout != "" {
    write_output(0, outcome.stdout)
  }
  if outcome.stderr != "" {
    write_output(1, outcome.stderr)
  }
  if outcome.exit_code != 0 {
    @sys.exit(outcome.exit_code)
  }
}
