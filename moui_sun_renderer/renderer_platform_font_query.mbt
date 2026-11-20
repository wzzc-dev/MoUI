///|
/// Platform font discovery for the Sun CPU raster renderer.
///
/// Linux resolves generic families through fontconfig (`moui_text_providers/fontconfig`),
/// so Sun asks the same source for the same faces: `fc-match` supplies one
/// sans/mono/serif face, `fc-list` is the fallback when a match is unavailable.
/// Windows resolves the faces DirectWrite hands Skia (Segoe UI, Consolas, Times
/// New Roman, then Arial/Georgia/Courier New) from the Windows Fonts directory.
/// Discovery happens in the native stub (`renderer_platform_font_query.c`) and
/// arrives here as one versioned payload; this file only decodes it and keeps
/// the file-byte cache that avoids re-reading the same face for every renderer.
///
/// Payload layout (little-endian i32 lengths):
///   i32 version (2)
///   i32 match_count
///     per match: i32 role, i32 weight, i32 path_len, path bytes,
///                i32 family_len, family bytes
///   i32 list_count
///     per list entry: i32 path_len, path bytes, i32 family_len, family
///
/// role: 0 = sans, 1 = monospace, 2 = serif. `weight` is the CSS weight bucket
/// the face was matched for (100/300/400/600/700/800), which is the same
/// quantisation the Skia fontconfig provider applies, so both renderers pick a
/// bold face at the same weight.
priv enum SunPlatformFontRole {
  Sans
  Monospace
  Serif
}

///|
priv struct SunPlatformFontMatch {
  role : SunPlatformFontRole
  /// CSS weight bucket this face was matched for; 400 is the regular bucket.
  weight : Int32
  path : String
  family : String
}

///|
priv struct SunPlatformFontListEntry {
  path : String
  family : String
}

///|
priv struct SunPlatformFontDiscovery {
  matches : Array[SunPlatformFontMatch]
  entries : Array[SunPlatformFontListEntry]
}

///|
extern "C" fn sun_platform_font_payload() -> Bytes = "moui_sun_platform_font_payload"

///|
/// Decoded font files keyed by path. Renderer construction must stay cheap:
/// without the cache every renderer would re-read and re-parse the same
/// several-hundred-KB faces once per family key.
priv struct SunPlatformFontFileCache {
  files : Map[String, Bytes]
  /// Paths already known to be unreadable, so a missing file is not retried.
  missing : Map[String, Unit]
}

///|
let sun_platform_font_file_cache : Ref[SunPlatformFontFileCache] = Ref({
  files: Map([]),
  missing: Map([]),
})

///|
/// Read a discovered font file once per process. Unreadable paths are
/// remembered as missing and yield `None`; they never raise.
fn sun_platform_font_file_data(path : String) -> Bytes? {
  let cache = sun_platform_font_file_cache.val
  if cache.missing.contains(path) {
    return None
  }
  match cache.files.get(path) {
    Some(data) => Some(data)
    None => {
      let data : Bytes? = Some(@fs.read_file_to_bytes(path)) catch { _ => None }
      match data {
        Some(data) => {
          cache.files.set(path, data)
          Some(data)
        }
        None => {
          cache.missing.set(path, ())
          None
        }
      }
    }
  }
}

///|
fn sun_platform_font_read_string(
  payload : Bytes,
  offset : Int32,
) -> (String, Int32)? {
  if offset < 0 || offset + 4 > payload.length() {
    return None
  }
  let length = @render_common.async_image_read_i32_le(payload, offset)
  if length < 0 || length > payload.length() - offset - 4 {
    return None
  }
  let start = offset + 4
  let end = start + length
  Some((@utf8.decode_lossy(payload[start:end], ignore_bom=false), end))
}

///|
fn sun_platform_font_role(code : Int32) -> SunPlatformFontRole? {
  match code {
    0 => Some(Sans)
    1 => Some(Monospace)
    2 => Some(Serif)
    _ => None
  }
}

///|
/// Decode the native discovery payload. `None` means the payload itself is
/// malformed (wrong version, truncated lengths); a well-formed payload with no
/// matches decodes to empty arrays, which is the "no fontconfig" case.
fn sun_decode_platform_font_payload(
  payload : Bytes,
) -> SunPlatformFontDiscovery? {
  if payload.length() < 8 {
    return None
  }
  let version = @render_common.async_image_read_i32_le(payload, 0)
  if version != 2 {
    return None
  }
  let match_count = @render_common.async_image_read_i32_le(payload, 4)
  if match_count < 0 || match_count > 18 {
    return None
  }
  let matches : Array[SunPlatformFontMatch] = []
  let mut offset = 8
  for _ in 0..<match_count {
    if offset + 4 > payload.length() {
      return None
    }
    let role_code = @render_common.async_image_read_i32_le(payload, offset)
    offset += 4
    match sun_platform_font_role(role_code) {
      None => return None
      Some(role) => {
        if offset + 4 > payload.length() {
          return None
        }
        let weight = @render_common.async_image_read_i32_le(payload, offset)
        offset += 4
        if !sun_platform_font_weight_is_known(weight) {
          return None
        }
        let path_result = sun_platform_font_read_string(payload, offset)
        guard path_result is Some(result) else { return None }
        let (path, after_path) = result
        offset = after_path
        let family_result = sun_platform_font_read_string(payload, offset)
        guard family_result is Some(result) else { return None }
        let (family, after_family) = result
        offset = after_family
        matches.push({ role, weight, path, family, })
      }
    }
  }
  if offset + 4 > payload.length() {
    return None
  }
  let list_count = @render_common.async_image_read_i32_le(payload, offset)
  offset += 4
  if list_count < 0 {
    return None
  }
  let entries : Array[SunPlatformFontListEntry] = []
  for _ in 0..<list_count {
    let path_result = sun_platform_font_read_string(payload, offset)
    guard path_result is Some(result) else { return None }
    let (path, after_path) = result
    offset = after_path
    let family_result = sun_platform_font_read_string(payload, offset)
    guard family_result is Some(result) else { return None }
    let (family, after_family) = result
    offset = after_family
    entries.push({ path, family, })
  }
  if offset != payload.length() {
    return None
  }
  Some({ matches, entries, })
}

///|
/// CSS weight buckets the native stub queries, in ascending order. Keeping the
/// list here (not just in the stub) lets the decoder reject a payload from a
/// stub that drifted, instead of silently mis-registering faces.
fn sun_platform_font_weight_is_known(weight : Int32) -> Bool {
  weight == 100 ||
  weight == 300 ||
  weight == 400 ||
  weight == 600 ||
  weight == 700 ||
  weight == 800
}

///|
fn sun_platform_font_discovery() -> SunPlatformFontDiscovery? {
  sun_decode_platform_font_payload(sun_platform_font_payload())
}
