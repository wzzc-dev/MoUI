// Multiline chat body rendering (plain text; preserves newlines and long lines).

///|
fn chat_message_body(
  text_ : String,
  role : @views.TextRole,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let display = if text_.trim().is_empty() { "(empty)" } else { text_ }
  let font_size = chat_message_text_role_font(role, theme).size
  let lines = chat_message_display_lines(display, width, font_size)
  if lines.is_empty() {
    return chat_message_text(
      "(empty)",
      role=@views.TextRole::Caption,
      theme~,
      width~,
    ).foreground(theme.palette.muted)
  }
  let rows : Array[@moui.View[CodeMsg]] = []
  for line in lines {
    rows.push(
      chat_message_text(
        line,
        role~,
        theme~,
        width~,
        height=chat_message_line_height(font_size),
      ),
    )
  }
  @views.column(rows, spacing=4.0, align=@views.CrossAlign::Start)
}

///|
fn chat_message_text(
  text : String,
  role? : @views.TextRole = @views.TextRole::Body,
  theme~ : @moui.Theme,
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @moui.View[CodeMsg] {
  @views.text(
    text,
    role~,
    theme~,
    width~,
    height~,
    align=@text.TextAlign::TextStart,
  )
}

///|
fn chat_message_text_role_font(
  role : @views.TextRole,
  theme : @moui.Theme,
) -> @text.FontSpec {
  match role {
    @views.TextRole::Body => theme.typography.body
    @views.TextRole::Title => theme.typography.title
    @views.TextRole::Caption => theme.typography.caption
    @views.TextRole::Control => theme.typography.control
    @views.TextRole::Mono =>
      { ..theme.typography.body, families: @text.FontFamilyStack::monospace() }
    @views.TextRole::Display => theme.typography.display
    @views.TextRole::Headline => theme.typography.headline
    @views.TextRole::Subtitle => theme.typography.subtitle
    @views.TextRole::Label => theme.typography.label
    @views.TextRole::Overline => theme.typography.overline
  }
}

// ---------------------------------------------------------------------------
// 换行结果缓存(memo)。
//
// MoUI 是立即式 view:每帧 `code_message_list` 都会重跑所有消息的
// `chat_message_body` → `chat_message_display_lines`。对非流式消息,文本不变,
// 换行结果可缓存;只有正在增长的流式消息(内容在变)必然 miss。缓存只存结果
// 数组(惰性复用,view 只读),键为 `(text length, width, font_size)` 的整数桶,
// 命中后先比长度、再校验完整文本以防碰撞。缓存按 FIFO 有界淘汰,避免满容量
// 整体清空导致长会话重复换行。
//
// 换行算法输出与原先完全一致(见 `workbench_wbtest.mbt` 的换行断言)。
// ---------------------------------------------------------------------------

///|
priv struct MessageLinesCacheEntry {
  text : String
  width : Double
  font_size : Double
  lines : Array[String]
}

///|
let message_lines_cache : Map[Int, Array[MessageLinesCacheEntry]] = Map([])

///|
priv struct MessageLinesCacheToken {
  key : Int
  text : String
  width : Double
  font_size : Double
}

///|
let message_lines_cache_order : Array[MessageLinesCacheToken] = []

///|
let message_lines_cache_evict_cursor : Ref[Int] = Ref(0)

///|
let message_lines_cache_limit : Int = 384

///|
fn message_lines_cache_key(
  text_ : String,
  width : Double,
  font_size : Double,
) -> Int {
  text_.length().lxor(width.hash()).lxor(font_size.hash())
}

///|
fn insert_message_lines_cache_entry(
  key : Int,
  entry : MessageLinesCacheEntry,
) -> Unit {
  let token = {
    key,
    text: entry.text,
    width: entry.width,
    font_size: entry.font_size,
  }
  if message_lines_cache_order.length() < message_lines_cache_limit {
    message_lines_cache_order.push(token)
  } else {
    let cursor = message_lines_cache_evict_cursor.val
    remove_message_lines_cache_entry(message_lines_cache_order[cursor])
    message_lines_cache_order[cursor] = token
    message_lines_cache_evict_cursor.val = (cursor + 1) %
      message_lines_cache_limit
  }
  let next = match message_lines_cache.get(key) {
    Some(bucket) => Array::copy(bucket)
    None => []
  }
  next.push(entry)
  message_lines_cache.set(key, next)
}

///|
fn remove_message_lines_cache_entry(token : MessageLinesCacheToken) -> Unit {
  match message_lines_cache.get(token.key) {
    Some(bucket) => {
      let next : Array[MessageLinesCacheEntry] = []
      let mut removed = false
      for entry in bucket {
        if !removed &&
          entry.width == token.width &&
          entry.font_size == token.font_size &&
          entry.text == token.text {
          removed = true
        } else {
          next.push(entry)
        }
      }
      if next.is_empty() {
        message_lines_cache.remove(token.key)
      } else {
        message_lines_cache.set(token.key, next)
      }
    }
    None => ()
  }
}

///|
fn cache_chat_message_display_lines(
  text_ : String,
  width : Double,
  font_size : Double,
) -> Array[String] {
  let key = message_lines_cache_key(text_, width, font_size)
  match message_lines_cache.get(key) {
    Some(bucket) =>
      for entry in bucket {
        if entry.width == width &&
          entry.font_size == font_size &&
          (physical_equal(entry.text, text_) || entry.text == text_) {
          return entry.lines
        }
      }
    None => ()
  }
  let lines = chat_message_display_lines_compute(text_, width, font_size)
  insert_message_lines_cache_entry(key, { text: text_, width, font_size, lines })
  lines
}

///|
fn chat_message_display_lines_compute(
  text_ : String,
  width : Double,
  font_size : Double,
) -> Array[String] {
  let max_width = width.max(chat_message_min_line_width(font_size))
  let out : Array[String] = []
  for raw in text_.split("\n") {
    let line = raw.to_owned()
    if line.is_empty() {
      out.push("")
    } else {
      let chars = line.to_array()
      let chunk = StringBuilder()
      let mut used_width = 0.0
      for c in chars {
        let advance = chat_message_char_advance(c, font_size)
        if !chunk.is_empty() && used_width + advance > max_width {
          out.push(chunk.to_string())
          chunk.reset()
          used_width = 0.0
        }
        chunk.write_char(c)
        used_width = used_width + advance
      }
      if !chunk.is_empty() {
        out.push(chunk.to_string())
      }
    }
  }
  out
}

///|
/// 按 `(text, width, font_size)` 换行,带 memo。换行算法输出与未缓存时完全一致。
fn chat_message_display_lines(
  text_ : String,
  width : Double,
  font_size : Double,
) -> Array[String] {
  cache_chat_message_display_lines(text_, width, font_size)
}

// ---------------------------------------------------------------------------
// 流式渲染节流。
//
// 流式输出时最后一条消息每帧内容都在增长,若每帧都重新逐字符换行 + 逐行
// Skia measure,长回复会把帧预算吃光(每帧 O(当前回复长度))。窗口化解决不了
// 这条成本曲线,因为它是单条消息自身的增长。这里缓存"上次实际渲染的内容
// 快照":内容增长未超过 `stream_render_step` 字符时,直接复用旧内容与旧换行
// 结果(显示滞后 ≤ 一步,视觉无感),使流式消息的每帧成本降为 O(1);同时旧内容
// 的换行结果在 `chat_message_display_lines` memo 中命中,text 节点 declaration
// 不变 → runtime measure 缓存命中,零重测。
// ---------------------------------------------------------------------------

///|
priv struct StreamRenderSnapshot {
  message_key : String
  content : String
  reasoning : String?
  total_len : Int
  width : Double
  font_size : Double
}

///|
let stream_render_snapshot : Ref[StreamRenderSnapshot?] = Ref(None)

///|
let stream_render_step : Int = 48

///|
/// 流式最后一条 Assistant 消息的渲染节流:返回本次实际应渲染的 `ChatMessage`。
/// `message_key` 识别消息(优先 message_id;缺失时用下标)。内容增量小于
/// `stream_render_step` 字符时返回上次渲染的内容快照,否则重算并更新快照。
fn throttled_assistant_message(
  content : String,
  reasoning : String?,
  message_key : String,
  theme : @moui.Theme,
  width : Double,
) -> ChatMessage {
  let font_size = chat_message_text_role_font(@views.TextRole::Body, theme).size
  let reasoning_len = match reasoning {
    Some(r) => r.char_length()
    None => 0
  }
  let total_len = content.char_length() + reasoning_len
  match stream_render_snapshot.val {
    Some(snap) =>
      if snap.message_key == message_key &&
        snap.width == width &&
        snap.font_size == font_size &&
        total_len >= snap.total_len &&
        total_len - snap.total_len < stream_render_step {
        return ChatMessage::Assistant(snap.content, snap.reasoning)
      }
    None => ()
  }
  stream_render_snapshot.val = Some({
    message_key,
    content,
    reasoning,
    total_len,
    width,
    font_size,
  })
  ChatMessage::Assistant(content, reasoning)
}

///|
fn chat_message_min_line_width(font_size : Double) -> Double {
  (font_size * 4.0).max(48.0)
}

///|
fn chat_message_char_advance(ch : Char, font_size : Double) -> Double {
  let scale = (font_size / 14.0).max(0.75)
  if ch == '\t' {
    16.0 * scale
  } else if ch.is_ascii_whitespace() {
    4.0 * scale
  } else if ch.is_ascii() {
    7.4 * scale
  } else {
    font_size
  }
}

///|
fn chat_message_line_height(font_size : Double) -> Double {
  (font_size + 7.0).max(20.0)
}
