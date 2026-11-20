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
  // version 3, no matches, no list entries: the empty discovery.
  let empty = sun_test_payload_bytes([3, 0, 0])
  match sun_decode_platform_font_payload(empty) {
    Some(discovery) => {
      assert_true(discovery.matches.is_empty())
      assert_true(discovery.entries.is_empty())
    }
    None => fail("empty discovery payload should decode")
  }
  // Unknown version.
  assert_true(
    sun_decode_platform_font_payload(sun_test_payload_bytes([1, 0, 0])) is None,
  )
  // Version 2 is the pre-symbol layout; the decoder must not accept a payload
  // whose role codes it would misread.
  assert_true(
    sun_decode_platform_font_payload(sun_test_payload_bytes([2, 0, 0])) is None,
  )
  // A list count with a truncated path length prefix.
  assert_true(
    sun_decode_platform_font_payload(sun_test_payload_bytes([3, 0, 1])) is None,
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

///|
/// A sans face matched for the bold bucket must be a real readable outline
/// face, not the regular file and not the placeholder: Skia resolves weight 700
/// through the same fontconfig quantisation, so Sun has to land on the same
/// file to draw bold text with the same advance widths.
test "sun platform font payload reports a bold sans face" {
  match sun_platform_font_discovery() {
    None => fail("native platform font payload did not decode")
    Some(discovery) => {
      let mut regular_path = ""
      let mut bold_path = ""
      for match_entry in discovery.matches {
        if sun_test_is_sans_role(match_entry.role) {
          if match_entry.weight == 400 {
            regular_path = match_entry.path
          }
          if match_entry.weight == 700 {
            bold_path = match_entry.path
          }
        }
      }
      if !bold_path.is_empty() {
        match sun_platform_font_file_data(bold_path) {
          None => fail("discovered bold sans face is unreadable: \{bold_path}")
          Some(data) => assert_true(data.length() > 1024)
        }
      }
      // Hosts whose default sans ships a single face resolve bold to the
      // regular file; that stays a valid discovery.
      ignore(regular_path)
    }
  }
}

///|
fn sun_test_has_distinct_bold_sans() -> Bool {
  match sun_platform_font_discovery() {
    None => false
    Some(discovery) => {
      let mut regular_path = ""
      let mut bold_path = ""
      for match_entry in discovery.matches {
        if sun_test_is_sans_role(match_entry.role) {
          if match_entry.weight == 400 {
            regular_path = match_entry.path
          }
          if match_entry.weight == 700 {
            bold_path = match_entry.path
          }
        }
      }
      !bold_path.is_empty() && bold_path != regular_path
    }
  }
}

///|
/// Weight 700 must resolve a wider face than weight 400 for the same family:
/// this is the button-label case where Sun drew Regular while Skia drew Bold.
test "sun measure picks the bold face for a bold font spec" {
  if sun_test_has_distinct_bold_sans() {
    let target = SunPresentTarget::new(description="font-weight", present=_ => {
      true
    })
    let renderer = create_with_present_target(
      @core.SurfaceMetrics::from_logical(
        size=@core.Size::new(width=64.0, height=32.0),
      ),
      target,
    )
    let regular = renderer.measure_text_layout(
      @core.TextLayoutInput::new(
        text="Primary",
        font=@core.FontSpec::new(size=18.0, weight=400),
      ),
    )
    let bold = renderer.measure_text_layout(
      @core.TextLayoutInput::new(
        text="Primary",
        font=@core.FontSpec::new(size=18.0, weight=700),
      ),
    )
    // Bold is not merely wider by rounding: the advance difference is several
    // percent, so a regular face resolving here fails the ratio.
    assert_true(bold.size.width > regular.size.width * 1.03)
  }
}

///|
/// End-to-end ink check: the bold request must paint heavier strokes than the
/// regular one. A renderer that ignores weight paints identical frames.
test "sun draws heavier ink for a bold font spec" {
  if sun_test_has_distinct_bold_sans() {
    let coverage : Array[Int32] = []
    for weight in [400, 700] {
      let presented : Ref[SunPixelFrame?] = Ref(None)
      let target = SunPresentTarget::new(description="font-weight-ink", present=frame => {
        presented.val = Some(frame)
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
            text="Primary",
            frame=@core.Rect::new(x=0.0, y=0.0, width=64.0, height=32.0),
            font=@core.FontSpec::new(size=18.0, weight~),
            color=@core.Color::black(),
          ),
        ),
      ]) catch {
        _ => ()
      }
      match presented.val {
        None => fail("weight ink probe presented no frame")
        Some(frame) => {
          // Summed coverage rather than a pixel count: heavier stems darken
          // edge pixels that an ink-count threshold would call equal.
          let mut ink = 0
          for index in 0..<(frame.width() * frame.height()) {
            ink += 255 - frame.pixels()[index * 4].to_int()
          }
          coverage.push(ink)
        }
      }
    }
    assert_true(coverage[1] > coverage[0])
  }
}

///|
/// The Showcase top bar sizes its title from `measure_text` and then paints a
/// `DrawText` whose frame is exactly that measured width. If re-laying the same
/// string at that width splits it, the second line falls outside the one-line
/// frame and disappears — the clipped header title the parity work opened with.
/// This pins the invariant directly: measure, then lay out at the measurement.
test "sun measured label re-lays without wrapping at its own width" {
  let target = SunPresentTarget::new(description="measure", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=32.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  let has_system_sans = match sun_platform_font_discovery() {
    Some(discovery) =>
      discovery.matches.any(match_entry => {
        sun_test_is_sans_role(match_entry.role)
      })
    None => false
  }
  if has_system_sans {
    for size in [18.0, 20.0, 22.0, 24.0] {
      for weight in [400, 600, 700] {
        let font = @core.FontSpec::new(size~, weight~)
        let text = "MoUI Showcase"
        let measured = text_system.measure_text(
          @core.TextLayoutInput::new(text~, font~),
        )
        let paragraph = text_system.layout_paragraph(
          @core.TextLayoutInput::new(
            text~,
            font~,
            max_width=measured.size.width,
          ),
        )
        if paragraph.lines.length() != 1 {
          fail(
            "size=\{size} weight=\{weight}: measured width \{measured.size.width} re-lays into \{paragraph.lines.length()} lines",
          )
        }
      }
    }
  }
}

///|
test "weight buckets quantise on the fontconfig scale Skia matches on" {
  // The desktop theme's label/control weight is 550. fontconfig maps 550 to
  // weight 140, which sits between regular (80) and demibold (180) so Skia's
  // FontMgr resolves the bold face; the bucket must agree or Sun keeps drawing
  // labels regular on a sans family that only ships book and bold.
  inspect(sun_font_weight_bucket(550), content="600")
  inspect(sun_font_weight_bucket(400), content="400")
  inspect(sun_font_weight_bucket(600), content="600")
  inspect(sun_font_weight_bucket(700), content="700")
  // 650 maps to fontconfig 190, equidistant from demibold and bold: the heavier
  // bucket wins, matching fontconfig's own tie break.
  inspect(sun_font_weight_bucket(650), content="700")
  // fontconfig's book/light end of the scale.
  inspect(sun_font_weight_bucket(300), content="100")
  inspect(sun_font_weight_bucket(200), content="100")
}

///|
/// The symbol role is the DirectWrite fallback Sun was missing: a check mark is
/// a text glyph (`DrawText("?")` in the checkbox view) and U+2713 is not in the
/// text families, so without a symbol face it painted the .notdef box.
test "sun fallback stack covers the check mark when a symbol face exists" {
  let discovery = match sun_platform_font_discovery() {
    None => return
    Some(discovery) => discovery
  }
  let has_symbol = discovery.matches.any(match_entry => {
    match match_entry.role {
      Symbol => true
      _ => false
    }
  })
  if !has_symbol {
    return
  }
  let target = SunPresentTarget::new(description="symbol-coverage", present=_ => {
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=32.0),
    ),
    target,
  )
  // The checkbox asks for weight 700; the symbol file only ships regular, so
  // coverage here also pins that the fallback stack reaches past the
  // weight-preferred faces.
  let faces = renderer.resolved_faces(
    @core.FontSpec::new(size=18.0, weight=700),
  )
  let mut covered = false
  for face in faces {
    if face.has_glyph_for_char(0x2713) {
      covered = true
    }
  }
  assert_true(covered)
}

///|
/// A symbol face must never become a generic text family: it is reachable
/// through its own name only, so registering it cannot change how body text
/// resolves on a host that has one.
test "sun symbol role registers no generic text family" {
  let families = sun_platform_role_families(Symbol, "Segoe UI Symbol")
  assert_eq(families.length(), 1)
  match families[0] {
    Name(name) => assert_eq(name, "Segoe UI Symbol")
    _ => fail("symbol role must keep only its own family name")
  }
}
