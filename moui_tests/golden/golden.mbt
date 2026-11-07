///|
/// Golden image regression harness for the MoUI draw-command pipeline.
///
/// The harness renders small deterministic scenes through the Sun CPU raster
/// renderer in-process — no GPU, no native Skia, no host font provider — and
/// gates the RGBA pixels two ways:
///
/// 1. a perceptual gate: two independent presentations of the same scene
///    (fresh renderer, then a second render through the same renderer so the
///    cached-layer paths are exercised) must diff at zero through
///    `pixelmatch`; and
/// 2. a golden gate: each scene's FNV-1a hash of its RGBA bytes must equal a
///    checked-in baseline constant in `baselines.mbt`.
///
/// The scenes are geometric only (rects, rounded rects, linear gradients,
/// clips, transforms, opacity, paths). Rasterizing them is pure arithmetic, so
/// the hashes are host-independent; text is deliberately excluded until glyph
/// rasterization is proven font-source-stable across hosts. A shadow scene
/// waits for the same proof.
///
/// When an intentional renderer or draw-command change moves a hash, read the
/// actual value from the failing test's diff, paste it into `baselines.mbt`,
/// and record the reason in the commit message — the same ratchet flow the
/// maintenance baselines use.

///|
let golden_scene_size : Int32 = 64

///|
/// The deterministic scene set. Every value below is chosen so rasterization
/// is exact arithmetic: integer-ish coordinates, rational transform
/// coefficients (no trigonometry), and lerped gradient colors.
pub fn golden_scenes() -> Array[(String, Array[@core.DrawCommand])] {
  let size = golden_scene_size.to_double()
  [
    (
      "solid_and_rounded_rects",
      [
        Clear(@core.Color::rgba(r=1.0, g=1.0, b=1.0)),
        FillRect(
          @core.Rect::new(x=6.0, y=6.0, width=22.0, height=22.0),
          @core.Color::rgba(r=0.12, g=0.36, b=0.95),
        ),
        FillRoundedRect(
          @core.RoundedRect::new(
            rect=@core.Rect::new(x=36.0, y=6.0, width=22.0, height=22.0),
            radius=6.0,
          ),
          @core.Color::rgba(r=0.86, g=0.27, b=0.24),
        ),
        StrokeRoundedRect(
          @core.RoundedRect::new(
            rect=@core.Rect::new(x=6.0, y=36.0, width=52.0, height=22.0),
            radius=8.0,
          ),
          @core.Color::rgba(r=0.15, g=0.65, b=0.34),
          2.5,
        ),
      ],
    ),
    (
      "linear_gradient",
      [
        Clear(@core.Color::rgba(r=1.0, g=1.0, b=1.0)),
        FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=@core.Rect::new(
              x=4.0,
              y=4.0,
              width=size - 8.0,
              height=size - 8.0,
            ),
            radius=10.0,
          ),
          @core.Brush::LinearGradient(@core.LinearGradientSpec::{
            start: @core.Point::new(x=4.0, y=4.0),
            end: @core.Point::new(x=size - 4.0, y=size - 4.0),
            start_color: @core.Color::rgba(r=0.98, g=0.74, b=0.18),
            end_color: @core.Color::rgba(r=0.61, g=0.15, b=0.67),
          }),
        ),
      ],
    ),
    (
      "clip_transform_opacity",
      [
        Clear(@core.Color::rgba(r=1.0, g=1.0, b=1.0)),
        PushClip(@core.Rect::new(x=8.0, y=8.0, width=48.0, height=48.0)),
        PushTransform({
          a: 0.9,
          b: 0.1,
          c: 0.0 - 0.1,
          d: 0.9,
          tx: 5.0,
          ty: 4.0,
        }),
        PushOpacity(0.6),
        FillRect(
          @core.Rect::new(x=10.0, y=10.0, width=36.0, height=36.0),
          @core.Color::rgba(r=0.16, g=0.5, b=0.73),
        ),
        PopOpacity,
        PopTransform,
        PopClip,
      ],
    ),
    (
      "path_fill",
      [
        Clear(@core.Color::rgba(r=1.0, g=1.0, b=1.0)),
        DrawPath({
          verbs: [
            MoveTo(@core.Point::new(x=32.0, y=6.0)),
            LineTo(@core.Point::new(x=58.0, y=52.0)),
            LineTo(@core.Point::new(x=6.0, y=52.0)),
            Close,
          ],
          fill: Some(
            @core.Brush::Solid(@core.Color::rgba(r=0.42, g=0.09, b=0.55)),
          ),
          stroke: None,
          stroke_width: 0.0,
        }),
      ],
    ),
  ]
}

///|
/// FNV-1a 64 over the scene's RGBA bytes: width * 4 bytes per row, so row
/// padding (if the renderer ever adds any) cannot leak into the hash.
pub fn golden_frame_hash(
  width~ : Int32,
  height~ : Int32,
  row_bytes~ : Int32,
  pixels~ : FixedArray[Byte],
) -> UInt64 {
  let mut hash : UInt64 = 14695981039346656037UL
  let mut offset = 0
  let stride = row_bytes - width * 4
  for _row in 0..<height {
    for _column in 0..<(width * 4) {
      hash = (hash ^ pixels[offset].to_uint64()) * 1099511628211UL
      offset = offset + 1
    }
    offset = offset + stride
  }
  hash
}

///|
/// Render one scene through a fresh Sun raster renderer and capture the RGBA
/// frame the present target receives.
pub fn golden_render_frame(
  commands : Array[@core.DrawCommand],
) -> @moui_sun_renderer.SunPixelFrame raise {
  match golden_render_frames(commands, passes=1).last() {
    Some(frame) => frame
    None => abort("golden renderer never presented a frame")
  }
}

///|
/// Render one scene `passes` times through a single Sun raster renderer —
/// pass 2+ exercises the renderer's cached-layer paths — and capture every
/// RGBA frame the present target receives.
pub fn golden_render_frames(
  commands : Array[@core.DrawCommand],
  passes~ : Int32,
) -> Array[@moui_sun_renderer.SunPixelFrame] raise {
  let frames : Array[@moui_sun_renderer.SunPixelFrame] = []
  let renderer = @moui_sun_renderer.create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(
        width=golden_scene_size.to_double(),
        height=golden_scene_size.to_double(),
      ),
    ),
    @moui_sun_renderer.SunPresentTarget::new(description="moui-golden", present=frame => {
      frames.push(frame)
      true
    }),
  )
  for _pass in 0..<passes {
    renderer.render(commands)
  }
  if frames.length() != passes {
    abort("golden renderer presented \{frames.length()} of \{passes} frames")
  }
  frames
}

///|
/// Convert a captured RGBA frame into a `pixelmatch` image.
pub fn golden_frame_image(
  frame : @moui_sun_renderer.SunPixelFrame,
) -> @pixelmatch.Image {
  let width = frame.width()
  let height = frame.height()
  let row_bytes = frame.row_bytes()
  let pixels = frame.pixels()
  let colors : Array[@pixelmatch.Color] = []
  for row in 0..<height {
    for column in 0..<width {
      let offset = row * row_bytes + column * 4
      colors.push(
        @pixelmatch.Color::rgba(
          pixels[offset].to_int(),
          pixels[offset + 1].to_int(),
          pixels[offset + 2].to_int(),
          pixels[offset + 3].to_int(),
        ),
      )
    }
  }
  @pixelmatch.Image::from_pixels(width, height, colors)
}
