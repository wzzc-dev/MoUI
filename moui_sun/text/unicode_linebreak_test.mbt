///|
test "get_line_break_class covers Unicode classes used by basic layout" {
  inspect(@text.get_line_break_class(0x002C), content="IS")
  inspect(@text.get_line_break_class(0x0035), content="NU")
  inspect(@text.get_line_break_class(0x0301), content="CM")
  inspect(@text.get_line_break_class(0x0600), content="NS")
  inspect(@text.get_line_break_class(0x1100), content="JL")
  inspect(@text.get_line_break_class(0x1161), content="JV")
  inspect(@text.get_line_break_class(0x11A8), content="JT")
  inspect(@text.get_line_break_class(0xAC00), content="H2")
  inspect(@text.get_line_break_class(0xAC01), content="H3")
  inspect(@text.get_line_break_class(0x1F1E6), content="RI")
  inspect(@text.get_line_break_class(0x1F3FB), content="EModifier")
  inspect(@text.get_line_break_class(0x200D), content="ZWJ")
  inspect(@text.get_line_break_class(0x21D4), content="B2")
  inspect(@text.get_line_break_class(0x2E3A), content="BB")
  inspect(@text.get_line_break_class(-1), content="Unknown")
}

///|
test "is_line_break_allowed protects joined Unicode clusters" {
  let al = @text.get_line_break_class(0x0061)
  let cm = @text.get_line_break_class(0x0301)
  let gl = @text.get_line_break_class(0x00A0)
  let wj = @text.get_line_break_class(0x2060)
  let zwj = @text.get_line_break_class(0x200D)
  let eb = @text.get_line_break_class(0x270B)
  let jl = @text.get_line_break_class(0x1100)
  let jv = @text.get_line_break_class(0x1161)
  let h2 = @text.get_line_break_class(0xAC00)
  let jt = @text.get_line_break_class(0x11A8)
  let bb = @text.get_line_break_class(0x2E3A)

  assert_true(!@text.is_line_break_allowed(al, cm))
  assert_true(
    !@text.is_line_break_allowed(@text.get_line_break_class(0x0020), cm),
  )
  assert_true(!@text.is_line_break_allowed(al, gl))
  assert_true(
    !@text.is_line_break_allowed(@text.get_line_break_class(0x0020), gl),
  )
  assert_true(!@text.is_line_break_allowed(wj, al))
  assert_true(!@text.is_line_break_allowed(zwj, eb))
  assert_true(!@text.is_line_break_allowed(jl, jv))
  assert_true(!@text.is_line_break_allowed(h2, jt))
  assert_true(@text.is_line_break_allowed(al, bb))
}
