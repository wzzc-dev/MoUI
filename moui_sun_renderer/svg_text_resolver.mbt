///|
/// Glyph-outline resolver for SVG `<text>` runs, backed by the pure-MoonBit
/// font stack in `moui_sun/text`. Applications install it at startup with
/// `install_svg_text_path_resolver`; every backend's SVG image decoder then
/// swaps bitmap-font text for vector outlines, renderer-independently.
///
/// Font selection is intentionally simple: the first default platform font
/// that loads and parses serves every run. Badge and icon markup asks for
/// DejaVu/Verdana/Helvetica-class sans faces, which the platform sans covers
/// closely; per-family matching can arrive with the seam's next iteration.

///|
priv struct SunSvgTextResolverState {
  mut face : @sun_text.FontFace?
}

///|
let sun_svg_text_resolver_state : SunSvgTextResolverState = { face: None }

///|
fn sun_svg_default_face() -> @sun_text.FontFace? {
  match sun_svg_text_resolver_state.face {
    Some(face) => Some(face)
    None => {
      for source in sun_default_platform_font_sources() {
        let data : Bytes? = Some(@fs.read_file_to_bytes(source.path)) catch {
          _ => None
        }
        match data {
          Some(data) =>
            match @sun_text.FontFace::from_bytes(data) {
              Ok(face) => {
                sun_svg_text_resolver_state.face = Some(face)
                return Some(face)
              }
              Err(_) => ()
            }
          None => ()
        }
      }
      None
    }
  }
}

///|
fn sun_svg_resolve_text_run(
  run : @render_common.SvgTextRun,
) -> @render_common.SvgTextRunOutline? {
  match sun_svg_default_face() {
    Some(face) => {
      // 0.0 means unspecified: the outline API treats non-positive targets
      // as natural spacing.
      let outline = face.text_run_outline(
        run.text,
        run.font_size,
        0.0,
        0.0,
        target_length=run.text_length,
      )
      if outline.polygons.is_empty() {
        None
      } else {
        Some({ width: outline.width, polygons: outline.polygons })
      }
    }
    None => None
  }
}

///|
/// Register the glyph-outline resolver with the renderer-neutral SVG
/// pipeline. Returns false when no default platform font could be loaded,
/// leaving SVG text on the renderer's bitmap fallback.
pub fn install_svg_text_path_resolver() -> Bool {
  match sun_svg_default_face() {
    Some(_) => {
      @render_common.set_svg_text_path_resolver(sun_svg_resolve_text_run)
      true
    }
    None => false
  }
}
