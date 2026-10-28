///|
/// Renderer-local glyph atlas: shelf packing over a lazily-grown set of RGBA8
/// coverage pages.
///
/// It is local because P14 (`docs/invariants.md`) forbids a renderer importing
/// another renderer, so the WGPU atlas cannot be reused. The shared-atlas
/// question belongs to plan stage L3, which decides the text architecture for
/// every non-Skia route; what lives here is the residency policy that question
/// has to be answered against — a page is cleared and repacked when the whole
/// page set fills, the same recovery `moui_wgpu_renderer/native_visual_plan.mbt`
/// runs, so a document longer than the atlas scrolls instead of losing its text
/// for the rest of the session.
///
/// The side is 1024 to match that route's measured budget, not this file's
/// convenience: at 512 a Retina frame of 14pt Chinese text ran out after ~200
/// distinct glyphs and dropped the rest of the page every frame (`docs/plans/
/// active/no-third-party-gpu-route.md`, L3c).
///
/// Growth is what fixes the case one page cannot hold. Clear-and-repack recovers
/// a *document* that outruns the atlas across frames, but a single frame whose
/// own glyph set exceeds an empty 1024×1024 page (~818 distinct 14pt hanzi at
/// device scale 2.0, ~347 at 24pt) was repacked into the same shortfall and lost
/// its overflow every frame. Such a frame now takes a second page. Page 0 exists
/// from construction and costs exactly what the single atlas costed; a page after
/// that is only allocated by a frame that needs it, and `METAL_ATLAS_MAX_PAGES`
/// bounds the worst case at 4 pages — 16 MB of CPU staging plus 16 MB of texture
/// — which is why the cap is part of the design rather than an afterthought.
///
/// The page an item samples is carried in the word the wire already had: a glyph
/// run that spills becomes one draw per page, each with `texture_key` naming its
/// page, so the 76-byte vertex, the 9-int32 item and the MSL are untouched.
priv struct MetalGlyphAtlas {
  mut pages : Array[MetalAtlasPage]
  mut placements : Map[String, MetalGlyphPlacement]
  mut full_events : Int32
  mut missing_glyphs : Int32
  mut resets : Int32
}

///|
/// One shelf-packed coverage page and its GPU mirror. `dirty` is per page so a
/// frame that only touched page 0 does not re-upload every other page.
priv struct MetalAtlasPage {
  pixels : Array[Byte]
  mut next_x : Int32
  mut next_y : Int32
  mut shelf_height : Int32
  mut dirty : Bool
}

///|
priv struct MetalGlyphPlacement {
  page : Int32
  x : Int32
  y : Int32
  width : Int32
  height : Int32
  bearing_x : Double
  bearing_y : Double
  coverage_only : Bool
}

///|
priv enum MetalGlyphLookup {
  Ready(MetalGlyphPlacement)
  Missing
  Full
}

///|
const METAL_ATLAS_SIZE : Int32 = 1024

///|
const METAL_ATLAS_PADDING : Int32 = 1

///|
const METAL_ATLAS_MAX_PAGES : Int32 = 4

///|
fn new_metal_atlas_page() -> MetalAtlasPage {
  MetalAtlasPage::{
    pixels: Array::make(METAL_ATLAS_SIZE * METAL_ATLAS_SIZE * 4, b'\x00'),
    next_x: 0,
    next_y: 0,
    shelf_height: 0,
    dirty: true,
  }
}

///|
fn new_metal_glyph_atlas() -> MetalGlyphAtlas {
  MetalGlyphAtlas::{
    pages: [new_metal_atlas_page()],
    placements: Map([]),
    full_events: 0,
    missing_glyphs: 0,
    resets: 0,
  }
}

///|
/// Empty every page: cursors back at the origin, placements dropped, pixels
/// zeroed, page 0 marked for re-upload. `cache_key` is documented to carry every
/// raster-affecting field (`moui/render/native_text/text_model.mbt:22-24`), so a
/// placement that is dropped here is re-rasterized on demand rather than reused
/// at the wrong size.
///
/// Only page 0 survives the clear. The host's textures for pages beyond it stay
/// allocated until the context is released — bounded by the same
/// `METAL_ATLAS_MAX_PAGES` — because a route that freed them here would rebuild a
/// 4 MB texture on every frame of a document that keeps crossing the cap.
fn clear_metal_glyph_atlas(atlas : MetalGlyphAtlas) -> Unit {
  let first = atlas.pages[0]
  first.next_x = 0
  first.next_y = 0
  first.shelf_height = 0
  first.pixels.fill(b'\x00')
  first.dirty = true
  atlas.pages = [first]
  atlas.placements = Map([])
}

///|
/// The pages this atlas has grown, in upload order.
fn metal_glyph_atlas_page_count(atlas : MetalGlyphAtlas) -> Int32 {
  atlas.pages.length()
}

///|
fn metal_glyph_atlas_page_dirty(atlas : MetalGlyphAtlas, page : Int32) -> Bool {
  atlas.pages[page].dirty
}

///|
fn metal_glyph_atlas_page_clean(atlas : MetalGlyphAtlas, page : Int32) -> Unit {
  atlas.pages[page].dirty = false
}

///|
fn metal_glyph_atlas_page_bytes(atlas : MetalGlyphAtlas, page : Int32) -> Bytes {
  Bytes::from_array(atlas.pages[page].pixels)
}

///|
fn ensure_metal_glyph(
  atlas : MetalGlyphAtlas,
  cache : @native_text.NativeTextCache,
  key : @native_text.NativeGlyphKey,
) -> MetalGlyphLookup {
  let cache_key = key.cache_key()
  match atlas.placements.get(cache_key) {
    Some(placement) => Ready(placement)
    None =>
      match cache.raster_glyph(key) {
        None => {
          atlas.missing_glyphs = atlas.missing_glyphs + 1
          Missing
        }
        Some(raster) =>
          match place_metal_glyph(atlas, raster.width(), raster.height()) {
            None => {
              atlas.full_events = atlas.full_events + 1
              Full
            }
            Some((page, x, y)) => {
              blit_metal_glyph(atlas.pages[page].pixels, x, y, raster)
              let placement = MetalGlyphPlacement::{
                page,
                x,
                y,
                width: raster.width(),
                height: raster.height(),
                bearing_x: raster.bearing_x().to_double(),
                bearing_y: raster.bearing_y().to_double(),
                coverage_only: raster.format() ==
                @native_text.NativeRasterGlyphFormat::AlphaMask,
              }
              atlas.placements.set(cache_key, placement)
              atlas.pages[page].dirty = true
              Ready(placement)
            }
          }
      }
  }
}

///|
/// Reserve a box, growing the atlas by one page when the last page has no room.
/// `None` means either a box no page can ever hold (wider or taller than the
/// side) or a page set at its cap — the caller's clear-and-rebuild retry is the
/// recovery for the second, and there is no recovery for the first.
fn place_metal_glyph(
  atlas : MetalGlyphAtlas,
  width : Int32,
  height : Int32,
) -> (Int32, Int32, Int32)? {
  if width + METAL_ATLAS_PADDING > METAL_ATLAS_SIZE || height > METAL_ATLAS_SIZE {
    return None
  }
  let last = atlas.pages[atlas.pages.length() - 1]
  match place_metal_glyph_on_page(last, width, height) {
    Some((x, y)) => Some((atlas.pages.length() - 1, x, y))
    None =>
      if atlas.pages.length() >= METAL_ATLAS_MAX_PAGES {
        None
      } else {
        let page = new_metal_atlas_page()
        atlas.pages.push(page)
        // An empty page takes any box the size guard above accepts, so the
        // second arm cannot be reached; it keeps the match total.
        match place_metal_glyph_on_page(page, width, height) {
          Some((x, y)) => Some((atlas.pages.length() - 1, x, y))
          None => None
        }
      }
  }
}

///|
/// Shelf packing inside one page: a box that leaves the row starts a new row at
/// the tallest height seen, and a row that leaves the page is `None`.
fn place_metal_glyph_on_page(
  page : MetalAtlasPage,
  width : Int32,
  height : Int32,
) -> (Int32, Int32)? {
  if width + METAL_ATLAS_PADDING > METAL_ATLAS_SIZE || height > METAL_ATLAS_SIZE {
    return None
  }
  if page.next_x + width + METAL_ATLAS_PADDING > METAL_ATLAS_SIZE {
    page.next_x = 0
    page.next_y = page.next_y + page.shelf_height + METAL_ATLAS_PADDING
    page.shelf_height = 0
  }
  if page.next_y + height > METAL_ATLAS_SIZE {
    return None
  }
  let x = page.next_x
  let y = page.next_y
  page.next_x = page.next_x + width + METAL_ATLAS_PADDING
  page.shelf_height = page.shelf_height.max(height)
  Some((x, y))
}

///|
fn blit_metal_glyph(
  pixels : Array[Byte],
  origin_x : Int32,
  origin_y : Int32,
  raster : @native_text.NativeRasterGlyph,
) -> Unit {
  let width = raster.width()
  let height = raster.height()
  let source = raster.pixels()
  let coverage_only = raster.format() ==
    @native_text.NativeRasterGlyphFormat::AlphaMask
  for row in 0..<height {
    for column in 0..<width {
      let target = ((origin_y + row) * METAL_ATLAS_SIZE + origin_x + column) * 4
      if coverage_only {
        // Coverage goes to alpha with white channels, so the vertex colour
        // tints it and one texture serves every run colour.
        pixels[target] = b'\xff'
        pixels[target + 1] = b'\xff'
        pixels[target + 2] = b'\xff'
        pixels[target + 3] = source[row * width + column]
      } else {
        let red = (row * width + column) * 4
        pixels[target] = source[red]
        pixels[target + 1] = source[red + 1]
        pixels[target + 2] = source[red + 2]
        pixels[target + 3] = source[red + 3]
      }
    }
  }
}
