///|
/// Conversation state: bounded history and per-character isolation.

///|
test "append grows the history and keeps oldest-first order" {
  let conversation = Conversation::new(character_id="lin")
  let filled = conversation
    .append(ChatLine::player("第一句"))
    .append(ChatLine::character("lin", "嗯。"))
  assert_eq(filled.lines().length(), 2)
  assert_eq(filled.lines()[0].text(), "第一句")
  assert_eq(filled.lines()[1].text(), "嗯。")
}

///|
test "history is capped at the limit, dropping the oldest" {
  let mut conversation = Conversation::new(character_id="lin")
  let mut index = 0
  while index < chat_history_limit + 20 {
    conversation = conversation.append(ChatLine::player("line \{index}"))
    index += 1
  }
  assert_eq(conversation.lines().length(), chat_history_limit)
  // The oldest surviving line is the first one that was not evicted.
  assert_true(conversation.lines()[0].text().contains("line 20"))
  // The newest is intact.
  assert_true(
    conversation.lines()[chat_history_limit - 1].text().contains("line 79"),
  )
}

///|
test "the pending flag tracks an in-flight turn" {
  let conversation = Conversation::new(character_id="lin")
  assert_false(conversation.pending())
  let busy = conversation.with_pending(true)
  assert_true(busy.pending())
  assert_false(busy.with_pending(false).pending())
}

///|
test "the book keeps one conversation per character and isolates them" {
  let book = ConversationBook::new()
  // A first read materialises an empty conversation.
  assert_eq(book.for_character("lin").lines().length(), 0)
  book.set(
    book.for_character("lin").append(ChatLine::player("只对林掌柜说")),
  )
  book.set(
    book.for_character("jianghu").append(ChatLine::player("只对江湖人说")),
  )
  assert_eq(book.for_character("lin").lines().length(), 1)
  assert_eq(book.for_character("jianghu").lines().length(), 1)
  assert_eq(book.for_character("mengmian").lines().length(), 0)
  // A second write replaces rather than duplicates.
  book.set(
    book.for_character("lin").append(ChatLine::character("lin", "嗯。")),
  )
  assert_eq(book.for_character("lin").lines().length(), 2)
}

///|
test "active_count only counts conversations that have content" {
  let book = ConversationBook::new()
  book.set(Conversation::new(character_id="lin"))
  assert_eq(book.active_count(), 0)
  book.set(book.for_character("lin").append(ChatLine::player("你好")))
  assert_eq(book.active_count(), 1)
}
