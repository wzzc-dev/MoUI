///|
test "get_line_break_class covers Unicode classes used by basic layout" {
  inspect(get_line_break_class(0x002C), content="IS")
  inspect(get_line_break_class(0x0035), content="NU")
  inspect(get_line_break_class(0x0301), content="CM")
  inspect(get_line_break_class(0x0600), content="NS")
  inspect(get_line_break_class(0x1100), content="JL")
  inspect(get_line_break_class(0x1161), content="JV")
  inspect(get_line_break_class(0x11A8), content="JT")
  inspect(get_line_break_class(0xAC00), content="H2")
  inspect(get_line_break_class(0xAC01), content="H3")
  inspect(get_line_break_class(0x1F1E6), content="RI")
  inspect(get_line_break_class(0x1F3FB), content="EModifier")
  inspect(get_line_break_class(0x200D), content="ZWJ")
  inspect(get_line_break_class(0x21D4), content="B2")
  inspect(get_line_break_class(0x2E3A), content="BB")
  inspect(get_line_break_class(-1), content="Unknown")
}

///|
test "is_line_break_allowed protects joined Unicode clusters" {
  let al = get_line_break_class(0x0061)
  let cm = get_line_break_class(0x0301)
  let gl = get_line_break_class(0x00A0)
  let wj = get_line_break_class(0x2060)
  let zwj = get_line_break_class(0x200D)
  let eb = get_line_break_class(0x270B)
  let jl = get_line_break_class(0x1100)
  let jv = get_line_break_class(0x1161)
  let h2 = get_line_break_class(0xAC00)
  let jt = get_line_break_class(0x11A8)
  let bb = get_line_break_class(0x2E3A)

  assert_true(!is_line_break_allowed(al, cm))
  assert_true(!is_line_break_allowed(get_line_break_class(0x0020), cm))
  assert_true(!is_line_break_allowed(al, gl))
  assert_true(!is_line_break_allowed(get_line_break_class(0x0020), gl))
  assert_true(!is_line_break_allowed(wj, al))
  assert_true(!is_line_break_allowed(zwj, eb))
  assert_true(!is_line_break_allowed(jl, jv))
  assert_true(!is_line_break_allowed(h2, jt))
  assert_true(is_line_break_allowed(al, bb))
}
