///|
/// White-box tests for the UCD fixture parser in
/// `generate_grapheme_break_fixtures`: boundary-marker grammar, hex parsing,
/// UTF-8 offset arithmetic, and the escaped MoonBit literal emitter.

///|
test "split_comment splits at the first hash and trims nothing else" {
  let (body, comment) = split_comment("÷ 0061 ÷ # e + combining")
  assert_eq(body, "÷ 0061 ÷ ")
  assert_eq(comment, " e + combining")
  let (plain, empty) = split_comment("÷ 0061 ÷")
  assert_eq(plain, "÷ 0061 ÷")
  assert_eq(empty, "")
}

///|
test "is_hex_token accepts only 4-6 hex digits" {
  assert_true(is_hex_token("0061"))
  assert_true(is_hex_token("1F600"))
  assert_false(is_hex_token("061"))
  assert_false(is_hex_token("0000061"))
  assert_false(is_hex_token("00G1"))
  match parse_hex_int("0061") {
    Ok(codepoint) => assert_eq(codepoint, 0x61)
    Err(message) => fail(message)
  }
  match parse_hex_int("10FFFF") {
    Ok(codepoint) => assert_eq(codepoint, 0x10FFFF)
    Err(message) => fail(message)
  }
  match parse_hex_int("zz") {
    Ok(_) => fail("invalid hex must be rejected")
    Err(message) => assert_eq(message, "invalid hex digit")
  }
  match parse_hex_int("110000") {
    Ok(_) => fail("out-of-range codepoints must be rejected")
    Err(message) => assert_eq(message, "codepoint out of range")
  }
}

///|
test "utf8_len_of_codepoint uses the UTF-8 length boundaries" {
  assert_eq(utf8_len_of_codepoint(0x7F), 1)
  assert_eq(utf8_len_of_codepoint(0x80), 2)
  assert_eq(utf8_len_of_codepoint(0x7FF), 2)
  assert_eq(utf8_len_of_codepoint(0x800), 3)
  assert_eq(utf8_len_of_codepoint(0xFFFF), 3)
  assert_eq(utf8_len_of_codepoint(0x10000), 4)
}

///|
test "utf8_offsets_for_boundaries accumulates codepoint widths" {
  // "A" (1 byte) + U+1F600 (4 bytes): boundaries [0, 1, 2] map to [0, 1, 5].
  let offsets = utf8_offsets_for_boundaries([0x41, 0x1F600], [0, 1, 2])
  assert_eq(offsets.length(), 3)
  assert_eq(offsets[0], 0)
  assert_eq(offsets[1], 1)
  assert_eq(offsets[2], 5)
}

///|
test "to_hex_upper and escape_moon_string emit MoonBit codepoint escapes" {
  assert_eq(to_hex_upper(0), "0")
  assert_eq(to_hex_upper(0x41), "41")
  assert_eq(to_hex_upper(0x1F600), "1F600")
  assert_eq(escape_moon_string([0x41, 0x1F600]), "\\u{41}\\u{1F600}")
}

///|
test "valid_helper_name rejects names that are not MoonBit identifiers" {
  assert_true(valid_helper_name("grapheme_break_0061"))
  assert_true(valid_helper_name("_private9"))
  assert_false(valid_helper_name(""))
  assert_false(valid_helper_name("9lives"))
  assert_false(valid_helper_name("has-dash"))
}

///|
test "parse_fixture_line derives boundaries from the ÷/× markers" {
  match parse_fixture_line("÷ 0061 × 0308 ÷  # e + combining", 1, "test") {
    Ok(Some(sample)) => {
      assert_eq(sample.line_number, 1)
      assert_eq(sample.codepoints.length(), 2)
      assert_eq(sample.codepoints[0], 0x61)
      assert_eq(sample.codepoints[1], 0x308)
      assert_eq(sample.boundaries.length(), 2)
      assert_eq(sample.boundaries[0], 0)
      assert_eq(sample.boundaries[1], 2)
      assert_eq(sample.comment, "e + combining")
    }
    _ => fail("expected a parsed sample")
  }
  // A blank line is a no-op rather than a sample.
  match parse_fixture_line("   ", 2, "test") {
    Ok(None) => ()
    _ => fail("blank fixture lines must be skipped")
  }
}

///|
test "parse_fixture_line reports the exact grammar failure" {
  match parse_fixture_line("0061 ÷", 3, "test") {
    Ok(_) => fail("a codepoint without a leading marker must be rejected")
    Err(message) =>
      assert_eq(
        message, "test:3: codepoint '0061' has no preceding boundary marker",
      )
  }
  match parse_fixture_line("÷ 0061", 4, "test") {
    Ok(_) => fail("a line without a closing boundary must be rejected")
    Err(message) =>
      assert_eq(message, "test:4: fixture must start and end with a boundary")
  }
  match parse_fixture_line("÷ 0061 ×", 5, "test") {
    Ok(_) => fail("a trailing no-break marker must be rejected")
    Err(message) =>
      assert_eq(message, "test:5: line ended with a no-break marker")
  }
  match parse_fixture_line("÷ zz ÷", 6, "test") {
    Ok(_) => fail("non-hex tokens must be rejected")
    Err(message) => assert_eq(message, "test:6: unsupported token 'zz'")
  }
}

///|
test "parse_fixture_text strips CRLF and keeps one sample per data line" {
  let text = "÷ 0041 ÷ # A\r\n\r\n÷ 0042 ÷ # B\r\n"
  match parse_fixture_text(text, "fixtures.txt") {
    Ok(samples) => {
      assert_eq(samples.length(), 2)
      assert_eq(samples[0].comment, "A")
      assert_eq(samples[1].comment, "B")
      assert_eq(samples[1].codepoints[0], 0x42)
    }
    Err(message) => fail(message)
  }
}

///|
test "join_ints and normalize_spaces produce stable output text" {
  assert_eq(join_ints([1, 2, 3]), "1, 2, 3")
  assert_eq(normalize_spaces("  a   b  "), "a b")
}
