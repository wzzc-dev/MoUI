///|
pub(all) enum ButtonVariant {
  Primary
  Tonal
  Outline
  Ghost
  Subtle
  SubtleBrand
} derive(Eq, Debug, ToJson)

///|
pub(all) enum TextFieldVariant {
  Filled
  Outline
  Plain
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ContainerVariant {
  Base
  Raised
  Overlay
} derive(Eq, Debug, ToJson)

///|
pub(all) enum TextRole {
  Body
  Title
  Caption
  Control
  Mono
  // Extended typography tiers (P2). The legacy Body/Title/Caption/Control
  // variants stay as aliases so existing callers are unaffected.
  Display
  Headline
  Subtitle
  Label
  Overline
} derive(Eq, Debug, ToJson)

///|
pub(all) enum MainAlign {
  Start
  Center
  End
  Between
  Around
  Evenly
} derive(Eq, Debug, ToJson)

///|
pub(all) enum CrossAlign {
  Start
  Center
  End
  Stretch
} derive(Eq, Debug, ToJson)

///|
/// Resolve a button variant into a `ButtonStyle` from the theme's first-class
/// `components.button` token set. This replaces the legacy hand-written
/// `ButtonStyle::filled/tonal/outline/ghost` helpers so a branded design
/// system that sets `Theme.components` once drives every button's appearance
/// without per-control `style=` arguments.
fn ButtonVariant::style(
  self : ButtonVariant,
  theme : @core.Theme,
) -> ButtonStyle {
  let bt = theme.components.button
  let v = self.to_token()
  {
    normal: bt.resolve(v, @core.InteractionState::Normal),
    hovered: bt.resolve(v, @core.InteractionState::Hovered),
    pressed: bt.resolve(v, @core.InteractionState::Pressed),
    disabled: bt.resolve(v, @core.InteractionState::Disabled),
  }
}

///|
fn ButtonVariant::to_token(self : ButtonVariant) -> @core.ButtonVariantToken {
  match self {
    Primary => @core.ButtonVariantToken::Primary
    Tonal => @core.ButtonVariantToken::Tonal
    Outline => @core.ButtonVariantToken::Outline
    Ghost => @core.ButtonVariantToken::Ghost
    Subtle => @core.ButtonVariantToken::Subtle
    SubtleBrand => @core.ButtonVariantToken::SubtleBrand
  }
}

///|
fn TextFieldVariant::style(
  self : TextFieldVariant,
  theme : @core.Theme,
) -> TextFieldStyle {
  match self {
    Filled => TextFieldStyle::filled(theme~)
    Outline => TextFieldStyle::outline(theme~)
    Plain => {
      let base = TextFieldStyle::filled(theme~)
      let clear = @core.Brush::solid(
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      )
      let normal = {
        ..base.normal,
        background: clear,
        border: None,
        radius: 0.0,
      }
      { ..base, normal, focused: normal }
    }
  }
}

///|
fn ContainerVariant::style(
  self : ContainerVariant,
  theme : @core.Theme,
) -> SurfaceStyle {
  match self {
    Base => SurfaceStyle::default(theme~)
    Raised => SurfaceStyle::raised(theme~)
    Overlay =>
      {
        ..SurfaceStyle::default(theme~),
        brush: theme.surface_brush(@core.SurfaceLevel::Overlay),
        level: @core.SurfaceLevel::Overlay,
      }
  }
}

///|
fn TextRole::font(self : TextRole, theme : @core.Theme) -> @core.FontSpec {
  match self {
    Body => theme.typography.body
    Title => theme.typography.title
    Caption => theme.typography.caption
    Control => theme.typography.control
    Mono =>
      { ..theme.typography.body, families: @core.FontFamilyStack::monospace() }
    Display => theme.typography.display
    Headline => theme.typography.headline
    Subtitle => theme.typography.subtitle
    Label => theme.typography.label
    Overline => theme.typography.overline
  }
}

///|
fn TextRole::color(self : TextRole, theme : @core.Theme) -> @core.Color {
  match self {
    Caption | Overline => theme.palette.muted
    Body | Title | Control | Mono | Display | Headline | Subtitle | Label =>
      theme.palette.foreground
  }
}

///|
fn MainAlign::core(self : MainAlign) -> @core.MainAxisAlignment {
  match self {
    Start => @core.MainAxisAlignment::MainStart
    Center => @core.MainAxisAlignment::MainCenter
    End => @core.MainAxisAlignment::MainEnd
    Between => @core.MainAxisAlignment::SpaceBetween
    Around => @core.MainAxisAlignment::SpaceAround
    Evenly => @core.MainAxisAlignment::SpaceEvenly
  }
}

///|
fn CrossAlign::core(self : CrossAlign) -> @core.CrossAxisAlignment {
  match self {
    Start => @core.CrossAxisAlignment::CrossStart
    Center => @core.CrossAxisAlignment::CrossCenter
    End => @core.CrossAxisAlignment::CrossEnd
    Stretch => @core.CrossAxisAlignment::CrossStretch
  }
}
