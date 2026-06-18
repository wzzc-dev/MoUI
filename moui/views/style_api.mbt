///|
pub(all) enum ButtonVariant {
  Primary
  Tonal
  Outline
  Ghost
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
fn ButtonVariant::style(
  self : ButtonVariant,
  theme : @core.Theme,
) -> ButtonStyle {
  match self {
    Primary => ButtonStyle::filled(theme~)
    Tonal => ButtonStyle::tonal(theme~)
    Outline => ButtonStyle::outline(theme~)
    Ghost => ButtonStyle::ghost(theme~)
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
      theme.foreground
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
