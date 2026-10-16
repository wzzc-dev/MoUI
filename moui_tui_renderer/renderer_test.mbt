/// S2 输出证据:ANSI 增量、降级诊断与 provider 门禁。
/// 这三件事决定终端路径能不能长期可用:重画必须是行级增量、
/// 画不出来的东西必须点名、绑定失败必须在 bind 阶段就说清。

///|
fn sample_tree() -> (@core.SemanticsNode, Array[@core.SemanticsNode]) {
  let items = [
    node(
      2UL,
      role=@core.SemanticsRole::Text,
      frame=rect(8.0, 16.0, 100.0, 16.0),
      label="alpha",
    ),
    node(
      3UL,
      role=@core.SemanticsRole::Text,
      frame=rect(8.0, 32.0, 100.0, 16.0),
      label="beta",
    ),
    node(
      4UL,
      role=@core.SemanticsRole::Text,
      frame=rect(8.0, 48.0, 100.0, 16.0),
      label="gamma",
    ),
  ]
  let root = container(
    1UL,
    frame=rect(0.0, 0.0, 160.0, 96.0),
    title="Files",
    children=items.map(n => n.node_id),
  )
  (root, [root] + items)
}

///|
fn sample_root() -> @core.SemanticsNode {
  node(
    1UL,
    role=@core.SemanticsRole::Group,
    frame=rect(0.0, 0.0, 160.0, 96.0),
    label="Root",
  )
}

///|
fn status_of(
  caps : Array[@render.RendererBackendFeatureCapability],
  feature : @render.RendererFeature,
) -> @render.RendererFeatureStatus? {
  for cap in caps {
    if cap.feature == feature {
      return Some(cap.status)
    }
  }
  None
}

///|
test "an unchanged frame emits zero bytes" {
  let (root, nodes) = sample_tree()
  let (sink, box) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  let first = renderer.render_frame(semantics_frame(nodes~, root~))
  assert_true(first.presented)
  assert_eq(box.chunks.length(), 1)
  println("\nfirst frame bytes: \{box.chunks[0].length()}")
  let second = renderer.render_frame(semantics_frame(nodes~, root~))
  // 内容没变就不该重画终端:presented=false 是增量通路生效的证据,不是失败
  assert_false(second.presented)
  assert_eq(box.chunks.length(), 1)
  assert_eq(renderer.present_count(), 1)
  assert_eq(renderer.frame_count(), 2)
}

///|
test "dropping a node repaints only the row it left behind" {
  let (root, nodes) = sample_tree()
  let (sink, box) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes~, root~)))
  let shrunk = [root, nodes[1], nodes[2]]
  ignore(renderer.render_frame(semantics_frame(nodes=shrunk, root~)))
  assert_eq(box.chunks.length(), 2)
  let bytes = box.chunks[1]
  println("\ndelta bytes: \{bytes}")
  // 只有 gamma 那一行(屏幕第 4 行)需要重画,其余行一个字节都不出
  assert_eq(count_occurrences(bytes, ";1H"), 1)
  assert_true(bytes.contains("[4;1H"))
  assert_true(bytes.contains("[2K"))
  assert_false(bytes.contains("[2J"))
  // 行里只剩容器边框:条目擦干净,兄弟笔画不能被误伤
  assert_false(renderer.line_text(3).contains("gamma"))
  assert_eq(cell_at(renderer, 3, 0), '│')
  assert_eq(cell_at(renderer, 3, 19), '│')
  assert_true(renderer.line_text(1).contains("alpha"))
}

///|
test "changing one line repaints one line" {
  let (root, nodes) = sample_tree()
  let (sink, box) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes~, root~)))
  let renamed_item = relabeled(nodes[2], label="BETA")
  let renamed = [root, nodes[1], renamed_item, nodes[3]]
  ignore(renderer.render_frame(semantics_frame(nodes=renamed, root~)))
  let bytes = box.chunks[1]
  assert_eq(count_occurrences(bytes, ";1H"), 1)
  assert_true(bytes.contains("[3;1H"))
  assert_true(renderer.line_text(2).contains("BETA"))
}

///|
test "resize rebuilds the whole screen instead of leaving residue" {
  let (root, nodes) = sample_tree()
  let (sink, box) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes~, root~)))
  renderer.resize(metrics(240.0, 96.0))
  assert_eq(renderer.cols(), 30)
  assert_eq(renderer.rows(), 6)
  ignore(renderer.render_frame(semantics_frame(nodes~, root~)))
  let bytes = box.chunks[1]
  // 尺寸变化 → 整屏标脏 → 必须先清屏,否则缩窗后右侧留残影
  assert_true(bytes.contains("\u{1b}[2J"))
  assert_eq(count_occurrences(bytes, ";1H"), 6)
  assert_true(box.total() > bytes.length())
}

///|
/// 缩窗重排必须重画"新布局的行",而不是旧栅格。
///
/// `TermScreen::resize` 走终端语义:缩高时把顶部行推进回看缓冲。投影器却把
/// `line_at(y)` 的第 `y` 行当可视行用,回看缓冲一旦非空,编码出去的就全是
/// 旧布局的快照 —— 终端收到的是上一版界面,栅格里却是这一版的。
/// 这里用"旧标签不该出现、新标签必须出现"把两件事钉住。
/// 放弃的方案:靠 `rebuild` 分支的 `ESC[2J` 加帧末清扫 —— 清屏由终端做了,
/// 但残格仍在栅格里,逐行 `runs()` 照旧把它们编码出去,清屏等于白清。
test "a shrink repaints the new grid, not the old one" {
  let (root, nodes) = sample_tree()
  let (sink, box) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes~, root~)))
  renderer.resize(metrics(160.0, 48.0))
  assert_eq(renderer.rows(), 3)
  let renamed = relabeled(nodes[1], label="omega")
  let moved = [root, renamed, nodes[2], nodes[3]]
  ignore(renderer.render_frame(semantics_frame(nodes=moved, root~)))
  let bytes = box.chunks[1]
  assert_true(bytes.contains("\u{1b}[2J"))
  assert_true(bytes.contains("omega"))
  assert_false(bytes.contains("alpha"))
  // gamma 现在落在可视区之外:它那一行只能留下边框,不能留下字。
  assert_false(bytes.contains("gamma"))
  assert_true(renderer.line_text(1).contains("omega"))
}

///|
/// 高亮带只改 attrs、不认领格子,归属清扫永远轮不到它 —— 带一移走,
/// 空格子上的反白就永久留在屏上(实测 2026-10-15:初始选中行的色块在
/// 选中移走之后一步不动)。回归:条目行自己不写字,它的整行反白带
/// 就是最纯粹的残留载体;带移到别处时,被放弃的那一行必须整行重发,
/// 且下一帧回到零字节(清扫是一次性的,不能把每个空帧都变成重绘)。
test "a band that moves away rewrites the cells it vacated" {
  let root = container(1UL, frame=rect(0.0, 0.0, 160.0, 96.0), title="Files", children=[
    nid(2UL),
    nid(3UL),
  ])
  // 条目行(Item)不写任何字形:行里每一个格子都是无归属的空格,
  // 旧实现的输入增量对它们无能为力,这是残留的唯一藏身处。
  let head = node(
    2UL,
    role=@core.SemanticsRole::ListItem,
    frame=rect(8.0, 16.0, 100.0, 16.0),
    state=state(selected=true),
  )
  let tail = node(
    3UL,
    role=@core.SemanticsRole::ListItem,
    frame=rect(8.0, 48.0, 100.0, 16.0),
    state=state(selected=false),
  )
  let (sink, box) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(
    renderer.render_frame(semantics_frame(nodes=[root, head, tail], root~)),
  )
  // 选中挪到第二条行:第一条行的带必须整行重发
  let head_dropped = node(
    2UL,
    role=@core.SemanticsRole::ListItem,
    frame=rect(8.0, 16.0, 100.0, 16.0),
    state=state(selected=false),
  )
  let tail_selected = node(
    3UL,
    role=@core.SemanticsRole::ListItem,
    frame=rect(8.0, 48.0, 100.0, 16.0),
    state=state(selected=true),
  )
  let delta = renderer.render_frame(
    semantics_frame(nodes=[root, head_dropped, tail_selected], root~),
  )
  assert_true(delta.presented)
  let bytes = box.chunks[1]
  // 第二条行拿到新带(第 4 行);被放弃的第 2 行字符一个没变,
  // 老实现因此一格都不发 —— 残留就躲在这个"零字节"里。
  assert_true(count_occurrences(bytes, ";1H") == 2)
  assert_true(bytes.contains("[2;1H"))
  assert_true(bytes.contains("[4;1H"))
  // 再来一帧同样的内容:清扫不能抖,不变帧必须回到零字节。
  let stable = renderer.render_frame(
    semantics_frame(nodes=[root, head_dropped, tail_selected], root~),
  )
  assert_false(stable.presented)
}

///|
test "pixel-only commands are named in diagnostics, never silently dropped" {
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::DrawImage({
      source: "banner.png",
      frame: rect(0.0, 0.0, 80.0, 16.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(verbs=[@core.PathVerb::Close, @core.PathVerb::Close]),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(name="glow", frame=rect(0.0, 0.0, 8.0, 8.0)),
    ),
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=@core.RoundedRect::new(rect=rect(0.0, 0.0, 8.0, 8.0)),
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0),
      ),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(4.0)),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(rect=rect(0.0, 0.0, 8.0, 8.0)),
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=0.0, y=0.0),
        end=@core.Point::new(x=8.0, y=8.0),
        start_color=@core.Color::rgba(r=1.0, g=0.0, b=0.0),
        end_color=@core.Color::rgba(r=0.0, g=0.0, b=1.0),
      ),
    ),
    @core.DrawCommand::StrokeRoundedRectBrush(
      @core.RoundedRect::new(rect=rect(0.0, 0.0, 8.0, 8.0)),
      @core.Brush::Solid(@core.Color::rgba(r=0.0, g=1.0, b=0.0)),
      1.0,
    ),
  ]
  let views : Array[@core.PlatformViewPlacement] = [
    @core.PlatformViewPlacement::new(
      id="map-1",
      kind="web_view",
      frame=rect(0.0, 0.0, 80.0, 80.0),
    ),
  ]
  let root = sample_root()
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  let frame = semantics_frame(
    nodes=[root],
    root~,
    commands~,
    platform_views=views,
  )
  ignore(renderer.render_frame(frame))
  let log = renderer.diagnostics()
  let listed = sources(log).join(", ")
  println("\ndegrade sources: \{listed}")
  for
    expected in [
      "draw-image", "draw-path", "draw-shader-effect", "draw-shadow", "push-filter",
      "gradient-brush", "platform-view",
    ] {
    assert_true(has_source(log, expected))
  }
  match log.find("draw-path") {
    Some(record) => assert_true(record.detail.contains("2"))
    None => fail("expected a draw-path record")
  }
  match log.find("platform-view") {
    Some(record) => assert_true(record.detail.contains("web_view (map-1)"))
    None => fail("expected a platform-view record")
  }
  // 纯色画刷不是渐变,不能误报;文本命令本身可投影,不该出现在降级里
  assert_false(listed.contains("draw-text"))
  match log.find("gradient-brush") {
    Some(record) => assert_eq(record.count, 1)
    None => fail("expected exactly one gradient-brush record")
  }
}

///|
test "unprojectable roles stay visible as placeholders" {
  let root = node(
    1UL,
    role=@core.SemanticsRole::Group,
    frame=rect(0.0, 0.0, 160.0, 96.0),
    children=[nid(2UL), nid(3UL)],
  )
  let picture = node(
    2UL,
    role=@core.SemanticsRole::Image,
    frame=rect(8.0, 16.0, 80.0, 32.0),
    label="banner",
  )
  let page = node(
    3UL,
    role=@core.SemanticsRole::WebView,
    frame=rect(8.0, 48.0, 80.0, 32.0),
    label="docs",
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(
    renderer.render_frame(semantics_frame(nodes=[root, picture, page], root~)),
  )
  let lines : Array[String] = []
  for y in 0..<renderer.rows() {
    lines.push(renderer.line_text(y))
  }
  println("\n===== placeholders =====\n\{grid(lines)}")
  // 不允许静默消失:占位格必须看得见,诊断必须点名
  assert_true(lines[1].contains("[image]"))
  assert_true(lines[3].contains("[web-view]"))
  assert_true(has_source(renderer.diagnostics(), "role-image"))
  assert_true(has_source(renderer.diagnostics(), "role-web-view"))
}

///|
test "a leaf without text still leaves a cell" {
  let root = node(
    1UL,
    role=@core.SemanticsRole::Group,
    frame=rect(0.0, 0.0, 160.0, 96.0),
    children=[nid(2UL)],
  )
  let blank_leaf = node(
    2UL,
    role=@core.SemanticsRole::Text,
    frame=rect(8.0, 16.0, 40.0, 16.0),
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(
    renderer.render_frame(semantics_frame(nodes=[root, blank_leaf], root~)),
  )
  assert_eq(cell_at(renderer, 1, 1), '?')
}

///|
test "a frame without semantics is diagnosed instead of blank" {
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
    diagnostics=@moui_tui_renderer.DegradeLog::new(),
  )
  let result = renderer.render_frame(empty_frame())
  assert_false(result.presented)
  match renderer.diagnostics().find("missing-semantics") {
    Some(record) =>
      assert_true(record.detail.contains("set_semantics_frames_enabled"))
    None => fail("expected a missing-semantics diagnostic")
  }
  assert_eq(renderer.line_text(0), "")
}

///|
test "the cell text system reports grid units not pixels" {
  let system = @moui_tui_renderer.cell_text_system(
    @moui_tui_renderer.CellBox::default(),
  )
  assert_eq(system.id(), "tui-cell")
  let font = @core.FontSpec::new()
  let wide = system.measure_text(
    @core.TextLayoutInput::new(text="hello", font~, max_width=32.0),
  )
  // 4 格宽只能放 4 个字符,并折成 2 行
  assert_eq(wide.size.width, 32.0)
  assert_eq(wide.size.height, 32.0)
  let cjk = system.measure_text(
    @core.TextLayoutInput::new(text="文件名", font~, max_width=32.0),
  )
  // 双宽字符按 2 格计:3 个汉字 6 格,4 格宽要占 2 行
  assert_eq(cjk.size.width, 32.0)
  assert_eq(cjk.size.height, 32.0)
}

///|
test "the cell text system gives every insertion point a grid column" {
  let system = @moui_tui_renderer.cell_text_system(
    @moui_tui_renderer.CellBox::new(width=10.0, height=20.0),
  )
  let font = @core.FontSpec::new()
  let empty = system.measure_text(
    @core.TextLayoutInput::new(text="", font~, max_width=80.0),
  )
  // 空文本也必须有一格插入点:文本框的绘制覆盖层按下标取几何,
  // 少这一项就是越界 panic(真终端里点一下文本框,整个应用当场没)。
  assert_eq(empty.caret_positions, [0.0])
  let ascii = system.measure_text(
    @core.TextLayoutInput::new(text="abc", font~, max_width=80.0),
  )
  assert_eq(ascii.caret_positions, [0.0, 10.0, 20.0, 30.0])
  let wide = system.measure_text(
    @core.TextLayoutInput::new(text="文b", font~, max_width=80.0),
  )
  assert_eq(wide.caret_positions, [0.0, 20.0, 30.0])
  // 折出视口的那几个点钉在右边界,和 core 的 clamp 规则一致:
  // 点击定位靠「最近的点」选插入点,点跑到框外就会永远选不中尾部。
  let clipped = system.measure_text(
    @core.TextLayoutInput::new(text="abcdef", font~, max_width=25.0),
  )
  assert_eq(clipped.caret_positions, [0.0, 10.0, 20.0, 25.0, 25.0, 25.0, 25.0])
}

///|
test "the capability table is total and honest about the cell grid" {
  let caps = @moui_tui_renderer.tui_feature_capabilities()
  assert_eq(caps.length(), 17)
  let seen : Array[String] = []
  for cap in caps {
    assert_eq(cap.provider_id, "tui-ansi")
    assert_eq(cap.backend, @render.RendererBackendKind::TerminalAnsiNative)
    assert_true(cap.note.length() > 0)
    seen.push(cap.feature.label())
  }
  // 每个特性只能出现一次,否则聚合报告会把同一条算两遍
  assert_false(has_duplicates(seen))
  assert_eq(
    status_of(caps, @render.RendererFeature::Text),
    Some(@render.RendererFeatureStatus::Supported),
  )
  assert_eq(
    status_of(caps, @render.RendererFeature::Rect),
    Some(@render.RendererFeatureStatus::Supported),
  )
  assert_eq(
    status_of(caps, @render.RendererFeature::Image),
    Some(@render.RendererFeatureStatus::Gap),
  )
  assert_eq(
    status_of(caps, @render.RendererFeature::Shadow),
    Some(@render.RendererFeatureStatus::Gap),
  )
  assert_eq(
    status_of(caps, @render.RendererFeature::Transform),
    Some(@render.RendererFeatureStatus::Gap),
  )
  assert_eq(
    status_of(caps, @render.RendererFeature::Opacity),
    Some(@render.RendererFeatureStatus::Partial),
  )
}

///|
test "the provider binds a real surface and rejects a degenerate one" {
  let (root, nodes) = sample_tree()
  let (sink, box) = capture()
  let provider = @moui_tui_renderer.ansi(sink~)
  assert_eq(provider.id(), "tui-ansi")
  let descriptor = provider.descriptor()
  assert_eq(descriptor.backend, @render.RendererBackendKind::TerminalAnsiNative)
  assert_eq(descriptor.family, @render.RendererFamily::Terminal)
  assert_eq(
    descriptor.presentation,
    @render.RendererPresentationModel::ExternalSurface,
  )
  assert_eq(descriptor.supported_targets, [@render.RendererTarget::Native])
  assert_eq(provider.capability_report().length(), 17)

  let good = @render.HostSurface::new(
    surface_id="stdout",
    metrics=metrics(160.0, 96.0),
  )
  match provider.bind_surface(good) {
    @render.RendererBindResult::Bound(session) => {
      assert_eq(session.text_system().id(), "tui-cell")
      assert_eq(session.present_count(), 0)
      let result = session.render_frame(
        submission(semantics_frame(nodes~, root~)),
      )
      assert_true(result.presented)
      assert_eq(session.present_count(), 1)
      assert_true(box.total() > 0)
      session.resize(metrics(240.0, 96.0))
      // 投影器没有 GPU 资源可丢,cell 栅格本身就是最终输出:
      // 恢复必须报"已完成",而不是悄悄退回一条不存在的路径
      match session.recover("noop") {
        @render.RecoveryResult::RecoverySucceeded => ()
        @render.RecoveryResult::RecoveryFailed(reason) =>
          fail("recovery reported a failure: \{reason}")
        @render.RecoveryResult::FallbackToCpu =>
          fail("the cell projector has no cpu fallback to take")
      }
    }
    @render.RendererBindResult::Rejected(reason) =>
      fail("expected the surface to bind: \{reason}")
  }

  let zero = @render.HostSurface::new(
    surface_id="zero",
    metrics=metrics(0.0, 0.0),
  )
  match provider.bind_surface(zero) {
    @render.RendererBindResult::Rejected(reason) =>
      assert_true(reason.length() > 0)
    @render.RendererBindResult::Bound(_) =>
      fail("expected a zero-sized surface to be rejected")
  }
}
