///|
test "请求体编码为 OpenAI 兼容结构且稳定" {
  let request = @model_provider.CompletionRequest::new(
      "fake-gpt-mini", "友好助手",
    )
    .with_message(User, "你好")
    .with_message(Assistant, "在的")
    .with_message(User, "讲个笑话")
  // G1:请求默认纯文本（json_mode=false）——不携带 response_format
  let request = { ..request, json_mode: false, }
  let body = @model_provider.build_request_body(request)
  let encoded = body.stringify()
  assert_true(encoded.contains("\"model\":\"fake-gpt-mini\""))
  assert_true(encoded.contains("\"role\":\"user\""))
  assert_false(encoded.contains("response_format"))
  // 提案类（json_mode=true）才带 response_format
  let json_body = @model_provider.build_request_body({
    ..request,
    json_mode: true,
  })
  assert_true(json_body.stringify().contains("\"response_format\""))
  // 二次编码一致（稳定性）
  assert_eq(encoded, body.stringify())
}

///|
test "解析正常响应提取首选文本" {
  let text = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"你好呀\"}}]}"
  match @model_provider.parse_completion(text) {
    Ok(content) => assert_eq(content, "你好呀")
    Err(reason) => fail("应解析成功：\{reason}")
  }
}

///|
test "解析拒绝错误体与残缺结构" {
  match
    @model_provider.parse_completion(
      "{\"error\":{\"message\":\"quota exceeded\"}}",
    ) {
    Ok(_) => fail("错误体必须被拒绝")
    Err(reason) => assert_true(reason.contains("quota exceeded"))
  }
  match @model_provider.parse_completion("{\"choices\":[]}") {
    Ok(_) => fail("空 choices 必须被拒绝")
    Err(_) => ()
  }
  match @model_provider.parse_completion("not json") {
    Ok(_) => fail("非法 JSON 必须被拒绝")
    Err(_) => ()
  }
}

///|
test "确定性假模型：相同输入相同输出" {
  let request = @model_provider.CompletionRequest::new(
    "fake-gpt-mini", "友好助手",
  ).with_message(User, "你好")
  let first = @model_provider.deterministic_completion(request)
  let second = @model_provider.deterministic_completion(request)
  assert_eq(first, second)
  assert_true(first.contains("【友好助手】"))
  assert_true(first.contains("你好"))
}

///|
test "请求预算守卫拒绝超长输入" {
  let small = @model_provider.CompletionRequest::new("m", "s").with_message(
    User,
    "短",
  )
  assert_true(@model_provider.request_within_budget(small, 100))
  let big = @model_provider.CompletionRequest::new("m", "s").with_message(
    User,
    "很长很长的内容",
  )
  assert_true(!@model_provider.request_within_budget(big, 4))
}

///|
test "补全 URL：base 拼接 / 全路径原样 / 尾斜杠归一" {
  assert_eq(
    @model_provider.completion_url("https://api.stepfun.com/step_plan/v1"),
    "https://api.stepfun.com/step_plan/v1/chat/completions",
  )
  assert_eq(
    @model_provider.completion_url(
      "https://api.stepfun.com/step_plan/v1/chat/completions",
    ),
    "https://api.stepfun.com/step_plan/v1/chat/completions",
  )
  assert_eq(
    @model_provider.completion_url("https://api.example.com/v1/"),
    "https://api.example.com/v1/chat/completions",
  )
}
