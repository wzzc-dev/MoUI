///|
/// App-registered embedded font: the family it was registered under plus the
/// Skia typeface created from the font data.
priv struct SkiaEmbeddedFont {
  family : @core.FontFamily
  typeface : @skia_native.Typeface
}

///|
/// Registry of fonts registered via `@core.TextSystem::register_font_data`.
/// Renderer-global so multiple text systems share one registry; later
/// registrations of the same family replace earlier ones.
let embedded_fonts : Ref[Array[SkiaEmbeddedFont]] = Ref([])

///|
/// Registers in-memory font data under a family. The typeface is created
/// eagerly so invalid data fails at registration time, and it is registered
/// with the native side so paragraph layout can resolve the family by name.
fn skia_register_font_data(family : @core.FontFamily, data : Bytes) -> Unit {
  let family_alias = skia_embedded_font_alias(family)
  match @skia_native.Typeface::register_data(family_alias, data) {
    Some(typeface) => {
      embedded_fonts.val = embedded_fonts.val.filter(fn(existing) {
        existing.family != family
      })
      embedded_fonts.val.push({ family, typeface })
    }
    None => ()
  }
}

///|
/// Returns the registered typeface for `font` when any family in the font
/// spec's family stack matches a registered embedded font. The font spec's
/// own order wins: the first matching registered family is used.
fn skia_typeface_from_embedded(font : @core.FontSpec) -> @skia_native.Typeface? {
  for family in font.families.families {
    for embedded in embedded_fonts.val {
      if embedded.family == family {
        return Some(embedded.typeface)
      }
    }
  }
  None
}

///|
/// Converts a font spec's variation axes into native (tag, value) pairs.
fn skia_variation_pairs(font : @core.FontSpec) -> Array[(Bytes, Float)] {
  font.variations.map(fn(variation) {
    (
      @utf8.encode(variation.axis[:], bom=false),
      Float::from_double(variation.value),
    )
  })
}

///|
/// Family alias used for native registration: `Name(name)` registers the
/// literal name; generic families register their first concrete candidate
/// so a `FontSpec` using the same generic family resolves the embedded font.
fn skia_embedded_font_alias(family : @core.FontFamily) -> Bytes {
  let candidates = skia_font_family_candidates(family)
  if candidates.is_empty() {
    b""
  } else {
    @utf8.encode(candidates[0][:], bom=false)
  }
}
