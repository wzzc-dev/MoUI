///|
/// LLM request construction and reply parsing.

///|
test "a well-formed response yields its first choice's text" {
  let reply = "{\"choices\":[{\"message\":{\"content\":\"嗯，酒温好了。\"}}]}"
  match llm_parse_reply(reply) {
    Some(text) => assert_eq(text, "嗯，酒温好了。")
    None => assert_true(false)
  }
}

///|
test "malformed and unexpected responses yield no reply" {
  // Every one of these must degrade, never crash the world.
  assert_true(llm_parse_reply("") is None)
  assert_true(llm_parse_reply("not json") is None)
  assert_true(llm_parse_reply("[]") is None)
  assert_true(llm_parse_reply("null") is None)
  assert_true(llm_parse_reply("{\"choices\":[]}") is None)
  assert_true(llm_parse_reply("{\"choices\":[{}]}") is None)
  assert_true(llm_parse_reply("{\"choices\":[{\"message\":{}}]}") is None)
  assert_true(llm_parse_reply("{\"error\":{\"message\":\"bad key\"}}") is None)
}

///|
test "a reply is only taken from the first choice" {
  let reply = "{\"choices\":[{\"message\":{\"content\":\"first\"}},{\"message\":{\"content\":\"second\"}}]}"
  assert_eq(llm_parse_reply(reply), Some("first"))
}

///|
test "clean_reply strips corner brackets and a name prefix" {
  // Both framings are common; left in place they read as third-person narration.
  assert_eq(llm_clean_reply("「嗯。」", "林掌柜"), "嗯。")
  assert_eq(llm_clean_reply("林掌柜：嗯。", "林掌柜"), "嗯。")
  assert_eq(llm_clean_reply("  嗯。  ", "林掌柜"), "嗯。")
  assert_eq(llm_clean_reply("嗯。", "林掌柜"), "嗯。")
}

///|
test "clean_reply leaves dialogue alone when there is no framing" {
  // A colon deep inside a sentence is dialogue, not scaffolding: only the
  // character's own name may be stripped, or content would be lost.
  let line = "他说：明早再走"
  assert_eq(llm_clean_reply(line, "林掌柜"), line)
  // Another character's name is content too, not this one's framing.
  assert_eq(
    llm_clean_reply("皇帝：平身。", "林掌柜"),
    "皇帝：平身。",
  )
}

///|
test "the request body carries model, system, user, and temperature" {
  let request = LlmRequest::new(
    character_id="lin",
    endpoint="https://api.openai.com/v1",
    api_key="sk-test",
    model="gpt-4o-mini",
    temperature=0.7,
    system="你是林掌柜",
    user="温一壶酒",
  )
  let body = llm_request_body(request).stringify()
  assert_true(body.contains("gpt-4o-mini"))
  assert_true(body.contains("你是林掌柜"))
  assert_true(body.contains("温一壶酒"))
  assert_true(body.contains("0.7"))
}
