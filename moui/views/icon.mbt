///|
/// Built-in icon glyphs. Each icon is authored on a normalized 24x24 viewBox
/// using stroke-only `PathVerb` data (Lucide/Heroicons outline style) and is
/// scaled to the requested size at paint time. Adding an icon means adding a
/// variant here and a branch in `icon_path` returning its 24x24 verbs.
pub(all) enum IconName {
  Check
  Close
  ChevronDown
  ChevronRight
  ChevronLeft
  Plus
  Minus
  Search
  ArrowRight
  Settings
  Trash
  Info
  // Document operations.
  FileNew
  FolderOpen
  Save
  Clipboard
  // Inline formatting.
  Bold
  Italic
  CodeInline
  Link
  // Block formatting.
  Heading
  ListBullet
  ListOrdered
  ListTask
  Quote
  Table
  // View modes.
  Eye
  Focus
  Columns
  /// Sidebar panel: a rectangle with a narrow left divider (Typora-style).
  Sidebar
} derive(Eq, Debug, ToJson)

///|
/// 24x24 viewBox stroke path data for each icon. Coordinates are in the
/// normalized 0..24 space; `icon` scales them to the final frame.
fn icon_path(name : IconName) -> Array[@core.PathVerb] {
  match name {
    Check =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=13.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=6.0)),
      ]
    Close =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=18.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=18.0)),
      ]
    ChevronDown =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=9.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=15.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=9.0)),
      ]
    ChevronRight =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=18.0)),
      ]
    ChevronLeft =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=15.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=18.0)),
      ]
    Plus =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=19.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
      ]
    Minus =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
      ]
    // Magnifier: circle approximated by four quadratic curves + handle.
    Search =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=11.0, y=11.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=11.0, y=7.0),
          @core.Point::new(x=7.5, y=7.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=4.0, y=7.0),
          @core.Point::new(x=4.0, y=11.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=4.0, y=15.0),
          @core.Point::new(x=7.5, y=15.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=11.0, y=15.0),
          @core.Point::new(x=11.0, y=11.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=14.5, y=14.5)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=20.0)),
      ]
    ArrowRight =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=13.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=13.0, y=18.0)),
      ]
    // Simplified gear: a center circle plus six short radial ticks.
    Settings =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=9.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=12.0, y=7.0),
          @core.Point::new(x=10.0, y=7.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=8.0, y=7.0),
          @core.Point::new(x=8.0, y=10.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=8.0, y=13.0),
          @core.Point::new(x=10.0, y=13.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=12.0, y=13.0),
          @core.Point::new(x=12.0, y=10.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=21.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=3.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=19.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=5.6, y=5.6)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=7.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=17.0, y=17.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.4, y=18.4)),
        @core.PathVerb::MoveTo(@core.Point::new(x=18.4, y=5.6)),
        @core.PathVerb::LineTo(@core.Point::new(x=17.0, y=7.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=7.0, y=17.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.6, y=18.4)),
      ]
    // Trash can: lid + body outline.
    Trash =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=7.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=7.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=17.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=7.0)),
      ]
    // Info: circle + dot + stem.
    Info =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=12.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=12.0, y=8.0),
          @core.Point::new(x=8.0, y=8.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=4.0, y=8.0),
          @core.Point::new(x=4.0, y=12.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=4.0, y=16.0),
          @core.Point::new(x=8.0, y=16.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=12.0, y=16.0),
          @core.Point::new(x=12.0, y=12.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=19.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=11.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=15.0)),
      ]
    // New file: page with a folded corner + a plus.
    FileNew =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=21.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=21.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=3.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=14.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=7.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=14.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=11.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=17.0)),
      ]
    // Folder open: two chevrons forming an open folder.
    FolderOpen =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=19.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=11.0, y=9.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=9.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=19.0)),
      ]
    // Save: floppy disk with a slot and label.
    Save =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=4.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=10.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=10.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=4.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=14.0)),
      ]
    // Clipboard: board with a clip and lines.
    Clipboard =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=4.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=11.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=11.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=15.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=15.0)),
      ]
    // Bold: a thick "B".
    Bold =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=7.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=13.0, y=19.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=17.0, y=19.0),
          @core.Point::new(x=17.0, y=15.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=17.0, y=12.0),
          @core.Point::new(x=14.0, y=12.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=7.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=13.0, y=12.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=17.0, y=12.0),
          @core.Point::new(x=17.0, y=9.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=17.0, y=5.0),
          @core.Point::new(x=13.0, y=5.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=5.0)),
      ]
    // Italic: a slanted "I".
    Italic =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=15.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=19.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=19.0)),
      ]
    // Inline code: angle brackets.
    CodeInline =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=16.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=15.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=16.0)),
      ]
    // Link: two broken chain arcs.
    Link =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=10.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=17.0, y=7.0),
          @core.Point::new(x=14.0, y=4.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=6.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=11.0, y=9.0),
          @core.Point::new(x=9.0, y=11.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=13.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=4.0, y=16.0),
          @core.Point::new(x=7.0, y=19.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=17.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=11.0, y=14.0),
          @core.Point::new(x=13.0, y=12.0),
        ),
      ]
    // Heading: an "H" with an underline emphasizing the heading level.
    Heading =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=19.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=18.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=19.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=21.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=21.0)),
      ]
    // Bullet list: three rows with dot markers.
    ListBullet =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=18.0)),
      ]
    // Ordered list: three rows with ordinal markers (short ticks).
    ListOrdered =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=8.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=20.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=20.0)),
      ]
    // Task list: three rows, the first with a check.
    ListTask =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=3.5, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.5, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.5, y=10.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=3.5, y=10.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=3.5, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.5, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=9.5)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.5, y=6.5)),
      ]
    // Quote: a vertical bar with an indented line.
    Quote =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=7.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=8.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=13.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=13.0)),
      ]
    // Table: a grid with a header row.
    Table =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=10.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=10.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=19.0)),
      ]
    // Eye: an eye outline with a pupil.
    Eye =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=2.0, y=12.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=7.0, y=5.0),
          @core.Point::new(x=12.0, y=5.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=17.0, y=5.0),
          @core.Point::new(x=22.0, y=12.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=17.0, y=19.0),
          @core.Point::new(x=12.0, y=19.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=7.0, y=19.0),
          @core.Point::new(x=2.0, y=12.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=9.0)),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=12.0, y=15.0),
          @core.Point::new(x=12.0, y=15.0),
        ),
        @core.PathVerb::QuadTo(
          @core.Point::new(x=12.0, y=9.0),
          @core.Point::new(x=12.0, y=9.0),
        ),
      ]
    // Focus: a dot ringed by corner brackets.
    Focus =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=4.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=16.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=8.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=20.0, y=16.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=20.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=16.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=12.0)),
      ]
    // Columns: two side-by-side panels (source/preview split).
    Columns =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=19.0)),
      ]
    // Sidebar: rectangle with a narrow left panel divider at ~1/3.
    Sidebar =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=19.0)),
      ]
  }
}

///|
/// Scale a single normalized 24x24 path point into the icon's paint frame.
fn icon_scale_point(
  point : @core.Point,
  origin_x : Double,
  origin_y : Double,
  scale : Double,
) -> @core.Point {
  @core.Point::new(x=origin_x + point.x * scale, y=origin_y + point.y * scale)
}

///|
/// Scale a full 24x24 verb list into the icon's paint frame. `Close` carries
/// no payload and passes through unchanged.
fn icon_scale_verbs(
  verbs : Array[@core.PathVerb],
  origin_x : Double,
  origin_y : Double,
  scale : Double,
) -> Array[@core.PathVerb] {
  let scaled : Array[@core.PathVerb] = []
  for verb in verbs {
    match verb {
      @core.PathVerb::MoveTo(point) =>
        scaled.push(
          @core.PathVerb::MoveTo(
            icon_scale_point(point, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::LineTo(point) =>
        scaled.push(
          @core.PathVerb::LineTo(
            icon_scale_point(point, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::QuadTo(control, end) =>
        scaled.push(
          @core.PathVerb::QuadTo(
            icon_scale_point(control, origin_x, origin_y, scale),
            icon_scale_point(end, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::CubicTo(c1, c2, end) =>
        scaled.push(
          @core.PathVerb::CubicTo(
            icon_scale_point(c1, origin_x, origin_y, scale),
            icon_scale_point(c2, origin_x, origin_y, scale),
            icon_scale_point(end, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::Close => scaled.push(@core.PathVerb::Close)
    }
  }
  scaled
}

///|
/// A vector icon rendered from normalized 24x24 stroke path data. The glyph
/// is scaled to `size` (square) and stroked with `color` at `weight`. Icons
/// are not focusable by default; wrap with `.focusable()` / `.on_click()` for
/// interactive use, or pass them to `button(icon=...)`.
pub fn[Msg] icon(
  name : IconName,
  size? : Double = 20.0,
  color? : @core.Color,
  weight? : Double = 1.6,
) -> @core.View[Msg] {
  let verbs = icon_path(name)
  let label = icon_label(name)
  let resolved_color = match color {
    Some(value) => value
    None => default_theme().palette.foreground
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Icon"),
    revision=() => {
      "icon:\{label}:\{size}:\{view_color_revision(resolved_color)}:\{weight}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=size, height=size)),
      )
    },
    paint=ctx => {
      // Center the 24x24 glyph in the frame and scale uniformly. Use the
      // smaller frame dimension so square icons stay square even if the parent
      // forced a non-square frame.
      let side = view_min_double(ctx.frame.size.width, ctx.frame.size.height)
      let scale = side / 24.0
      let origin_x = ctx.frame.origin.x + (ctx.frame.size.width - side) / 2.0
      let origin_y = ctx.frame.origin.y + (ctx.frame.size.height - side) / 2.0
      let scaled = icon_scale_verbs(verbs, origin_x, origin_y, scale)
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::DrawPath(
          @core.PathSpec::new(
            verbs=scaled,
            stroke=Some(@core.Brush::solid(resolved_color)),
            stroke_width=weight,
          ),
        ),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Text, label~)
    },
  )
}

///|
/// Human-readable label for an icon, used for semantics and revision keys.
fn icon_label(name : IconName) -> String {
  match name {
    Check => "Check"
    Close => "Close"
    ChevronDown => "Chevron down"
    ChevronRight => "Chevron right"
    ChevronLeft => "Chevron left"
    Plus => "Plus"
    Minus => "Minus"
    Search => "Search"
    ArrowRight => "Arrow right"
    Settings => "Settings"
    Trash => "Trash"
    Info => "Info"
    FileNew => "New file"
    FolderOpen => "Open"
    Save => "Save"
    Clipboard => "Clipboard"
    Bold => "Bold"
    Italic => "Italic"
    CodeInline => "Code"
    Link => "Link"
    Heading => "Heading"
    ListBullet => "Bullet list"
    ListOrdered => "Ordered list"
    ListTask => "Task list"
    Quote => "Quote"
    Table => "Table"
    Eye => "Eye"
    Focus => "Focus"
    Columns => "Columns"
    Sidebar => "Sidebar"
  }
}
