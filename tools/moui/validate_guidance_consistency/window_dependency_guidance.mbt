///|
fn window_dependency_token_delimiter(char : UInt16) -> Bool {
  char == ' ' ||
  char == '\n' ||
  char == '\r' ||
  char == '\t' ||
  char == '"' ||
  char == '`' ||
  char == ',' ||
  char == ')' ||
  char == ']' ||
  char == ';'
}

///|
fn window_dependency_tokens(text : String) -> Array[String] {
  let marker = "wzzc-dev/window@"
  let tokens : Array[String] = []
  let mut start = 0
  while start < text.length() {
    match text[start:].find(marker) {
      Some(offset) => {
        let token_start = start + offset
        let mut token_end = token_start
        while token_end < text.length() &&
              !window_dependency_token_delimiter(text[token_end]) {
          token_end += 1
        }
        tokens.push(text[token_start:token_end].to_owned())
        start = token_end
      }
      None => break
    }
  }
  tokens
}

///|
fn current_window_dependency_token(
  repo_root : String,
) -> Result[String, String] {
  match read_repo_text(repo_root, "moui/moon.mod") {
    Ok(text) => {
      let tokens = unique_values(window_dependency_tokens(text))
      match tokens.length() {
        0 => Err("moui/moon.mod: expected wzzc-dev/window dependency token")
        1 => Ok(tokens[0])
        _ =>
          Err(
            "moui/moon.mod: expected one wzzc-dev/window dependency token, got " +
            @tools.comma_join(tokens),
          )
      }
    }
    Err(message) => Err(message)
  }
}

///|
fn window_dependency_guidance_failures(
  path : String,
  current_token : String,
  text : String,
) -> Array[String] {
  let failures : Array[String] = []
  let tokens = unique_values(window_dependency_tokens(text))
  if tokens.is_empty() {
    failures.push(path + ": expected to mention " + current_token)
    return failures
  }
  if !tokens.contains(current_token) {
    failures.push(path + ": expected to mention " + current_token)
  }
  for token in tokens {
    if token != current_token {
      failures.push(
        path +
        ": window dependency token '" +
        token +
        "' should be '" +
        current_token +
        "'",
      )
    }
  }
  failures
}

///|
fn push_window_dependency_guidance_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  match current_window_dependency_token(repo_root) {
    Ok(current_token) =>
      for path in guidance_window_dependency_paths() {
        match read_repo_text(repo_root, path) {
          Ok(text) =>
            for
              failure in window_dependency_guidance_failures(
                path, current_token, text,
              ) {
              failures.push(failure)
            }
          Err(message) => failures.push(message)
        }
      }
    Err(message) => failures.push(message)
  }
}
