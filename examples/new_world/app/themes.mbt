///|
/// The two appearances: 宣纸 (paper) and 墨蓝 (ink).
///
/// The product's look is "cold Chinese, low saturation, room to breathe": a
/// visual-novel reading surface, not a game HUD. Paper is the default — a
/// warm off-white page with ink-grey text and a mist-blue accent; ink is the
/// same design at night, a dark blue-black room with moon-white text. Both
/// are built through the framework's public palette factory
/// (`ColorPalette::from_seed`) plus two hand-set roles the factory derives
/// only approximately: `secondary` (玉) and `warning` (金).
///
/// Switching is a model field (`ModelConfig::appearance`, persisted to the
/// library's `config.json`) wrapped once at the view root with
/// `View::theme`: the TEA loop rebuilds the tree every frame, so the whole
/// product re-skins without any provider event.

///|
/// The two hand-tuned appearances.
pub(all) enum Appearance {
  Paper
  Ink
} derive(Eq, Debug)

///|
pub extend Appearance with Debug::{to_repr}

///|
pub extend Appearance with Eq::{not_equal, equal}

///|
/// The stable string an appearance serializes to (config.json).
pub fn Appearance::wire(self : Appearance) -> String {
  match self {
    Paper => "paper"
    Ink => "ink"
  }
}

///|
/// Decode the stored appearance; anything unknown reads as paper.
pub fn appearance_from_wire(text : String) -> Appearance {
  match text.trim().to_lower() {
    "ink" => Ink
    _ => Paper
  }
}

///|
/// The palette the scheme's semantic colors start from. 雾蓝 seeds every
/// derived role (containers, on-colors, focus); 墨灰 neutrals are set by
/// hand because the factory's greys are colder than 宣纸 wants.
fn palette_paper() -> @views.ColorPalette {
  let seeded = @views.ColorPalette::from_seed(
    primary=@graphics.Color::rgba(r=0.357, g=0.478, b=0.600),
    @state.ColorScheme::Light,
    background=@graphics.Color::rgba(r=0.961, g=0.945, b=0.910),
    foreground=@graphics.Color::rgba(r=0.180, g=0.173, b=0.157),
    surface=@graphics.Color::rgba(r=0.980, g=0.973, b=0.949),
    surface_variant=@graphics.Color::rgba(r=0.929, g=0.906, b=0.851),
    outline=@graphics.Color::rgba(r=0.788, g=0.761, b=0.706),
    muted=@graphics.Color::rgba(r=0.431, g=0.416, b=0.380),
  )
  // 玉 rides on `secondary`; 金 rides on `warning` (the framework has no
  // separate "accent" role, and 金 must stay rare enough to live there);
  // 朱红 replaces the factory's colder red on `error`/`danger`.
  {
    ..seeded,
    secondary: jade_paper(),
    warning: gold_paper(),
    error: vermilion_paper(),
    danger: vermilion_paper(),
  }
}

///|
/// The night palette: 墨蓝 ground, 月白 text, brighter 雾蓝/玉/金 so they
/// still read on a dark surface.
fn palette_ink() -> @views.ColorPalette {
  let seeded = @views.ColorPalette::from_seed(
    primary=@graphics.Color::rgba(r=0.498, g=0.639, b=0.769),
    @state.ColorScheme::Dark,
    background=@graphics.Color::rgba(r=0.063, g=0.094, b=0.125),
    foreground=@graphics.Color::rgba(r=0.910, g=0.902, b=0.875),
    surface=@graphics.Color::rgba(r=0.086, g=0.129, b=0.169),
    surface_variant=@graphics.Color::rgba(r=0.122, g=0.173, b=0.220),
    outline=@graphics.Color::rgba(r=0.180, g=0.239, b=0.302),
    muted=@graphics.Color::rgba(r=0.541, g=0.576, b=0.627),
  )
  {
    ..seeded,
    secondary: jade_ink(),
    warning: gold_ink(),
    error: vermilion_ink(),
    danger: vermilion_ink(),
  }
}

///|
/// 玉, paper: a desaturated green used for calm accents.
fn jade_paper() -> @graphics.Color {
  @graphics.Color::rgba(r=0.482, g=0.663, b=0.561)
}

///|
/// 玉, ink: the same hue lifted for dark surfaces.
fn jade_ink() -> @graphics.Color {
  @graphics.Color::rgba(r=0.561, g=0.761, b=0.706)
}

///|
/// 金, paper: the rare warm accent (pinned memories, warm scenes).
fn gold_paper() -> @graphics.Color {
  @graphics.Color::rgba(r=0.706, g=0.541, b=0.235)
}

///|
/// 金, ink.
fn gold_ink() -> @graphics.Color {
  @graphics.Color::rgba(r=0.788, g=0.643, b=0.361)
}

///|
/// 朱红, paper: the rare danger accent (destructive row actions, tense mood).
fn vermilion_paper() -> @graphics.Color {
  @graphics.Color::rgba(r=0.706, g=0.263, b=0.227)
}

///|
/// 朱红, ink: lifted so it still reads on 墨蓝.
fn vermilion_ink() -> @graphics.Color {
  @graphics.Color::rgba(r=0.851, g=0.412, b=0.361)
}

///|
/// The theme one appearance resolves to. Built through the public `theme`
/// builder so every derived token (surfaces, controls, motion) follows the
/// framework's own resolver instead of a hand-written second theme.
pub fn app_theme(appearance : Appearance) -> @moui.Theme {
  @views.theme(
    scheme=match appearance {
      Paper => @state.ColorScheme::Light
      Ink => @state.ColorScheme::Dark
    },
    palette=match appearance {
      Paper => palette_paper()
      Ink => palette_ink()
    },
    // Reading is the product: the transcript is long-form Chinese prose, so
    // the body tier sits a half-step above the control default.
    typography={
      let base = @views.default_theme().typography
      { ..base, body: @text.FontSpec::new(size=16.5, weight=400), }
    },
  )
}

///|
/// The theme the stored appearance string asks for. The convenience views
/// use: one call from `ModelConfig::appearance` to a drawable theme.
pub fn app_theme_for(appearance : String) -> @moui.Theme {
  app_theme(appearance_from_wire(appearance))
}

///|
/// The accent colour a scene mood paints with: the scene header's hairline,
/// the ambient map's tint, the pinned-memory pin. 金/朱红 stay rare — warm
/// and tense are the only moods that may spend them, and only as accents.
pub fn mood_accent(
  theme : @moui.Theme,
  variant : MoodVariant,
) -> @graphics.Color {
  match variant {
    Calm => theme.palette.secondary
    Tense => theme.palette.danger
    Warm => theme.palette.warning
    Cold => theme.palette.primary
    Mysterious => theme.palette.primary.darken(0.25)
  }
}

///|
/// The compact row-action theme: the caller's palette with shrunk metrics.
///
/// A `button` treats `height` as a *minimum*, so the half-height row actions
/// (‹ › 改 删 分叉) need smaller spacing and label metrics, not a smaller
/// height. The palette stays the caller's, so row actions follow the
/// appearance instead of the old hardcoded default.
pub fn compact_action_theme(theme : @moui.Theme) -> @moui.Theme {
  let label = @text.FontSpec::new(size=10.5, weight=600)
  theme
  .with_spacing_scale({ xs: 1.0, sm: 1.0, md: 8.0, lg: 10.0, xl: 16.0, })
  .with_typography({ ..theme.typography, label, control: label, })
}

///|
/// Ghost geometry with the palette's danger colour as the foreground.
///
/// A `ButtonStyle` cannot read the environment theme at paint time, so the
/// colour is chosen here, from the caller's palette: a red *label* stays
/// legible in both schemes, where a hardcoded red *fill* would not.
pub fn destructive_ghost_style(theme : @moui.Theme) -> @views.ButtonStyle {
  let danger = theme.palette.danger
  let transparent = @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  let border = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(danger.multiply_alpha(0.45)),
    width=1.0,
  )
  let normal = @views.new_control_state_style(
    foreground=danger,
    background=@graphics.Brush::solid(transparent),
    border~,
    radius=6.0,
  )
  let hovered = @views.new_control_state_style(
    foreground=danger,
    background=@graphics.Brush::solid(danger.multiply_alpha(0.10)),
    border~,
    radius=6.0,
  )
  let pressed = @views.new_control_state_style(
    foreground=danger,
    background=@graphics.Brush::solid(danger.multiply_alpha(0.18)),
    border~,
    radius=6.0,
  )
  let disabled = @views.new_control_state_style(
    foreground=danger.multiply_alpha(0.38),
    background=@graphics.Brush::solid(transparent),
    radius=6.0,
  )
  @views.ButtonStyle::new(normal~, hovered~, pressed~, disabled~)
}
