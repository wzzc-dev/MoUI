///|
// Platform font discovery: maps CSS-style font specs to concrete faces
// registered with the Sun text system. Split out of renderer_text_draw.mbt to
// keep that file inside its maintenance line budget.

///|
fn SunRasterRenderer::register_font_family_data(
  self : SunRasterRenderer,
  family : @core.FontFamily,
  data : Bytes,
  weight~ : Int32 = 400,
) -> Unit {
  for key in sun_font_family_registration_keys(family, weight) {
    ignore(self.text_system.register_font_bytes(key, data))
  }
  // The face stack a run resolves to depends on the registered fonts.
  self.text_run_cache.clear()
  self.text_run_cache_order = []
}

///|
priv struct SunPlatformFontFace {
  path : String
  /// CSS weight bucket the face was matched for. 400 is the regular bucket and
  /// registers under the plain family keys, so existing lookups still resolve
  /// the regular face.
  weight : Int32
  families : Array[@core.FontFamily]
}

///|
/// Face files bundled at fixed macOS paths, still used by the macOS route.
priv struct SunBundledFontSource {
  path : String
  families : Array[@core.FontFamily]
}

///|
fn SunRasterRenderer::register_default_platform_fonts(
  self : SunRasterRenderer,
) -> Unit {
  for face in sun_default_platform_font_faces() {
    match sun_platform_font_file_data(face.path) {
      Some(data) =>
        for family in face.families {
          for key in sun_font_family_registration_keys(family, face.weight) {
            ignore(self.text_system.register_font_bytes(key, data))
          }
        }
      None => ()
    }
  }
}

///|
/// Platform faces Sun draws with, in registration priority order.
///
/// Linux discovers the explicit candidate families Skia's fontconfig provider
/// resolves, so both renderers draw the same system families at the same weight
/// (see `renderer_platform_font_query.mbt`). Windows adds a symbol role (Segoe UI
/// Symbol) that joins the fallback stack under its own family only, so a check
/// mark or arrow the text families do not cover draws an outline instead of the
/// .notdef box. Bundled macOS paths stay for the macOS route; on Linux they
/// simply do not exist and are skipped. Callers tolerate missing files, so a
/// host without system fonts keeps falling back to placeholder glyphs instead of
/// panicking.
///
/// A weight bucket whose file is the same as the regular one adds nothing: the
/// plain family keys already resolve that file, which is exactly what
/// fontconfig does when a family ships a single face.
fn sun_default_platform_font_faces() -> Array[SunPlatformFontFace] {
  let faces : Array[SunPlatformFontFace] = []
  let grouped : Map[String, Int32] = Map([])
  let regular_roles : Map[Int32, Unit] = Map([])
  let regular_paths : Map[Int32, String] = Map([])
  match sun_platform_font_discovery() {
    Some(discovery) => {
      // The regular bucket owns the plain keys every other bucket falls back
      // to, so collect it first and use it to drop non-distinct weight faces.
      for entry in discovery.matches {
        if entry.weight == 400 {
          let code = sun_platform_font_role_code(entry.role)
          regular_roles.set(code, ())
          regular_paths.set(code, entry.path)
        }
      }
      for entry in discovery.matches {
        if entry.weight != 400 {
          match regular_paths.get(sun_platform_font_role_code(entry.role)) {
            Some(regular_path) => if regular_path == entry.path { continue }
            None => ()
          }
        }
        sun_push_platform_font_face(
          faces,
          grouped,
          entry.path,
          entry.weight,
          sun_platform_role_families(entry.role, entry.family),
        )
      }
      // fc-list 兜底: a role fontconfig could not match directly still gets a
      // same-class face rather than the placeholder path.
      for role in [Sans, Monospace, Serif] {
        if regular_roles.contains(sun_platform_font_role_code(role)) {
          continue
        }
        match sun_platform_font_list_fallback(discovery, role, grouped) {
          Some(entry) =>
            sun_push_platform_font_face(
              faces,
              grouped,
              entry.path,
              400,
              sun_platform_role_families(role, entry.family),
            )
          None => ()
        }
      }
    }
    None => ()
  }
  let bundled : Array[SunBundledFontSource] = [
    {
      path: "/System/Library/Fonts/Supplemental/Arial.ttf",
      families: [
        SystemUi,
        UiSansSerif,
        SansSerif,
        Name("Arial"),
        Name("Helvetica"),
      ],
    },
    {
      path: "/System/Library/Fonts/Supplemental/Courier New.ttf",
      families: [UiMonospace, Monospace, Name("Courier New"), Name("Menlo")],
    },
    {
      path: "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
      families: [UiSerif, Serif, Name("Times New Roman")],
    },
  ]
  for source in bundled {
    sun_push_platform_font_face(
      faces,
      grouped,
      source.path,
      400,
      source.families,
    )
  }
  faces
}

///|
/// Add one face, merging family keys when another role resolved the same file
/// at the same weight: the file is read and parsed once, not once per role.
fn sun_push_platform_font_face(
  faces : Array[SunPlatformFontFace],
  grouped : Map[String, Int32],
  path : String,
  weight : Int32,
  families : Array[@core.FontFamily],
) -> Unit {
  let group_key = path + "#" + weight.to_string()
  match grouped.get(group_key) {
    Some(index) =>
      for family in families {
        faces[index].families.push(family)
      }
    None => {
      grouped.set(group_key, faces.length())
      faces.push({ path, weight, families, })
    }
  }
}

///|
fn sun_platform_font_role_code(role : SunPlatformFontRole) -> Int32 {
  match role {
    Sans => 0
    Monospace => 1
    Serif => 2
    Symbol => 3
  }
}

///|
/// Family keys registered for one fontconfig-discovered face. Generic names
/// mirror what the Skia fontconfig provider maps to `sans-serif`/`serif`/
/// `monospace`, so a `system-ui` request resolves to the same file on both
/// renderers. The symbol role deliberately registers no generic name: its face
/// joins the fallback stack through its own family only, so a symbol font can
/// never take over ordinary text.
fn sun_platform_role_families(
  role : SunPlatformFontRole,
  family : String,
) -> Array[@core.FontFamily] {
  let families : Array[@core.FontFamily] = match role {
    Sans => [SystemUi, UiSansSerif, SansSerif]
    Monospace => [UiMonospace, Monospace]
    Serif => [UiSerif, Serif]
    Symbol => []
  }
  if !family.is_empty() {
    families.push(Name(family))
  }
  families
}

///|
fn sun_platform_font_list_fallback(
  discovery : SunPlatformFontDiscovery,
  role : SunPlatformFontRole,
  grouped : Map[String, Int32],
) -> SunPlatformFontListEntry? {
  let keyword = match role {
    Sans => "sans"
    Monospace => "mono"
    Serif => "serif"
    // Symbol faces are resolved through the candidate table, never through the
    // role fallback list, so no family keyword can match here.
    Symbol => "symbol"
  }
  for entry in discovery.entries {
    if grouped.contains(entry.path + "#400") {
      continue
    }
    if entry.family.to_lower().contains(keyword) {
      return Some(entry)
    }
  }
  None
}

///|
/// fontconfig's weight scale equivalent of an OpenType/CSS weight, mirroring
/// `FcWeightFromOpenType`. Skia resolves a `FontSpec` weight through its system
/// FontMgr on this fontconfig scale, so Sun has to quantise on the same scale
/// before picking a face; quantising on the CSS scale instead made every label
/// at weight 550 (`TypographyScale::desktop` `label`/`control`) resolve regular
/// here while Skia resolved the bold face.
fn sun_font_fontconfig_weight(weight : Int32) -> Double {
  let points : Array[(Double, Double)] = [
    (0.0, 0.0),
    (100.0, 0.0),
    (200.0, 40.0),
    (300.0, 50.0),
    (350.0, 55.0),
    (380.0, 75.0),
    (400.0, 80.0),
    (500.0, 100.0),
    (600.0, 180.0),
    (700.0, 200.0),
    (800.0, 205.0),
    (900.0, 210.0),
    (1000.0, 215.0),
  ]
  let requested = weight.to_double()
  let mut index = 0
  while index + 1 < points.length() && requested > points[index + 1].0 {
    index += 1
  }
  if index + 1 >= points.length() {
    return points[points.length() - 1].1
  }
  let (low_css, low_weight) = points[index]
  let (high_css, high_weight) = points[index + 1]
  if requested <= low_css || high_css <= low_css {
    return low_weight
  }
  let ratio = (requested - low_css) / (high_css - low_css)
  low_weight + (high_weight - low_weight) * ratio
}

///|
/// CSS weight bucket a requested weight renders with: the registered face whose
/// fontconfig weight is closest to the requested weight's fontconfig weight,
/// preferring the heavier bucket on a tie the way fontconfig's matcher breaks
/// the same tie. This is what makes a 550 request draw the bold face on a host
/// whose sans family only ships book and bold.
fn sun_font_weight_bucket(weight : Int32) -> Int32 {
  let requested = sun_font_fontconfig_weight(weight)
  // Bucket CSS weight paired with the fontconfig weight the native stub matched
  // that bucket's face for (see `g_weight_query` in the stub).
  let buckets : Array[(Int32, Double)] = [
    (100, 50.0),
    (300, 75.0),
    (400, 80.0),
    (600, 180.0),
    (700, 200.0),
    (800, 210.0),
  ]
  let mut best = 400
  let mut best_distance = -1.0
  for entry in buckets {
    let (bucket, bucket_weight) = entry
    let distance = (requested - bucket_weight).abs()
    if best_distance < 0.0 ||
      distance < best_distance ||
      (distance == best_distance && bucket > best) {
      best = bucket
      best_distance = distance
    }
  }
  best
}

///|
/// The weight buckets the native stub queries, in ascending order. The bucket
/// list lives here as well as in the stub so a drifted stub is rejected by the
/// decoder instead of silently mis-registering faces.
fn sun_platform_font_weight_buckets() -> Array[Int32] {
  [100, 300, 400, 600, 700, 800]
}

///|
fn sun_font_family_registration_keys(
  family : @core.FontFamily,
  weight : Int32,
) -> Array[String] {
  let names : Array[String] = match family {
    Name(name) => [name, name.to_lower()]
    _ => {
      let css = family.css_name()
      [css, css.to_lower()]
    }
  }
  let keys : Array[String] = []
  if weight == 400 {
    for name in names {
      keys.push(name)
    }
  } else {
    // Non-regular faces get their own keys: registering them under a family
    // name would replace the regular face for every lookup.
    let suffix = "#w" + weight.to_string()
    for name in names {
      keys.push(name + suffix)
    }
  }
  keys
}

///|
fn sun_font_key_weight_bucket(key : String) -> Int32? {
  for weight in sun_platform_font_weight_buckets() {
    if key.has_suffix("#w" + weight.to_string()) {
      return Some(weight)
    }
  }
  None
}

///|
fn SunRasterRenderer::resolved_faces(
  self : SunRasterRenderer,
  font : @core.FontSpec,
) -> Array[@sun_text.FontFace] {
  let faces : Array[@sun_text.FontFace] = []
  let seen : Map[String, Unit] = Map([])
  for key in sun_font_spec_candidate_keys(font) {
    if seen.contains(key) {
      continue
    }
    seen[key] = ()
    match self.text_system.get_font_face(key) {
      Ok(face) => faces.push(face)
      Err(_) => ()
    }
  }
  // Fallbacks, in the order fontconfig would substitute them: faces matched for
  // the requested weight come first, then the plain regular faces, then the
  // other weight variants. Without the first group a family Sun does not have
  // would draw regular text at a bold request.
  let bucket = sun_font_weight_bucket(font.weight)
  let preferred : Array[String] = []
  let regular : Array[String] = []
  let remaining : Array[String] = []
  for key in self.text_system.get_font_keys() {
    if seen.contains(key) {
      continue
    }
    seen[key] = ()
    match sun_font_key_weight_bucket(key) {
      Some(weight) =>
        if weight == bucket {
          preferred.push(key)
        } else {
          remaining.push(key)
        }
      None => regular.push(key)
    }
  }
  for key in preferred {
    match self.text_system.get_font_face(key) {
      Ok(face) => faces.push(face)
      Err(_) => ()
    }
  }
  for key in regular {
    match self.text_system.get_font_face(key) {
      Ok(face) => faces.push(face)
      Err(_) => ()
    }
  }
  for key in remaining {
    match self.text_system.get_font_face(key) {
      Ok(face) => faces.push(face)
      Err(_) => ()
    }
  }
  faces
}

///|
/// Lookup keys for a font spec, weight face first: the exact weight the text
/// asks for wins over the regular face of the same family, the way fontconfig
/// resolves `family:weight=bold` to the bold face rather than the book one.
fn sun_font_spec_candidate_keys(font : @core.FontSpec) -> Array[String] {
  let keys : Array[String] = []
  let bucket = sun_font_weight_bucket(font.weight)
  for family in font.families.families {
    let names : Array[String] = match family {
      Name(name) => [name, name.to_lower()]
      _ => {
        let css = family.css_name()
        [css, css.to_lower()]
      }
    }
    if bucket != 400 {
      for name in names {
        keys.push(name + "#w" + bucket.to_string())
      }
    }
    for name in names {
      keys.push(name)
    }
  }
  keys
}

///|
/// Read one CJK fallback face into the font stack. The default macOS stack
/// (Arial / Courier New / Times New Roman) has no Han coverage, so committed
/// IME text drew placeholder boxes. Candidates are system collections in
/// preference order; paths that do not exist are skipped, so Linux/Windows
/// fall through to their own discovery untouched. Parsed lazily on the first
/// uncovered run, registered under its own family so it only joins the
/// fallback tail and never takes over ordinary Latin text.
fn SunRasterRenderer::register_platform_cjk_fallback(
  self : SunRasterRenderer,
) -> Bool {
  let candidates : Array[(String, String)] = [
    // Arial Unicode first: its CJK glyphs share Arial's sans-serif design, so
    // mixed "Components你好" runs keep one texture and weight. Songti stays as
    // a coverage backstop; Hiragino is CFF (OTTO) and this parser cannot
    // decode it.
    ("/Library/Fonts/Arial Unicode.ttf", "Arial Unicode"),
    ("/System/Library/Fonts/Supplemental/Songti.ttc", "Songti SC"),
  ]
  for candidate in candidates {
    let (path, family) = candidate
    match sun_platform_font_file_data(path) {
      Some(data) => {
        self.register_font_family_data(
          @core.FontFamily::Name(family),
          data,
          weight=400,
        )
        return true
      }
      None => ()
    }
  }
  false
}
