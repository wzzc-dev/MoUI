///|
/// Layout-result memo shared by every `TextSystem`.
///
/// Identity of a cached layout is (text system id, font generation,
/// full `TextLayoutInput`). Lookups index a 64-bit FNV-1a digest of
/// that identity into buckets and verify the exact identity on hit, so
/// a hash collision can never return the wrong layout. Font
/// registration bumps the generation, retiring every pre-registration
/// entry. Total cached text is bounded by a byte budget and an entry
/// cap; exceeding either drops every entry, mirroring the
/// wholesale-clear pattern of the rich-text caches.
priv struct TextParagraphCacheEntry {
  text_system_id : String
  font_generation : Int
  input : TextLayoutInput
  result : TextParagraphLayoutResult
}

///|
let text_paragraph_cache_buckets : Map[UInt64, Array[TextParagraphCacheEntry]] = Map([],
)

///|
let text_paragraph_cache_count : Ref[Int] = Ref(0)

///|
let text_paragraph_cache_text_bytes : Ref[Int] = Ref(0)

///|
let text_paragraph_cache_font_generation : Ref[Int] = Ref(0)

///|
let text_paragraph_cache_capacity : Ref[Int] = Ref(4096)

///|
let text_paragraph_cache_text_budget_bytes : Ref[Int] = Ref(16 * 1024 * 1024)

///|
fn text_paragraph_cache_digest_mix(hash : UInt64, value : UInt64) -> UInt64 {
  let mut hash = hash ^ value
  hash = hash * 0x100000001b3UL
  hash
}

///|
fn text_paragraph_cache_digest_string(hash : UInt64, text : String) -> UInt64 {
  let mut hash = text_paragraph_cache_digest_mix(
    hash,
    text.length().to_uint64(),
  )
  for ch in text {
    hash = text_paragraph_cache_digest_mix(hash, ch.to_int().to_uint64())
  }
  hash
}

///|
fn text_paragraph_cache_digest_family(
  hash : UInt64,
  family : FontFamily,
) -> UInt64 {
  match family {
    Name(name) =>
      text_paragraph_cache_digest_string(
        text_paragraph_cache_digest_mix(hash, 0UL),
        name,
      )
    SystemUi => text_paragraph_cache_digest_mix(hash, 1UL)
    UiSansSerif => text_paragraph_cache_digest_mix(hash, 2UL)
    UiSerif => text_paragraph_cache_digest_mix(hash, 3UL)
    UiMonospace => text_paragraph_cache_digest_mix(hash, 4UL)
    SansSerif => text_paragraph_cache_digest_mix(hash, 5UL)
    Serif => text_paragraph_cache_digest_mix(hash, 6UL)
    Monospace => text_paragraph_cache_digest_mix(hash, 7UL)
    Emoji => text_paragraph_cache_digest_mix(hash, 8UL)
    Math => text_paragraph_cache_digest_mix(hash, 9UL)
    FangSong => text_paragraph_cache_digest_mix(hash, 10UL)
  }
}

///|
fn text_paragraph_cache_digest_font(hash : UInt64, font : FontSpec) -> UInt64 {
  let mut hash = text_paragraph_cache_digest_mix(
    hash,
    font.families.families.length().to_uint64(),
  )
  for family in font.families.families {
    hash = text_paragraph_cache_digest_family(hash, family)
  }
  hash = text_paragraph_cache_digest_string(hash, font.size.to_string())
  hash = text_paragraph_cache_digest_string(hash, font.weight.to_string())
  hash = match font.style {
    Normal => text_paragraph_cache_digest_mix(hash, 0UL)
    Italic => text_paragraph_cache_digest_mix(hash, 1UL)
  }
  hash = text_paragraph_cache_digest_mix(
    hash,
    font.variations.length().to_uint64(),
  )
  for variation in font.variations {
    hash = text_paragraph_cache_digest_string(hash, variation.axis)
    hash = text_paragraph_cache_digest_string(hash, variation.value.to_string())
  }
  hash
}

///|
fn text_paragraph_cache_input_digest(
  text_system_id : String,
  input : TextLayoutInput,
) -> UInt64 {
  let mut hash = 0xcbf29ce484222325UL
  hash = text_paragraph_cache_digest_string(hash, text_system_id)
  hash = text_paragraph_cache_digest_mix(
    hash,
    text_paragraph_cache_font_generation.val.to_uint64(),
  )
  hash = match input.max_width {
    None => text_paragraph_cache_digest_mix(hash, 0UL)
    Some(width) =>
      text_paragraph_cache_digest_string(
        text_paragraph_cache_digest_mix(hash, 1UL),
        width.to_string(),
      )
  }
  hash = text_paragraph_cache_digest_string(hash, input.text)
  text_paragraph_cache_digest_font(hash, input.font)
}

///|
fn text_paragraph_cache_entry_matches(
  entry : TextParagraphCacheEntry,
  text_system_id : String,
  input : TextLayoutInput,
) -> Bool {
  entry.font_generation == text_paragraph_cache_font_generation.val &&
  entry.text_system_id == text_system_id &&
  entry.input == input
}

///|
fn text_paragraph_cache_clear() -> Unit {
  text_paragraph_cache_buckets.clear()
  text_paragraph_cache_count.val = 0
  text_paragraph_cache_text_bytes.val = 0
}

///|
fn text_paragraph_cache_lookup(
  text_system_id : String,
  input : TextLayoutInput,
) -> TextParagraphLayoutResult? {
  if text_paragraph_cache_count.val == 0 {
    return None
  }
  let digest = text_paragraph_cache_input_digest(text_system_id, input)
  match text_paragraph_cache_buckets.get(digest) {
    None => None
    Some(bucket) => {
      let mut found : TextParagraphLayoutResult? = None
      for entry in bucket {
        if text_paragraph_cache_entry_matches(entry, text_system_id, input) {
          found = Some(entry.result)
          break
        }
      }
      found
    }
  }
}

///|
fn text_paragraph_cache_store(
  text_system_id : String,
  input : TextLayoutInput,
  result : TextParagraphLayoutResult,
) -> Unit {
  let text_bytes = input.text.length()
  if text_bytes > text_paragraph_cache_text_budget_bytes.val {
    return
  }
  if text_paragraph_cache_count.val >= text_paragraph_cache_capacity.val ||
    text_paragraph_cache_text_bytes.val + text_bytes >
    text_paragraph_cache_text_budget_bytes.val {
    text_paragraph_cache_clear()
  }
  let entry = {
    text_system_id,
    font_generation: text_paragraph_cache_font_generation.val,
    input,
    result,
  }
  let digest = text_paragraph_cache_input_digest(text_system_id, input)
  let cached = text_paragraph_cache_buckets.get(digest)
  let previous : Array[TextParagraphCacheEntry] = match cached {
    None => []
    Some(bucket) => bucket
  }
  let bucket = previous.filter(existing => {
    !text_paragraph_cache_entry_matches(existing, text_system_id, input)
  })
  let removed = previous.length() - bucket.length()
  bucket.push(entry)
  text_paragraph_cache_buckets[digest] = bucket
  text_paragraph_cache_count.val = text_paragraph_cache_count.val + 1 - removed
  text_paragraph_cache_text_bytes.val = text_paragraph_cache_text_bytes.val +
    text_bytes
}

///|
test "paragraph layouts are memoized per input identity" {
  let layout_count = [0]
  let system = TextSystem::new(
    id="memoized-paragraph-test",
    measure=input => fallback_text_layout_result(input),
    paragraph_layout=Some(input => {
      layout_count[0] = layout_count[0] + 1
      fallback_paragraph_layout_result(
        input,
        input => fallback_text_layout_result(input),
        "memoized-paragraph-test",
      )
    }),
  )
  let input = TextLayoutInput::new(
    text="one two three four five",
    font=FontSpec::new(size=14.0),
    max_width=80.0,
  )
  let first = system.layout_paragraph(input)
  let second = system.layout_paragraph(input)
  assert_eq(layout_count[0], 1)
  assert_true(first == second)
}

///|
test "distinct inputs never share a cached layout" {
  let layout_count = [0]
  let count_layout = input => {
    layout_count[0] = layout_count[0] + 1
    fallback_paragraph_layout_result(
      input,
      input => fallback_text_layout_result(input),
      "distinct-input-paragraph-test",
    )
  }
  let system = TextSystem::new(
    id="distinct-input-paragraph-test",
    measure=input => fallback_text_layout_result(input),
    paragraph_layout=Some(count_layout),
  )
  let font = FontSpec::new(size=14.0)
  // Widths that only differ in the least bits, empty text vs. width
  // change, and font fields must each produce their own underlying
  // layout call — a shared key would silently reuse one of them.
  let _ = system.layout_paragraph(
    TextLayoutInput::new(text="hello", font~, max_width=80.0),
  )
  let _ = system.layout_paragraph(
    TextLayoutInput::new(text="hello", font~, max_width=80.5),
  )
  let _ = system.layout_paragraph(TextLayoutInput::new(text="hello", font~))
  let _ = system.layout_paragraph(
    TextLayoutInput::new(text="hellp", font~, max_width=80.0),
  )
  let _ = system.layout_paragraph(
    TextLayoutInput::new(
      text="hello",
      font=FontSpec::new(size=15.0),
      max_width=80.0,
    ),
  )
  let _ = system.layout_paragraph(
    TextLayoutInput::new(
      text="hello",
      font=FontSpec::new(size=14.0, weight=700),
      max_width=80.0,
    ),
  )
  let _ = system.layout_paragraph(
    TextLayoutInput::new(text="hello", font~, max_width=80.0),
  )
  assert_eq(layout_count[0], 6)
}

///|
test "font registration retires cached layouts" {
  let layout_count = [0]
  let system = TextSystem::new(
    id="font-generation-paragraph-test",
    measure=input => fallback_text_layout_result(input),
    paragraph_layout=Some(input => {
      layout_count[0] = layout_count[0] + 1
      fallback_paragraph_layout_result(
        input,
        input => fallback_text_layout_result(input),
        "font-generation-paragraph-test",
      )
    }),
  )
  let input = TextLayoutInput::new(
    text="generate",
    font=FontSpec::new(size=14.0),
    max_width=80.0,
  )
  let _ = system.layout_paragraph(input)
  let _ = system.layout_paragraph(input)
  assert_eq(layout_count[0], 1)
  system.register_font_data(
    FontFamily::Name("regenerated"),
    Bytes::make(4, b'\x00'),
  )
  let _ = system.layout_paragraph(input)
  assert_eq(layout_count[0], 2)
}

///|
test "different text systems never share cached layouts" {
  let layout_count = [0]
  let count_layout = id => {
    input => {
      layout_count[0] = layout_count[0] + 1
      fallback_paragraph_layout_result(
        input,
        input => fallback_text_layout_result(input),
        id,
      )
    }
  }
  let first = TextSystem::new(
    id="shared-input-paragraph-a",
    measure=input => fallback_text_layout_result(input),
    paragraph_layout=Some(count_layout("shared-input-paragraph-a")),
  )
  let second = TextSystem::new(
    id="shared-input-paragraph-b",
    measure=input => fallback_text_layout_result(input),
    paragraph_layout=Some(count_layout("shared-input-paragraph-b")),
  )
  let input = TextLayoutInput::new(
    text="shared",
    font=FontSpec::new(size=14.0),
    max_width=80.0,
  )
  let first_result = first.layout_paragraph(input)
  let second_result = second.layout_paragraph(input)
  let _ = first.layout_paragraph(input)
  let _ = second.layout_paragraph(input)
  assert_eq(layout_count[0], 2)
  assert_eq(first_result.metadata.text_system_id, "shared-input-paragraph-a")
  assert_eq(second_result.metadata.text_system_id, "shared-input-paragraph-b")
}

///|
test "the text byte budget drops stale paragraph entries" {
  let layout_count = [0]
  let count_layout = input => {
    layout_count[0] = layout_count[0] + 1
    fallback_paragraph_layout_result(
      input,
      input => fallback_text_layout_result(input),
      "budget-paragraph-test",
    )
  }
  let system = TextSystem::new(
    id="budget-paragraph-test",
    measure=input => fallback_text_layout_result(input),
    paragraph_layout=Some(count_layout),
  )
  let budget = text_paragraph_cache_text_budget_bytes.val
  let font = FontSpec::new(size=14.0)
  text_paragraph_cache_text_budget_bytes.val = 8
  let first = TextLayoutInput::new(text="aaaaaaaa", font~, max_width=80.0)
  let second = TextLayoutInput::new(text="bbbbbbbb", font~, max_width=80.0)
  let _ = system.layout_paragraph(first)
  assert_eq(layout_count[0], 1)
  let _ = system.layout_paragraph(first)
  assert_eq(layout_count[0], 1)
  // The second eight-byte entry lands exactly on the budget; a third
  // one must clear everything instead of growing past it.
  let _ = system.layout_paragraph(second)
  assert_eq(layout_count[0], 2)
  let _ = system.layout_paragraph(first)
  assert_eq(layout_count[0], 3)
  let _ = system.layout_paragraph(second)
  assert_eq(layout_count[0], 4)
  text_paragraph_cache_text_budget_bytes.val = budget
}

///|
test "oversized inputs bypass the paragraph cache" {
  let layout_count = [0]
  let system = TextSystem::new(
    id="oversized-paragraph-test",
    measure=input => fallback_text_layout_result(input),
    paragraph_layout=Some(input => {
      layout_count[0] = layout_count[0] + 1
      fallback_paragraph_layout_result(
        input,
        input => fallback_text_layout_result(input),
        "oversized-paragraph-test",
      )
    }),
  )
  let budget = text_paragraph_cache_text_budget_bytes.val
  text_paragraph_cache_text_budget_bytes.val = 8
  let input = TextLayoutInput::new(
    text="aaaaaaaaa",
    font=FontSpec::new(size=14.0),
    max_width=80.0,
  )
  // The cache is process-global and shared across tests, so this only
  // asserts the oversized input itself never occupies an entry.
  let cached = text_paragraph_cache_count.val
  let _ = system.layout_paragraph(input)
  let _ = system.layout_paragraph(input)
  assert_eq(layout_count[0], 2)
  assert_eq(text_paragraph_cache_count.val, cached)
  text_paragraph_cache_text_budget_bytes.val = budget
}
