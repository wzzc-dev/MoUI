///|
pub(all) struct CodeEditorToken {
  text : String
  kind : String
}

///|
pub(all) struct CodeCompletionItem {
  label : String
  insert_text : String
  detail : String
}

///|
pub fn CodeCompletionItem::new(
  label~ : String,
  insert_text~ : String,
  detail? : String = "",
) -> CodeCompletionItem {
  { label, insert_text, detail }
}

///|
pub(all) struct CodeHover {
  symbol : String
  detail : String
}

///|
pub fn CodeHover::new(symbol~ : String, detail~ : String) -> CodeHover {
  { symbol, detail }
}

///|
pub(all) struct CodeDefinition {
  symbol : String
  file : String
  line : Int
  column : Int
}

///|
pub fn CodeDefinition::new(
  symbol~ : String,
  file~ : String,
  line~ : Int,
  column~ : Int,
) -> CodeDefinition {
  { symbol, file, line, column }
}

///|
pub(all) struct CodeDiagnostic {
  range : @text.TextRange
  severity : CodeDiagnosticSeverity
  message : String
}

///|
pub(all) enum CodeDiagnosticSeverity {
  Info
  Warning
  Error
}

///|
pub fn CodeDiagnosticSeverity::label(self : CodeDiagnosticSeverity) -> String {
  match self {
    Info => "Info"
    Warning => "Warning"
    Error => "Error"
  }
}

///|
pub struct CodeLanguageProvider {
  id : String
  label : String
  tokenizer : (String) -> Array[CodeEditorToken]
  completion_provider : (String, Int) -> Array[CodeCompletionItem]
  hover_provider : (String, Int) -> CodeHover?
  definition_provider : (String, Int) -> CodeDefinition?
  diagnostic_provider : (String) -> Array[CodeDiagnostic]
}

///|
pub fn CodeLanguageProvider::new(
  id~ : String,
  label~ : String,
  tokenizer~ : (String) -> Array[CodeEditorToken],
  completion_provider~ : (String, Int) -> Array[CodeCompletionItem],
  hover_provider~ : (String, Int) -> CodeHover?,
  definition_provider~ : (String, Int) -> CodeDefinition?,
  diagnostic_provider? : (String) -> Array[CodeDiagnostic] = no_code_diagnostics,
) -> CodeLanguageProvider {
  {
    id,
    label,
    tokenizer,
    completion_provider,
    hover_provider,
    definition_provider,
    diagnostic_provider,
  }
}

///|
fn no_code_diagnostics(_source : String) -> Array[CodeDiagnostic] {
  []
}

///|
pub struct CodeLanguageRegistry {
  providers : Array[CodeLanguageProvider]
}

///|
pub fn CodeLanguageRegistry::new() -> CodeLanguageRegistry {
  { providers: [moonbit_provider(), moui_script_provider()] }
}

///|
pub fn CodeLanguageRegistry::register_language(
  self : CodeLanguageRegistry,
  provider : CodeLanguageProvider,
) -> CodeLanguageRegistry {
  let providers : Array[CodeLanguageProvider] = []
  for existing in self.providers {
    if existing.id != provider.id {
      providers.push(existing)
    }
  }
  providers.push(provider)
  { providers, }
}

///|
pub fn CodeLanguageRegistry::tokenize(
  self : CodeLanguageRegistry,
  language_id : String,
  source : String,
) -> Array[CodeEditorToken] {
  match self.find_provider(language_id) {
    Some(provider) => (provider.tokenizer)(source)
    None =>
      richtext_tokens_to_code_tokens(
        @moui_richtext.code_highlight_tokenize(source, language_id),
      )
  }
}

///|
pub fn CodeLanguageRegistry::completions(
  self : CodeLanguageRegistry,
  language_id : String,
  source : String,
  offset : Int,
) -> Array[CodeCompletionItem] {
  match self.find_provider(language_id) {
    Some(provider) => (provider.completion_provider)(source, offset)
    None => []
  }
}

///|
pub fn CodeLanguageRegistry::hover(
  self : CodeLanguageRegistry,
  language_id : String,
  source : String,
  offset : Int,
) -> CodeHover? {
  match self.find_provider(language_id) {
    Some(provider) => (provider.hover_provider)(source, offset)
    None => None
  }
}

///|
pub fn CodeLanguageRegistry::definition(
  self : CodeLanguageRegistry,
  language_id : String,
  source : String,
  offset : Int,
) -> CodeDefinition? {
  match self.find_provider(language_id) {
    Some(provider) => (provider.definition_provider)(source, offset)
    None => None
  }
}

///|
pub fn CodeLanguageRegistry::diagnostics(
  self : CodeLanguageRegistry,
  language_id : String,
  source : String,
) -> Array[CodeDiagnostic] {
  match self.find_provider(language_id) {
    Some(provider) => (provider.diagnostic_provider)(source)
    None => []
  }
}

///|
fn CodeLanguageRegistry::find_provider(
  self : CodeLanguageRegistry,
  language_id : String,
) -> CodeLanguageProvider? {
  for provider in self.providers {
    if provider.id == language_id {
      return Some(provider)
    }
  }
  None
}

///|
fn richtext_tokens_to_code_tokens(
  spans : Array[@moui_richtext.CodeHighlightSpan],
) -> Array[CodeEditorToken] {
  spans.map(span => { text: span.text, kind: code_highlight_kind(span.kind) })
}

///|
fn code_highlight_kind(kind : @moui_richtext.CodeHighlightToken) -> String {
  match kind {
    CodePlain => "plain"
    CodeKeyword => "keyword"
    CodeString => "string"
    CodeComment => "comment"
    CodeNumber => "number"
    CodeFunction => "function"
    CodeType => "type"
    CodeOperator => "operator"
    CodeAnnotation => "annotation"
    CodeEscape => "escape"
  }
}

///|
fn moonbit_provider() -> CodeLanguageProvider {
  CodeLanguageProvider::new(
    id="moonbit",
    label="MoonBit",
    tokenizer=source => {
      richtext_tokens_to_code_tokens(
        @moui_richtext.code_highlight_tokenize(source, "moonbit"),
      )
    },
    completion_provider=(source, offset) => {
      let prefix = word_prefix_at(source, offset).to_lower()
      [
        CodeCompletionItem::new(
          label="println",
          insert_text="println()",
          detail="Print a value to the console.",
        ),
        CodeCompletionItem::new(
          label="fn",
          insert_text="fn name {\n  \n}",
          detail="Function declaration snippet.",
        ),
        CodeCompletionItem::new(
          label="let",
          insert_text="let value = ",
          detail="Immutable binding.",
        ),
      ].filter(item => prefix == "" || item.label.contains(prefix))
    },
    hover_provider=(source, offset) => {
      match word_at(source, offset) {
        "print" | "println" =>
          Some(
            CodeHover::new(
              symbol="print",
              detail="Print / println writes diagnostic output.",
            ),
          )
        "fn" => Some(CodeHover::new(symbol="fn", detail="Declare a function."))
        "let" =>
          Some(CodeHover::new(symbol="let", detail="Bind a local value."))
        _ => None
      }
    },
    definition_provider=(source, offset) => {
      match word_at(source, offset) {
        "print" | "println" =>
          Some(
            CodeDefinition::new(
              symbol="print",
              file="moonbitlang/core/builtin.mbt",
              line=1,
              column=1,
            ),
          )
        "main" =>
          Some(
            CodeDefinition::new(symbol="main", file="app.mbt", line=1, column=4),
          )
        _ => None
      }
    },
    diagnostic_provider=code_diagnostics,
  )
}

///|
fn moui_script_provider() -> CodeLanguageProvider {
  CodeLanguageProvider::new(
    id="moui-script",
    label="MoUI Script",
    tokenizer=source => {
      custom_keyword_tokenizer(source, [
        "component", "state", "view", "on", "emit", "theme",
      ])
    },
    completion_provider=(source, offset) => {
      let prefix = word_prefix_at(source, offset)
      [
        CodeCompletionItem::new(
          label="component",
          insert_text="component ",
          detail="Register a UI component.",
        ),
        CodeCompletionItem::new(
          label="state",
          insert_text="state ",
          detail="Declare component state.",
        ),
        CodeCompletionItem::new(
          label="emit",
          insert_text="emit ",
          detail="Dispatch a UI event.",
        ),
      ].filter(item => prefix == "" || item.label.contains(prefix))
    },
    hover_provider=(source, offset) => {
      match word_at(source, offset) {
        "component" =>
          Some(
            CodeHover::new(
              symbol="component",
              detail="Defines a native MoUI component in the custom language.",
            ),
          )
        "state" =>
          Some(
            CodeHover::new(
              symbol="state",
              detail="Declares mutable component state.",
            ),
          )
        _ => None
      }
    },
    definition_provider=(source, offset) => {
      match word_at(source, offset) {
        "component" =>
          Some(
            CodeDefinition::new(
              symbol="component",
              file="moui-script.lang",
              line=1,
              column=1,
            ),
          )
        _ => None
      }
    },
  )
}

///|
fn custom_keyword_tokenizer(
  source : String,
  keywords : Array[String],
) -> Array[CodeEditorToken] {
  let tokens : Array[CodeEditorToken] = []
  let chars = source.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if is_word_char(ch) {
      let start = i
      while i < chars.length() && is_word_char(chars[i]) {
        i = i + 1
      }
      let text = String::from_array(chars[start:i])
      tokens.push({
        text,
        kind: if keywords.contains(text) {
          "keyword"
        } else {
          "plain"
        },
      })
    } else {
      tokens.push({ text: String::from_array([ch]), kind: "plain" })
      i = i + 1
    }
  }
  merge_adjacent_tokens(tokens)
}

///|
fn merge_adjacent_tokens(
  tokens : Array[CodeEditorToken],
) -> Array[CodeEditorToken] {
  let merged : Array[CodeEditorToken] = []
  for token in tokens {
    if merged.length() > 0 && merged[merged.length() - 1].kind == token.kind {
      let last = merged[merged.length() - 1]
      merged[merged.length() - 1] = {
        text: last.text + token.text,
        kind: last.kind,
      }
    } else {
      merged.push(token)
    }
  }
  merged
}

///|
fn word_at(source : String, offset : Int) -> String {
  let chars = source.to_array()
  if chars.is_empty() {
    return ""
  }
  let index = clamp_int(offset, 0, chars.length() - 1)
  let anchor = if is_word_char(chars[index]) {
    index
  } else if index > 0 && is_word_char(chars[index - 1]) {
    index - 1
  } else {
    return ""
  }
  let mut start = anchor
  while start > 0 && is_word_char(chars[start - 1]) {
    start = start - 1
  }
  let mut end = anchor + 1
  while end < chars.length() && is_word_char(chars[end]) {
    end = end + 1
  }
  String::from_array(chars[start:end])
}

///|
fn word_prefix_at(source : String, offset : Int) -> String {
  let chars = source.to_array()
  let end = clamp_int(offset, 0, chars.length())
  let mut start = end
  while start > 0 && is_word_char(chars[start - 1]) {
    start = start - 1
  }
  String::from_array(chars[start:end])
}

///|
fn is_word_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_'
}
