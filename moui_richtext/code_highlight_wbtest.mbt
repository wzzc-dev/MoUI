///|
test "code highlight supports common languages and ignores unknown aliases" {
  assert_true(code_highlight_supports_language("python"))
  assert_true(code_highlight_supports_language("PYTHON"))
  assert_true(code_highlight_supports_language("ts"))
  assert_true(code_highlight_supports_language("yaml"))
  assert_true(code_highlight_supports_language("dockerfile"))
  assert_false(code_highlight_supports_language("perl"))
}

///|
test "code highlight tokenizes Python with keyword comment and plain spans" {
  let spans = code_highlight_tokenize(
    "# config.py\ndef add(a, b):\n    return a + b\n", "python",
  )
  let comment_spans = spans.filter(span => {
    highlight_kind_name(span.kind) == "CodeComment"
  })
  let keyword_spans = spans.filter(span => {
    highlight_kind_name(span.kind) == "CodeKeyword"
  })
  assert_true(comment_spans.any(span => span.text == "# config.py"))
  assert_true(keyword_spans.any(span => span.text == "def"))
  assert_true(
    spans.any(span => {
      span.text == "add" && highlight_kind_name(span.kind) == "CodeFunction"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "a" && highlight_kind_name(span.kind) == "CodePlain"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "b" && highlight_kind_name(span.kind) == "CodePlain"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "+" && highlight_kind_name(span.kind) == "CodeOperator"
    }),
  )
}

///|
test "code highlight tokenizes TypeScript with keywords and numbers" {
  let spans = code_highlight_tokenize(
    "const n = 3.14;\nexport async function load() { return 1; }\n", "typescript",
  )
  let keyword_spans = spans.filter(span => {
    highlight_kind_name(span.kind) == "CodeKeyword"
  })
  let keyword_texts = keyword_spans.map(span => span.text)
  assert_true(keyword_texts.contains("const"))
  assert_true(keyword_texts.contains("async"))
  assert_true(keyword_texts.contains("function"))
  assert_true(keyword_texts.contains("return"))
  assert_true(keyword_texts.contains("export"))
  assert_true(keyword_texts.contains("interface") == false)
  assert_true(keyword_texts.contains("readonly") == false)
  assert_true(
    spans.any(span => {
      span.text == "3.14" && highlight_kind_name(span.kind) == "CodeNumber"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "load" && highlight_kind_name(span.kind) == "CodeFunction"
    }),
  )
}

///|
test "code highlight tokenizes YAML with line comments and plain keys" {
  let spans = code_highlight_tokenize(
    "# deployment\nservice:\n  image: nginx:1.25\n  replicas: 3\n", "yaml",
  )
  let comment_spans = spans.filter(span => {
    highlight_kind_name(span.kind) == "CodeComment"
  })
  assert_true(comment_spans.any(span => span.text == "# deployment"))
  assert_true(
    spans.any(span => {
      span.text.contains("service") &&
      highlight_kind_name(span.kind) == "CodePlain"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "3" && highlight_kind_name(span.kind) == "CodeNumber"
    }),
  )
}

///|
test "code highlight tokenizes Rust with keywords and plain type literals" {
  let spans = code_highlight_tokenize(
    "fn main() { let mut count = 10; }\n", "rust",
  )
  let keyword_spans = spans.filter(span => {
    highlight_kind_name(span.kind) == "CodeKeyword"
  })
  let keyword_texts = keyword_spans.map(span => span.text)
  let plain_spans = spans.filter(span => {
    highlight_kind_name(span.kind) == "CodePlain"
  })
  let plain_texts = plain_spans.map(span => span.text)
  assert_true(keyword_texts.contains("fn"))
  assert_true(keyword_texts.contains("let"))
  assert_true(keyword_texts.contains("mut"))
  assert_true(
    spans.any(span => {
      span.text == "main" && highlight_kind_name(span.kind) == "CodeFunction"
    }),
  )
  assert_true(plain_texts.contains("count"))
}

///|
//|
test "code highlight detects function call tokens" {
  let spans = code_highlight_tokenize(
    "fn run() { println(\"hello\"); }\n", "rust",
  )
  assert_true(
    spans.any(span => {
      span.text == "println" && highlight_kind_name(span.kind) == "CodeFunction"
    }),
  )
}

//|

///|
test "code highlight detects operator tokens" {
  let spans = code_highlight_tokenize(
    "let x = a + b * c;\nreturn x == 1;\n", "typescript",
  )
  let operator_texts = spans
    .filter(span => highlight_kind_name(span.kind) == "CodeOperator")
    .map(span => span.text)
  assert_true(operator_texts.contains("="))
  assert_true(operator_texts.contains("+"))
  assert_true(operator_texts.contains("*"))
  assert_true(operator_texts.contains("=="))
}

//|

///|
test "code highlight detects arrow function operator" {
  let spans = code_highlight_tokenize("items.map(x => x + 1)\n", "typescript")
  assert_true(
    spans.any(span => {
      span.text == "=>" && highlight_kind_name(span.kind) == "CodeOperator"
    }),
  )
}

//|

///|
test "code highlight detects PascalCase type tokens" {
  let spans = code_highlight_tokenize(
    "class UserService extends BaseRepository {\n}\n", "typescript",
  )
  assert_true(
    spans.any(span => {
      span.text == "UserService" && highlight_kind_name(span.kind) == "CodeType"
    }),
  )
}

//|

///|
test "code highlight detects common type names" {
  let spans = code_highlight_tokenize(
    "let name: String = \"foo\"\nlet count: Int = 5\n", "swift",
  )
  assert_true(
    spans.any(span => {
      span.text == "String" && highlight_kind_name(span.kind) == "CodeType"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "Int" && highlight_kind_name(span.kind) == "CodeType"
    }),
  )
}

//|

///|
test "code highlight detects annotation tokens" {
  let spans = code_highlight_tokenize(
    "#[derive(Eq)]\n@override\nfn run() {}\n", "rust",
  )
  assert_true(
    spans.any(span => {
      span.text == "#[derive(Eq)]" &&
      highlight_kind_name(span.kind) == "CodeAnnotation"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "@override" &&
      highlight_kind_name(span.kind) == "CodeAnnotation"
    }),
  )
}

//|

///|
test "code highlight detects escape sequences in strings" {
  let spans = code_highlight_tokenize(
    "let msg = \"hello\\nworld\\ttab\"\n", "typescript",
  )
  assert_true(
    spans.any(span => {
      span.text == "\\n" && highlight_kind_name(span.kind) == "CodeEscape"
    }),
  )
  assert_true(
    spans.any(span => {
      span.text == "\\t" && highlight_kind_name(span.kind) == "CodeEscape"
    }),
  )
  // The literal parts should still be CodeString
  assert_true(
    spans.any(span => {
      span.text.contains("hello") &&
      highlight_kind_name(span.kind) == "CodeString"
    }),
  )
}

///|
test "code highlight falls back to a single plain span for unsupported snippets" {
  let spans = code_highlight_tokenize("let x = 1", "perl")
  assert_eq(spans.length(), 1)
  assert_eq(highlight_kind_name(spans[0].kind), "CodePlain")
}

///|
fn highlight_kind_name(kind : CodeHighlightToken) -> String {
  match kind {
    CodePlain => "CodePlain"
    CodeKeyword => "CodeKeyword"
    CodeString => "CodeString"
    CodeComment => "CodeComment"
    CodeNumber => "CodeNumber"
    CodeFunction => "CodeFunction"
    CodeType => "CodeType"
    CodeOperator => "CodeOperator"
    CodeAnnotation => "CodeAnnotation"
    CodeEscape => "CodeEscape"
  }
}
