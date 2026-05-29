///|
fn append_picker_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : PickerViewSpec,
  frame : Rect,
  environment : RenderEnvironment,
) -> Unit {
  let rounded = RoundedRect::new(rect=frame, radius=data.cornerRadius)
  commands.push(FillRoundedRectBrush(rounded, data.background))
  commands.push(
    StrokeRoundedRectBrush(
      rounded,
      Brush::solid(Theme::default().palette.surface_variant),
      1.0,
    ),
  )
  let mut selected_label = data.placeholder
  for item in data.items {
    if item.id == data.selected.get() {
      selected_label = item.label
      break
    }
  }
  let text_frame = frame.inset(Insets::symmetric(horizontal=12.0, vertical=0.0))
  commands.push(
    DrawText(
      TextRun::new(
        text=selected_label,
        frame=text_frame,
        font=environment_font(environment, data.font),
        color=environment_color(environment, data.foreground),
        align=TextAlign::TextStart,
      ),
    ),
  )
  let arrow_size = 12.0
  let arrow_x = frame.origin.x + frame.size.width - arrow_size - 12.0
  let arrow_y = frame.origin.y + (frame.size.height - arrow_size) / 2.0
  let arrow_text = if element.control.picker_expanded { "▲" } else { "▼" }
  commands.push(
    DrawText(
      TextRun::new(
        text=arrow_text,
        frame=Rect::new(
          x=arrow_x,
          y=arrow_y,
          width=arrow_size,
          height=arrow_size,
        ),
        font=FontSpec::new(size=arrow_size * 0.9, weight=400),
        color=environment_color(environment, data.foreground),
        align=TextAlign::TextCenter,
      ),
    ),
  )
  if element.control.picker_expanded {
    let item_height = 36.0
    let count = data.items.length().to_double()
    let list_height = min_double(data.maxHeight, count * item_height)
    let list_frame = Rect::new(
      x=frame.origin.x,
      y=frame.origin.y + frame.size.height + 4.0,
      width=frame.size.width,
      height=list_height,
    )
    let list_rounded = RoundedRect::new(
      rect=list_frame,
      radius=data.cornerRadius,
    )
    commands.push(
      DrawShadow(
        ShadowSpec::new(
          rect=list_rounded,
          color=Color::black().with_alpha(0.15),
          offset=Point::new(x=0.0, y=4.0),
          blur_radius=12.0,
          spread=0.0,
        ),
      ),
    )
    commands.push(FillRoundedRectBrush(list_rounded, data.background))
    for i, item in data.items {
      let index = i.to_double()
      let item_frame = Rect::new(
        x=list_frame.origin.x,
        y=list_frame.origin.y + index * item_height,
        width=list_frame.size.width,
        height=item_height,
      )
      let is_selected = item.id == data.selected.get()
      if is_selected {
        commands.push(
          FillRoundedRectBrush(
            RoundedRect::new(
              rect=item_frame.inset(
                Insets::symmetric(horizontal=4.0, vertical=2.0),
              ),
              radius=4.0,
            ),
            Brush::solid(Theme::default().palette.primary.with_alpha(0.1)),
          ),
        )
      }
      commands.push(
        DrawText(
          TextRun::new(
            text=item.label,
            frame=item_frame.inset(
              Insets::symmetric(horizontal=12.0, vertical=0.0),
            ),
            font=environment_font(environment, data.font),
            color=environment_color(
              environment,
              if is_selected {
                Theme::default().palette.primary
              } else {
                data.foreground
              },
            ),
            align=TextAlign::TextStart,
          ),
        ),
      )
    }
  }
}

///|
fn append_datepicker_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : DatePickerViewSpec,
  frame : Rect,
  environment : RenderEnvironment,
) -> Unit {
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  let theme = Theme::default()
  let border_color = Brush::solid(theme.palette.outline.with_alpha(0.5))

  // 绘制选择器背景和边框
  commands.push(FillRoundedRectBrush(rounded, data.background))
  commands.push(StrokeRoundedRectBrush(rounded, border_color, 1.0))

  // 显示选中的日期或占位符
  let selected = data.selected.get()
  let display_text = selected.format(data.mode)
  let font = environment_font(environment, data.font)
  let color = environment_color(environment, data.foreground)
  commands.push(
    DrawText(
      TextRun::new(
        text=display_text,
        frame=frame.inset(Insets::symmetric(horizontal=12.0, vertical=0.0)),
        font~,
        color~,
        align=TextAlign::TextStart,
      ),
    ),
  )

  // 绘制箭头指示器
  let arrow_size = 16.0
  let arrow_frame = Rect::new(
    x=frame.origin.x + frame.size.width - arrow_size - 12.0,
    y=frame.origin.y + (frame.size.height - arrow_size) / 2.0,
    width=arrow_size,
    height=arrow_size,
  )
  commands.push(
    DrawText(
      TextRun::new(
        text="▼",
        frame=arrow_frame,
        font=FontSpec::new(size=12.0),
        color=data.foreground,
      ),
    ),
  )

  // 展开时显示日期选择面板
  if element.control.datepicker_expanded {
    let panel_width = max_double(frame.size.width, 280.0)
    let panel_height = 350.0
    let panel_frame = Rect::new(
      x=frame.origin.x,
      y=frame.origin.y + frame.size.height + 4.0,
      width=panel_width,
      height=panel_height,
    )
    let panel_rounded = RoundedRect::new(rect=panel_frame, radius=8.0)
    commands.push(
      DrawShadow(
        ShadowSpec::new(
          rect=panel_rounded,
          color=Color::black().with_alpha(0.15),
          offset=Point::new(x=0.0, y=4.0),
          blur_radius=12.0,
          spread=0.0,
        ),
      ),
    )
    commands.push(FillRoundedRectBrush(panel_rounded, data.background))

    // 绘制标题和导航
    let header_height = 50.0
    let header_frame = Rect::new(
      x=panel_frame.origin.x,
      y=panel_frame.origin.y,
      width=panel_frame.size.width,
      height=header_height,
    )
    let view_date = element.control.datepicker_view
    let header_text = "{view_date.year}年{view_date.month}月"
    commands.push(
      DrawText(
        TextRun::new(
          text=header_text,
          frame=header_frame,
          font=FontSpec::new(size=16.0, weight=600),
          color=data.foreground,
        ),
      ),
    )

    // 绘制左右导航按钮
    let button_size = 32.0
    let left_button_frame = Rect::new(
      x=panel_frame.origin.x + 8.0,
      y=panel_frame.origin.y + (header_height - button_size) / 2.0,
      width=button_size,
      height=button_size,
    )
    let right_button_frame = Rect::new(
      x=panel_frame.origin.x + panel_frame.size.width - button_size - 8.0,
      y=panel_frame.origin.y + (header_height - button_size) / 2.0,
      width=button_size,
      height=button_size,
    )
    commands.push(
      DrawText(
        TextRun::new(
          text="◀",
          frame=left_button_frame,
          font=FontSpec::new(size=18.0),
          color=data.foreground,
        ),
      ),
    )
    commands.push(
      DrawText(
        TextRun::new(
          text="▶",
          frame=right_button_frame,
          font=FontSpec::new(size=18.0),
          color=data.foreground,
        ),
      ),
    )

    // 绘制星期标题
    let day_header_height = 36.0
    let day_cell_width = panel_frame.size.width / 7.0
    let day_names = ["日", "一", "二", "三", "四", "五", "六"]
    let mut day_index = 0
    while day_index < 7 {
      let day = day_names[day_index]
      let day_frame = Rect::new(
        x=panel_frame.origin.x + day_index.to_double() * day_cell_width,
        y=panel_frame.origin.y + header_height,
        width=day_cell_width,
        height=day_header_height,
      )
      commands.push(
        DrawText(
          TextRun::new(
            text=day,
            frame=day_frame,
            font=FontSpec::new(size=12.0, weight=500),
            color=data.foreground.with_alpha(0.6),
          ),
        ),
      )
      day_index = day_index + 1
    }

    // 绘制日期网格
    let cell_height = 36.0
    let start_y = panel_frame.origin.y + header_height + day_header_height

    // 计算该月第一天是星期几 (0=周日, 1=周一...)
    // 使用 Zeller 公式的简化版本
    let year = view_date.year
    let month = view_date.month
    let q = 1
    let m = if month < 3 { month + 12 } else { month }
    let y = if month < 3 { year - 1 } else { year }
    let k = y % 100
    let j = y / 100
    let h = (q + 13 * (m + 1) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
    let first_day_weekday = h

    let days_in_month_count = days_in_month(year, month)

    // 绘制当前月的日期
    let mut day = 1
    while day <= days_in_month_count {
      let total_index = first_day_weekday + day - 1
      let col = total_index % 7
      let row = total_index / 7
      let cell_frame = Rect::new(
        x=panel_frame.origin.x + col.to_double() * day_cell_width,
        y=start_y + row.to_double() * cell_height,
        width=day_cell_width,
        height=cell_height,
      )

      let is_selected = selected.year == year &&
        selected.month == month &&
        selected.day == day
      let candidate = { ..selected, year, month, day }
      let is_selectable = date_value_in_range(
        candidate,
        data.min_date,
        data.max_date,
      )
      let cell_rounded = RoundedRect::new(
        rect=cell_frame.inset(Insets::all(4.0)),
        radius=18.0,
      )

      if is_selected {
        commands.push(FillRoundedRect(cell_rounded, theme.palette.primary))
      }

      let day_color = if is_selected {
        Color::white()
      } else if !is_selectable {
        data.foreground.with_alpha(0.28)
      } else {
        data.foreground
      }

      commands.push(
        DrawText(
          TextRun::new(
            text="{day}",
            frame=cell_frame,
            font=FontSpec::new(size=14.0),
            color=day_color,
          ),
        ),
      )
      day = day + 1
    }
  }
}
