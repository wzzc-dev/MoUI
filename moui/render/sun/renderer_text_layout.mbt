///|
priv struct SunTextLine {
  text : String
  width : Double
  start_scalar : Int
  scalar_count : Int
}

///|
priv struct SunTextLinePlan {
  lines : Array[SunTextLine]
  line_height : Double
  baseline : Double
}

///|
priv enum SunTextLayoutToken {
  Text(String, Int)
  LineBreak(Int)
}

///|
fn sun_text_line_plan(
  faces : Array[@sun_text.FontFace],
  text : String,
  config : @sun_text.LayoutConfig,
) -> SunTextLinePlan {
  let lines : Array[SunTextLine] = []
  let line_height = config.line_height.max(1.0)
  let baseline = sun_text_baseline_for_faces(faces, config)
  let tokens = sun_text_layout_tokens(text)
  let mut current_text = ""
  let mut current_width = 0.0
  let mut current_start = 0
  let mut current_scalar_count = 0
  let mut cursor_scalar = 0
  let mut saw_line = false
  for token in tokens {
    match token {
      SunTextLayoutToken::Text(token_text, token_scalar_count) => {
        let token_width = sun_measure_fallback_line_width(
          faces, token_text, config,
        )
        let is_space = token_text is " "
        let needs_break = current_scalar_count > 0 &&
          !is_space &&
          config.max_width > 0.0 &&
          current_width + token_width > config.max_width
        if needs_break {
          sun_text_line_plan_push(
            lines, faces, config, current_text, current_start, current_scalar_count,
          )
          saw_line = true
          current_start = cursor_scalar
          current_text = ""
          current_width = 0.0
          current_scalar_count = 0
        }
        current_text = current_text + token_text
        current_width = current_width + token_width
        current_scalar_count += token_scalar_count
        cursor_scalar += token_scalar_count
      }
      SunTextLayoutToken::LineBreak(line_break_scalar_count) => {
        sun_text_line_plan_push(
          lines, faces, config, current_text, current_start, current_scalar_count,
        )
        saw_line = true
        cursor_scalar += line_break_scalar_count
        current_start = cursor_scalar
        current_text = ""
        current_width = 0.0
        current_scalar_count = 0
      }
    }
  }
  if current_scalar_count > 0 || saw_line || lines.is_empty() {
    sun_text_line_plan_push(
      lines, faces, config, current_text, current_start, current_scalar_count,
    )
  }
  { lines, line_height, baseline }
}

///|
fn sun_text_line_plan_push(
  lines : Array[SunTextLine],
  faces : Array[@sun_text.FontFace],
  config : @sun_text.LayoutConfig,
  text : String,
  start_scalar : Int,
  scalar_count : Int,
) -> Unit {
  lines.push({
    text,
    width: sun_measure_fallback_line_width(faces, text, config),
    start_scalar,
    scalar_count,
  })
}

///|
fn sun_text_layout_tokens(text : String) -> Array[SunTextLayoutToken] {
  let tokens : Array[SunTextLayoutToken] = []
  let chars = text.to_array()
  let current_word : Array[Char] = []
  let mut current_word_class : @sun_text.LineBreakClass? = None
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch is '\n' || ch is '\r' {
      sun_text_layout_tokens_flush_word(tokens, current_word)
      let line_break_scalar_count = if ch is '\r' &&
        index + 1 < chars.length() &&
        chars[index + 1] is '\n' {
        index += 1
        2
      } else {
        1
      }
      tokens.push(SunTextLayoutToken::LineBreak(line_break_scalar_count))
      current_word_class = None
    } else if ch is ' ' || ch is '\t' {
      sun_text_layout_tokens_flush_word(tokens, current_word)
      current_word_class = None
      if ch is ' ' {
        tokens.push(SunTextLayoutToken::Text(" ", 1))
      }
    } else {
      let curr_class = @sun_text.get_line_break_class(ch.to_int())
      match current_word_class {
        Some(prev_class) =>
          if sun_should_split_unspaced_layout_token(prev_class, curr_class) {
            sun_text_layout_tokens_flush_word(tokens, current_word)
            current_word_class = None
          }
        None => ()
      }
      current_word.push(ch)
      current_word_class = Some(curr_class)
    }
    index += 1
  }
  sun_text_layout_tokens_flush_word(tokens, current_word)
  tokens
}

///|
fn sun_text_layout_tokens_flush_word(
  tokens : Array[SunTextLayoutToken],
  current_word : Array[Char],
) -> Unit {
  if current_word.length() > 0 {
    tokens.push(
      SunTextLayoutToken::Text(
        String::from_array(current_word),
        current_word.length(),
      ),
    )
    current_word.clear()
  }
}

///|
fn sun_should_split_unspaced_layout_token(
  prev_class : @sun_text.LineBreakClass,
  curr_class : @sun_text.LineBreakClass,
) -> Bool {
  @sun_text.is_line_break_allowed(prev_class, curr_class) &&
  sun_can_start_unspaced_layout_token(curr_class) &&
  (
    sun_is_unspaced_layout_break_class(prev_class) ||
    sun_is_unspaced_layout_break_class(curr_class)
  )
}

///|
fn sun_can_start_unspaced_layout_token(
  class : @sun_text.LineBreakClass,
) -> Bool {
  match class {
    @sun_text.LineBreakClass::CL => false
    @sun_text.LineBreakClass::CP => false
    @sun_text.LineBreakClass::EX => false
    @sun_text.LineBreakClass::IS => false
    @sun_text.LineBreakClass::SY => false
    @sun_text.LineBreakClass::NS => false
    _ => true
  }
}

///|
fn sun_is_unspaced_layout_break_class(class : @sun_text.LineBreakClass) -> Bool {
  match class {
    @sun_text.LineBreakClass::ID => true
    @sun_text.LineBreakClass::H2 => true
    @sun_text.LineBreakClass::H3 => true
    @sun_text.LineBreakClass::JL => true
    @sun_text.LineBreakClass::JV => true
    @sun_text.LineBreakClass::JT => true
    _ => false
  }
}
