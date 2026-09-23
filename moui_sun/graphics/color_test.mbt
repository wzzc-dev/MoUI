///|
test "Color::new creates color with correct values" {
  let color = @graphics.Color::new(r=100, g=150, b=200, a=255)
  assert_eq(color.r, 100)
  assert_eq(color.g, 150)
  assert_eq(color.b, 200)
  assert_eq(color.a, 255)
}

///|
test "Color::white creates white color" {
  let color = @graphics.Color::white()
  assert_eq(color, @graphics.Color::new(r=255, g=255, b=255))
}

///|
test "Color::black creates black color" {
  let color = @graphics.Color::black()
  assert_eq(color, @graphics.Color::new(r=0, g=0, b=0))
}

///|
test "Color::transparent creates transparent color" {
  let color = @graphics.Color::transparent()
  assert_eq(color, @graphics.Color::new(r=0, g=0, b=0, a=0))
}

///|
test "Color::with_alpha replaces alpha" {
  let color = @graphics.Color::red().with_alpha(128)
  assert_eq(color, @graphics.Color::new(r=255, g=0, b=0, a=128))
}

///|
test "Color::scale_alpha clamps opacity" {
  assert_eq(@graphics.Color::red().scale_alpha(0.5).a, 128)
  assert_eq(@graphics.Color::red().scale_alpha(-1.0).a, 0)
  assert_eq(@graphics.Color::red().scale_alpha(2.0).a, 255)
  assert_eq(@graphics.Color::red().scale_alpha(0.0 / 0.0).a, 0)
}

///|
test "Color::blend_over composites straight alpha" {
  let src = @graphics.Color::new(r=255, g=0, b=0, a=128)
  let dst = @graphics.Color::blue()
  assert_eq(src.blend_over(dst), @graphics.Color::new(r=128, g=0, b=127, a=255))
}

///|
test "Color::blend_over preserves transparent source and opaque source" {
  let dst = @graphics.Color::new(r=10, g=20, b=30, a=200)
  assert_eq(@graphics.Color::transparent().blend_over(dst), dst)
  assert_eq(@graphics.Color::green().blend_over(dst), @graphics.Color::green())
}

///|
test "Color::blend_with applies opaque blend modes" {
  let src = @graphics.Color::new(r=200, g=100, b=50)
  let dst = @graphics.Color::new(r=100, g=150, b=200)
  assert_eq(src.blend_with(dst, Clear), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, Source), src)
  assert_eq(src.blend_with(dst, Destination), dst)
  assert_eq(src.blend_with(dst, DestinationOver), dst)
  assert_eq(src.blend_with(dst, SourceIn), src)
  assert_eq(src.blend_with(dst, SourceOut), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, DestinationIn), dst)
  assert_eq(src.blend_with(dst, DestinationOut), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, SourceAtop), src)
  assert_eq(src.blend_with(dst, DestinationAtop), dst)
  assert_eq(src.blend_with(dst, Xor), @graphics.Color::transparent())
  assert_eq(
    src.blend_with(dst, Multiply),
    @graphics.Color::new(r=78, g=59, b=39),
  )
  assert_eq(
    src.blend_with(dst, Screen),
    @graphics.Color::new(r=222, g=191, b=211),
  )
  assert_eq(src.blend_with(dst, Add), @graphics.Color::new(r=255, g=250, b=250))
  assert_eq(
    src.blend_with(dst, Darken),
    @graphics.Color::new(r=100, g=100, b=50),
  )
  assert_eq(
    src.blend_with(dst, Lighten),
    @graphics.Color::new(r=200, g=150, b=200),
  )
  assert_eq(
    src.blend_with(dst, Difference),
    @graphics.Color::new(r=100, g=50, b=150),
  )
  assert_eq(
    src.blend_with(dst, Exclusion),
    @graphics.Color::new(r=143, g=132, b=172),
  )
  assert_eq(
    src.blend_with(dst, Overlay),
    @graphics.Color::new(r=157, g=127, b=167),
  )
  assert_eq(
    src.blend_with(dst, HardLight),
    @graphics.Color::new(r=188, g=118, b=78),
  )
  assert_eq(
    src.blend_with(dst, SoftLight),
    @graphics.Color::new(r=134, g=137, b=174),
  )
  assert_eq(
    src.blend_with(dst, ColorDodge),
    @graphics.Color::new(r=255, g=247, b=249),
  )
  assert_eq(
    src.blend_with(dst, ColorBurn),
    @graphics.Color::new(r=57, g=0, b=0),
  )
  assert_eq(src.blend_with(dst, Hue), @graphics.Color::new(r=191, g=124, b=91))
  assert_eq(
    src.blend_with(dst, Saturation),
    @graphics.Color::new(r=80, g=155, b=230),
  )
  assert_eq(
    src.blend_with(dst, Color),
    @graphics.Color::new(r=216, g=116, b=66),
  )
  assert_eq(
    src.blend_with(dst, Luminosity),
    @graphics.Color::new(r=84, g=134, b=184),
  )
  assert_eq(
    src.blend_with(dst, LinearBurn),
    @graphics.Color::new(r=45, g=0, b=0),
  )
  assert_eq(
    src.blend_with(dst, Subtract),
    @graphics.Color::new(r=0, g=50, b=150),
  )
  assert_eq(
    @graphics.Color::white().blend_with(dst, ColorDodge),
    @graphics.Color::white(),
  )
  assert_eq(
    @graphics.Color::black().blend_with(dst, ColorBurn),
    @graphics.Color::black(),
  )
}

///|
test "Color::blend_with preserves color dodge and burn extrema" {
  assert_eq(
    @graphics.Color::white().blend_with(@graphics.Color::black(), ColorDodge),
    @graphics.Color::black(),
  )
  assert_eq(
    @graphics.Color::black().blend_with(@graphics.Color::white(), ColorBurn),
    @graphics.Color::white(),
  )
}

///|
test "Color::blend_with applies Porter-Duff blend modes" {
  let src = @graphics.Color::new(r=200, g=100, b=50, a=128)
  let dst = @graphics.Color::new(r=100, g=150, b=200, a=192)
  assert_eq(src.blend_with(dst, Clear), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, Destination), dst)
  assert_eq(
    src.blend_with(dst, DestinationOver),
    @graphics.Color::new(r=114, g=143, b=178, a=224),
  )
  assert_eq(
    src.blend_with(dst, SourceAtop),
    @graphics.Color::new(r=150, g=125, b=125, a=192),
  )
  assert_eq(
    src.blend_with(dst, DestinationAtop),
    @graphics.Color::new(r=125, g=138, b=163, a=128),
  )
  assert_eq(
    src.blend_with(dst, Xor),
    @graphics.Color::new(r=124, g=137, b=162, a=128),
  )
}

///|
test "Color::blend_with handles transparent Porter-Duff source" {
  let src = @graphics.Color::transparent()
  let dst = @graphics.Color::new(r=10, g=20, b=30, a=200)
  assert_eq(src.blend_with(dst, Clear), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, Source), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, Destination), dst)
  assert_eq(src.blend_with(dst, SourceOver), dst)
  assert_eq(src.blend_with(dst, DestinationOver), dst)
  assert_eq(src.blend_with(dst, SourceIn), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, DestinationIn), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, SourceOut), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, DestinationOut), dst)
  assert_eq(src.blend_with(dst, SourceAtop), dst)
  assert_eq(
    src.blend_with(dst, DestinationAtop),
    @graphics.Color::transparent(),
  )
  assert_eq(src.blend_with(dst, Xor), dst)
}

///|
test "Color::blend_with respects straight alpha" {
  let src = @graphics.Color::new(r=200, g=100, b=50, a=128)
  let dst = @graphics.Color::new(r=100, g=150, b=200)
  let semi_dst = @graphics.Color::new(r=100, g=150, b=200, a=128)
  assert_eq(src.blend_with(dst, Clear), @graphics.Color::transparent())
  assert_eq(src.blend_with(dst, Source), src)
  assert_eq(src.blend_with(dst, Destination), dst)
  assert_eq(src.blend_with(dst, DestinationOver), dst)
  assert_eq(
    src.blend_with(semi_dst, SourceIn),
    @graphics.Color::new(r=200, g=100, b=50, a=64),
  )
  assert_eq(
    src.blend_with(semi_dst, SourceOut),
    @graphics.Color::new(r=200, g=100, b=50, a=64),
  )
  assert_eq(
    src.blend_with(dst, DestinationIn),
    @graphics.Color::new(r=100, g=150, b=200, a=128),
  )
  assert_eq(
    src.blend_with(dst, DestinationOut),
    @graphics.Color::new(r=100, g=150, b=200, a=127),
  )
  assert_eq(
    src.blend_with(dst, SourceAtop),
    @graphics.Color::new(r=150, g=125, b=125),
  )
  assert_eq(
    src.blend_with(dst, DestinationAtop),
    @graphics.Color::new(r=100, g=150, b=200, a=128),
  )
  assert_eq(
    src.blend_with(dst, Xor),
    @graphics.Color::new(r=100, g=150, b=200, a=127),
  )
  assert_eq(
    src.blend_with(dst, Multiply),
    @graphics.Color::new(r=89, g=104, b=119),
  )
  assert_eq(
    src.blend_with(dst, Screen),
    @graphics.Color::new(r=161, g=171, b=206),
  )
  assert_eq(src.blend_with(dst, Add), @graphics.Color::new(r=178, g=200, b=225))
  assert_eq(
    src.blend_with(dst, Darken),
    @graphics.Color::new(r=100, g=125, b=125),
  )
  assert_eq(
    src.blend_with(dst, Lighten),
    @graphics.Color::new(r=150, g=150, b=200),
  )
  assert_eq(
    src.blend_with(dst, Difference),
    @graphics.Color::new(r=100, g=100, b=175),
  )
  assert_eq(
    src.blend_with(dst, Exclusion),
    @graphics.Color::new(r=122, g=141, b=186),
  )
  assert_eq(
    src.blend_with(dst, Overlay),
    @graphics.Color::new(r=129, g=138, b=183),
  )
  assert_eq(
    src.blend_with(dst, HardLight),
    @graphics.Color::new(r=144, g=134, b=139),
  )
  assert_eq(
    src.blend_with(dst, SoftLight),
    @graphics.Color::new(r=117, g=143, b=187),
  )
  assert_eq(
    src.blend_with(dst, ColorDodge),
    @graphics.Color::new(r=178, g=199, b=225),
  )
  assert_eq(
    src.blend_with(dst, ColorBurn),
    @graphics.Color::new(r=78, g=75, b=100),
  )
  assert_eq(src.blend_with(dst, Hue), @graphics.Color::new(r=146, g=137, b=145))
  assert_eq(
    src.blend_with(dst, Saturation),
    @graphics.Color::new(r=90, g=153, b=215),
  )
  assert_eq(
    src.blend_with(dst, Color),
    @graphics.Color::new(r=158, g=133, b=133),
  )
  assert_eq(
    src.blend_with(dst, Luminosity),
    @graphics.Color::new(r=92, g=142, b=192),
  )
  assert_eq(
    src.blend_with(dst, LinearBurn),
    @graphics.Color::new(r=72, g=75, b=100),
  )
  assert_eq(
    src.blend_with(dst, Subtract),
    @graphics.Color::new(r=50, g=100, b=175),
  )
}
