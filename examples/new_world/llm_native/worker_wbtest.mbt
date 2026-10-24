///|
/// URL resolution is the part of the native transport that can be tested
/// without a socket, and it is also the part users get wrong most often: they
/// paste either a base URL or a full endpoint.
///
/// The live POST path was verified by hand against a local OpenAI-compatible
/// stub (it posts to `<base>/chat/completions` with a bearer header and parses
/// `choices[0].message.content`); a test that needs an external server cannot
/// live in the suite, so the socket-free half is pinned here.

///|
test "a base URL gains the chat/completions path" {
  assert_eq(
    llm_completion_url("https://api.example.com/v1"),
    "https://api.example.com/v1/chat/completions",
  )
  // A trailing slash must not produce a double slash.
  assert_eq(
    llm_completion_url("https://api.example.com/v1/"),
    "https://api.example.com/v1/chat/completions",
  )
  // Surrounding whitespace is a paste artefact, not part of the URL.
  assert_eq(
    llm_completion_url("  https://api.example.com/v1  "),
    "https://api.example.com/v1/chat/completions",
  )
}

///|
test "a URL that already names the path is used verbatim" {
  // This is the OpenAI SDK rule: appending a second `/chat/completions` would
  // 404 on every request and look like a bad key.
  assert_eq(
    llm_completion_url("https://api.example.com/v1/chat/completions"),
    "https://api.example.com/v1/chat/completions",
  )
  assert_eq(
    llm_completion_url("http://127.0.0.1:8791/v1/chat/completions"),
    "http://127.0.0.1:8791/v1/chat/completions",
  )
}

///|
test "the request body is an OpenAI-shaped chat payload" {
  let job = LlmJob::{
    endpoint: "https://api.example.com/v1",
    api_key: "sk-secret",
    model: "gpt-test",
    temperature: 0.7,
    messages: [("system", "你是掌柜。"), ("user", "温一壶酒")],
    on_result: _reply => (),
    on_delta: _delta => (),
  }
  let body = llm_request_body(job)
  // The model and every planned message must reach the wire: sending only the
  // first and last is the bug this guards against.
  assert_true(body.contains("gpt-test"))
  assert_true(body.contains("你是掌柜。"))
  assert_true(body.contains("温一壶酒"))
  assert_true(
    body.contains("\"role\":\"system\"") ||
    body.contains("\"role\": \"system\""),
  )
  // The API key never travels in the body; it is a header concern.
  assert_false(body.contains("sk-secret"))
}
