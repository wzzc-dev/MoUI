///|
fn text_font_features_theme(font : @core.FontSpec) -> @core.Theme {
  let theme = @core.Theme::neutral()
  theme.with_typography({ ..theme.typography, body: font, })
}

///|
test "text passes letter spacing and features to the text system" {
  let captured : Ref[@core.FontSpec?] = Ref(None)
  let system = @core.TextSystem::new(id="font-feature-probe", measure=input => {
    captured.val = Some(input.font)
    {
      size: @core.Size::new(width=42.0, height=10.0),
      baseline: 8.0,
      caret_positions: [0.0, 10.0, 20.0, 30.0],
    }
  })
  let font = @core.FontSpec::new(size=10.0, letter_spacing=-0.2, features=[
    @core.FontFeature::new(tag="tnum"),
  ])
  let view : @core.View[Unit] = text(
    "abc",
    role=Body,
    theme=text_font_features_theme(font),
  )
  let context : @core.ViewLayoutContext = {
    constraints: @core.Constraints::loose(
      @core.Size::new(width=200.0, height=100.0),
    ),
    child_sizes: [],
    child_flex_weights: [],
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_system: system,
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
  let result = view.layout(context)
  assert_eq(result.size.width, 42.0)
  match captured.val {
    Some(value) => {
      assert_eq(value.letter_spacing, Some(-0.2))
      assert_eq(value.features.length(), 1)
      assert_eq(value.features[0].tag, "tnum")
    }
    None => abort("expected the text system to receive the font")
  }
}
