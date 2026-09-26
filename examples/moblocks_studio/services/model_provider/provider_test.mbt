///|
test "请求体编码为 OpenAI 兼容结构且稳定" {
  let request = CompletionRequest::new("fake-gpt-mini", "友好助手")
    .with_message(User, "你好")
    .with_message(Assistant, "在的")
    .with_message(User, "讲个笑话")
  let body = build_request_body(request)
  let encoded = body.stringify()
  assert_true(encoded.contains("\"model\":\"fake-gpt-mini\""))
  assert_true(encoded.contains("\"role\":\"user\""))
  assert_true(encoded.contains("\"response_format\""))
  // 二次编码一致（稳定性）
  assert_eq(encoded, body.stringify())
}

///|
test "解析正常响应提取首选文本" {
  let text = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"你好呀\"}}]}"
  match parse_completion(text) {
    Ok(content) => assert_eq(content, "你好呀")
    Err(reason) => fail("应解析成功：\{reason}")
  }
}

///|
test "解析拒绝错误体与残缺结构" {
  match parse_completion("{\"error\":{\"message\":\"quota exceeded\"}}") {
    Ok(_) => fail("错误体必须被拒绝")
    Err(reason) => assert_true(reason.contains("quota exceeded"))
  }
  match parse_completion("{\"choices\":[]}") {
    Ok(_) => fail("空 choices 必须被拒绝")
    Err(_) => ()
  }
  match parse_completion("not json") {
    Ok(_) => fail("非法 JSON 必须被拒绝")
    Err(_) => ()
  }
}

///|
test "确定性假模型：相同输入相同输出" {
  let request = CompletionRequest::new("fake-gpt-mini", "友好助手").with_message(
    User,
    "你好",
  )
  let first = deterministic_completion(request)
  let second = deterministic_completion(request)
  assert_eq(first, second)
  assert_true(first.contains("【友好助手】"))
  assert_true(first.contains("你好"))
}

///|
test "请求预算守卫拒绝超长输入" {
  let small = CompletionRequest::new("m", "s").with_message(User, "短")
  assert_true(request_within_budget(small, 100))
  let big = CompletionRequest::new("m", "s").with_message(
    User,
    "很长很长的内容",
  )
  assert_true(!request_within_budget(big, 4))
}
