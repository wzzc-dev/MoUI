///|
fn declaration_layout(key : DeclarationKey) -> ViewDeclaration {
  ViewDeclaration::channels(
    layout=Exact(key),
    paint=Constant,
    semantics=Constant,
    platform=Constant,
  )
}

///|
fn declaration_paint(key : DeclarationKey) -> ViewDeclaration {
  ViewDeclaration::channels(
    layout=Constant,
    paint=Exact(key),
    semantics=Constant,
    platform=Constant,
  )
}

///|
fn declaration_semantics(key : DeclarationKey) -> ViewDeclaration {
  ViewDeclaration::channels(
    layout=Constant,
    paint=Constant,
    semantics=Exact(key),
    platform=Constant,
  )
}

///|
fn[Msg] modifier_declaration(modifier : ViewModifier[Msg]) -> ViewDeclaration {
  match modifier {
    KeyModifier(_)
    | ClipModifier
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier
    | RepaintBoundaryModifier
    | FocusTrapModifier(_)
    | OnTapMessageModifier(_)
    | OnLongPressMessageModifier(_)
    | OnDoubleTapMessageModifier(_)
    | OnDragMessageModifier(_)
    | OnDragWithFrameMessageModifier(_)
    | OnFileDropMessageModifier(_)
    | KeyboardShortcutModifier(_) => ViewDeclaration::constant()
    PaddingModifier(insets) => declaration_layout(declaration_insets(insets))
    FrameModifier(data) =>
      declaration_layout(
        DeclarationKey::record(type_tag="FrameModifier", fields=[
          ("width", declaration_option_double(data.width)),
          ("height", declaration_option_double(data.height)),
          ("min_width", declaration_option_double(data.min_width)),
          ("min_height", declaration_option_double(data.min_height)),
          ("max_width", declaration_option_double(data.max_width)),
          ("max_height", declaration_option_double(data.max_height)),
        ]),
      )
    FontModifier(font) => declaration_layout(declaration_font(font))
    BackgroundModifier(brush) => declaration_paint(declaration_brush(brush))
    ForegroundModifier(color) => declaration_paint(declaration_color(color))
    CornerRadiusModifier(radius) =>
      declaration_paint(DeclarationKey::double(radius))
    OpacityModifier(opacity) =>
      declaration_paint(DeclarationKey::double(opacity))
    ShadowModifier(style) => declaration_paint(declaration_shadow(style))
    BorderModifier(style) => declaration_paint(declaration_border(style))
    OffsetModifier(dx, dy) =>
      declaration_layout(
        DeclarationKey::record(type_tag="Offset", fields=[
          ("dx", DeclarationKey::double(dx)),
          ("dy", DeclarationKey::double(dy)),
        ]),
      )
    ScaleModifier(sx, sy) =>
      declaration_paint(
        DeclarationKey::record(type_tag="Scale", fields=[
          ("sx", DeclarationKey::double(sx)),
          ("sy", DeclarationKey::double(sy)),
        ]),
      )
    DisabledModifier(disabled) => {
      let key = DeclarationKey::bool(disabled)
      ViewDeclaration::channels(
        layout=Constant,
        paint=Exact(key),
        semantics=Exact(key),
        platform=Exact(key),
      )
    }
    AccessibilityLabelModifier(label) =>
      declaration_semantics(DeclarationKey::string(label))
    SemanticIdModifier(id) =>
      declaration_semantics(DeclarationKey::string(id.value()))
    SemanticsCompositionModifier(composition) =>
      declaration_semantics(
        DeclarationKey::string(
          match composition {
            Transparent => "transparent"
            Boundary => "boundary"
            MergeDescendants => "merge-descendants"
            Hidden => "hidden"
          },
        ),
      )
    SemanticsRoleModifier(role) =>
      declaration_semantics(DeclarationKey::string(role_label(role)))
    SemanticsLevelModifier(level) =>
      declaration_semantics(DeclarationKey::int(level))
    SemanticsUrlModifier(url) =>
      declaration_semantics(DeclarationKey::string(url))
    SemanticsSelectedModifier(selected)
    | SemanticsPressedModifier(selected)
    | SemanticsCheckedModifier(selected)
    | SemanticsExpandedModifier(selected)
    | SemanticsInvalidModifier(selected)
    | SemanticsRequiredModifier(selected)
    | FocusableModifier(selected) =>
      declaration_semantics(DeclarationKey::bool(selected))
    SemanticsDescriptionModifier(description) =>
      declaration_semantics(DeclarationKey::string(description))
    FlexibleModifier(weight)
    | LayoutPriorityModifier(weight)
    | SpacingModifier(weight)
    | AspectRatioModifier(weight) =>
      declaration_layout(DeclarationKey::double(weight))
    AlignModifier(alignment) =>
      declaration_layout(
        DeclarationKey::record(type_tag="Alignment", fields=[
          ("x", DeclarationKey::double(alignment.x)),
          ("y", DeclarationKey::double(alignment.y)),
        ]),
      )
    MainAxisAlignmentModifier(alignment) =>
      declaration_layout(
        DeclarationKey::string(main_axis_alignment_label(alignment)),
      )
    CrossAxisAlignmentModifier(alignment) =>
      declaration_layout(
        DeclarationKey::string(cross_axis_alignment_label(alignment)),
      )
    ThemeModifier(_) | EnvironmentModifier(_) =>
      // Theme ownership is handled by its separate RFC. Until then, complete
      // aggregate changes remain correct by explicitly disabling caching.
      ViewDeclaration::uncacheable()
  }
}
