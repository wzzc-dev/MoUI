///|
/// White-box tests for the native platform font discovery payload.
///
/// The payload carries every discovered path and family as length-prefixed
/// strings, so a wrong byte count anywhere truncates the last string and the
/// decoder rejects the whole discovery. These tests pin the layout: a
/// well-formed payload must decode, a truncated one must not, and the decoded
/// sans face must exist on disk so Sun really draws outlines instead of
/// placeholder glyphs.

///|
fn sun_test_is_sans_role(role : SunPlatformFontRole) -> Bool {
  match role {
    Sans => true
    _ => false
  }
}

///|
fn sun_test_payload_bytes(values : Array[Int32]) -> Bytes {
  let out : Array[Byte] = []
  for value in values {
    let unsigned = value.reinterpret_as_uint()
    out.push((unsigned & 0xFF).to_byte())
    out.push(((unsigned >> 8) & 0xFF).to_byte())
    out.push(((unsigned >> 16) & 0xFF).to_byte())
    out.push(((unsigned >> 24) & 0xFF).to_byte())
  }
  Bytes::from_array(out)
}

///|
test "sun platform font payload decodes to a well-formed discovery" {
  match sun_platform_font_discovery() {
    None => fail("native platform font payload did not decode")
    Some(discovery) => {
      for match_entry in discovery.matches {
        assert_true(!match_entry.path.is_empty())
      }
      for entry in discovery.entries {
        assert_true(!entry.path.is_empty())
      }
    }
  }
}

///|
test "sun platform font payload rejects a short or mistyped header" {
  let no_payload : Bytes = Bytes::from_array([])
  assert_true(sun_decode_platform_font_payload(no_payload) is None)
  // version 1, no matches, no list entries: the empty discovery.
  let empty = sun_test_payload_bytes([1, 0, 0])
  match sun_decode_platform_font_payload(empty) {
    Some(discovery) => {
      assert_true(discovery.matches.is_empty())
      assert_true(discovery.entries.is_empty())
    }
    None => fail("empty discovery payload should decode")
  }
  // Unknown version.
  assert_true(
    sun_decode_platform_font_payload(sun_test_payload_bytes([2, 0, 0])) is None,
  )
  // A list count with a truncated path length prefix.
  assert_true(
    sun_decode_platform_font_payload(sun_test_payload_bytes([1, 0, 1])) is None,
  )
}

///|
test "sun platform font payload accepts the discovered system sans face" {
  match sun_platform_font_discovery() {
    None => fail("native platform font payload did not decode")
    Some(discovery) => {
      let mut sans_path = ""
      let mut has_sans = false
      for match_entry in discovery.matches {
        if sun_test_is_sans_role(match_entry.role) {
          sans_path = match_entry.path
          has_sans = true
        }
      }
      if has_sans {
        match sun_platform_font_file_data(sans_path) {
          None => fail("discovered sans face is unreadable: \{sans_path}")
          Some(data) => assert_true(data.length() > 1024)
        }
      } else {
        // No fontconfig on this host: the documented fallback is an empty
        // discovery, and Sun keeps drawing placeholder glyphs instead of
        // panicking. Nothing to read.
        assert_true(discovery.matches.is_empty())
      }
    }
  }
}

///|
test "sun draws system sans text from a discovered outline face" {
  let presented : Ref[SunPixelFrame?] = Ref(None)
  let target = SunPresentTarget::new(description="font", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=32.0),
    ),
    target,
  )
  let has_system_sans = match sun_platform_font_discovery() {
    Some(discovery) =>
      discovery.matches.any(match_entry => {
        sun_test_is_sans_role(match_entry.role)
      })
    None => false
  }
  renderer.render([
    Clear(@core.Color::white()),
    DrawText(
      @core.TextRun::new(
        text="A",
        frame=@core.Rect::new(x=0.0, y=0.0, width=64.0, height=32.0),
        font=@core.FontSpec::new(size=20.0),
        color=@core.Color::black(),
      ),
    ),
  ]) catch {
    _ => fail("rendering system sans text raised")
  }
  match presented.val {
    None => fail("font probe presented no frame")
    Some(frame) => {
      let mut ink = 0
      for index in 0..<(frame.width() * frame.height()) {
        let offset = index * 4
        if frame.pixels()[offset].to_int() < 250 ||
          frame.pixels()[offset + 1].to_int() < 250 ||
          frame.pixels()[offset + 2].to_int() < 250 {
          ink += 1
        }
      }
      assert_true(ink > 0)
      if has_system_sans {
        // A resolved system face must draw outlines without reporting a
        // missing-glyph placeholder fallback.
        inspect(renderer.unsupported_command_count(), content="0")
      }
    }
  }
}

///|
/// The discovered face must be a real parsed outline font, and drawing it must
/// produce grayscale coverage AA: partial values between the text color and the
/// surface. The 5x7 placeholder paints solid cells, so a placeholder frame has
/// no partial pixels at all — this pins the actual TTF path.
test "sun registers a parsed outline face and draws with grayscale coverage" {
  let presented : Ref[SunPixelFrame?] = Ref(None)
  let target = SunPresentTarget::new(description="font-aa", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=32.0),
    ),
    target,
  )
  let has_system_sans = match sun_platform_font_discovery() {
    Some(discovery) =>
      discovery.matches.any(match_entry => {
        sun_test_is_sans_role(match_entry.role)
      })
    None => false
  }
  if has_system_sans {
    let faces = renderer.resolved_faces(@core.FontSpec::new(size=24.0))
    assert_true(!faces.is_empty())
    let mut parsed_outline = false
    for face in faces {
      if face.get_units_per_em() > 0 && face.has_glyph_for_char(65) {
        parsed_outline = true
      }
    }
    assert_true(parsed_outline)
  }
  renderer.render([
    Clear(@core.Color::white()),
    DrawText(
      @core.TextRun::new(
        text="A",
        frame=@core.Rect::new(x=0.0, y=0.0, width=64.0, height=32.0),
        font=@core.FontSpec::new(size=24.0),
        color=@core.Color::black(),
      ),
    ),
  ]) catch {
    _ => fail("rendering AA probe raised")
  }
  match presented.val {
    None => fail("AA probe presented no frame")
    Some(frame) => {
      let mut partial = 0
      for index in 0..<(frame.width() * frame.height()) {
        let offset = index * 4
        let value = frame.pixels()[offset].to_int()
        if value > 16 && value < 239 {
          partial += 1
        }
      }
      // A placeholder cell is uniformly black, so this only passes with
      // coverage AA on the glyph edges.
      assert_true(partial > 8)
    }
  }
}

///|
test "sun text with an unknown family falls back without raising" {
  let target = SunPresentTarget::new(description="font-missing", present=_ => {
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=32.0),
    ),
    target,
  )
  renderer.render([
    Clear(@core.Color::white()),
    DrawText(
      @core.TextRun::new(
        text="A",
        frame=@core.Rect::new(x=0.0, y=0.0, width=64.0, height=32.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([
            @core.FontFamily::Name("NoSuchFamily"),
          ]),
          size=20.0,
        ),
        color=@core.Color::black(),
      ),
    ),
  ]) catch {
    _ => fail("missing family raised instead of falling back")
  }
}
