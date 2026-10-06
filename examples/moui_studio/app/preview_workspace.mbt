///|
/// 预览工作区(M1-2):FramePreview 构建回执的 headless 帧重放画布。
///
/// 数据流:构建(BkFramePreview = `moon run .studio/preview`)→ 哨兵协议
/// 解析 → `PreviewFrame` → 本视图把重建的 `DrawCommand` 序列**按序推回
/// PaintContext**(PaintContext 本就是 DrawCommand 收集器,重放零转换);
/// 未知 op 在画布上方的横幅里诚实列出,不静默丢。
///
/// 坐标 1:1(设计坐标 640×480,画布按帧尺寸给);缩放/模式二/三状态条
/// 在后续里程碑接。

///|
/// 预览工作区主体(ide_root 的 workspace_content 分派)。
pub fn preview_workspace(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  match active_project_of(model) {
    None =>
      @views.container(
        empty_hint(text(t, "app.project.no_project"), width, height),
        background=ide_editor_background(),
        width~,
        height~,
        padding=0.0,
      )
    Some(project) => {
      // 模式条(M2-2/M3):画布快览 / 网页实时 / 独立运行。
      // Web 需要静态服务 + webview 控制器(native 入口),缺失则禁用。
      let controls = preview_web_controls()
      let web_available = controls.port > 0 &&
        preview_web_controller() is Some(_)
      let mode_strip = @views.row(
        [
          mode_strip_button(
            text(t, "app.project.mode.frame"),
            model.preview_mode is PmFrame,
            SetPreviewMode(PmFrame),
          ),
          mode_strip_button(
            text(t, "app.project.mode.web"),
            model.preview_mode is PmWeb,
            if web_available {
              SetPreviewMode(PmWeb)
            } else {
              SetNotice(text(t, "app.project.preview_web_unavailable"))
            },
          ),
          mode_strip_button(
            text(t, "app.project.mode.native"),
            false,
            ProjectBuildRun(@build.BkRunNative),
          ),
          // 外部改动重载（M8）：手动刷新入口——外部编辑器改了 form.mbt
          // 后点这里读取比对，提示并重载设计器会话。只在布局设计器
          // 会话打开时显示（无会话时无事可查）。
          if model.form_designer is Some(_) {
            mode_strip_button(
              text(t, "app.project.external_check"),
              false,
              FormDesignExternalCheck,
            )
          } else {
            @views.text("", width=1.0, height=1.0)
          },
          // 布局页签（M4 收尾）：画布/布局二分，只属于模式一。
          if model.preview_mode is PmFrame {
            mode_strip_button(
              text(t, "app.project.design_tab"),
              model.preview_design_open,
              SetPreviewDesignOpen(!model.preview_design_open),
            )
          } else {
            @views.text("", width=1.0, height=1.0)
          },
        ],
        spacing=4.0,
        align=Center,
      )
      let head = @views.container(
        @views.row(
          [
            @views.text(
              project.module_name,
              theme=studio_theme(),
              width=(width - 420.0).max(80.0),
              height=20.0,
              align=TextStart,
            ).foreground(ide_text()),
            mode_strip,
            @views.text(
              if model.build_busy {
                text(t, "app.project.preview_building")
              } else {
                text(t, "app.project.preview_rebuild_hint")
              },
              theme=studio_theme(),
              width=(width - 260.0).max(80.0),
              height=18.0,
              align=TextEnd,
            ).foreground(ide_text_muted()),
            icon_button(
              Save,
              text(t, "app.project.preview_rebuild"),
              false,
              ProjectBuildRun(BkFramePreview),
              24.0,
              24.0,
              12.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        background=ide_panel(),
        width~,
        height=40.0,
        padding=0.0,
      )
      // 布局设计器区（M4 收尾）：会话在 = 画布；不在 = 打开入口。
      let designer_area = fn(area_height : Double) -> @moui.View[Msg] {
        let area_width = (width - 226.0).max(120.0)
        match model.form_designer {
          Some(session) =>
            form_design_canvas(
              session,
              model.selected_form_control,
              area_width,
              area_height,
            )
          None =>
            @views.container(
              @views.column(
                [
                  @views.text(
                    text(t, "app.project.design_empty"),
                    theme=studio_theme(),
                    width=(area_width - 40.0).max(80.0),
                    height=24.0,
                    align=TextCenter,
                  ).foreground(ide_text_muted()),
                  @views.button(
                    text(t, "app.project.design_open"),
                    on_click=FormDesignOpen,
                    variant=Primary,
                  ),
                ],
                spacing=12.0,
                align=Center,
              ),
              width=area_width,
              height~,
              padding=0.0,
            )
        }
      }
      let body = if model.preview_design_open {
        // 布局设计器不依赖预览帧：未构建也能进入（M4 收尾）
        designer_area(height)
      } else {
        match model.preview_frame {
          None =>
            @views.container(
              @views.column(
                [
                  @views.text(
                    text(t, "app.project.preview_empty"),
                    theme=studio_theme(),
                    width=(width - 40.0).max(80.0),
                    height=24.0,
                    align=TextCenter,
                  ).foreground(ide_text_muted()),
                  @views.button(
                    text(t, "app.project.preview_build_now"),
                    on_click=ProjectBuildRun(BkFramePreview),
                    variant=Primary,
                  ),
                ],
                spacing=12.0,
                align=Center,
              ),
              width~,
              height~,
              padding=0.0,
            )
          Some(frame) => {
            // 未知 op 横幅:诚实列出,不静默
            let warning = if frame.unknown_ops.length() > 0 {
              @views.container(
                @views.padding_xy(
                  @views.text(
                    fit_label(
                      text_with(t, "app.project.preview_unknown_ops", [
                        ("a", frame.unknown_ops.length().to_string()),
                      ]),
                      (width - 260.0).max(60.0),
                    ),
                    theme=studio_theme(),
                    width=(width - 260.0).max(60.0),
                    height=18.0,
                    align=TextStart,
                  ).foreground(ide_text_muted()),
                  horizontal=12.0,
                  vertical=4.0,
                ),
                background=ide_panel(),
                width~,
                height=26.0,
                padding=0.0,
              )
            } else {
              @views.text("", width=1.0, height=1.0)
            }
            let canvas_width = (width - 226.0).max(120.0)
            let canvas_area = if model.preview_mode is PmWeb {
              match preview_web_controller() {
                Some(controller) =>
                  @webview_views.web_view(
                    controller~,
                    title="preview",
                    width=Some(canvas_width),
                    height=Some(frame.height),
                  )
                None =>
                  @views.container(
                    empty_hint(
                      text(t, "app.project.preview_web_unavailable"),
                      canvas_width,
                      height,
                    ),
                    width=canvas_width,
                    height~,
                    padding=0.0,
                  )
              }
            } else if model.preview_design_open {
              // 布局设计器（M4 收尾）：拖拽/保存 → span 补丁写 form.mbt
              designer_area(frame.height)
            } else {
              preview_replay_canvas(model, frame, canvas_width)
            }
            let canvas_column = @views.column(
              [warning, canvas_area],
              spacing=0.0,
            ).frame(width=canvas_width, height~)
            @views.row(
              [canvas_column, semantic_property_strip(model, t, height)],
              spacing=0.0,
              align=Start,
            ).frame(width~, height~)
          }
        }
      }
      @views.container(
        @views.column([head, body], spacing=0.0).frame(width~, height~),
        background=ide_editor_background(),
        width~,
        height~,
        padding=0.0,
      )
    }
  }
}

///|
/// 重放画布:按帧尺寸 1:1 出图,重放解析好的 DrawCommand 序列;
/// 选中节点画高亮描边;点击做语义命中测试(点空处取消选中)。
pub fn preview_replay_canvas(
  model : Model,
  frame : PreviewFrame,
  pane_width : Double,
) -> @moui.View[Msg] {
  // 画布 1:1(帧坐标),超出交给外层滚动;缩放跟随 M2 的适配逻辑
  let canvas_width = frame.width.max(1.0)
  let canvas_height = frame.height.max(1.0)
  let nodes = semantic_hit_nodes(frame)
  let selected = match model.selected_semantic {
    Some(index) =>
      if index >= 0 && index < nodes.length() {
        Some(nodes[index])
      } else {
        None
      }
    None => None
  }
  @views.container(
    @views.measured_canvas(
      measure=fn(_constraints, _text_system) {
        @geometry.Size::new(width=canvas_width, height=canvas_height)
      },
      draw=fn(ctx, _frame) {
        // 重放:解析好的 DrawCommand 按序推回 PaintContext
        for command in frame.commands {
          ctx.commands.push(command)
        }
        // 选中高亮:强调色描边(画在重放内容之上)
        match selected {
          Some(node) =>
            ctx.commands.push(
              @core.StrokeRect(
                @geometry.Rect::new(
                  x=node.frame.origin.x - 2.0,
                  y=node.frame.origin.y - 2.0,
                  width=node.frame.size.width + 4.0,
                  height=node.frame.size.height + 4.0,
                ),
                ide_accent(),
                2.0,
              ),
            )
          None => ()
        }
      },
      semantics_label="preview-canvas",
    ).on_tap_with_frame(fn(position, tap_frame) {
      // 画布局部坐标 = 帧坐标(1:1);命中取最深(最后一个匹配)
      let x = position.x - tap_frame.origin.x
      let y = position.y - tap_frame.origin.y
      Msg::SelectSemanticNode(semantic_hit_index(nodes, x, y))
    }),
    background=ide_editor_background(),
    width=canvas_width.min(pane_width - 2.0).max(1.0),
    height=canvas_height,
    padding=0.0,
  )
}

///|
/// 属性条(M1-3):选中语义节点的信息 + label 字面量编辑 + 提交。
pub fn semantic_property_strip(
  model : Model,
  t : @i18n.Translator,
  height : Double,
) -> @moui.View[Msg] {
  let selected = match model.selected_semantic {
    Some(index) =>
      match model.preview_frame {
        Some(frame) => {
          let nodes = semantic_hit_nodes(frame)
          if index >= 0 && index < nodes.length() {
            Some(nodes[index])
          } else {
            None
          }
        }
        None => None
      }
    None => None
  }
  let rows : Array[@moui.View[Msg]] = [
    @views.padding_xy(
      @views.text(
        text(t, "app.project.props_title"),
        theme=studio_theme(),
        width=196.0,
        height=18.0,
        align=TextStart,
      ).foreground(ide_text()),
      horizontal=12.0,
      vertical=8.0,
    ),
  ]
  match selected {
    None =>
      rows.push(
        @views.padding_xy(
          @views.text(
            text(t, "app.project.props_none"),
            theme=studio_theme(),
            width=196.0,
            height=34.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          horizontal=12.0,
          vertical=0.0,
        ),
      )
    Some(node) => {
      rows.push(
        @views.padding_xy(
          @views.text(
            text_with(t, "app.project.props_role", [("a", node.role)]),
            theme=studio_theme(),
            width=196.0,
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_muted()),
          horizontal=12.0,
          vertical=0.0,
        ),
      )
      rows.push(
        @views.padding_xy(
          @views.text_field(
            model.semantic_draft,
            on_input=text => SemanticLabelInput(text),
            placeholder=text(t, "app.project.props_label_hint"),
            variant=Outline,
            width=196.0,
            height=FIELD_HEIGHT,
          ),
          horizontal=12.0,
          vertical=6.0,
        ),
      )
      rows.push(
        @views.container(
          @views.center(
            @views.text(
              text(t, "app.project.props_apply"),
              theme=studio_theme(),
              width=80.0,
              height=18.0,
            ),
            width=196.0,
            height=28.0,
          ),
          background=ide_accent(),
          corner_radius=4.0,
          width=196.0,
          height=28.0,
          padding=0.0,
        ).on_tap(SemanticLabelCommit),
      )
    }
  }
  @views.container(
    @views.scroll_view(
      @views.column(rows, spacing=4.0),
      width=220.0,
      height~,
      shows_indicator=true,
    ),
    background=ide_panel(),
    width=220.0,
    height~,
    padding=0.0,
  )
}

///|
/// 模式条按钮:文字 + 高亮(选中 = 选中底色 + 强调文字)。
fn mode_strip_button(
  label : String,
  selected : Bool,
  on_click : Msg,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.text(label, theme=studio_theme(), width=88.0, height=16.0).foreground(
        if selected {
          ide_text()
        } else {
          ide_text_muted()
        },
      ),
      width=96.0,
      height=24.0,
    ),
    background=if selected { ide_selection() } else { ide_panel() },
    corner_radius=4.0,
    width=96.0,
    height=24.0,
    padding=0.0,
  ).on_tap(on_click)
}
