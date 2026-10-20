///|
/// The responsive shell: which panels are on screen, and how wide they are.
///
/// The product now has three form factors, and the *same* view tree has to serve
/// all of them (Web desktop, Web on a phone in portrait, Studio's plugin panel):
///
/// - **wide** (`>= wide_min`): the three-column workbench — library rail, stage,
///   controls rail;
/// - **medium** (`>= medium_min`): the stage plus one side rail, tabs to switch
///   between the library and the controls;
/// - **compact** (anything narrower, i.e. a portrait phone): a single column with
///   a bottom tab bar. The stage, the library, and the controls each get the full
///   width, because a 310px rail next to a 260px stage is unusable.
///
/// The layout is derived from `ViewEnvironment::viewport_size`, so a resize (a
/// rotated phone, a resized browser window) re-derives it on the next frame. It
/// is pure data computed in `view`, never stored on the model: it is a function
/// of the viewport, not player state.
///
/// `Layout` kept its name and its three column widths so the plugin frame tests
/// and `Layout::for_width` keep meaning what they meant; what changed is that
/// `view` no longer assumes the wide file always fits.

///|
/// Wide-enough-for-three-columns threshold (logical px).
pub let layout_wide_min : Double = 1080.0

///|
/// Wide-enough-for-stage-plus-one-rail threshold.
pub let layout_medium_min : Double = 760.0

///|
/// Below this width the composer buttons stack instead of sharing a row.
pub let layout_compact_controls_min : Double = 520.0

///|
pub(all) enum LayoutMode {
  /// Three columns: library | stage | controls.
  Wide
  /// Two columns: stage plus one rail, switched by the sidebar tabs.
  Medium
  /// One column plus a bottom tab bar.
  Compact
} derive(Eq, Debug)

///|
pub extend LayoutMode with Debug::{to_repr}

///|
pub extend LayoutMode with Eq::{not_equal, equal}

///|
/// Which single-column page a compact layout is showing.
///
/// On a phone there is no room for a persistent tab row of three panels, so the
/// shell shows one of them at a time and the tab bar picks which.
pub(all) enum CompactTab {
  Chat
  Library
  Controls
} derive(Eq, Debug)

///|
pub extend CompactTab with Debug::{to_repr}

///|
pub extend CompactTab with Eq::{not_equal, equal}

///|
pub fn LayoutMode::is_compact(self : LayoutMode) -> Bool {
  self is Compact
}

///|
/// Column widths of the three-column workbench.
///
/// **Why a record instead of three loose constants** (plan P5.1): the same `app`
/// package must be able to fill a standalone window (Web/macOS) *and* a panel of
/// an arbitrary size when the plugin runs inside Studio. Hardcoded widths make
/// the stage refuse to adapt when the window shrinks.
///
/// `Layout::default()` reproduces the original constants exactly, so the plugin
/// frame probes and the ratio test keep their meaning.
pub(all) struct Layout {
  rail_width : Double
  stage_width : Double
  controls_width : Double
  /// The two 20px gutters between the three columns, scaled with them.
  gutter : Double
} derive(Eq, Debug)

///|
pub extend Layout with Debug::{to_repr}

///|
pub extend Layout with Eq::{not_equal, equal}

///|
pub fn Layout::default() -> Layout {
  {
    rail_width: 310.0,
    stage_width: 520.0,
    controls_width: 330.0,
    gutter: 40.0,
  }
}

///|
/// Scale the three columns to fill `total_width`, keeping their proportions.
///
/// This is what makes the plugin case work: Studio hands the plugin a rectangle,
/// and the layout fills it instead of assuming 310+520+330+40 = 1,200 px.
pub fn Layout::for_width(total_width : Double) -> Layout {
  let base = Layout::default()
  // The two 20px gutters are part of the content width, so they must be scaled
  // with the columns or `content_width()` never reaches the target.
  let gutter = 40.0
  let base_total = base.rail_width +
    base.stage_width +
    base.controls_width +
    gutter
  if base_total <= 0.0 || total_width <= 0.0 {
    return base
  }
  let scale = total_width / base_total
  {
    rail_width: base.rail_width * scale,
    stage_width: base.stage_width * scale,
    controls_width: base.controls_width * scale,
    gutter: gutter * scale,
  }
}

///|
pub fn Layout::content_width(self : Layout) -> Double {
  self.rail_width + self.stage_width + self.controls_width + self.gutter
}

///|
/// Everything a view function needs to know about the available space.
///
/// Passed explicitly rather than read from a global: the same model is rendered
/// by the Web page, the macOS window, and (in the plugin) a panel, and a cached
/// "current width" would make one of them render at another's size.
pub(all) struct Screen {
  width : Double
  height : Double
  mode : LayoutMode
  /// The three-column proportions, scaled to the wide width. Kept even in
  /// medium/compact so `Layout::for_width` and the plugin frame keep using it.
  layout : Layout
  /// Width of the content column for the current mode (stage width, or the full
  /// width minus page padding in compact).
  stage : Double
  /// Width of the library rail (medium/wide only; `0` in compact).
  rail : Double
  /// Width of the controls rail (medium/wide only; `0` in compact).
  controls : Double
  /// Horizontal padding inside the window.
  page_padding : Double
  /// Map viewport width.
  map_width : Double
  /// Upper bound on the map's height. The actual height is the scenario's own
  /// aspect ratio fitted to `map_width`, capped here: a map that crops half a
  /// tavern reads as broken, and one that takes 40% of a phone screen leaves no
  /// room for the conversation.
  map_height : Double
  /// True when a control row should wrap instead of overflowing.
  tight_controls : Bool
} derive(Eq, Debug)

///|
pub extend Screen with Debug::{to_repr}

///|
pub extend Screen with Eq::{not_equal, equal}

///|
/// The screen a viewport yields.
///
/// The three modes are width-driven only: height changes the scroll and flex
/// budget (the transcript shrinks, the composer stays pinned) but never moves
/// controls to another column, which would make a short window look like a
/// different product.
pub fn Screen::for_viewport(width : Double, height : Double) -> Screen {
  let safe_width = if width.is_nan() || width <= 0.0 { 1200.0 } else { width }
  let safe_height = if height.is_nan() || height <= 0.0 {
    800.0
  } else {
    height
  }
  let mode = if safe_width >= layout_wide_min {
    Wide
  } else if safe_width >= layout_medium_min {
    Medium
  } else {
    Compact
  }
  // Wide keeps the designed 310/520/330 block centered when there is room to
  // spare, and shrinks it proportionally between the wide threshold and the
  // block's own 1,200px: stretching the columns on a 2,500px monitor would make
  // a 60-character dialogue line read as a newspaper column.
  let designed_total = Layout::default().content_width()
  match mode {
    Wide => {
      // The three-column block sits inside `main_view`'s page padding, so the
      // columns must fit the window *minus* that padding. Scaling to the full
      // width painted the block 44px past the right edge on the default
      // 1200px window and clipped the controls rail's 推进时间 button in half.
      let page_padding = 22.0
      let layout = Layout::for_width(
        (safe_width - page_padding * 2.0).min(designed_total),
      )
      let rail = layout.rail_width
      let stage = layout.stage_width
      let controls = layout.controls_width
      {
        width: safe_width,
        height: safe_height,
        mode,
        layout,
        stage,
        rail,
        controls,
        page_padding: 22.0,
        map_width: stage,
        // A third of the stage is enough to read the whole map; the rest of the
        // column is the conversation, which is the point of the screen.
        map_height: clamp_screen(safe_height * 0.30, 180.0, 300.0),
        tight_controls: false,
      }
    }
    Medium => {
      // Stage plus one 300px rail; the rail is the library, and the controls
      // panel is one tab away rather than squeezed into a strip.
      let page_padding = 18.0
      let rail = 300.0
      let stage = (safe_width - page_padding * 2.0 - rail - 20.0).max(320.0)
      {
        width: safe_width,
        height: safe_height,
        mode,
        layout: Layout::for_width(safe_width.min(designed_total)),
        stage,
        rail,
        controls: rail,
        page_padding,
        map_width: stage,
        map_height: clamp_screen(safe_height * 0.34, 180.0, 300.0),
        tight_controls: false,
      }
    }
    Compact => {
      let page_padding = 12.0
      let stage = (safe_width - page_padding * 2.0).max(240.0)
      {
        width: safe_width,
        height: safe_height,
        mode,
        layout: Layout::for_width(safe_width.min(designed_total)),
        stage,
        rail: 0.0,
        controls: 0.0,
        page_padding,
        map_width: stage,
        // The map is a *peek* on a phone, not a window: 844px of height has to
        // hold the header, the tabs, the map, a readable transcript, and a
        // two-row composer.
        map_height: clamp_screen(safe_height * 0.24, 130.0, 200.0),
        tight_controls: safe_width < layout_compact_controls_min,
      }
    }
  }
}

///|
/// Column widths of the three-stage layout (default instance).
pub let rail_width : Double = 310.0

///|
pub let stage_width : Double = 520.0

///|
pub let controls_width : Double = 330.0

///|
/// Total width of the centered content block: the three rails plus the two
/// 20px gutters between them. The header row is sized to the same total, so
/// both wrap into one visually centered column at any window width.
pub let content_width : Double = rail_width +
  stage_width +
  controls_width +
  40.0

///|
/// Clamp a screen dimension, tolerating NaN (which a host may report before its
/// first real resize).
fn clamp_screen(value : Double, low : Double, high : Double) -> Double {
  if value.is_nan() {
    low
  } else if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}
