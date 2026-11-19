///|
/// White-box tests for the UCD property-range parser in
/// `generate_grapheme_property_data`: hex/range grammar, deterministic range
/// merging, chunked function emission, and the property lookup fallback.

///|
fn range(start : Int32, end : Int32) -> CodeRange {
  { start, end, }
}

///|
fn single_ranges(values : Array[Int32]) -> Array[CodeRange] {
  values.map(value => { start: value, end: value, })
}

///|
test "split_comment and split_fields follow the UCD line format" {
  assert_eq(split_comment("0041..005A # latin"), "0041..005A ")
  assert_eq(split_comment("0041..005A"), "0041..005A")
  let fields = split_fields("0041..005A; Lu; 0; L; ...")
  assert_eq(fields.length(), 5)
  assert_eq(fields[0], "0041..005A")
  assert_eq(fields[1], "Lu")
}

///|
test "parse_hex_int validates digits and the Unicode ceiling" {
  match parse_hex_int("41") {
    Ok(codepoint) => assert_eq(codepoint, 0x41)
    Err(message) => fail(message)
  }
  match parse_hex_int("10FFFF") {
    Ok(codepoint) => assert_eq(codepoint, 0x10FFFF)
    Err(message) => fail(message)
  }
  match parse_hex_int("110000") {
    Ok(_) => fail("codepoints above 0x10FFFF must be rejected")
    Err(message) => assert_eq(message, "codepoint out of range")
  }
  match parse_hex_int("0G") {
    Ok(_) => fail("non-hex digits must be rejected")
    Err(message) => assert_eq(message, "invalid hex digit")
  }
}

///|
test "parse_range accepts singles and ordered pairs only" {
  match parse_range("0041..005A", "fixtures.txt", 1) {
    Ok(value) => {
      assert_eq(value.start, 0x41)
      assert_eq(value.end, 0x5A)
    }
    Err(message) => fail(message)
  }
  match parse_range("0041", "fixtures.txt", 2) {
    Ok(value) => {
      assert_eq(value.start, 0x41)
      assert_eq(value.end, 0x41)
    }
    Err(message) => fail(message)
  }
  match parse_range("005A..0041", "fixtures.txt", 3) {
    Ok(_) => fail("reversed ranges must be rejected")
    Err(message) =>
      assert_eq(message, "fixtures.txt:3: range end precedes start")
  }
  match parse_range("0041..zzzz", "fixtures.txt", 4) {
    Ok(_) => fail("non-hex endpoints must be rejected")
    Err(message) =>
      assert_eq(message, "fixtures.txt:4: invalid codepoint 'zzzz'")
  }
}

///|
test "merge_ranges sorts, deduplicates, and coalesces adjacent ranges" {
  let merged = merge_ranges([
    range(0x10, 0x10),
    range(0x03, 0x05),
    range(0x01, 0x02),
    range(0x06, 0x07),
  ])
  assert_eq(merged.length(), 2)
  assert_eq(merged[0].start, 0x01)
  assert_eq(merged[0].end, 0x07)
  assert_eq(merged[1].start, 0x10)
  assert_eq(merged[1].end, 0x10)
  // A nested range must not extend the outer one past its own end.
  let nested = merge_ranges([range(0x10, 0x20), range(0x12, 0x15)])
  assert_eq(nested.length(), 1)
  assert_eq(nested[0].start, 0x10)
  assert_eq(nested[0].end, 0x20)
}

///|
test "expression_for_ranges renders ranges in hex with trailing disjunction" {
  let single = expression_for_ranges([range(0x41, 0x41)])
  assert_eq(single.length(), 1)
  assert_eq(single[0], "  codepoint == 0x0041")
  let pair = expression_for_ranges([range(0x41, 0x5A), range(0x61, 0x7A)])
  assert_eq(pair.length(), 2)
  assert_eq(pair[0], "  (codepoint >= 0x0041 && codepoint <= 0x005A) ||")
  assert_eq(pair[1], "  (codepoint >= 0x0061 && codepoint <= 0x007A)")
  assert_eq(expression_for_ranges([])[0], "  false")
}

///|
test "function_for_ranges chunks past the 48-range boundary" {
  assert_eq(range_chunk_size(), 48)
  let at_limit = single_ranges([
    1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41,
    43, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81,
    83, 85, 87, 89, 91, 93, 95,
  ])
  let flat = function_for_ranges("is_property", at_limit)
  assert_eq(at_limit.length(), 48)
  assert_false(flat.contains("_chunk_"))
  assert_true(flat.contains("fn is_property(codepoint : Int) -> Bool {"))
  let over_limit = single_ranges([
    1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41,
    43, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81,
    83, 85, 87, 89, 91, 93, 95, 97,
  ])
  let chunked = function_for_ranges("is_property", over_limit)
  assert_true(chunked.contains("is_property_chunk_0(codepoint)"))
  assert_true(chunked.contains("is_property_chunk_1(codepoint)"))
  assert_true(
    chunked.contains("fn is_property_chunk_1(codepoint : Int) -> Bool {"),
  )
}

///|
test "ranges_or_empty falls back to an empty range list" {
  let map : Map[String, Array[CodeRange]] = Map([])
  map["Lu"] = [range(0x41, 0x5A)]
  assert_eq(ranges_or_empty(map, "Lu").length(), 1)
  assert_eq(ranges_or_empty(map, "Missing").length(), 0)
}
