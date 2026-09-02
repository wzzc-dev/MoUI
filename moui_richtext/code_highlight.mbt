///|
/// A minimal syntax-highlight tokenizer for fenced code blocks. It classifies
/// runs into four token kinds — keywords, strings, comments and numbers — and
/// maps each to a color. Coverage is intentionally small (MoonBit, JavaScript,
/// Markdown, JSON, TypeScript, Python, Rust, Go, C/C++, Bash, YAML, TOML, SQL, PHP, Ruby, Swift, Kotlin, Scala, HTML, CSS, XML, Diff, Makefile, Dockerfile, INI) so unknown languages fall back to a single plain run; the
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
  CodeFunction
  CodeType
  CodeOperator
  CodeAnnotation
  CodeEscape
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
fn code_highlight_color(kind : CodeHighlightToken) -> @core.Color {
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
    CodeFunction =>
      // Blue.
      @core.Color::rgba(r=0.27, g=0.42, b=0.70, a=1.0)
    CodeType =>
      // Teal.
      @core.Color::rgba(r=0.22, g=0.77, b=0.62, a=1.0)
    CodeOperator =>
      // Red.
      @core.Color::rgba(r=0.87, g=0.33, b=0.33, a=1.0)
    CodeAnnotation =>
      // Magenta.
      @core.Color::rgba(r=0.76, g=0.32, b=0.62, a=1.0)
    CodeEscape =>
      // Purple.
      @core.Color::rgba(r=0.67, g=0.29, b=0.91, a=1.0)
  }
}

///|
/// True if the language id has a highlighter. Used to decide whether to apply
/// token coloring or fall back to a single plain run.
fn code_highlight_supports_language(language : String) -> Bool {
  let lower = language.to_lower()
  lower == "moonbit" ||
  lower == "moon" ||
  lower == "python" ||
  lower == "py" ||
  lower == "rust" ||
  lower == "rs" ||
  lower == "go" ||
  lower == "golang" ||
  lower == "typescript" ||
  lower == "ts" ||
  lower == "html" ||
  lower == "css" ||
  lower == "bash" ||
  lower == "sh" ||
  lower == "shell" ||
  lower == "yaml" ||
  lower == "yml" ||
  lower == "c" ||
  lower == "cpp" ||
  lower == "java" ||
  lower == "php" ||
  lower == "ruby" ||
  lower == "rb" ||
  lower == "swift" ||
  lower == "kotlin" ||
  lower == "scala" ||
  lower == "sql" ||
  lower == "xml" ||
  lower == "toml" ||
  lower == "ini" ||
  lower == "diff" ||
  lower == "makefile" ||
  lower == "dockerfile" ||
  lower == "js" ||
  lower == "javascript" ||
  lower == "markdown" ||
  lower == "md" ||
  lower == "json"
}

///|
/// Check if a multi-character or single-char operator starts at index `pos`.
/// Returns Some(length) if found, None otherwise.
fn code_highlight_try_operator(chars : Array[Char], n : Int, pos : Int) -> Int? {
  if pos + 1 < n {
    let two = String::from_array(chars[pos:pos + 2])
    if two == "==" ||
      two == "!=" ||
      two == "<=" ||
      two == ">=" ||
      two == "&&" ||
      two == "||" ||
      two == "++" ||
      two == "--" ||
      two == "->" ||
      two == "=>" ||
      two == "::" ||
      two == ".." ||
      two == "+=" ||
      two == "-=" ||
      two == "*=" ||
      two == "/=" ||
      two == "%=" {
      return Some(2)
    }
  }
  let c = chars[pos]
  if c == '+' ||
    c == '-' ||
    c == '*' ||
    c == '/' ||
    c == '%' ||
    c == '=' ||
    c == '!' ||
    c == '<' ||
    c == '>' ||
    c == '&' ||
    c == '|' ||
    c == '^' ||
    c == '~' ||
    c == ':' ||
    c == '.' ||
    c == '?' {
    return Some(1)
  }
  None
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
    // Annotation: @ prefix or #[ prefix.
    if c == '@' {
      flush_plain()
      let mut j = i
      while j < n &&
            chars[j] != ' ' &&
            chars[j] != '\t' &&
            chars[j] != '\n' &&
            chars[j] != '(' &&
            chars[j] != ')' {
        j = j + 1
      }
      spans.push({ text: String::from_array(chars[i:j]), kind: CodeAnnotation })
      i = j
      continue
    }
    if c == '#' && i + 1 < n && chars[i + 1] == '[' {
      flush_plain()
      let mut j = i
      while j < n && chars[j] != '\n' {
        j = j + 1
      }
      spans.push({ text: String::from_array(chars[i:j]), kind: CodeAnnotation })
      i = j
      continue
    }
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
    // Hash comment: # ... end of line (Markdown front-matter-ish / shell / YAML / Python / Ruby / TOML / Makefile / Dockerfile).
    if c == '#' &&
      (
        lower == "markdown" ||
        lower == "md" ||
        lower == "python" ||
        lower == "py" ||
        lower == "ruby" ||
        lower == "rb" ||
        lower == "bash" ||
        lower == "sh" ||
        lower == "shell" ||
        lower == "yaml" ||
        lower == "yml" ||
        lower == "toml" ||
        lower == "makefile" ||
        lower == "dockerfile"
      ) {
      flush_plain()
      let mut j = i
      while j < n && chars[j] != '\n' {
        j = j + 1
      }
      spans.push({ text: String::from_array(chars[i:j]), kind: CodeComment })
      i = j
      continue
    }
    // String literal: " ... " or ' ... ' with escape highlighting.
    if c == '"' || c == '\'' {
      flush_plain()
      let quote = c
      let mut j = i + 1
      let mut seg_start = i
      while j < n && chars[j] != quote {
        if chars[j] == '\\' && j + 1 < n {
          // Push text before escape as string.
          if j > seg_start {
            spans.push({
              text: String::from_array(chars[seg_start:j]),
              kind: CodeString,
            })
          }
          // Push escape sequence as CodeEscape.
          let esc_end = if j + 2 < n &&
            chars[j + 1] == 'u' &&
            chars[j + 2] == '{' {
            // \u{...} multi-char escape
            let mut k = j + 3
            while k < n &&
                  chars[k] != '}' &&
                  chars[k] != '"' &&
                  chars[k] != '\'' {
              k = k + 1
            }
            if k < n && chars[k] == '}' {
              k + 1
            } else {
              j + 2
            }
          } else {
            j + 2
          }
          spans.push({
            text: String::from_array(chars[j:esc_end]),
            kind: CodeEscape,
          })
          j = esc_end
          seg_start = j
        } else {
          j = j + 1
        }
      }
      if j < n {
        j = j + 1
      }
      if j > seg_start {
        spans.push({
          text: String::from_array(chars[seg_start:j]),
          kind: CodeString,
        })
      }
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
    // Identifier: letter/underscore, check against keyword/function/type.
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
      let kind = if keywords.contains(word) {
        CodeKeyword
      } else {
        // Check if followed by '(' — likely a function call.
        let mut peek = j
        while peek < n && (chars[peek] == ' ' || chars[peek] == '\t') {
          peek = peek + 1
        }
        if peek < n && chars[peek] == '(' {
          CodeFunction
        } else if word.length() > 0 {
          let first = word[0]
          // PascalCase (starts with 'A'-'Z' and not a common keyword) → likely a type name.
          if first >= 65 && first <= 90 {
            CodeType
          } else {
            CodePlain
          }
        } else if code_highlight_common_type(word) {
          CodeType
        } else {
          CodePlain
        }
      }
      spans.push({ text: word, kind })
      i = j
      continue
    }
    // Operator: multi-char or single-char operator symbols.
    if code_highlight_try_operator(chars, n, i) is Some(len) {
      flush_plain()
      spans.push({
        text: String::from_array(chars[i:i + len]),
        kind: CodeOperator,
      })
      i = i + len
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
        if last.kind == span.kind &&
          !code_highlight_span_is_identifier(last) &&
          !code_highlight_span_is_identifier(span) {
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
fn code_highlight_span_is_identifier(span : CodeHighlightSpan) -> Bool {
  if span.kind != CodePlain {
    return false
  }
  let chars = span.text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if !(c.is_ascii_alphabetic() || c == '_') {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Common type names recognized across languages. Matched when a PascalCase
/// check is not sufficient (e.g. all-caps acronyms or single-word types).
fn code_highlight_common_type(word : String) -> Bool {
  word == "String" ||
  word == "Int" ||
  word == "Float" ||
  word == "Double" ||
  word == "Bool" ||
  word == "Boolean" ||
  word == "Char" ||
  word == "Byte" ||
  word == "Short" ||
  word == "Long" ||
  word == "Void" ||
  word == "Unit" ||
  word == "Object" ||
  word == "Array" ||
  word == "List" ||
  word == "Map" ||
  word == "Set" ||
  word == "Vector" ||
  word == "Option" ||
  word == "Result" ||
  word == "Future" ||
  word == "Promise" ||
  word == "Error" ||
  word == "Nullable" ||
  word == "Any" ||
  word == "Never" ||
  word == "number" ||
  word == "string" ||
  word == "boolean" ||
  word == "undefined"
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
    "typescript" | "ts" =>
      [
        "function", "const", "let", "var", "return", "if", "else", "for", "while",
        "do", "break", "continue", "switch", "case", "default", "class", "extends",
        "new", "this", "super", "import", "export", "from", "async", "await", "yield",
        "try", "catch", "finally", "throw", "typeof", "instanceof", "in", "of", "true",
        "false", "null", "undefined", "void", "interface", "type", "as", "readonly",
      ]
    "python" | "py" =>
      [
        "def", "class", "return", "if", "elif", "else", "for", "while", "break",
        "continue", "import", "from", "as", "try", "except", "finally", "raise",
        "with", "yield", "lambda", "pass", "and", "or", "not", "is", "in", "True",
        "False", "None", "self", "async", "await",
      ]
    "rust" | "rs" =>
      [
        "fn", "let", "mut", "pub", "priv", "struct", "enum", "impl", "trait", "match",
        "if", "else", "for", "while", "loop", "return", "break", "continue", "true",
        "false", "mod", "use", "super", "self", "Self", "const", "static", "unsafe",
        "async", "await", "move", "ref", "type", "where", "dyn", "crate",
      ]
    "go" | "golang" =>
      [
        "func", "return", "if", "else", "for", "range", "switch", "case", "default",
        "struct", "type", "var", "const", "import", "package", "defer", "go", "select",
        "chan", "map", "make", "new", "nil", "true", "false", "fallthrough",
      ]
    "c" | "cpp" =>
      [
        "int", "long", "short", "char", "float", "double", "void", "return", "if",
        "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
        "struct", "class", "public", "private", "protected", "new", "delete", "true",
        "false", "nullptr", "const", "static", "typedef", "enum", "namespace", "using",
        "template", "typename", "virtual", "override", "final",
      ]
    "java" =>
      [
        "public", "private", "protected", "static", "final", "class", "interface",
        "extends", "implements", "new", "return", "if", "else", "for", "while", "do",
        "switch", "case", "default", "break", "continue", "throw", "throws", "try",
        "catch", "finally", "import", "package", "true", "false", "null", "this",
        "super", "instanceof", "void", "int", "long", "double", "boolean", "String",
      ]
    "php" =>
      [
        "function", "class", "public", "private", "protected", "static", "return",
        "if", "else", "elseif", "foreach", "for", "while", "do", "switch", "case",
        "default", "break", "continue", "try", "catch", "finally", "throw", "new",
        "echo", "print", "true", "false", "null", "array", "echo", "isset", "unset",
        "namespace", "use", "as", "implements", "extends", "interface", "trait",
      ]
    "ruby" | "rb" =>
      [
        "def", "end", "class", "module", "return", "if", "elsif", "else", "unless",
        "case", "when", "while", "until", "for", "do", "break", "next", "redo", "retry",
        "raise", "rescue", "ensure", "begin", "yield", "self", "true", "false", "nil",
        "require", "include", "extend", "attr_reader", "attr_writer", "attr_accessor",
      ]
    "swift" =>
      [
        "func", "return", "if", "else", "guard", "switch", "case", "default", "for",
        "while", "repeat", "break", "continue", "class", "struct", "enum", "protocol",
        "extension", "import", "true", "false", "nil", "self", "super", "init", "deinit",
        "as", "try", "catch", "throw", "throws", "rethrows", "let", "var",
      ]
    "kotlin" =>
      [
        "fun", "return", "if", "else", "when", "for", "while", "do", "break", "continue",
        "class", "interface", "object", "sealed", "data", "enum", "val", "var", "true",
        "false", "null", "this", "super", "as", "is", "in", "throw", "try", "catch",
        "finally", "import", "package", "companion", "init", "suspend", "lateinit",
      ]
    "scala" =>
      [
        "def", "class", "trait", "object", "extends", "with", "new", "return", "if",
        "else", "for", "while", "do", "break", "continue", "match", "case", "try",
        "catch", "finally", "throw", "import", "package", "true", "false", "null",
        "val", "var", "lazy", "implicit", "sealed", "final", "override", "type",
      ]
    "sql" =>
      [
        "select", "from", "where", "join", "left", "right", "inner", "outer", "on",
        "group", "by", "order", "having", "limit", "offset", "insert", "into", "values",
        "update", "set", "delete", "create", "table", "alter", "drop", "index", "view",
        "as", "case", "when", "then", "else", "end", "and", "or", "not", "null",
        "true", "false", "count", "sum", "avg", "min", "max", "distinct",
      ]
    "html" | "css" | "xml" => []
    "bash" | "sh" | "shell" | "makefile" | "dockerfile" => []
    "yaml" | "yml" | "toml" | "ini" | "diff" => []
    "json" => ["true", "false", "null"]
    "markdown" | "md" => []
    _ => []
  }
}
