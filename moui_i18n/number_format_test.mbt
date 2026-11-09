///|
fn locale(tag : String) -> @moui_i18n.Locale {
  @moui_i18n.Locale::parse(tag).unwrap()
}

///|
test "format_int groups digits by locale" {
  inspect(locale("en").format_int(0L), content="0")
  inspect(locale("en").format_int(123L), content="123")
  inspect(locale("en").format_int(1234L), content="1,234")
  inspect(locale("en-US").format_int(1234567L), content="1,234,567")
  inspect(locale("en").format_int(-1234567L), content="-1,234,567")
  inspect(locale("de").format_int(1234567L), content="1.234.567")
  inspect(locale("fr").format_int(1234567L), content="1\u{202F}234\u{202F}567")
  inspect(locale("ru").format_int(1234567L), content="1\u{00A0}234\u{00A0}567")
  inspect(locale("es").format_int(1234567L), content="1.234.567")
  inspect(locale("ja").format_int(1234567L), content="1,234,567")
  inspect(locale("zh").format_int(1234567L), content="1,234,567")
  inspect(locale("ar").format_int(1234567L), content="1,234,567")
}

///|
test "format_int uses lakh and crore grouping for Indian locales" {
  inspect(locale("en-IN").format_int(1234L), content="1,234")
  inspect(locale("en-IN").format_int(12345L), content="12,345")
  inspect(locale("en-IN").format_int(1234567L), content="12,34,567")
  inspect(locale("en-IN").format_int(123456789L), content="12,34,56,789")
  inspect(locale("hi").format_int(123456789L), content="12,34,56,789")
  inspect(locale("en-IN").format_int(-123456789L), content="-12,34,56,789")
}

///|
test "format_int honors pt-PT minimum grouping digits" {
  inspect(locale("pt").format_int(1234L), content="1.234")
  inspect(locale("pt-PT").format_int(1234L), content="1234")
  inspect(locale("pt-PT").format_int(12345L), content="12\u{00A0}345")
  inspect(
    locale("pt-PT").format_int(1234567L),
    content="1\u{00A0}234\u{00A0}567",
  )
}

///|
test "format_number selects locale decimal and grouping separators" {
  inspect(
    locale("en").format_number(1234.5, fraction_digits=1),
    content="1,234.5",
  )
  inspect(
    locale("de").format_number(1234.5, fraction_digits=1),
    content="1.234,5",
  )
  inspect(
    locale("fr").format_number(1234.5, fraction_digits=1),
    content="1\u{202F}234,5",
  )
  inspect(
    locale("en-IN").format_number(123456.5, fraction_digits=1),
    content="1,23,456.5",
  )
  inspect(
    locale("ru").format_number(1234.5, fraction_digits=1),
    content="1\u{00A0}234,5",
  )
}

///|
test "format_number defaults to two fraction digits and pads them" {
  inspect(locale("en").format_number(1234.5), content="1,234.50")
  inspect(locale("en").format_number(0.5), content="0.50")
  inspect(locale("de").format_number(0.05), content="0,05")
  inspect(locale("en").format_number(-1234.5), content="-1,234.50")
}

///|
test "format_number rounds half up and clamps fraction digits" {
  inspect(locale("en").format_number(2.5, fraction_digits=0), content="3")
  inspect(locale("en").format_number(-2.5, fraction_digits=0), content="-3")
  inspect(
    locale("en").format_number(1234.567, fraction_digits=2),
    content="1,234.57",
  )
  inspect(
    locale("en").format_number(1234.5, fraction_digits=-1),
    content="1,235",
  )
  inspect(
    locale("en").format_number(1.25, fraction_digits=99),
    content="1.250000000000000",
  )
}

///|
test "format_number renders non-finite values" {
  inspect(locale("en").format_number(0.0 / 0.0), content="NaN")
  inspect(locale("en").format_number(1.0 / 0.0), content="∞")
  inspect(locale("en").format_number(-1.0 / 0.0), content="-∞")
}
