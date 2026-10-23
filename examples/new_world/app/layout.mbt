///|
/// The responsive shell: which panels are on screen, and how wide they are.
///
/// The product is a reading surface with one companion list, so the layout has
/// exactly two columns and three form factors:
///
/// - **wide** (`>= wide_min`): character rail | stage, both centered, with the
///   stage capped at a readable measure;
/// - **medium** (`>= medium_min`): the stage takes the width, and the rail is a
///   toggleable side column (`ToggleRail`);
/// - **compact** (a portrait phone): the stage is a full-screen chat; the rail
///   is a full-screen overlay.
///
/// What used to be a permanent third column (events, memory drafts) is now a
/// drawer (`drawers.mbt`), so no breakpoint has to budget for it.
///
/// The layout is derived from `ViewEnvironment::viewport_size`, so a resize
/// re-derives it on the next frame. It is pure data computed in `view`, never
/// stored on the model: it is a function of the viewport, not player state.

///|
/// Wide-enough-for-two-columns threshold (logical px).
pub let layout_wide_min : Double = 1080.0

///|
/// Wide-enough-for-stage-plus-toggleable-rail threshold.
pub let layout_medium_min : Double = 760.0

///|
/// Below this width the composer buttons stack instead of sharing a row.
pub let layout_compact_controls_min : Double = 520.0

///|
pub(all) enum LayoutMode {
  /// Two columns: character rail | stage.
  Wide
  /// The stage plus a toggleable rail column.
  Medium
  /// One full-screen column; the rail is an overlay.
  Compact
} derive(Eq, Debug)

///|
pub extend LayoutMode with Debug::{to_repr}

///|
pub extend LayoutMode with Eq::{not_equal, equal}

///|
pub fn LayoutMode::is_compact(self : LayoutMode) -> Bool {
  self is Compact
}

///|
/// Column widths of the two-column shell.
///
/// **Why a record instead of loose constants**: the same `app` package must
/// fill a standalone window (Web/macOS) *and* a panel of an arbitrary size
/// when the plugin runs inside Studio. Hardcoded widths make the stage refuse
/// to adapt when the window shrinks.
///
/// The stage has a *maximum* rather than a designed width: a 60-character
/// Chinese dialogue line stretched across a 2,500px monitor reads as a
/// newspaper column, so the stage stops growing at `stage_max` and the block
/// stays centered.
pub(all) struct Layout {
  rail_width : Double
  stage_max : Double
  /// The gutter between the two columns.
  gutter : Double
} derive(Eq, Debug)

///|
pub extend Layout with Debug::{to_repr}

///|
pub extend Layout with Eq::{not_equal, equal}

///|
pub fn Layout::default() -> Layout {
  { rail_width: 300.0, stage_max: 760.0, gutter: 20.0, }
}

///|
/// Scale the two columns to fill `total_width`, keeping their proportions.
///
/// This is what makes the plugin case work: Studio hands the plugin a
/// rectangle, and the layout fills it instead of assuming 300 + 760 + 20.
pub fn Layout::for_width(total_width : Double) -> Layout {
  let base = Layout::default()
  let base_total = base.content_width()
  if base_total <= 0.0 || total_width <= 0.0 {
    return base
  }
  let scale = total_width / base_total
  {
    rail_width: base.rail_width * scale,
    stage_max: base.stage_max * scale,
    gutter: base.gutter * scale,
  }
}

///|
pub fn Layout::content_width(self : Layout) -> Double {
  self.rail_width + self.stage_max + self.gutter
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
  /// The two-column proportions, scaled to the available width. Kept so the
  /// plugin frame and `Layout::for_width` keep meaning what they meant.
  layout : Layout
  /// Width of the stage column for the current mode.
  stage : Double
  /// Width of the character rail (`0` in compact, where it is an overlay).
  rail : Double
  /// Horizontal padding inside the window.
  page_padding : Double
  /// Height of the scene header row (avatar, name, scene title, actions).
  header_height : Double
  /// Width of a side drawer (profile / memory / model / events).
  drawer_width : Double
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
pub fn Screen::for_viewport(width : Double, height : Double) -> Screen {  let safe_width = if width.is_nan() || width <= 0.0 { 1200.0 } else { width }
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
  match mode {
    Wide => {
      // The two-column block sits inside `main_view`'s page padding, so the
      // columns must fit the window *minus* that padding. The stage stops at
      // its designed maximum, so a wide monitor gets a centered reading
      // measure instead of a newspaper column.
      let page_padding = 22.0
      let layout = Layout::for_width(
        (safe_width - page_padding * 2.0).min(Layout::default().content_width()),
      )
      let rail = layout.rail_width
      let stage = (safe_width - page_padding * 2.0 - rail - layout.gutter)
        .min(layout.stage_max)
        .max(320.0)
      {
        width: safe_width,
        height: safe_height,
        mode,
        layout,
        stage,
        rail,
        page_padding,
        header_height: 64.0,
        drawer_width: 360.0,
        tight_controls: false,
      }
    }
    Medium => {
      // The stage takes the width; the rail is a toggleable 300px column.
      let page_padding = 18.0
      let rail = 300.0
      let stage = (safe_width - page_padding * 2.0).max(320.0)
      {
        width: safe_width,
        height: safe_height,
        mode,
        layout: Layout::for_width(safe_width.min(Layout::default().content_width())),
        stage,
        rail,
        page_padding,
        header_height: 64.0,
        drawer_width: 360.0,
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
        layout: Layout::for_width(safe_width.min(Layout::default().content_width())),
        stage,
        rail: 0.0,
        page_padding,
        header_height: 56.0,
        drawer_width: safe_width - page_padding * 2.0,
        tight_controls: safe_width < layout_compact_controls_min,
      }
    }
  }
}
