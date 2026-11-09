///|
fn date_locale(tag : String) -> @moui_i18n.Locale {
  @moui_i18n.Locale::parse(tag).unwrap()
}

///|
test "CalendarDate validates ranges and leap years" {
  assert_true(@moui_i18n.CalendarDate::new(year=2026, month=0, day=1) is None)
  assert_true(@moui_i18n.CalendarDate::new(year=2026, month=13, day=1) is None)
  assert_true(@moui_i18n.CalendarDate::new(year=2026, month=1, day=0) is None)
  assert_true(@moui_i18n.CalendarDate::new(year=2026, month=1, day=32) is None)
  assert_true(@moui_i18n.CalendarDate::new(year=2026, month=4, day=31) is None)
  assert_true(@moui_i18n.CalendarDate::new(year=2023, month=2, day=29) is None)
  assert_true(@moui_i18n.CalendarDate::new(year=1900, month=2, day=29) is None)
  assert_true(
    @moui_i18n.CalendarDate::new(year=2024, month=2, day=29) is Some(_),
  )
  assert_true(
    @moui_i18n.CalendarDate::new(year=2000, month=2, day=29) is Some(_),
  )
  assert_true(@moui_i18n.CalendarDate::new(year=-1, month=1, day=1) is None)
  assert_true(@moui_i18n.CalendarDate::new(year=10000, month=1, day=1) is None)
}

///|
test "format_date follows locale field order and separator" {
  let date = @moui_i18n.CalendarDate::new(year=2026, month=11, day=9).unwrap()
  inspect(date_locale("en").format_date(date), content="11/09/2026")
  inspect(date_locale("en-US").format_date(date), content="11/09/2026")
  inspect(date_locale("en-GB").format_date(date), content="09/11/2026")
  inspect(date_locale("en-AU").format_date(date), content="09/11/2026")
  inspect(date_locale("en-IN").format_date(date), content="09/11/2026")
  inspect(date_locale("en-CA").format_date(date), content="2026-11-09")
  inspect(date_locale("de").format_date(date), content="09.11.2026")
  inspect(date_locale("fr").format_date(date), content="09/11/2026")
  inspect(date_locale("ru").format_date(date), content="09.11.2026")
  inspect(date_locale("pl").format_date(date), content="09.11.2026")
  inspect(date_locale("cs").format_date(date), content="09.11.2026")
  inspect(date_locale("ja").format_date(date), content="2026/11/09")
  inspect(date_locale("zh").format_date(date), content="2026/11/09")
  inspect(date_locale("zh-Hans-CN").format_date(date), content="2026/11/09")
  inspect(date_locale("ko").format_date(date), content="2026. 11. 09.")
  inspect(date_locale("hu").format_date(date), content="2026. 11. 09.")
  inspect(date_locale("sv").format_date(date), content="2026-11-09")
  inspect(date_locale("ar").format_date(date), content="09/11/2026")
  inspect(date_locale("nl").format_date(date), content="09-11-2026")
}

///|
test "format_date pads fields and defaults unlisted locales to ISO order" {
  let date = @moui_i18n.CalendarDate::new(year=2026, month=1, day=2).unwrap()
  inspect(date_locale("en-US").format_date(date), content="01/02/2026")
  inspect(date_locale("de").format_date(date), content="02.01.2026")
  inspect(date_locale("ja").format_date(date), content="2026/01/02")
  inspect(date_locale("zz").format_date(date), content="2026-01-02")
  let early = @moui_i18n.CalendarDate::new(year=7, month=3, day=4).unwrap()
  inspect(date_locale("sv").format_date(early), content="0007-03-04")
}
