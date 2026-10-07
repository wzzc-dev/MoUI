///|
/// v4 IDE 右栏：Context（属性/状态/数据/动作/依赖）+ 快速操作 + 运行时监视。
/// 设计稿的右栏是「当前对象的全貌」：不只是属性编辑，还包括它现在是什么
/// 状态、有哪些数据、能触发什么、被谁依赖。五页签就是这个全貌的五刀切面。

// ============================================================================
// 右栏
// ============================================================================

///|
/// 右栏：Context 头（选中对象 + 类型徽标）+ 五页签 + 页签体 +
/// 快速操作 + 运行时监视。
///
/// 选中积木时，页签体**顶部**多一段「编辑积木」卡（见 `context_block_editor`）：
/// 语句编辑从积木画布搬到了这里。旧版把编辑卡夹在链条中间，把画布切成
/// 三段，块一多就挤得看不全——用户读到的是「点积木后下面内容显示不全」。
/// 侧栏是滚动容器，编辑面在这里永远完整可见。
pub fn ide_right_panel(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let ctx_head = context_head(model, t, width)
  let tabs = context_tabs(model, t, width)
  // 高度预算：头 30 + 页签 30 + 正文（可滚动）+ 快速操作 + 监视。
  // 正文之外的块都定高，正文吃掉剩余——列也必须显式定尺，
  // 否则容器盒会把整列居中（右栏头会掉到中间）。
  let body_height = (height - 30.0 - 30.0 - 56.0 - 150.0).max(100.0)
  let body = context_body(model, t, width, body_height)
  @views.container(
    @views.column(
      [
        ctx_head,
        tabs,
        body,
        quick_actions(model, t, width),
        watch_pane(model, t, width),
      ],
      spacing=0.0,
    ).frame(width~, height~),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 页签体：五个切面各自的只读视图（编辑仍走属性页签的输入框）。
///
/// **积木编辑卡在最上面**：它是「当前选中积木」的编辑面，与下面五个
/// 「当前选中控件」的切面是两个对象，所以不做成第六个页签（页签是同一
/// 对象的不同切面），而是常驻在正文顶部——选中积木时立刻可见、无需再点。
fn context_body(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let content = match model.ctx_tab {
    CtxProps => context_props(model, t, width)
    CtxState => context_state(model, t, width)
    CtxData => context_data(model, t, width)
    CtxActions => context_actions(model, t, width)
    CtxDeps => context_deps(model, t, width)
    CtxRuntime => context_runtime(model, t, width)
  }
  let sections : Array[@moui.View[Msg]] = []
  match context_block_editor(model, t, width) {
    Some(editor) => sections.push(editor)
    None => ()
  }
  sections.push(content)
  @views.container(
    @views.scroll_view(
      @views.column(sections, spacing=0.0),
      width~,
      height~,
      shows_indicator=true,
    ),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 积木编辑卡（右栏版）：分类色徽章 + 语句文本 + 三个动作。
///
/// 这是旧版「链条内编辑卡」的搬迁目标——画布不再为编辑让位，侧栏负责
/// 承载输入。返回 None = 没有选中积木（不画空卡，也不显示上一个块的草稿）。
///
/// 布局按侧栏宽度**从上到下**排（不是旧版的一行四格）：右栏只有 272pt，
/// 徽章 + 输入框 + 三颗图标挤在一行时输入框只剩 ~90pt，中文语句两三个字
/// 就被截断——那正是「内容显示不全」的另一半成因。竖排让输入框吃满整宽。
fn context_block_editor(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg]? {
  let blocks = block_chain_of(model)
  let sel = model.selected_block
  if sel < 0 || sel >= blocks.length() || blocks[sel].path.length() == 0 {
    return None
  }
  let kind = blocks[sel].kind
  let label = text(t, @blocks.block_label_key(kind))
  // 徽章宽按标签算（中英混排，同 `button_label_width` 口径），不写死：
  // 「否则如果」比「否则」宽一倍，写死会截字。
  let chip_w = button_label_width(label).max(56.0)
  let inner = (width - 16.0).max(120.0)
  let icon_size = 28.0
  let head = @views.row(
    [
      @views.container(
        @views.center(
          @views.text(
            label,
            theme=studio_theme(),
            width=chip_w - 10.0,
            height=16.0,
          ).foreground(block_text_color()),
          width=chip_w,
          height=22.0,
        ),
        background=block_fill(kind),
        corner_radius=4.0,
        width=chip_w,
        height=22.0,
        padding=0.0,
      ),
      @views.spacer(min_length=4.0, weight=1.0),
      // 三个动作挤在徽章右侧（图标 28 + 间隙 4×2 = 92pt，侧栏放得下）。
      ghost_icon_button(
        Check,
        text(t, "app.block.apply"),
        false,
        CommitBlock,
        icon_size,
        22.0,
        13.0,
        ide_elevated(),
      ),
      ghost_icon_button(
        Clipboard,
        text(t, "app.block.duplicate"),
        false,
        DuplicateBlock,
        icon_size,
        22.0,
        13.0,
        ide_elevated(),
      ),
      ghost_icon_button(
        Trash,
        text(t, "app.block.delete"),
        false,
        DeleteBlock,
        icon_size,
        22.0,
        13.0,
        ide_elevated(),
      ),
    ],
    spacing=4.0,
    align=Center,
  )
  Some(
    @views.container(
      @views.padding_xy(
        @views.column(
          [
            @views.padding_xy(
              @views.text(
                text(t, "app.block.edit_title"),
                theme=studio_theme(),
                width=inner,
                height=18.0,
                align=TextStart,
              ).foreground(ide_text()),
              horizontal=8.0,
              vertical=0.0,
            ),
            @views.padding_xy(head, horizontal=8.0, vertical=0.0),
            // 单行语句编辑用 text_field：原生单行控件（自带水平滚动），
            // Enter 直接应用草稿（text_area 的 8pt×2 垂直内垫会竖切字形）。
            //
            // **值编辑进行中时，同一个格子改为编辑那个值**（Scratch 的
            // 「点值改值」）：只换绑定的数据源与提交消息，不另开一块面板——
            // 用户点的还是积木上那个数，编辑框就该在同一个位置。
            @views.padding_xy(
              @views.text_field(
                match model.block_value_edit {
                  Some((_, _, draft)) => draft
                  None => model.block_draft
                },
                on_input=source => {
                  match model.block_value_edit {
                    Some(_) => BlockValueInput(source)
                    None => EditBlock(source)
                  }
                },
                on_submit=Some(
                  match model.block_value_edit {
                    Some(_) => BlockValueCommit
                    None => CommitBlock
                  },
                ),
                placeholder=text(
                  t,
                  match model.block_value_edit {
                    Some(_) => "app.block.value_hint"
                    None => "app.block.editor_hint"
                  },
                ),
                variant=Outline,
                width=inner,
                height=FIELD_HEIGHT,
              ),
              horizontal=8.0,
              vertical=0.0,
            ),
            @views.padding_xy(
              @views.text(
                text(t, "app.block.edit_hint"),
                theme=studio_theme(),
                width=inner,
                height=16.0,
                align=TextStart,
              ).foreground(ide_text_faint()),
              horizontal=8.0,
              vertical=0.0,
            ),
            // **给这段脚本写说明**（Scratch 的「加注释」）。
            //
            // `Handler` / `FuncDef` 一直有 `note_zh` / `note_en` 字段，AI
            // 上下文也一直在读它（`handler_note`），但界面上没有写的入口，
            // 所以那两个字段永远是空的——「能力在、入口不在」的又一例。
            @views.padding_xy(
              @views.text(
                text(t, "app.block.note_label"),
                theme=studio_theme(),
                width=inner,
                height=16.0,
                align=TextStart,
              ).foreground(ide_text_faint()),
              horizontal=8.0,
              vertical=0.0,
            ),
            @views.padding_xy(
              @views.text_field(
                target_note(model),
                on_input=note => EditTargetNote(note),
                placeholder=text(t, "app.block.note_hint"),
                variant=Outline,
                width=inner,
                height=FIELD_HEIGHT,
              ),
              horizontal=8.0,
              vertical=0.0,
            ),
          ],
          spacing=6.0,
        ),
        horizontal=0.0,
        vertical=6.0,
      ),
      background=ide_elevated(),
      corner_radius=6.0,
      width~,
      padding=0.0,
    ),
  )
}

///|
/// Context 头：选中对象名 + 种类徽标。没选中对象时显式说「未选中」——
/// 不静默显示上一个对象的属性（那是误导）。
fn context_head(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  // 四条槽的优先级：非控件对象 → 控件 → 子程序 → 无。
  // `side_target` 排在最前是因为它只在「用户点了窗体/变量/数据行」时被
  // 设置，而那三条入口已经清掉了控件与子程序槽（`select_target` 漏斗），
  // 所以这里不会出现「同时有效」的歧义。
  let (name, kind) = match model.side_target {
    Some(SideWindow) => (model.program.window.title, text(t, "app.ctx.window"))
    Some(SideVariable(variable_name)) =>
      (
        variable_name,
        match selected_variable(model) {
          Some(_) => text(t, "app.ctx.variable")
          // 变量被删掉后槽还指着旧名字：如实显示「已不存在」而不是
          // 继续显示一个幽灵对象。
          None => text(t, "app.ctx.gone")
        },
      )
    Some(SideData(file_name)) =>
      (
        file_name,
        match selected_data_file(model) {
          Some(_) => text(t, "app.ctx.data")
          None => text(t, "app.ctx.gone")
        },
      )
    Some(SideFunction(func_name)) =>
      (
        func_name,
        match selected_function(model) {
          Some(_) => text(t, "app.ctx.function")
          None => text(t, "app.ctx.gone")
        },
      )
    None =>
      match find_selected_control(model) {
        Some(control) => (control.name, text(t, control_kind_key(control.kind)))
        None =>
          match current_handler(model) {
            Some(handler) =>
              (
                "\{handler.control_name}.\{handler.event.tag()}",
                text(t, "app.ctx.handler"),
              )
            None => (text(t, "app.ctx.none"), "")
          }
      }
  }
  // 行内布局（对齐设计稿 `.ctxsel`）：`对象名 + 清除 ✕` 靠左成组，
  // 然后权重 spacer，右边是种类徽标与**收起整个右栏**的 ✕。
  //
  // 为什么两个 ✕ 必须分开：设计稿的 `#clearSel` 是**对象芯片内部**的小 ✕
  // （`.objchip` 里紧挨着名字），而面板关闭按钮属于窗格头。之前把
  // `ClearSelection` 放在整行的最右端——那正是「关闭面板」按钮该在的位置，
  // 于是点它只是清了选中、面板纹丝不动，用户读到的语义就是「关闭右栏
  // 关错了东西」。位置即语义，两者不能互换。
  let has_selection = name != text(t, "app.ctx.none")
  let lead : Array[@moui.View[Msg]] = [
    @views.text(
      name,
      theme=studio_theme(),
      width=(width - 130.0).max(60.0),
      height=18.0,
      align=TextStart,
    ).foreground(ide_text()),
  ]
  if has_selection {
    lead.push(
      icon_button(
        Close,
        text(t, "app.ctx.clear"),
        false,
        ClearSelection,
        18.0,
        18.0,
        10.0,
      ),
    )
  }
  let trail : Array[@moui.View[Msg]] = []
  if kind != "" {
    trail.push(count_badge(kind, 4))
  }
  trail.push(
    icon_button(
      Close,
      text(t, "app.right.hide"),
      false,
      SetRightView(RvHidden),
      20.0,
      20.0,
      12.0,
    ),
  )
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.row(lead, spacing=4.0, align=Center),
          @views.spacer(min_length=4.0, weight=1.0),
          @views.row(trail, spacing=4.0, align=Center),
        ],
        (width - 16.0).max(80.0),
        4.0,
        Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel_alt(),
    height=PANEL_HEAD_HEIGHT,
    width~,
    padding=0.0,
  )
}

///|
/// 五页签条：属性/状态/数据/动作/依赖。每页签宽度均分。
fn context_tabs(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let entries : Array[(ContextTab, String)] = [
    (CtxProps, text(t, "app.ctx.props")),
    (CtxState, text(t, "app.ctx.state")),
    (CtxData, text(t, "app.ctx.data")),
    (CtxActions, text(t, "app.ctx.actions")),
    (CtxDeps, text(t, "app.ctx.deps")),
    (CtxRuntime, text(t, "app.ctx.runtime")),
  ]
  // 页签总宽 = 6×cell + 5×gap，必须**连同左右内垫**一起塞进 width。
  // 原来只减了 12（内垫）却忘了 4 个 3px 间隙：5×52+12 = 272 = 面板宽，
  // 于是「依赖」页签正好顶到右边缘被切掉半个字（实际截图可见）。
  // 加到六页签后同一纪律继续成立：cell 宽把 5 个间隙也算进去。
  let cell_width = ((width - 12.0 - 5.0 * 3.0) / 6.0).max(28.0)
  let tabs : Array[@moui.View[Msg]] = []
  for entry in entries {
    let (tab, label) = entry
    let selected = same_tab(model.ctx_tab, tab)
    tabs.push(
      @views.container(
        @views.center(
          @views.text(
            label,
            theme=studio_theme(),
            width=cell_width - 4.0,
            height=16.0,
          ).foreground(if selected { ide_text() } else { ide_text_faint() }),
          width=cell_width,
          height=22.0,
        ),
        background=if selected { ide_selection() } else { ide_panel_alt() },
        corner_radius=3.0,
        width=cell_width,
        height=22.0,
        padding=0.0,
      )
      .accessibility_label(label)
      .on_tap(SetContextTab(tab)),
    )
  }
  @views.container(
    @views.padding_xy(
      fill_row(tabs, (width - 12.0).max(80.0), 3.0, Center),
      horizontal=6.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=PANEL_HEAD_HEIGHT,
    width~,
    padding=0.0,
  )
}

///|
/// 页签同一性：ContextTab 无 Eq 派生，按 tag 比。
fn same_tab(a : ContextTab, b : ContextTab) -> Bool {
  match (a, b) {
    (CtxProps, CtxProps)
    | (CtxState, CtxState)
    | (CtxData, CtxData)
    | (CtxActions, CtxActions)
    | (CtxDeps, CtxDeps)
    | (CtxRuntime, CtxRuntime) => true
    _ => false
  }
}

///|
/// 属性页签：名称/文本/位置/尺寸 + 列表项（可编辑——这是检查器本体）。
fn context_props(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  // 非控件对象（窗体/变量/数据）没有「名称/文本/位置/尺寸」四件套，
  // 各给一套贴身的属性。这三类此前点了树行**完全没反应**，属性面是空的。
  match model.side_target {
    Some(SideWindow) => return window_props(model, t, width)
    Some(SideVariable(_)) => return variable_props(model, t, width)
    Some(SideData(_)) => return data_props(model, t, width)
    Some(SideFunction(_)) => return function_props(model, t, width)
    None => ()
  }
  match find_selected_control(model) {
    None => empty_hint(text(t, "app.inspector.none"), width, 120.0)
    Some(control) => {
      let field_width = (width - 90.0).max(80.0)
      let rows : Array[@moui.View[Msg]] = [
        field_label(t, "app.inspector.name", width),
        @views.text_field(
          control.name,
          on_input=new_value => SetControlName(control.name, new_value),
          width=field_width,
          height=FIELD_HEIGHT,
        ),
        field_label(t, "app.inspector.text", width),
        @views.text_field(
          control.text,
          on_input=new_value => SetControlText(control.name, new_value),
          width=field_width,
          height=FIELD_HEIGHT,
        ),
        field_label(t, "app.inspector.position", width),
        @views.row(
          [
            @views.text_field(
              control.x.to_string(),
              on_input=raw => SetControlRect(control.name, @ir.RectX, raw),
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
            @views.text_field(
              control.y.to_string(),
              on_input=raw => SetControlRect(control.name, @ir.RectY, raw),
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
          ],
          spacing=6.0,
        ),
        field_label(t, "app.inspector.size", width),
        @views.row(
          [
            @views.text_field(
              control.width.to_string(),
              on_input=raw => SetControlRect(control.name, @ir.RectWidth, raw),
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
            @views.text_field(
              control.height.to_string(),
              on_input=raw => SetControlRect(control.name, @ir.RectHeight, raw),
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
          ],
          spacing=6.0,
        ),
        // 属性 v2（G7.2）：字号/加粗/颜色/对齐/可见——改属性 = 改程序
        //（走撤销点），运行预览与设计画布同一渲染出口。
        field_label(t, "app.inspector.props", width),
        @views.row(
          [
            @views.text_field(
              if control.props.font_size > 0 {
                control.props.font_size.to_string()
              } else {
                ""
              },
              on_input=raw => SetControlPropText(control.name, "font_size", raw),
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
            @views.button(
              text(t, "app.props.bold"),
              on_click=ToggleControlProp(control.name, "bold"),
              variant=if control.props.bold { Primary } else { Outline },
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
          ],
          spacing=6.0,
        ),
        @views.row(
          [
            @views.text_field(
              control.props.text_color,
              on_input=raw => {
                SetControlPropText(control.name, "text_color", raw)
              },
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
            @views.text_field(
              control.props.back_color,
              on_input=raw => {
                SetControlPropText(control.name, "back_color", raw)
              },
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
          ],
          spacing=6.0,
        ),
        @views.row(
          [
            @views.button(
              text(t, "app.props.align_start"),
              on_click=SetControlPropText(control.name, "align", "start"),
              variant=if control.props.align == "start" ||
                control.props.align == "" {
                Primary
              } else {
                Outline
              },
              width=(field_width - 12.0) / 3.0,
              height=FIELD_HEIGHT,
            ),
            @views.button(
              text(t, "app.props.align_center"),
              on_click=SetControlPropText(control.name, "align", "center"),
              variant=if control.props.align == "center" {
                Primary
              } else {
                Outline
              },
              width=(field_width - 12.0) / 3.0,
              height=FIELD_HEIGHT,
            ),
            @views.button(
              text(t, "app.props.align_end"),
              on_click=SetControlPropText(control.name, "align", "end"),
              variant=if control.props.align == "end" {
                Primary
              } else {
                Outline
              },
              width=(field_width - 12.0) / 3.0,
              height=FIELD_HEIGHT,
            ),
          ],
          spacing=6.0,
        ),
        @views.row(
          [
            @views.button(
              text(t, "app.props.visible"),
              on_click=ToggleControlProp(control.name, "visible"),
              variant=if control.props.visible { Primary } else { Outline },
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
            @views.button(
              text(t, "app.props.disabled"),
              on_click=ToggleControlProp(control.name, "disabled"),
              variant=if control.props.disabled { Primary } else { Outline },
              width=(field_width - 6.0) / 2.0,
              height=FIELD_HEIGHT,
            ),
          ],
          spacing=6.0,
        ),
      ]
      // 属性 schema 的数据面（切片 G）：items 按种类承载不同载荷——
      // 列表框/表格/下拉框 = 多行选项；进度条 = 绑定变量名；图片 = 资源路径
      if control.kind is @ir.ListBox ||
        control.kind is @ir.Table ||
        control.kind is @ir.Dropdown {
        rows.push(field_label(t, "app.inspector.items", width))
        rows.push(
          @views.text_area(
            join_lines(control.items),
            on_input=new_value => SetControlItems(control.name, new_value),
            lines=4,
            width=field_width,
            line_height=20.0,
          ),
        )
      }
      if control.kind is @ir.ProgressBar {
        rows.push(field_label(t, "app.inspector.progress_var", width))
        rows.push(
          @views.text_field(
            match control.items {
              [name, ..] => name
              [] => ""
            },
            on_input=new_value => SetControlItems(control.name, new_value),
            width=field_width,
            height=FIELD_HEIGHT,
          ),
        )
      }
      if control.kind is @ir.Image {
        rows.push(field_label(t, "app.inspector.image_path", width))
        rows.push(
          @views.text_field(
            match control.items {
              [path, ..] => path
              [] => ""
            },
            on_input=new_value => SetControlItems(control.name, new_value),
            width=field_width,
            height=FIELD_HEIGHT,
          ),
        )
      }
      @views.padding_xy(
        @views.column(rows, spacing=4.0),
        horizontal=8.0,
        vertical=6.0,
      )
    }
  }
}

///|
/// 字段标签：8pt 行，弱色（IDE 检查器的密度口径）。
fn field_label(
  t : @i18n.Translator,
  key : String,
  width : Double,
) -> @moui.View[Msg] {
  @views.text(
    text(t, key),
    theme=studio_theme(),
    width=(width - 16.0).max(60.0),
    height=16.0,
    align=TextStart,
  ).foreground(ide_text_faint())
}

///|
/// 状态页签：运行态事实（是否运行、当前轨、闸门、单步、事件计数）。
fn context_state(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = [
    kv_row(
      text(t, "app.ctx.state.running"),
      if app_running(model) {
        text(t, "app.yes")
      } else {
        text(t, "app.no")
      },
      width - 16.0,
      false,
    ),
    kv_row(
      text(t, "app.ctx.state.track"),
      match current_track(model) {
        Interpret => text(t, "app.track.interpret")
        Compile => text(t, "app.track.compile")
      },
      width - 16.0,
      false,
    ),
    kv_row(
      text(t, "app.ctx.state.gate"),
      if gate_pending(model) {
        text(t, "app.run.gate_pending")
      } else {
        "—"
      },
      width - 16.0,
      false,
    ),
    kv_row(
      text(t, "app.ctx.state.steps"),
      audit_step_count(model).to_string(),
      width - 16.0,
      true,
    ),
    kv_row(
      text(t, "app.ctx.state.edited"),
      if model.dirty {
        text(t, "app.ctx.state.dirty")
      } else {
        text(t, "app.ctx.state.clean")
      },
      width - 16.0,
      false,
    ),
  ]
  @views.padding_xy(
    @views.column(rows, spacing=2.0),
    horizontal=8.0,
    vertical=6.0,
  )
}

///|
/// 已执行指令数：解释轨读 step 计数，编译轨读审计条数（口径一致）。
fn audit_step_count(model : Model) -> Int {
  match current_track(model) {
    Interpret =>
      match model.run {
        Some(run) => run.state.steps
        None => 0
      }
    Compile =>
      match model.compiled_run {
        Some(run) => run.runtime.steps
        None => 0
      }
  }
}

///|
/// 数据页签：当前子程序涉及的变量（程序声明的 + handler 里出现的名字）。
/// handler 没有独立的变量表——IR 里变量只有程序级声明；这里把 handler
/// 语句文本里出现的变量名也列出来，让「这个子程序用到哪些数据」可见。
fn context_data(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  for variable in model.program.variables {
    rows.push(kv_row(variable.name, variable.init, width - 16.0, true))
  }
  match current_handler(model) {
    None => ()
    Some(handler) => {
      let rendered = @studio_lang.render_stmts(
        handler.body,
        model.language.dsl_language(),
      )
      for variable in model.program.variables {
        if rendered.contains(variable.name) {
          rows.push(
            kv_row(
              "\{variable.name} · \{text(t, "app.ctx.data.used")}",
              variable.init,
              width - 16.0,
              true,
            ),
          )
        }
      }
    }
  }
  if rows.length() == 0 {
    return empty_hint(text(t, "app.ctx.data.none"), width, 120.0)
  }
  @views.padding_xy(
    @views.column(rows, spacing=2.0),
    horizontal=8.0,
    vertical=6.0,
  )
}

///|
/// 动作页签：当前对象能触发的事件（点一下建子程序 / 切到已有子程序）。
fn context_actions(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let control = find_selected_control(model)
  let control_name = match control {
    Some(control) => control.name
    None =>
      match current_handler(model) {
        Some(handler) => handler.control_name
        None => return empty_hint(text(t, "app.ctx.actions.none"), width, 120.0)
      }
  }
  // 事件集合由控件种类决定（按钮只有 onClick、输入框还有 onChange）——
  // 用 IR 的支持表推导，不硬编码控件-事件矩阵。
  let events : Array[@ir.EventKind] = match control {
    Some(control) => control_events(control)
    None =>
      match @ir.parse_control_kind("button") {
        Some(kind) => {
          let all : Array[@ir.EventKind] = []
          if kind.supports_event(@ir.OnClick) {
            all.push(@ir.OnClick)
          }
          if kind.supports_event(@ir.OnChange) {
            all.push(@ir.OnChange)
          }
          all
        }
        None => [@ir.OnClick]
      }
  }
  let rows : Array[@moui.View[Msg]] = []
  for event in events {
    let key = handler_key(control_name, event.tag())
    let exists = match @ir.find_handler(model.program, control_name, event) {
      Some(_) => true
      None => false
    }
    let selected = model.selected_handler == key
    rows.push(
      @views.container(
        @views.padding_xy(
          fill_row(
            [
              @views.text(
                text(t, "event.\{event.tag()}"),
                theme=studio_theme(),
                width=(width - 100.0).max(60.0),
                height=18.0,
                align=TextStart,
              ).foreground(if selected { ide_text() } else { ide_text_muted() }),
              @views.spacer(min_length=4.0, weight=1.0),
              if exists {
                pill(text(t, "app.ctx.actions.ready"), ide_success(), 48.0)
              } else {
                pill(text(t, "app.ctx.actions.create"), ide_text_faint(), 48.0)
              },
            ],
            (width - 16.0).max(80.0),
            4.0,
            Center,
          ),
          horizontal=8.0,
          vertical=0.0,
        ),
        background=if selected { ide_selection() } else { ide_panel() },
        height=TREE_ROW_HEIGHT,
        width~,
        padding=0.0,
      ).on_tap(
        if exists {
          SelectHandler(key)
        } else {
          CreateHandler(control_name, event)
        },
      ),
    )
  }
  @views.column(rows, spacing=0.0)
}

///|
/// 依赖页签：谁引用了当前对象（控件被哪些子程序的事件绑定；
/// 变量被哪些语句读写）。这是「改动会波及谁」的查询面。
fn context_deps(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let target = match find_selected_control(model) {
    Some(control) => control.name
    None =>
      match current_handler(model) {
        Some(handler) => handler.control_name
        None => return empty_hint(text(t, "app.ctx.deps.none"), width, 120.0)
      }
  }
  let rows : Array[@moui.View[Msg]] = []
  // 绑定依赖：哪些子程序挂在这个控件上
  for handler in model.program.handlers {
    if handler.control_name == target {
      rows.push(
        kv_row(
          "\{text(t, "app.ctx.deps.bound")} · \{text(t, "event.\{handler.event.tag()}")}",
          "×\{handler.body.length()}",
          width - 16.0,
          true,
        ),
      )
    }
  }
  // 变量依赖：变量名在哪些 handler 的语句文本里出现（粗粒度文本匹配——
  // 精确的作用域分析属于语言层，这里只做「可能相关」的提示）
  for variable in model.program.variables {
    let mut users = 0
    for handler in model.program.handlers {
      if @studio_lang.render_stmts(handler.body, model.language.dsl_language()).contains(
          variable.name,
        ) {
        users = users + 1
      }
    }
    if users > 0 {
      rows.push(kv_row(variable.name, "×\{users}", width - 16.0, true))
    }
  }
  if rows.length() == 0 {
    return empty_hint(text(t, "app.ctx.deps.empty"), width, 120.0)
  }
  @views.padding_xy(
    @views.column(rows, spacing=2.0),
    horizontal=8.0,
    vertical=6.0,
  )
}

///|
/// 快速操作条：左/中/右对齐 + 复制 + 删除 + AI 优化。
/// 设计稿 qaBar：24pt 边距、居中 = (640 − w)/2。
fn quick_actions(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let target = match find_selected_control(model) {
    Some(control) => Some(control.name)
    None => None
  }
  let head = panel_head(text(t, "app.qa.title"), "", [], width)
  let buttons : Array[@moui.View[Msg]] = []
  match target {
    None =>
      buttons.push(
        @views.container(
          @views.padding_xy(
            @views.text(
              text(t, "app.qa.none"),
              theme=studio_theme(),
              width=(width - 20.0).max(60.0),
              height=18.0,
              align=TextStart,
            ).foreground(ide_text_faint()),
            horizontal=8.0,
            vertical=0.0,
          ),
          height=TREE_ROW_HEIGHT,
          width~,
          padding=0.0,
        ),
      )
    Some(name) => {
      // 行宽必须按面板宽算：6 格 + 5 个 4px 间隙 + 左右内垫 = 面板宽。
      // 原来把「AI 优化」按 64 声明、实际 ~88，窄栏必溢出。
      let icon_size = 28.0
      let gap = 4.0
      let inner = (width - 16.0).max(120.0)
      let ai_min = 56.0
      let fixed = icon_size * 5.0 + gap * 5.0 + ai_min
      let qa_ai_width = if fixed <= inner {
        (inner - icon_size * 5.0 - gap * 5.0).min(88.0)
      } else {
        // 极窄：优先保住图标按钮，AI 优化收到下限
        ai_min
      }
      let icon_w = if fixed <= inner {
        icon_size
      } else {
        ((inner - gap * 5.0 - ai_min) / 5.0).max(20.0)
      }
      buttons.push(
        @views.padding_xy(
          // 行必须定宽：不定宽的 row 量不到 slack，六个按钮会挤成一段
          // 并被容器居中（见 fill_row 注释）。
          fill_row(
            [
              icon_button(
                ChevronLeft,
                text(t, "app.qa.align_left"),
                false,
                AlignControlLeft(name),
                icon_w,
                AiActionHeight,
                13.0,
              ),
              icon_button(
                Columns,
                text(t, "app.qa.align_center"),
                false,
                AlignControlCenter(name),
                icon_w,
                AiActionHeight,
                13.0,
              ),
              icon_button(
                ChevronRight,
                text(t, "app.qa.align_right"),
                false,
                AlignControlRight(name),
                icon_w,
                AiActionHeight,
                13.0,
              ),
              icon_button(
                Clipboard,
                text(t, "app.inspector.duplicate"),
                false,
                DuplicateControl(name),
                icon_w,
                AiActionHeight,
                13.0,
              ),
              icon_button(
                Trash,
                text(t, "app.inspector.delete"),
                false,
                DeleteControl(name),
                icon_w,
                AiActionHeight,
                13.0,
              ),
              // 手搓而不是 @views.button：button 的 width 是**最小值**，
              // 内容加左右各 16 的内垫会把 64 撑成 ~88，右栏窄时整行溢出
              // （实测 w=820 时「AI 优化」右缘 824 > 820）。
              ai_action_chip(text(t, "app.qa.ai"), qa_ai_width, AiActionHeight),
            ],
            (width - 16.0).max(120.0),
            4.0,
            Center,
          ),
          horizontal=8.0,
          vertical=0.0,
        ),
      )
    }
  }
  @views.container(
    @views.column([head, @views.column(buttons, spacing=0.0)], spacing=0.0).frame(
      width~,
    ),
    background=ide_panel(),
    width~,
    padding=0.0,
  )
}

///|
/// 运行时监视：变量名 + 值 + 类型。未运行时空态提示。
fn watch_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let head = panel_head(
    text(t, "app.watch.title"),
    "",
    [count_badge(watch_rows(model).length().to_string(), 0)],
    width,
    trailing_widths=[56.0],
  )
  let rows = watch_rows(model)
  let body : Array[@moui.View[Msg]] = []
  if rows.length() == 0 {
    body.push(
      @views.container(
        @views.padding_xy(
          @views.text(
            text(t, "app.watch.empty"),
            theme=studio_theme(),
            width=(width - 20.0).max(60.0),
            height=18.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          horizontal=8.0,
          vertical=4.0,
        ),
        width~,
        padding=0.0,
      ),
    )
  } else {
    for row in rows {
      // 名称/类型按内容算宽（变量允许中文语义命名，写死 72 会截断），
      // 值列拿剩余；类型标签用 TextEnd 贴齐。
      let name_w = (text_estimate_width(row.name) * 1.02 + 8.0).max(48.0)
      let type_w = (text_estimate_width(row.type_label) * 1.02 + 8.0).max(36.0)
      body.push(
        @views.container(
          @views.padding_xy(
            @views.row(
              [
                @views.text(
                  row.name,
                  theme=studio_theme(),
                  width=name_w,
                  height=18.0,
                  align=TextStart,
                ).foreground(ide_text_muted()),
                @views.text(
                  row.value,
                  theme=studio_theme(),
                  role=Mono,
                  width=(width - 32.0 - name_w - type_w).max(40.0),
                  height=18.0,
                  align=TextStart,
                ).foreground(ide_text()),
                @views.text(
                  row.type_label,
                  theme=studio_theme(),
                  width=type_w,
                  height=16.0,
                  align=TextEnd,
                ).foreground(ide_text_faint()),
              ],
              spacing=4.0,
              align=Center,
            ),
            horizontal=8.0,
            vertical=0.0,
          ),
          height=TREE_ROW_HEIGHT,
          width~,
          padding=0.0,
        ),
      )
    }
  }
  @views.container(
    @views.column([head, @views.column(body, spacing=0.0)], spacing=0.0),
    background=ide_panel(),
    width~,
    padding=0.0,
  )
}

///|
/// 快速操作行高（与左栏树行同高，视觉上成一条）。
const AiActionHeight : Double = 24.0

///|
/// 「AI 优化」小胶囊：手搓容器而不是 `@views.button`——button 的 width
/// 是**最小值**，内容 + 左右各 16 内垫会把 64 撑成 ~88，窄右栏必溢出。
fn ai_action_chip(
  label : String,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.text(
        label,
        theme=studio_theme(),
        width=(width - 10.0).max(20.0),
        height=16.0,
      ).foreground(ide_accent()),
      width~,
      height~,
    ),
    background=ide_accent_soft(),
    corner_radius=4.0,
    width~,
    height~,
    padding=0.0,
  ).on_tap(GenerateProposal)
}

// ============================================================================
// 非控件对象的属性面板（窗体 / 变量 / 数据）
// ============================================================================

///|
/// 窗体属性：标题 + 设计尺寸。尺寸用**只读**文本：设计坐标系（640×480）
/// 目前是全局常量 `@ir.DESIGN_WIDTH/HEIGHT`，运行舞台按它等比缩放；
/// 允许编辑会与画布/舞台换算、控件越界校验（`InvalidControlRect` 按同一
/// 常量判定）三处脱节。v1 先如实展示，不给一个会破坏不变量的输入框。
fn window_props(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let field_width = (width - 90.0).max(80.0)
  @views.column(
    [
      field_label(t, "app.inspector.window_title", width),
      @views.text_field(
        model.program.window.title,
        on_input=value => SetWindowTitle(value),
        width=field_width,
        height=FIELD_HEIGHT,
      ),
      field_label(t, "app.inspector.window_size", width),
      kv_row(
        text(t, "app.inspector.design_size"),
        "\{@ir.DESIGN_WIDTH} × \{@ir.DESIGN_HEIGHT}",
        width,
        true,
      ),
      field_label(t, "app.inspector.timer_interval", width),
      @views.text_field(
        model.program.window.timer_interval.to_string(),
        on_input=value => SetTimerInterval(value),
        width=field_width,
        height=FIELD_HEIGHT,
      ),
      hint_lines_view(
        text(t, "app.inspector.window_size_hint"),
        width,
        ide_text_faint(),
        3,
      ),
      hint_lines_view(
        text(t, "app.inspector.timer_hint"),
        width,
        ide_text_faint(),
        2,
      ),
      // 窗体级处理器（切片 G）：定时器 / 广播——不属于任何控件
      window_event_rows(model, t, width),
    ],
    spacing=6.0,
    align=Start,
  )
}

///|
/// 窗体级事件行：定时器 / 广播消息——存在即选中（跳到对应草稿），
/// 不存在给创建按钮。
fn window_event_rows(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  for event in [@ir.OnTimer, @ir.OnBroadcast, @ir.OnStart] {
    let exists = @ir.find_handler(model.program, "", event) is Some(_)
    let selected = model.selected_handler == handler_key("", event.tag())
    let action = if exists {
      SelectHandler(handler_key("", event.tag()))
    } else {
      CreateHandler("", event)
    }
    let label = text(t, "event.\{event.tag()}")
    let action_w = text_estimate_width(
        text(
          t,
          if exists {
            "app.inspector.window_event_edit"
          } else {
            "app.inspector.window_event_create"
          },
        ),
      ) +
      34.0
    rows.push(
      @views.container(
        @views.padding_xy(
          fill_row(
            [
              @views.text(
                label,
                theme=studio_theme(),
                width=(width - action_w - 40.0).max(60.0),
                height=18.0,
                align=TextStart,
              ).foreground(if selected { ide_text() } else { ide_text_muted() }),
              foot_chip_like(
                text(
                  t,
                  if exists {
                    "app.inspector.window_event_edit"
                  } else {
                    "app.inspector.window_event_create"
                  },
                ),
                action_w,
                action,
              ),
            ],
            (width - 20.0).max(80.0),
            6.0,
            Center,
          ),
          horizontal=8.0,
          vertical=2.0,
        ),
        background=if selected { ide_selection() } else { ide_panel() },
        width~,
        height=26.0,
        padding=0.0,
      ),
    )
  }
  @views.column(rows, spacing=0.0)
}

///|
/// 变量属性：名称 + 初值 + 删除。名称与初值都即时写回 IR，改名会同步
/// 改写所有引用（见 `rename_variable`）。
fn variable_props(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let variable = match selected_variable(model) {
    Some(variable) => variable
    None => return empty_hint(text(t, "app.inspector.gone"), width, 120.0)
  }
  let field_width = (width - 90.0).max(80.0)
  @views.column(
    [
      field_label(t, "app.inspector.name", width),
      @views.text_field(
        variable.name,
        on_input=value => RenameVariable(variable.name, value),
        width=field_width,
        height=FIELD_HEIGHT,
      ),
      field_label(t, "app.inspector.init", width),
      @views.text_field(
        variable.init,
        on_input=value => SetVariableInit(variable.name, value),
        width=field_width,
        height=FIELD_HEIGHT,
      ),
      hint_lines_view(
        text(t, "app.inspector.variable_hint"),
        width,
        ide_text_faint(),
        2,
      ),
      action_chip(
        text(t, "app.inspector.delete_variable"),
        DeleteVariable(variable.name),
        Quiet,
        28.0,
      ),
    ],
    spacing=6.0,
    align=Start,
  )
}

///|
/// 数据条目属性：来源 + 只读预览。
///
/// 数据条目是从程序**派生**的（列表/表格控件的 `items`，或变量集合），
/// 不是独立实体——所以这里是**只读**视图，编辑入口回到来源控件本身
/// （选中该控件后在同一个属性页签改 items，或改程序语句）。
/// 给一个能改的输入框会让人以为数据有独立存储。

///|
/// **自定义积木**的属性：名字、参数个数、以及「谁在调用它」的提示。
///
/// 为什么参数编辑先只做**个数**：`FuncDef.params` 是位置参数（`Call` 按
/// 顺序传实参），改名要同步改写所有调用点的实参顺序语义——那需要一次
/// 全程序重写。先把「造得出来、看得见、能改主体」做通，参数改名单独一步。
fn function_props(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let func = match selected_function(model) {
    Some(func) => func
    None => return empty_hint(text(t, "app.inspector.gone"), width, 120.0)
  }
  let field_width = (width - 90.0).max(80.0)
  let rows : Array[@moui.View[Msg]] = [
    field_label(t, "app.inspector.name", width),
    @views.text_field(
      func.name,
      on_input=new_value => RenameFunction(func.name, new_value),
      width=field_width,
      height=FIELD_HEIGHT,
    ),
    field_label(t, "app.inspector.function_params", width),
    @views.text(
      text_with(t, "app.inspector.function_param_count", [
        ("count", func.params.length().to_string()),
      ]),
      theme=studio_theme(),
      width=field_width,
      height=20.0,
      align=TextStart,
    ).foreground(ide_text_muted()),
    field_label(t, "app.inspector.function_body", width),
    @views.text(
      text_with(t, "app.inspector.function_body_hint", [
        ("count", func.body.length().to_string()),
      ]),
      theme=studio_theme(),
      width=field_width,
      height=20.0,
      align=TextStart,
    ).foreground(ide_text_muted()),
  ]
  @views.column(rows, spacing=6.0)
}

///|
fn data_props(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let entry = match selected_data_file(model) {
    Some(entry) => entry
    None => return empty_hint(text(t, "app.inspector.gone"), width, 120.0)
  }
  @views.column(
    [
      field_label(t, "app.inspector.data_source", width),
      kv_row(text(t, "app.inspector.name"), entry.name, width, false),
      kv_row(text(t, "app.inspector.data_meta"), entry.meta, width, true),
      kv_row(
        text(t, "app.inspector.data_access"),
        if entry.locked {
          text(t, "app.data.readonly")
        } else {
          text(t, "app.data.live")
        },
        width,
        false,
      ),
      field_label(t, "app.inspector.data_preview", width),
      @views.container(
        @views.padding_xy(
          @views.text(
            if entry.preview == "" {
              text(t, "app.data.empty")
            } else {
              entry.preview
            },
            theme=studio_theme(),
            role=Mono,
            width=(width - 12.0).max(60.0),
            height=120.0,
            align=TextStart,
          ).foreground(ide_text_muted()),
          horizontal=4.0,
          vertical=4.0,
        ),
        background=ide_editor_background(),
        corner_radius=4.0,
        width~,
        padding=0.0,
      ),
      hint_lines_view(
        text(t, "app.inspector.data_hint"),
        width,
        ide_text_faint(),
        3,
      ),
    ],
    spacing=6.0,
    align=Start,
  )
}

///|
/// 运行时页签：`moui_devtools` 快照的呈现层。
/// 报告是入口注入回调格式化的纯文本——这里只做三件事：单行摘要、
/// 刷新按钮（RuntimeRefresh，采样是 O(节点数)，绝不自动连刷）、
/// 分节报告滚动 + 摘要历史条。
fn context_runtime(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let refresh_w = text_estimate_width(text(t, "app.runtime.refresh")) + 34.0
  let head = fill_row(
    [
      @views.text(
        text(t, "app.runtime.title"),
        theme=studio_theme(),
        width=(width - refresh_w - 30.0).max(60.0),
        height=18.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
      foot_chip_like(text(t, "app.runtime.refresh"), refresh_w, RuntimeRefresh),
    ],
    (width - 16.0).max(80.0),
    6.0,
    Center,
  )
  let sections : Array[@moui.View[Msg]] = [head]
  match model.runtime_report {
    Some(sample) => {
      sections.push(
        @views.container(
          @views.padding_xy(
            @views.text(
              sample.summary,
              theme=studio_theme(),
              role=Mono,
              width=(width - 24.0).max(80.0),
              height=16.0,
              align=TextStart,
            ).foreground(ide_ir_highlight()),
            horizontal=8.0,
            vertical=4.0,
          ),
          background=ide_panel_alt(),
          width~,
          padding=0.0,
        ),
      )
      for line in sample.report.split("\n") {
        sections.push(
          @views.container(
            @views.padding_xy(
              @views.text(
                if line == "" {
                  " "
                } else {
                  line.to_owned()
                },
                theme=studio_theme(),
                role=Mono,
                width=(width - 24.0).max(80.0),
                height=16.0,
                align=TextStart,
              ).foreground(ide_text_muted()),
              horizontal=8.0,
              vertical=1.0,
            ),
            background=ide_panel(),
            width~,
            padding=0.0,
          ),
        )
      }
    }
    None =>
      sections.push(
        @views.container(
          @views.padding_xy(
            @views.text(
              text(
                t,
                if model.runtime_missing {
                  "app.runtime.unavailable"
                } else {
                  "app.runtime.hint"
                },
              ),
              theme=studio_theme(),
              width=(width - 24.0).max(80.0),
              height=16.0,
              align=TextStart,
            ).foreground(ide_text_faint()),
            horizontal=8.0,
            vertical=6.0,
          ),
          background=ide_panel(),
          width~,
          padding=0.0,
        ),
      )
  }
  // 摘要历史条（新到旧，去重，封顶 24 条）
  if model.runtime_history.length() > 1 {
    sections.push(
      @views.container(
        @views.padding_xy(
          @views.text(
            text(t, "app.runtime.history"),
            theme=studio_theme(),
            width=(width - 24.0).max(80.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          horizontal=8.0,
          vertical=4.0,
        ),
        background=ide_panel(),
        width~,
        padding=0.0,
      ),
    )
    for summary in model.runtime_history {
      sections.push(
        @views.container(
          @views.padding_xy(
            @views.text(
              summary,
              theme=studio_theme(),
              role=Mono,
              width=(width - 24.0).max(80.0),
              height=16.0,
              align=TextStart,
            ).foreground(ide_text_faint()),
            horizontal=8.0,
            vertical=1.0,
          ),
          background=ide_panel(),
          width~,
          padding=0.0,
        ),
      )
    }
  }
  @views.column(sections, spacing=0.0)
}

///|
/// 右栏小胶囊：与代码页脚 foot_chip 同款（foot_chip 在 code_view.mbt，
/// 未导出；此处按同一做法本地实现，避免为一个小胶囊扩大导出面）。
fn foot_chip_like(
  label : String,
  width : Double,
  on_click : Msg,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.text(
        label,
        theme=studio_theme(),
        width=(width - 6.0).max(20.0),
        height=16.0,
      ).foreground(ide_accent()),
      width~,
      height=22.0,
    ),
    background=ide_accent_soft(),
    corner_radius=4.0,
    width~,
    height=22.0,
    padding=0.0,
  )
  .accessibility_label(label)
  .on_tap(on_click)
}
