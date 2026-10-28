///|
/// Real-provider text smoke: the L1 acceptance leg that a glyph run reaches a
/// Metal render target as *coverage*, not as a filled rectangle.
///
/// A renderer-local test cannot cover this, because the module depends on no
/// text provider (that is what plan stage L0.5 bought). So the composition root
/// injects the platform engine and this function asserts on read-back pixels.
/// The shape check is the point: an ink ratio inside the band can only come
/// from partial coverage, and the noop control proves the ink came from text.
pub fn metal_text_smoke(text_engine~ : NativeTextEngine) -> Unit {
  let width = 220
  let height = 48
  let run = @core.DrawText(
    @core.TextRun::new(
      text="MMMMWWWW@",
      frame=@core.Rect::new(
        x=0.0,
        y=0.0,
        width=width.to_double(),
        height=height.to_double(),
      ),
      font=@core.FontSpec::new(size=32.0),
      color=@core.Color::white(),
      align=@core.TextStart,
    ),
  )
  let inked = metal_smoke_ink(width~, height~, commands=[run], text_engine~).inked
  let control = metal_smoke_ink(
      width~,
      height~,
      commands=[run],
      text_engine=native_noop_text_engine(),
    ).inked
  let ratio = inked.to_double() / (width * height).to_double()
  println(
    "MoUI metal text smoke inked=\{inked} ratio=\{ratio.to_string()} control=\{control}",
  )
  if control != 0 {
    abort("metal text smoke: the noop engine must paint nothing")
  }
  if ratio < 0.02 || ratio > 0.6 {
    abort(
      "metal text smoke: ink ratio is not glyph coverage (solid bar or empty)",
    )
  }
  let report = metal_frame_report(
    commands=[run],
    width=width.to_double(),
    height=height.to_double(),
    text_engine~,
  )
  if !report.draws_anything() || report.text_dropped_glyphs != 0 {
    abort("metal text smoke: the frame report disagrees with the painted ink")
  }
  println(
    "MoUI metal frame report items=\{report.items} vertices=\{report.vertices} refused=\{report.refused_count()}",
  )
  metal_emoji_smoke(text_engine~)
  metal_text_capacity_smoke(text_engine~)
  println("MoUI metal text smoke passed glyph-coverage-shape zero-ink-control")
}

///|
/// The within-frame half of the `Text` row, through the same real provider.
///
/// 1,600 distinct ideographs at 14pt is what the L3c measurement found a single
/// 1024×1024 page cannot hold at device scale 2.0: its ceiling was ~818 of those
/// boxes, so the frame dropped roughly 780 glyph boxes *every* frame — the
/// clear-and-rebuild retry could not help, because the second pass ran into the
/// same wall. Growth is the fix, and the claim is counted rather than eyeballed:
/// zero dropped glyphs at both scales, and the report has to say it drew
/// something.
///
/// Scale 1.0 is measured alongside 2.0 because the two pin different halves. The
/// density that forces a second page is a device-scale property, so the 1.0 run
/// must stay one item: a frame page 0 already covers has to pay exactly what it
/// paid before paging existed, and an atlas that grew on a fit frame would show
/// up here as two items rather than as a memory comment.
fn metal_text_capacity_smoke(text_engine~ : NativeTextEngine) -> Unit {
  // (size, device scale, distinct ideographs, the least number of text items the
  // frame must build). The first cell fits page 0 at scale 1.0, the second is the
  // Retina page that forced this design, and the third is a second size so the
  // paging is not a fact about 14pt alone: ~347 distinct 24pt boxes fit a page at
  // scale 2.0, so 900 of them cannot be one item.
  let cells : Array[(Double, Double, Int32, Int32)] = [
    (14.0, 1.0, 1600, 1),
    (14.0, 2.0, 1600, 2),
    (24.0, 2.0, 900, 2),
  ]
  for cell in cells {
    let (size, scale, glyphs, least_items) = cell
    let builder = StringBuilder(size_hint=glyphs)
    for index in 0..<glyphs {
      builder.write_char((0x4E00 + index).unsafe_to_char())
    }
    let text = builder.to_string()
    let frame = @core.Rect::new(x=0.0, y=0.0, width=700.0, height=4000.0)
    let report = metal_frame_report(
      commands=[
        @core.DrawText(
          @core.TextRun::new(
            text~,
            frame~,
            font=@core.FontSpec::new(size~),
            color=@core.Color::white(),
            align=@core.TextStart,
          ),
        ),
      ],
      width=frame.size.width,
      height=frame.size.height,
      scale_factor=scale,
      text_engine~,
    )
    println(
      "MoUI metal text smoke capacity distinct=\{glyphs} size=\{size.to_string()}pt scale=\{scale.to_string()} items=\{report.items} least=\{least_items} dropped=\{report.text_dropped_glyphs}",
    )
    if !report.draws_anything() || report.text_dropped_glyphs != 0 {
      abort(
        "metal text smoke: a frame denser than one atlas page did not grow past it",
      )
    }
    if report.items < least_items {
      abort(
        "metal text smoke: a cell that needs several pages built fewer text items than it takes",
      )
    }
    if size == 14.0 && scale == 1.0 && report.items != 1 {
      abort("metal text smoke: a frame one page covers grew the atlas anyway")
    }
  }
}

///|
fn metal_emoji_run(
  text : String,
  color : @core.Color,
  size~ : Double = 32.0,
  side~ : Double = 48.0,
) -> @core.DrawCommand {
  @core.DrawText(
    @core.TextRun::new(
      text~,
      frame=@core.Rect::new(x=0.0, y=0.0, width=side, height=side),
      font=@core.FontSpec::new(size~),
      color~,
      align=@core.TextStart,
    ),
  )
}

///|
/// The colour half of the row, through the same real provider.
///
/// `moui_metal_text_fragment` multiplies the atlas sample by the run colour, so
/// a run tinted pure red can only light a green channel if the glyph arrived
/// with its own pixels. The mirrored half (pure green run, red channel lit)
/// fails together with it, which is the point: a provider that hands back
/// monochrome coverage for an emoji is caught by both, and a solid bar is caught
/// by neither claim because each names a channel the run colour zeroes.
///
/// Two samples, because a single-codepoint emoji and a ZWJ sequence reach the
/// atlas through different paths — the sequence is one composite glyph the
/// provider folds the carets over.
fn metal_emoji_smoke(text_engine~ : NativeTextEngine) -> Unit {
  for sample in ["🙂", "👩‍💻"] {
    let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0)
    let green = @core.Color::rgba(r=0.0, g=1.0, b=0.0)
    for size in [24.0, 32.0, 48.0] {
      let side = (size * 1.5).to_int()
      let sized = metal_emoji_run(sample, red, size~, side=size * 1.5)
      let sized_green = metal_emoji_run(sample, green, size~, side=size * 1.5)
      let sized_control = metal_emoji_run(sample, red, size~, side=size * 1.5)
      let at_size = metal_smoke_ink(
        width=side,
        height=side,
        commands=[sized],
        text_engine~,
      )
      let mirror = metal_smoke_ink(
        width=side,
        height=side,
        commands=[sized_green],
        text_engine~,
      )
      let zero = metal_smoke_ink(
        width=side,
        height=side,
        commands=[sized_control],
        text_engine=native_noop_text_engine(),
      )
      let sized_report = metal_frame_report(
        commands=[sized],
        width=side.to_double(),
        height=side.to_double(),
        text_engine~,
      )
      println(
        "MoUI metal text smoke emoji=\{sample} size=\{size.to_string()}pt inked=\{at_size.inked} green=\{at_size.green} red-from-green-run=\{mirror.red} control=\{zero.inked} dropped=\{sized_report.text_dropped_glyphs}",
      )
      if zero.inked != 0 {
        abort(
          "metal text smoke: the noop engine must paint no emoji at any size",
        )
      }
      if at_size.inked == 0 || sized_report.text_dropped_glyphs != 0 {
        abort("metal text smoke: an emoji size painted nothing or was dropped")
      }
      if at_size.green == 0 || mirror.red == 0 {
        abort(
          "metal text smoke: emoji ink carries no channel the run colour cannot produce, at a size that asked for colour",
        )
      }
    }
    // The same claim at a Retina device scale, which is the case a MacBook
    // actually draws and that the proof pass could not express until it took a
    // scale itself.
    let retina_side = 64
    let retina = metal_smoke_ink(
      width=retina_side,
      height=retina_side,
      commands=[metal_emoji_run(sample, red, size=48.0, side=64.0)],
      text_engine~,
      scale_factor=2.0,
    )
    let retina_control = metal_smoke_ink(
      width=retina_side,
      height=retina_side,
      commands=[metal_emoji_run(sample, red, size=48.0, side=64.0)],
      text_engine=native_noop_text_engine(),
      scale_factor=2.0,
    )
    println(
      "MoUI metal text smoke emoji=\{sample} scale=2 inked=\{retina.inked} green=\{retina.green} control=\{retina_control.inked}",
    )
    if retina_control.inked != 0 {
      abort(
        "metal text smoke: a noop engine paints no emoji at scale 2.0 either",
      )
    }
    if retina.inked == 0 || retina.green == 0 {
      abort(
        "metal text smoke: the colour glyph did not survive the device-scale raster",
      )
    }
    // The same colour claim through a layer composite, so the pixel that proves
    // the provider's colour survived is now read off a group's own target rather
    // than the main pass: a route that only took the colour branch on the main
    // pass, or re-tinted inside the group, lands red where green is due.
    let grouped : Array[@core.DrawCommand] = [
      @core.PushLayer(@core.LayerSpec::new()),
      metal_emoji_run(sample, red, size=48.0, side=64.0),
      @core.PopLayer,
    ]
    let in_group = metal_smoke_ink(
      width=64,
      height=64,
      commands=grouped,
      text_engine~,
    )
    let group_control = metal_smoke_ink(
      width=64,
      height=64,
      commands=grouped,
      text_engine=native_noop_text_engine(),
    )
    let group_report = metal_frame_report(
      commands=grouped,
      width=64.0,
      height=64.0,
      text_engine~,
    )
    println(
      "MoUI metal text smoke emoji=\{sample} in-layer inked=\{in_group.inked} green=\{in_group.green} control=\{group_control.inked} layers=\{group_report.layers} dropped=\{group_report.text_dropped_glyphs}",
    )
    if group_control.inked != 0 {
      abort(
        "metal text smoke: a noop engine paints nothing inside a layer either",
      )
    }
    if in_group.inked == 0 || in_group.green == 0 {
      abort(
        "metal text smoke: the colour glyph did not survive the group's own composite",
      )
    }
    if group_report.layers != 1 || group_report.text_dropped_glyphs != 0 {
      abort("metal text smoke: the grouped emoji frame reports no single pass")
    }
    let red_run = metal_smoke_ink(
      width=48,
      height=48,
      commands=[metal_emoji_run(sample, red)],
      text_engine~,
    )
    let green_run = metal_smoke_ink(
      width=48,
      height=48,
      commands=[metal_emoji_run(sample, green)],
      text_engine~,
    )
    let control = metal_smoke_ink(
      width=48,
      height=48,
      commands=[metal_emoji_run(sample, red)],
      text_engine=native_noop_text_engine(),
    )
    let report = metal_frame_report(
      commands=[metal_emoji_run(sample, @core.Color::white())],
      width=48.0,
      height=48.0,
      text_engine~,
    )
    println(
      "MoUI metal text smoke emoji=\{sample} inked=\{red_run.inked} green-channel=\{red_run.green} red-channel-from-green-run=\{green_run.red} control=\{control.inked} dropped=\{report.text_dropped_glyphs}",
    )
    if control.inked != 0 {
      abort("metal text smoke: the noop engine must paint no emoji either")
    }
    if red_run.inked == 0 ||
      report.text_dropped_glyphs != 0 ||
      report.text_runs_dropped != 0 {
      abort("metal text smoke: the emoji run painted nothing or was dropped")
    }
    if red_run.green == 0 || green_run.red == 0 {
      abort(
        "metal text smoke: emoji ink carries no channel the run colour cannot produce",
      )
    }
  }
}

///|
priv struct MetalSmokeInk {
  inked : Int32
  /// Pixels lighting the green channel past the ink threshold. A run colour
  /// with `g = 0` cannot produce one.
  green : Int32
  /// The mirror of `green`, for the run tinted pure green.
  red : Int32
}

///|
fn metal_smoke_ink(
  width~ : Int32,
  height~ : Int32,
  commands~ : Array[@core.DrawCommand],
  text_engine~ : NativeTextEngine,
  scale_factor~ : Double = 1.0,
) -> MetalSmokeInk {
  let pixels = match
    metal_proof_pixels(
      width~,
      height~,
      commands~,
      clear=@core.Color::black(),
      text_engine~,
      scale_factor~,
    ) {
    Some(pixels) => pixels
    None => abort("metal text smoke needs a Metal device")
  }
  let device_width = (width.to_double() * scale_factor).to_int()
  let device_height = (height.to_double() * scale_factor).to_int()
  let total = device_width * device_height
  let mut inked = 0
  let mut green = 0
  let mut red = 0
  for index in 0..<total {
    let offset = index * 4
    let channel_red = pixels[offset].to_int()
    let channel_green = pixels[offset + 1].to_int()
    let channel_blue = pixels[offset + 2].to_int()
    if channel_red > 40 || channel_green > 40 || channel_blue > 40 {
      inked = inked + 1
    }
    if channel_green > 40 {
      green = green + 1
    }
    if channel_red > 40 {
      red = red + 1
    }
  }
  MetalSmokeInk::{ inked, green, red, }
}
