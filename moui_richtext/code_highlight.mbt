///|
/// A minimal syntax-highlight tokenizer for fenced code blocks. It classifies
/// runs into four token kinds — keywords, strings, comments and numbers — and
/// maps each to a color. Coverage is intentionally small (MoonBit, JavaScript,
/// Markdown, JSON) so unknown languages fall back to a single plain run; the
/// goal is visual differentiation close to Typora's default, not a full grammar.
///
/// The tokenizer is line-oriented and stateless between lines except for
/// block-comment tracking, which keeps it cheap on every reparse.

///|
/// Token kinds produced by the highlighter, each with a stable color.
pub enum CodeHighlightToken {
  CodePlain
  CodeKeyword
  CodeString
  CodeComment
  CodeNumber
} derive(Eq, Debug)

///|
/// A highlighted slice: a piece of source text and the token kind it belongs to.
pub struct CodeHighlightSpan {
  text : String
  kind : CodeHighlightToken
}

///|
/// Resolve a token kind to a display color. Colors are tuned to read well on
/// both light and dark surfaces.
pub fn code_highlight_color(kind : CodeHighlightToken) -> @core.Color {
  match kind {
    // Plain text uses the run's inherited color (caller decides), so signal
    // that with a sentinel that callers translate to None.
    CodePlain => @core.Color::black()
    CodeKeyword =>
      // Indigo.
      @core.Color::rgba(r=0.36, g=0.32, b=0.78, a=1.0)
    CodeString =>
      // Green.
      @core.Color::rgba(r=0.20, g=0.62, b=0.36, a=1.0)
    CodeComment =>
      // Muted grey.
      @core.Color::rgba(r=0.45, g=0.48, b=0.52, a=1.0)
    CodeNumber =>
      // Amber.
      @core.Color::rgba(r=0.78, g=0.52, b=0.18, a=1.0)
  }
}

///|
/// True if the language id has a highlighter. Used to decide whether to apply
/// token coloring or fall back to a single plain run.
pub fn code_highlight_supports_language(language : String) -> Bool {
  let lower = language.to_lower()
  lower == "moonbit" ||
  lower == "moon" ||
  lower == "js" ||
  lower == "javascript" ||
  lower == "markdown" ||
  lower == "md" ||
  lower == "json"
}

///|
/// Tokenize a code source into highlight spans. Adjacent spans of the same kind
/// are merged so the run list stays compact. Returns a single plain span when
/// the language is unsupported or the source is empty.
pub fn code_highlight_tokenize(
  source : String,
  language : String,
) -> Array[CodeHighlightSpan] {
  if source == "" || !code_highlight_supports_language(language) {
    return [{ text: source, kind: CodePlain }]
  }
  let lower = language.to_lower()
  let keywords = code_highlight_keywords(lower)
  let spans : Array[CodeHighlightSpan] = []
  let chars = source.to_array()
  let n = chars.length()
  let mut i = 0
  let mut buffer : Array[Char] = []
  // Flush the accumulated plain buffer as a single plain span.
  let flush_plain = () => {
    if buffer.length() > 0 {
      spans.push({ text: String::from_array(buffer), kind: CodePlain })
      buffer = []
    }
  }
  while i < n {
    let c = chars[i]
    // Line comment: // ... end of line (MoonBit/JS/JSON-free).
    if c == '/' && i + 1 < n && chars[i + 1] == '/' {
      flush_plain()
      let mut j = i
      while j < n && chars[j] != '\n' {
        j = j + 1
      }
      spans.push({ text: String::from_array(chars[i:j]), kind: CodeComment })
      i = j
      continue
    }
    // Hash comment: # ... end of line (Markdown front-matter-ish / shell).
    if c == '#' && (lower == "markdown" || lower == "md") {
      flush_plain()
      let mut j = i
      while j < n && chars[j] != '\n' {
        j = j + 1
      }
      spans.push({ text: String::from_array(chars[i:j]), kind: CodeComment })
      i = j
      continue
    }
    // String literal: " ... " or ' ... ' (no escape-awareness for brevity).
    if c == '"' || c == '\'' {
      flush_plain()
      let quote = c
      let mut j = i + 1
      while j < n && chars[j] != quote {
        // Allow escaped quote inside the string.
        if chars[j] == '\\' && j + 1 < n {
          j = j + 2
        } else {
          j = j + 1
        }
      }
      if j < n {
        j = j + 1
      }
      spans.push({ text: String::from_array(chars[i:j]), kind: CodeString })
      i = j
      continue
    }
    // Number: leading digit, consume digits and a single decimal point.
    if c.is_ascii_digit() {
      flush_plain()
      let mut j = i
      let mut seen_dot = false
      while j < n {
        if chars[j].is_ascii_digit() {
          j = j + 1
        } else if chars[j] == '.' &&
          !seen_dot &&
          j + 1 < n &&
          chars[j + 1].is_ascii_digit() {
          seen_dot = true
          j = j + 1
        } else {
          break
        }
      }
      spans.push({ text: String::from_array(chars[i:j]), kind: CodeNumber })
      i = j
      continue
    }
    // Identifier: letter/underscore, check against keyword set.
    if c.is_ascii_alphabetic() || c == '_' {
      flush_plain()
      let mut j = i
      while j < n {
        let d = chars[j]
        if d.is_ascii_alphabetic() || d.is_ascii_digit() || d == '_' {
          j = j + 1
        } else {
          break
        }
      }
      let word = String::from_array(chars[i:j])
      let kind = if keywords.contains(word) { CodeKeyword } else { CodePlain }
      spans.push({ text: word, kind })
      i = j
      continue
    }
    // Any other character accumulates into the plain buffer.
    buffer.push(c)
    i = i + 1
  }
  flush_plain()
  code_highlight_merge_adjacent(spans)
}

///|
/// Merge consecutive spans of the same kind into one, keeping the run list
/// compact for the rich-text renderer.
fn code_highlight_merge_adjacent(
  spans : Array[CodeHighlightSpan],
) -> Array[CodeHighlightSpan] {
  let merged : Array[CodeHighlightSpan] = []
  for span in spans {
    match merged.length() {
      0 => merged.push(span)
      _ => {
        let last = merged[merged.length() - 1]
        if last.kind == span.kind {
          merged[merged.length() - 1] = {
            text: last.text + span.text,
            kind: last.kind,
          }
        } else {
          merged.push(span)
        }
      }
    }
  }
  merged
}

///|
/// The keyword set for a given language id (already lower-cased).
fn code_highlight_keywords(language : String) -> Array[String] {
  match language {
    "moonbit" | "moon" =>
      [
        "fn", "let", "mut", "pub", "priv", "struct", "enum", "type", "match", "if",
        "else", "for", "while", "return", "break", "continue", "true", "false", "Unit",
        "Bool", "Int", "Double", "String", "Char", "Array", "ignore", "trait", "impl",
        "extern", "derive", "test", "in", "is", "as", "where", "try", "catch", "raise",
      ]
    "js" | "javascript" =>
      [
        "function", "const", "let", "var", "return", "if", "else", "for", "while",
        "do", "break", "continue", "switch", "case", "default", "class", "extends",
        "new", "this", "super", "import", "export", "from", "async", "await", "yield",
        "try", "catch", "finally", "throw", "typeof", "instanceof", "in", "of", "true",
        "false", "null", "undefined", "void",
      ]
    "json" => ["true", "false", "null"]
    "markdown" | "md" => []
    _ => []
  }
}
