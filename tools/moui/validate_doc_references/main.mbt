///|
/// Validate that path references inside repository markdown documentation
/// actually resolve.
///
/// Three reference forms are checked (each against the real filesystem):
///
/// 1. Markdown link targets: `[label](target)` and `[label]: target`.
///    URL schemes (`http:`, `https:`, `mailto:`, `file:`, `data:`) and
///    same-file anchors (`#...`) are skipped. Relative targets resolve
///    against the directory of the referencing file.
///
/// 2. Shell command paths inside fenced code blocks: arguments of
///    `moon` / `node` / `sh` / `bash` / `python3` / `ruby` / `npx` lines
///    that look like repository-relative paths (`scripts/`, `moui/`,
///    `tools/`, `docs/`, `checks/`, `smoke/`, `.github/`, `examples/`,
///    `moui_*/`, `window/`). These resolve against the repository root.
///
/// 3. Inline path tokens in prose or inline code (`` ` ``): tokens with a
///    repository-relative prefix and a file-like shape (contains `/` and a
///    dot extension) are resolved against the repository root.
///
/// Not scanned: `docs/ai-sessions/`, `docs/plans/` and `docs/decisions/`
/// (historical or in-flight documents whose references intentionally
/// describe other points in time), generated `website/` output, and
/// `_build/` artifacts.

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_doc_references [--repo-root PATH]
    #|
    #|Checks that path references in docs/**/*.md and README.md resolve.
    #|
  )
}

///|
/// Repository-relative path prefixes that we treat as file references.
fn looks_like_repo_path(token : String) -> Bool {
  let prefixes = [
    "scripts/", "tools/", "moui/", "moui_skia/", "moui_cli/", "moui_theme/", "moui_webview/",
    "moui_devtools/", "moui_i18n/", "moui_richtext/", "moui_sun/", "moui_agent",
    "examples/", "docs/", "checks/", "smoke/", ".github/", "window/",
  ]
  let mut result = false
  for prefix in prefixes {
    if token.has_prefix(prefix) {
      result = true
      break
    }
  }
  result
}

///|
fn is_url_scheme(target : String) -> Bool {
  target.has_prefix("http://") ||
  target.has_prefix("https://") ||
  target.has_prefix("mailto:") ||
  target.has_prefix("file://") ||
  target.has_prefix("data:")
}

///|
/// Remove a trailing anchor (`#...`) from a link target.
fn strip_anchor(target : String) -> String {
  match target.find("#") {
    Some(index) => target[:index].to_owned()
    None => target
  }
}

///|
fn find_from(text : String, needle : String, start : Int) -> Int? {
  if start >= text.length() {
    return None
  }
  let tail = text[start:].to_owned()
  match tail.find(needle) {
    Some(index) => Some(start + index)
    None => None
  }
}

///|
/// Extract markdown link targets from a line: inline `](target)` and
/// reference-style `[label]: target`. Returns raw targets (before anchor /
/// URL filtering).
fn link_targets(line : String) -> Array[String] {
  let targets : Array[String] = []
  // Inline links: `](` ... `)`.
  let mut index = 0
  while index < line.length() {
    match find_from(line, "](", index) {
      Some(open) =>
        match find_from(line, ")", open + 2) {
          Some(close) => {
            targets.push(line[open + 2:close].to_owned())
            index = close + 1
          }
          None => index = line.length()
        }
      None => index = line.length()
    }
  }
  // Reference-style definitions: `[label]: target` at line start (allow
  // leading whitespace).
  let trimmed = line.trim()
  if trimmed.has_prefix("[") {
    match trimmed.find("]:") {
      Some(close) => {
        let rest = trimmed[close + 2:].to_owned().trim().to_owned()
        if rest.length() > 0 && !rest.has_prefix("#") {
          // The target runs to end of line; strip an optional trailing
          // `"title"` and surrounding `<...>`.
          let target = rest
          let target = if target.has_prefix("<") {
            match target.find(">") {
              Some(end) => target[1:end].to_owned()
              None => target
            }
          } else {
            target
          }
          let target = match target.find(" ") {
            Some(space) => target[:space].to_owned()
            None => target
          }
          targets.push(target)
        }
      }
      None => ()
    }
  }
  targets
}

///|
/// Extract repository-relative path arguments from a shell command line
/// inside a fenced code block.
fn command_paths(line : String) -> Array[String] {
  let paths : Array[String] = []
  let trimmed = line.trim()
  let command = match trimmed.find(" ") {
    Some(space) => trimmed[:space].to_owned()
    None => trimmed.to_owned()
  }
  if command != "moon" &&
    command != "node" &&
    command != "sh" &&
    command != "bash" &&
    command != "python3" &&
    command != "ruby" &&
    command != "npx" &&
    command != "npm" {
    return paths
  }
  for raw_token in trimmed.split(" ") {
    let token = raw_token.to_owned()
    if token.length() == 0 ||
      token.has_prefix("-") ||
      token.has_prefix("$") ||
      token.has_prefix("<") ||
      token.has_prefix("\"") ||
      token.has_prefix("window/") ||
      token.has_prefix("./window/") ||
      token.contains("*") ||
      token.contains("{") {
      continue
    }
    if token.has_prefix("./") && looks_like_repo_path(token[2:].to_owned()) {
      paths.push(token[2:].to_owned())
    } else if looks_like_repo_path(token) {
      paths.push(token)
    }
  }
  paths
}

///|
fn trim_punctuation(token : String) -> String {
  let mut start = 0
  let mut end = token.length()
  while start < end {
    let ch = token[start]
    if ch == '(' ||
      ch == '`' ||
      ch == '[' ||
      ch == '"' ||
      ch == '《' ||
      ch == '（' {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let ch = token[end - 1]
    if ch == ')' ||
      ch == ',' ||
      ch == '.' ||
      ch == ';' ||
      ch == ':' ||
      ch == '`' ||
      ch == ']' ||
      ch == '"' ||
      ch == '。' ||
      ch == '）' ||
      ch == '：' ||
      ch == '、' ||
      ch == '，' ||
      ch == '」' ||
      ch == '》' ||
      ch == '”' {
      end -= 1
    } else {
      break
    }
  }
  token[start:end].to_owned()
}

///|
/// Normalize an inline token into a repo path: strip surrounding
/// punctuation, then cut any line/range suffix (`:27`, `:390-470`,
/// `:27,32`, `#L140`). Tokens with glob characters or braces are not
/// file references and yield `None`.
fn normalize_inline_path(token : String) -> String? {
  let trimmed = token.trim().to_owned()
  if trimmed.contains("*") || trimmed.contains("{") || trimmed.contains("<") {
    return None
  }
  let mut t = trim_punctuation(trimmed)
  // `window/` references point into the window submodule; its internal
  // layout is not gated by this repository.
  if t.has_prefix("window/") {
    return None
  }
  // `smoke/evidence` and `smoke/proof` are generated evidence directories
  // (gitignored); references to them are descriptive.
  if t.has_prefix("smoke/evidence") || t.has_prefix("smoke/proof") {
    return None
  }
  // `tools/call` / `tools/list` are MCP JSON-RPC method names, not paths.
  if t == "tools/call" || t == "tools/list" {
    return None
  }
  // Bare `moui/<name>` package references (no further slash, no dot) are
  // descriptive; they often appear in dependency-boundary prose listing
  // packages that must not exist. Symbol references such as `moui/views.web_view`
  // are kept whole and degrade at check time to the package directory.
  if t.has_prefix("moui/") {
    let rest = t["moui/".length():].to_owned()
    if !rest.contains("/") && !rest.contains(".") {
      return None
    }
  }
  // Cut `#anchor` suffixes (`#L140`).
  match t.find("#") {
    Some(index) => t = t[:index].to_owned()
    None => ()
  }
  // Cut line/range suffixes after the last `/`: `path:390-470`,
  // `path:27,32`, `path:84`.
  match last_slash_index(t) {
    Some(slash) => {
      let after = t[slash + 1:].to_owned()
      match after.find(":") {
        Some(col) => {
          // Only cut when the part after `:` is a line/range shape.
          let tail = after[col + 1:].to_owned()
          let tail = tail.trim()
          let mut line_shape = tail.length() > 0
          for ch in tail {
            if ch != '/' &&
              ch != '-' &&
              ch != ',' &&
              ch != ' ' &&
              (ch < '0' || ch > '9') {
              line_shape = false
              break
            }
          }
          if line_shape {
            t = t[:slash + 1 + col].to_owned()
          }
        }
        None => ()
      }
    }
    None => ()
  }
  // Cut parenthesized annotations: `path（说明）` or `path (note)`.
  match t.find("（") {
    Some(index) => t = t[:index].to_owned()
    None => ()
  }
  match t.find("(") {
    Some(index) => t = t[:index].to_owned()
    None => ()
  }
  if looks_like_repo_path(t) {
    Some(t)
  } else {
    None
  }
}

///|
/// Collect every `.md` file under `root`, skipping `ai-sessions/` and
/// `plans/done/` subtrees. `relative` is the repo-relative path prefix.
fn collect_md_files(
  root : String,
  relative : String,
  out : Array[String],
) -> Unit {
  let entries = @fs.read_dir(root) catch { _ => return }
  for entry in entries {
    if entry == "ai-sessions" || entry == "plans" || entry == "decisions" {
      continue
    }
    let path = @tools.join_path(root, entry)
    let rel = if relative.length() == 0 {
      entry
    } else {
      relative + "/" + entry
    }
    if @tools.directory_exists(path) {
      collect_md_files(path, rel, out)
    } else if entry.has_suffix(".md") {
      out.push(rel)
    }
  }
}

///|
/// One failed reference.
struct RefFailure {
  path : String
  line_no : Int
  reference : String
  detail : String
}

///|
fn last_slash_index(s : String) -> Int? {
  let mut result : Int? = None
  let mut i = 0
  while i < s.length() {
    if s[i] == '/' {
      result = Some(i)
    }
    i += 1
  }
  result
}

///|
fn check_path(
  repo_root : String,
  rel_path : String,
  line_no : Int,
  path : String,
  failures : Array[RefFailure],
) -> Unit {
  if !@tools.file_exists(@tools.resolve_path(repo_root, path)) &&
    !@tools.directory_exists(@tools.resolve_path(repo_root, path)) {
    failures.push({
      path: rel_path,
      line_no,
      reference: path,
      detail: "inline path does not exist",
    })
  }
}

///|
fn path_exists(repo_root : String, path : String) -> Bool {
  @tools.file_exists(@tools.resolve_path(repo_root, path)) ||
  @tools.directory_exists(@tools.resolve_path(repo_root, path))
}

///|
/// Check a path; `moui/<segment.dot>` symbol references degrade to the
/// package directory when the dotted form does not exist.
fn check_inline_path(
  repo_root : String,
  rel_path : String,
  line_no : Int,
  path : String,
  failures : Array[RefFailure],
) -> Unit {
  if path_exists(repo_root, path) {
    return
  }
  if path.has_prefix("moui/") {
    let rest = path["moui/".length():].to_owned()
    if !rest.contains("/") && rest.contains(".") {
      let dot = match rest.find(".") {
        Some(i) => i
        None => 0
      }
      let degraded = "moui/" + rest[:dot].to_owned()
      if path_exists(repo_root, degraded) {
        return
      }
    }
  }
  failures.push({
    path: rel_path,
    line_no,
    reference: path,
    detail: "inline path does not exist",
  })
}

///|
fn check_file(
  repo_root : String,
  rel_path : String,
  failures : Array[RefFailure],
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, rel_path)
  let text = match @tools.read_required_text(absolute, rel_path) {
    Ok(text) => text
    Err(_) => return
  }
  // Directory of the referencing file, for relative link resolution.
  let file_dir = match last_slash_index(rel_path) {
    Some(index) => rel_path[:index].to_owned()
    None => ""
  }
  let mut in_code_block = false
  let mut line_no = 0
  for line_view in text.split("\n") {
    line_no += 1
    let line = line_view.to_owned()
    if line.trim().has_prefix("```") {
      in_code_block = !in_code_block
      continue
    }
    if in_code_block {
      for path in command_paths(line) {
        if !@tools.file_exists(@tools.resolve_path(repo_root, path)) &&
          !@tools.directory_exists(@tools.resolve_path(repo_root, path)) {
          failures.push({
            path: rel_path,
            line_no,
            reference: path,
            detail: "command path does not exist",
          })
        }
      }
    } else {
      for target in link_targets(line) {
        if target.length() == 0 || is_url_scheme(target) {
          continue
        }
        let stripped = strip_anchor(target)
        if stripped.length() == 0 {
          continue
        }
        let resolved = if file_dir.length() > 0 {
          @tools.resolve_path(repo_root, file_dir + "/" + stripped)
        } else {
          @tools.resolve_path(repo_root, stripped)
        }
        if !@tools.file_exists(resolved) && !@tools.directory_exists(resolved) {
          failures.push({
            path: rel_path,
            line_no,
            reference: stripped,
            detail: "link target does not exist",
          })
        }
      }
      // Extract backtick-wrapped inline code segments at line level first
      // (they may contain spaces, e.g. `` `node scripts/foo.mjs` ``), then
      // scan the remaining text token-by-token.
      let mut rest = line
      let code_fragments : Array[String] = []
      while true {
        match rest.find("`") {
          Some(open) =>
            match find_from(rest, "`", open + 1) {
              Some(close) => {
                code_fragments.push(rest[open + 1:close].to_owned())
                rest = rest[:open].to_owned() +
                  " " +
                  rest[close + 1:].to_owned()
              }
              None => break
            }
          None => break
        }
      }
      for fragment in code_fragments {
        // A code fragment may itself be a shell command line; reuse the
        // command-path extraction for those. Otherwise, when it contains a
        // space, take the first space-separated token (a path command such
        // as `scripts/check.sh --profile daily`); else treat it as a path.
        let cmd_paths = command_paths(fragment)
        if cmd_paths.length() > 0 {
          for path in cmd_paths {
            check_path(repo_root, rel_path, line_no, path, failures)
          }
        } else {
          let mut fragment = fragment
          match fragment.find(" ") {
            Some(space) => fragment = fragment[:space].to_owned()
            None => ()
          }
          match normalize_inline_path(fragment) {
            Some(path) =>
              check_inline_path(repo_root, rel_path, line_no, path, failures)
            None => ()
          }
        }
      }
      for raw_token in rest.split(" ") {
        let token = raw_token.to_owned()
        match normalize_inline_path(token) {
          Some(path) =>
            check_inline_path(repo_root, rel_path, line_no, path, failures)
          None => ()
        }
      }
    }
  }
}

///|
fn run(repo_root : String) -> Int {
  let docs_root = @tools.resolve_path(repo_root, "docs")
  let files : Array[String] = []
  collect_md_files(docs_root, "docs", files)
  files.push("README.md")
  files.sort()
  let failures : Array[RefFailure] = []
  for rel in files {
    check_file(repo_root, rel, failures)
  }
  if failures.length() > 0 {
    println("doc references: \{failures.length()} broken reference(s):")
    for failure in failures {
      println(
        "  \{failure.path}:\{failure.line_no}: \{failure.reference} (\{failure.detail})",
      )
    }
    1
  } else {
    println(
      "doc references: \{files.length()} files checked, all references resolve",
    )
    0
  }
}

///|
fn main {
  let args = @tools.args_without_program(@env.args())
  let mut repo_root = "."
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--repo-root" =>
        if i + 1 < args.length() {
          repo_root = args[i + 1]
          i += 2
          continue
        }
      "--help" | "-h" => {
        println(usage())
        return
      }
      _ => ()
    }
    i += 1
  }
  let code = run(repo_root)
  if code != 0 {
    @sys.exit(code)
  }
}
