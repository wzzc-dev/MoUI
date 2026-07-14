///|
/// Error returned by font loaders and loader-backed cache helpers.
pub(all) enum FontLoadError {
  MissingFontData(String)
  FontFileReadFailed(String, String)
  FontParseFailed(String, FontParseError)
} derive(Eq, Debug)

///|
/// Pluggable source of keyed font bytes.
pub(open) trait FontLoader {
  fn load_font_data(Self, String) -> Result[FontData, FontLoadError]
}

///|
/// One file-backed font source registered in a loader.
struct FontFileSource {
  path : String
  font_index : Int
} derive(Eq, Debug)

///|
/// In-memory font loader for tests, embedded assets, and caller-owned bytes.
struct MemoryFontLoader {
  mut fonts : Map[String, FontData]
} derive(Debug)

///|
/// File-backed font loader keyed by caller-provided resource names.
struct FileFontLoader {
  mut sources : Map[String, FontFileSource]
} derive(Debug)

///|
/// Create a file-backed font source.
pub fn FontFileSource::new(
  path : String,
  font_index? : Int = 0,
) -> FontFileSource {
  { path, font_index }
}

///|
/// Return the file path for this source.
pub fn FontFileSource::get_path(self : FontFileSource) -> String {
  self.path
}

///|
/// Return the face index inside the font file.
pub fn FontFileSource::get_font_index(self : FontFileSource) -> Int {
  self.font_index
}

///|
/// Create an empty in-memory font loader.
pub fn MemoryFontLoader::new() -> MemoryFontLoader {
  { fonts: Map([]) }
}

///|
/// Return the number of registered in-memory font entries.
pub fn MemoryFontLoader::len(self : MemoryFontLoader) -> Int {
  self.fonts.length()
}

///|
/// Return whether this loader has no registered font entries.
pub fn MemoryFontLoader::is_empty(self : MemoryFontLoader) -> Bool {
  self.len() is 0
}

///|
/// Return whether this loader has font data for a key.
pub fn MemoryFontLoader::contains(
  self : MemoryFontLoader,
  key : String,
) -> Bool {
  self.fonts.contains(key)
}

///|
/// Register or replace font data for a key.
pub fn MemoryFontLoader::insert(
  self : MemoryFontLoader,
  key : String,
  data : FontData,
) -> FontData {
  self.fonts[key] = data
  data
}

///|
/// Remove a registered in-memory font entry.
pub fn MemoryFontLoader::remove(self : MemoryFontLoader, key : String) -> Unit {
  self.fonts.remove(key)
}

///|
/// Drop all registered in-memory font entries.
pub fn MemoryFontLoader::clear(self : MemoryFontLoader) -> Unit {
  self.fonts = Map([])
}

///|
pub impl FontLoader for MemoryFontLoader with fn load_font_data(self, key) {
  match self.fonts.get(key) {
    Some(data) => Ok(data)
    None => Err(FontLoadError::MissingFontData(key))
  }
}

///|
/// Create an empty file-backed font loader.
pub fn FileFontLoader::new() -> FileFontLoader {
  { sources: Map([]) }
}

///|
/// Return the number of registered file-backed font entries.
pub fn FileFontLoader::len(self : FileFontLoader) -> Int {
  self.sources.length()
}

///|
/// Return whether this loader has no registered file-backed font entries.
pub fn FileFontLoader::is_empty(self : FileFontLoader) -> Bool {
  self.len() is 0
}

///|
/// Return whether this loader has a source for a key.
pub fn FileFontLoader::contains(self : FileFontLoader, key : String) -> Bool {
  self.sources.contains(key)
}

///|
/// Register or replace a file source for a key.
pub fn FileFontLoader::insert(
  self : FileFontLoader,
  key : String,
  source : FontFileSource,
) -> FontFileSource {
  self.sources[key] = source
  source
}

///|
/// Remove a registered file source.
pub fn FileFontLoader::remove(self : FileFontLoader, key : String) -> Unit {
  self.sources.remove(key)
}

///|
/// Drop all registered file sources.
pub fn FileFontLoader::clear(self : FileFontLoader) -> Unit {
  self.sources = Map([])
}

///|
pub impl FontLoader for FileFontLoader with fn load_font_data(self, key) {
  match self.sources.get(key) {
    Some(source) => {
      let loaded : Bytes? = Some(read_file(source.path)) catch { _ => None }
      match loaded {
        Some(data) => Ok(FontData::new(data, font_index=source.font_index))
        None => Err(FontLoadError::FontFileReadFailed(key, source.path))
      }
    }
    None => Err(FontLoadError::MissingFontData(key))
  }
}

///|
/// Load font data from a generic loader.
pub fn[L : FontLoader] load_font_data(
  loader : L,
  key : String,
) -> Result[FontData, FontLoadError] {
  loader.load_font_data(key)
}

///|
/// Load and parse a checked font face from a generic loader.
pub fn[L : FontLoader] load_font_face(
  loader : L,
  key : String,
) -> Result[FontFace, FontLoadError] {
  match loader.load_font_data(key) {
    Err(error) => Err(error)
    Ok(data) =>
      match FontFace::from_data(data) {
        Ok(face) => Ok(face)
        Err(error) => Err(FontLoadError::FontParseFailed(key, error))
      }
  }
}

///|
/// Load and parse a font face on first use, then reuse the cached face.
pub fn[L : FontLoader] FontFaceCache::get_or_load_result(
  self : FontFaceCache,
  key : String,
  loader : L,
) -> Result[FontFaceCacheParseResult, FontLoadError] {
  match self.get(key) {
    Some(face) => Ok({ face, did_parse: false })
    None =>
      match loader.load_font_data(key) {
        Err(error) => Err(error)
        Ok(data) =>
          match FontFace::from_data(data) {
            Ok(face) => Ok({ face: self.insert(key, face), did_parse: true })
            Err(error) => Err(FontLoadError::FontParseFailed(key, error))
          }
      }
  }
}

///|
/// Load and parse a font face on first use, returning just the face.
pub fn[L : FontLoader] FontFaceCache::get_or_load(
  self : FontFaceCache,
  key : String,
  loader : L,
) -> Result[FontFace, FontLoadError] {
  match self.get_or_load_result(key, loader) {
    Ok(result) => Ok(result.get_face())
    Err(error) => Err(error)
  }
}
