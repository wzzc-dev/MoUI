///|
struct CliOptions {
  input : String
  output : String
  helper_name : String
  test_name : String
  actual_kind : String
  check : Bool
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/generate_grapheme_break_fixtures [--input <GraphemeBreakTest-style.txt>] [--output <test.mbt>] [--helper-name <identifier>] [--test-name <name>] [--actual-kind <core-boundaries|core-editing|core-layout|skia-clusters>] [--check]
    #|
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut input = "moui/core/unicode/testdata/grapheme_break_samples.txt"
  let mut output = "moui/core/unicode/grapheme_break_fixtures_wbtest.mbt"
  let mut helper_name = "assert_generated_grapheme_break_fixture"
  let mut test_name = "generated grapheme break fixture samples"
  let mut actual_kind = "core-boundaries"
  let mut check = false
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--input" => {
        if index + 1 >= args.length() {
          return Err("missing value for --input")
        }
        input = args[index + 1]
        index += 2
      }
      "--output" => {
        if index + 1 >= args.length() {
          return Err("missing value for --output")
        }
        output = args[index + 1]
        index += 2
      }
      "--helper-name" => {
        if index + 1 >= args.length() {
          return Err("missing value for --helper-name")
        }
        helper_name = args[index + 1]
        index += 2
      }
      "--test-name" => {
        if index + 1 >= args.length() {
          return Err("missing value for --test-name")
        }
        test_name = args[index + 1]
        index += 2
      }
      "--actual-kind" => {
        if index + 1 >= args.length() {
          return Err("missing value for --actual-kind")
        }
        actual_kind = args[index + 1]
        index += 2
      }
      "--check" => {
        check = true
        index += 1
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok(
    {
      input,
      output,
      helper_name,
      test_name,
      actual_kind,
      check,
      help,
    },
  )
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
      if options.input == "" ||
        options.output == "" ||
        options.helper_name == "" ||
        options.test_name == "" {
        println(usage())
        return 2
      }
      if !valid_helper_name(options.helper_name) {
        println("invalid MoonBit helper name '" + options.helper_name + "'")
        return 1
      }
      let text = match
        @tools.read_required_text(options.input, options.input) {
        Ok(value) => value
        Err(message) => {
          println(message)
          return 1
        }
      }
      let samples = match parse_fixture_text(text, options.input) {
        Ok(value) => value
        Err(message) => {
          println(message)
          return 1
        }
      }
      let generated = match generate_fixture(
        options.actual_kind,
        options.input,
        options.helper_name,
        options.test_name,
        samples,
      ) {
        Ok(value) => value
        Err(message) => {
          println(message)
          return 1
        }
      }
      if options.check {
        match @tools.read_required_text(options.output, options.output) {
          Ok(current) =>
            if current != generated {
              println(
                options.output +
                ": generated grapheme break fixture test is out of date",
              )
              1
            } else {
              println(options.output + ": ok")
              0
            }
          Err(message) => {
            println(options.output + ": " + message)
            1
          }
        }
      } else {
        match @tools.write_text_file(options.output, generated, options.output) {
          Ok(_) => {
            println("wrote " + options.output)
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
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
