///|
fn GlyphAtlas::new(width~ : Int, height~ : Int) -> GlyphAtlas {
  {
    width,
    height,
    padding: atlas_padding,
    next_x: 0,
    next_y: 0,
    shelf_height: 0,
    entries: {},
    pixels: Array::make(width * height * 4, b'\x00'),
    dirty: true,
  }
}

///|
fn GlyphAtlas::clear(self : GlyphAtlas) -> Unit {
  self.next_x = 0
  self.next_y = 0
  self.shelf_height = 0
  self.entries = {}
  self.pixels = Array::make(self.width * self.height * 4, b'\x00')
  self.dirty = true
}

///|
fn GlyphAtlas::to_bytes(self : GlyphAtlas) -> Bytes {
  Bytes::from_array(self.pixels)
}

///|
fn GlyphAtlas::ensure_glyph(
  self : GlyphAtlas,
  cache : NativeFontCache,
  key : NativeGlyphKey,
) -> GlyphLookup {
  match self.entries.get(key.cache_key) {
    Some(entry) => GlyphReady(entry)
    None =>
      match cache.text_engine.raster_glyph(cache, key) {
        None => GlyphMissing
        Some(raster) =>
          match self.place_glyph(raster.width, raster.height) {
            None => GlyphAtlasFull
            Some((x, y)) => {
              self.blit_glyph(x, y, raster)
              let entry = {
                x,
                y,
                width: raster.width,
                height: raster.height,
                bearing_x: raster.bearing_x,
                bearing_y: raster.bearing_y,
                format: raster.format,
              }
              self.entries[key.cache_key] = entry
              self.dirty = true
              GlyphReady(entry)
            }
          }
      }
  }
}

///|
fn GlyphAtlas::place_glyph(
  self : GlyphAtlas,
  width : Int,
  height : Int,
) -> (Int, Int)? {
  if width == 0 || height == 0 {
    return Some((0, 0))
  }
  let padded_width = width + self.padding * 2
  let padded_height = height + self.padding * 2
  if padded_width > self.width || padded_height > self.height {
    return None
  }
  if self.next_x + padded_width > self.width {
    self.next_x = 0
    self.next_y = self.next_y + self.shelf_height
    self.shelf_height = 0
  }
  if self.next_y + padded_height > self.height {
    return None
  }
  let x = self.next_x + self.padding
  let y = self.next_y + self.padding
  self.next_x = self.next_x + padded_width
  self.shelf_height = self.shelf_height.max(padded_height)
  Some((x, y))
}

///|
fn GlyphAtlas::blit_glyph(
  self : GlyphAtlas,
  dst_x : Int,
  dst_y : Int,
  raster : NativeRasterGlyph,
) -> Unit {
  match raster.format {
    NativeRasterGlyphFormat::AlphaMask =>
      for y in 0..<raster.height {
        for x in 0..<raster.width {
          let alpha = raster.pixels[y * raster.width + x]
          if alpha != b'\x00' {
            let dst = ((dst_y + y) * self.width + dst_x + x) * 4
            self.pixels[dst] = b'\xff'
            self.pixels[dst + 1] = b'\xff'
            self.pixels[dst + 2] = b'\xff'
            self.pixels[dst + 3] = alpha
          }
        }
      }
    NativeRasterGlyphFormat::ColorRgba =>
      for y in 0..<raster.height {
        for x in 0..<raster.width {
          let src = (y * raster.width + x) * 4
          let alpha = raster.pixels[src + 3]
          if alpha != b'\x00' {
            let dst = ((dst_y + y) * self.width + dst_x + x) * 4
            self.pixels[dst] = raster.pixels[src]
            self.pixels[dst + 1] = raster.pixels[src + 1]
            self.pixels[dst + 2] = raster.pixels[src + 2]
            self.pixels[dst + 3] = alpha
          }
        }
      }
  }
}

///|
