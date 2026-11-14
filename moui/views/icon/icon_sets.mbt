///|
/// Official icon-set adapter and the SF Symbols name bridge.
///
/// `lucide_icon` draws any icon from the vendored Lucide subset
/// (`resource/icons/lucide.json`, generated into `lucide.generated.mbt`), so an
/// app can use one open icon vocabulary on every platform. `sf_symbol_icon`
/// accepts Apple's SF Symbols names and resolves them to the closest Lucide
/// glyph, which keeps macOS-flavored code portable.
///
/// Native SF Symbols (per-weight Apple artwork via AppKit) is a host
/// capability, not a view-layer one: it needs the macOS window/backend to
/// provide symbol images. Until that host service lands, the adapter is the
/// name bridge plus the vendored vector set, and unknown symbols render
/// nothing (the label still reaches assistive technology).

///|
/// Draw a Lucide icon by name. Unknown names paint nothing; check
/// `lucide_icon_path_data(name)` first when the name comes from user input.
pub fn[Msg] lucide_icon(
  name : String,
  size~ : Double = 20.0,
  color? : @core.Color,
  stroke_width~ : Double = 1.6,
  label~ : String = "",
) -> @core.View[Msg] {
  let path = match lucide_icon_path_data(name) {
    Some(value) => value
    None => ""
  }
  let markup = "<svg viewBox=\"0 0 24 24\"><path d=\"" + path + "\"/></svg>"
  let resolved_label = if label == "" { name } else { label }
  icon_svg(markup, size~, color?, stroke_width~, label=resolved_label)
}

///|
/// True when the vendored subset carries `name`.
pub fn lucide_has(name : String) -> Bool {
  lucide_icon_path_data(name) is Some(_)
}

///|
/// SF Symbols name → Lucide icon name table. Kept as data so the mapping is
/// enumerable (tests verify every target exists in the vendored subset).
let sf_symbol_lucide_pairs : Array[(String, String)] = [
  ("magnifyingglass", "search"),
  ("house", "house"),
  ("house.fill", "house"),
  ("gearshape", "settings"),
  ("gearshape.fill", "settings"),
  ("person", "user"),
  ("person.fill", "user"),
  ("person.2", "users"),
  ("person.2.fill", "users"),
  ("plus", "plus"),
  ("plus.circle", "plus"),
  ("plus.circle.fill", "plus"),
  ("minus", "minus"),
  ("minus.circle", "minus"),
  ("checkmark", "check"),
  ("checkmark.circle", "check"),
  ("checkmark.circle.fill", "check"),
  ("xmark", "x"),
  ("xmark.circle", "x"),
  ("xmark.circle.fill", "x"),
  ("chevron.down", "chevron-down"),
  ("chevron.up", "chevron-up"),
  ("chevron.left", "chevron-left"),
  ("chevron.right", "chevron-right"),
  ("arrow.right", "arrow-right"),
  ("arrow.left", "arrow-left"),
  ("trash", "trash-2"),
  ("trash.fill", "trash-2"),
  ("folder", "folder"),
  ("folder.fill", "folder"),
  ("folder.open", "folder-open"),
  ("doc", "file"),
  ("doc.fill", "file"),
  ("doc.text", "file-text"),
  ("square.and.arrow.down", "download"),
  ("square.and.arrow.up", "upload"),
  ("pencil", "pencil"),
  ("eye", "eye"),
  ("eye.slash", "eye-off"),
  ("lock", "lock"),
  ("lock.fill", "lock"),
  ("lock.open", "unlock"),
  ("bell", "bell"),
  ("bell.fill", "bell"),
  ("calendar", "calendar"),
  ("clock", "clock"),
  ("star", "star"),
  ("star.fill", "star"),
  ("heart", "heart"),
  ("heart.fill", "heart"),
  ("play.fill", "play"),
  ("pause.fill", "pause"),
  ("ellipsis", "more-horizontal"),
  ("ellipsis.vertical", "more-vertical"),
  ("line.3.horizontal", "menu"),
  ("square.grid.2x2", "grid-3x3"),
  ("list.bullet", "list"),
  ("line.3.horizontal.decrease", "filter"),
  ("arrow.clockwise", "refresh-cw"),
  ("arrow.up.right.square", "external-link"),
  ("link", "link"),
  ("envelope", "mail"),
  ("envelope.fill", "mail"),
  ("bubble.left", "message-circle"),
  ("phone", "phone"),
  ("phone.fill", "phone"),
  ("camera", "camera"),
  ("camera.fill", "camera"),
  ("photo", "image"),
  ("video", "video"),
  ("music.note", "music"),
  ("wifi", "wifi"),
  ("battery.100", "battery"),
  ("sun.max", "sun"),
  ("moon", "moon"),
  ("moon.fill", "moon"),
  ("cloud", "cloud"),
  ("cloud.fill", "cloud"),
  ("bolt", "zap"),
  ("bolt.fill", "zap"),
  ("waveform.path.ecg", "activity"),
  ("exclamationmark.triangle", "alert-triangle"),
  ("exclamationmark.circle", "alert-circle"),
  ("info.circle", "info"),
  ("questionmark.circle", "help-circle"),
  ("rectangle.portrait.and.arrow.right", "log-out"),
  ("arrow.right.to.line", "log-in"),
  ("arrow.up.left.and.arrow.down.right", "maximize"),
  ("arrow.down.right.and.arrow.up.left", "minimize"),
  ("arrow.up.and.down.and.arrow.left.and.right", "move"),
  ("sidebar.left", "panel-left"),
  ("sidebar.right", "panel-right"),
  ("rectangle.split.3x1", "columns-3"),
  ("tablecells", "table"),
  ("cylinder.split.1x2", "database"),
  ("server.rack", "server"),
  ("terminal", "terminal"),
  ("chevron.left.forwardslash.chevron.right", "code"),
  ("arrow.triangle.branch", "git-branch"),
  ("shippingbox", "package"),
  ("tag", "tag"),
  ("bookmark", "bookmark"),
  ("bookmark.fill", "bookmark"),
  ("paperplane", "send"),
  ("printer", "printer"),
  ("paperclip", "paperclip"),
  ("mappin", "map-pin"),
  ("safari", "compass"),
  ("globe", "globe"),
  ("shield", "shield"),
  ("shield.fill", "shield"),
  ("key", "key"),
  ("rosette", "award"),
  ("gift", "gift"),
  ("cart", "shopping-cart"),
  ("creditcard", "credit-card"),
  ("dollarsign.circle", "dollar-sign"),
  ("percent", "percent"),
  ("chart.line.uptrend.xyaxis", "trending-up"),
  ("chart.line.downtrend.xyaxis", "trending-down"),
  ("chart.bar", "bar-chart-3"),
  ("chart.pie", "pie-chart"),
  ("chart.xyaxis.line", "line-chart"),
]

///|
let sf_symbol_lucide_table : Map[String, String] = {
  let table : Map[String, String] = Map([])
  for pair in sf_symbol_lucide_pairs {
    table.set(pair.0, pair.1)
  }
  table
}

///|
/// Every SF Symbols name the adapter knows, with its Lucide target.
pub fn sf_symbol_lucide_mappings() -> Array[(String, String)] {
  sf_symbol_lucide_pairs.copy()
}

///|
/// SF Symbols name → Lucide icon name, or `None` when the adapter has no
/// mapping for it.
pub fn sf_symbol_lucide_name(name : String) -> String? {
  sf_symbol_lucide_table.get(name)
}

///|
/// Draw an SF Symbols name through the Lucide adapter. Unknown symbols paint
/// nothing; the label still reaches assistive technology.
pub fn[Msg] sf_symbol_icon(
  name : String,
  size~ : Double = 20.0,
  color? : @core.Color,
  stroke_width~ : Double = 1.6,
  label~ : String = "",
) -> @core.View[Msg] {
  let lucide_name = match sf_symbol_lucide_name(name) {
    Some(value) => value
    None => name
  }
  let resolved_label = if label == "" { name } else { label }
  lucide_icon(lucide_name, size~, color?, stroke_width~, label=resolved_label)
}
