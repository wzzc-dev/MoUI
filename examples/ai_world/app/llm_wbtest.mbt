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
test "the request body carries model, every message, and temperature" {
  let request = LlmRequest::single_shot(
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

///|
test "every planned message reaches the request body in order" {
  // The context layer's whole value is that the model sees history; a body
  // that only forwarded the first and last message made every turn stateless.
  let request = LlmRequest::new(
    character_id="lin",
    endpoint="https://api.openai.com/v1",
    api_key="sk-test",
    model="gpt-4o-mini",
    temperature=0.7,
    messages=[
      ("system", "你是林掌柜"),
      ("system", "【此前】他们谈妥了赊账。"),
      ("system", "【相关背景】后堂埋着女儿红。"),
      ("user", "温一壶酒"),
      ("assistant", "嗯，酒温好了。"),
      ("user", "再来一壶"),
    ],
  )
  let body = llm_request_body(request).stringify()
  // Each role and content survives, in order.
  let order : Array[String] = [
    "你是林掌柜", "【此前】他们谈妥了赊账。", "【相关背景】后堂埋着女儿红。",
    "温一壶酒", "嗯，酒温好了。", "再来一壶",
  ]
  let mut cursor = 0
  for needle in order {
    let at = match body.find(needle) {
      Some(index) => index
      None => fail("body is missing \{needle}")
    }
    assert_true(at >= cursor)
    cursor = at
  }
  assert_true(body.contains("\"assistant\""))
  // The accessors read the planned array, not a removed field.
  assert_eq(request.system(), "你是林掌柜")
  assert_eq(request.user(), "再来一壶")
  assert_eq(request.messages().length(), 6)
}
