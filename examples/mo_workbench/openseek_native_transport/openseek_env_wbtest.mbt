// URL normalization for OpenAI-compatible bases.

///|
test "chat completions url appends path to v1 base" {
  inspect(
    openseek_chat_completions_url("https://token.sensenova.cn/v1"),
    content="https://token.sensenova.cn/v1/chat/completions",
  )
}

///|
test "chat completions url keeps full endpoint" {
  inspect(
    openseek_chat_completions_url("https://api.deepseek.com/chat/completions"),
    content="https://api.deepseek.com/chat/completions",
  )
}
