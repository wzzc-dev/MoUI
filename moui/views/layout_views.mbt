///|
fn[Msg] stack_layout(
  children~ : Array[@core.View[Msg]],
  kind? : String = "Stack",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => "stack",
    children=() => children,
    layout=ctx => {
      let mut width = 0.0
      let mut height = 0.0
      let frames : Array[@core.Rect] = []
      for size in ctx.child_sizes {
        width = view_max_double(width, size.width)
        height = view_max_double(height, size.height)
      }
      let size = ctx.constraints.constrain(@core.Size::new(width~, height~))
      for _child in ctx.child_sizes {
        frames.push(
          @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
        )
      }
      @core.ViewLayoutResult::new(size~, child_frames=frames)
    },
    paint=_ctx => @core.ViewPaintPlan::empty(),
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn[Msg] padding_layout(
  child~ : @core.View[Msg],
  insets~ : @core.Insets,
  kind? : String = "Padding",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "padding:\{insets.top}:\{insets.right}:\{insets.bottom}:\{insets.left}"
    },
    children=() => [child],
    child_constraints=constraints => constraints.deflate(insets),
    layout=ctx => {
      let child_size = first_child_size(ctx.child_sizes)
      let size = ctx.constraints.constrain(child_size.inflate(insets))
      // Clamp the child frame to the deflated available area so a greedy child
      // (e.g. web_view reporting max constraints) cannot overflow this node's
      // own frame in the place pass.
      let available = ctx.constraints.deflate(insets)
      @core.ViewLayoutResult::new(size~, child_frames=[
        @core.Rect::new(
          x=insets.left,
          y=insets.top,
          width=view_min_double(
            view_max_double(0.0, available.max.width),
            child_size.width,
          ),
          height=view_min_double(
            view_max_double(0.0, available.max.height),
            child_size.height,
          ),
        ),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn[Msg] frame_layout(
  child~ : @core.View[Msg],
  width~ : Double?,
  height~ : Double?,
  min_width~ : Double?,
  min_height~ : Double?,
  max_width~ : Double?,
  max_height~ : Double?,
  kind? : String = "Frame",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "frame:\{view_double_option_revision(width)}:\{view_double_option_revision(height)}:\{view_double_option_revision(min_width)}:\{view_double_option_revision(min_height)}:\{view_double_option_revision(max_width)}:\{view_double_option_revision(max_height)}"
    },
    children=() => [child],
    child_constraints=constraints => {
      frame_constraints_for_measure(constraints, width~, height~)
    },
    layout=ctx => {
      let size = ctx.constraints.constrain(
        resolve_frame_size(
          first_child_size(ctx.child_sizes),
          width~,
          height~,
          min_width~,
          min_height~,
          max_width~,
          max_height~,
        ),
      )
      @core.ViewLayoutResult::new(size~, child_frames=[
        @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn[Msg] container_box(
  child? : @core.View[Msg]? = None,
  size? : @core.Size? = None,
  background? : @core.Brush? = None,
  border? : @core.BorderStyle? = None,
  corner_radius? : Double = 0.0,
  shadow? : @core.ShadowStyle? = None,
  kind? : String = "Container",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "container:\{view_size_option_revision(size)}:\{view_brush_option_revision(background)}:\{view_border_option_revision(border)}:\{corner_radius}:\{view_shadow_option_revision(shadow)}"
    },
    children=() => {
      match child {
        Some(value) => [value]
        None => []
      }
    },
    layout=ctx => {
      let measured = match size {
        Some(value) => value
        None => first_child_size(ctx.child_sizes)
      }
      let measured = ctx.constraints.constrain(measured)
      let frames = if ctx.child_sizes.length() > 0 {
        let child_size = ctx.child_sizes[0]
        let x = views_max_double(0.0, (measured.width - child_size.width) / 2.0)
        let y = views_max_double(
          0.0,
          (measured.height - child_size.height) / 2.0,
        )
        [
          @core.Rect::new(
            x~,
            y~,
            width=child_size.width,
            height=child_size.height,
          ),
        ]
      } else {
        []
      }
      @core.ViewLayoutResult::new(size=measured, child_frames=frames)
    },
    paint=ctx => {
      container_paint(
        ctx.frame,
        background~,
        border~,
        corner_radius~,
        shadow~,
        scheme=ctx.environment.color_scheme(),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn[Msg] grid_layout(
  children~ : Array[@core.View[Msg]],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
  kind? : String = "Grid",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => "grid:\{columns}:\{row_spacing}:\{column_spacing}",
    children=() => children,
    layout=ctx => {
      let columns = view_max_int(1, columns)
      let count = ctx.child_sizes.length()
      let rows = grid_row_count(count, columns)
      let mut cell_width = 0.0
      let mut cell_height = 0.0
      for size in ctx.child_sizes {
        cell_width = view_max_double(cell_width, size.width)
        cell_height = view_max_double(cell_height, size.height)
      }
      let measured = ctx.constraints.constrain(
        @core.Size::new(
          width=cell_width * columns.to_double() +
            column_spacing * view_max_int(0, columns - 1).to_double(),
          height=cell_height * rows.to_double() +
            row_spacing * view_max_int(0, rows - 1).to_double(),
        ),
      )
      let frames : Array[@core.Rect] = []
      for index, _size in ctx.child_sizes {
        let row = index / columns
        let column = index % columns
        frames.push(
          @core.Rect::new(
            x=column.to_double() * (cell_width + column_spacing),
            y=row.to_double() * (cell_height + row_spacing),
            width=cell_width,
            height=cell_height,
          ),
        )
      }
      @core.ViewLayoutResult::new(size=measured, child_frames=frames)
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn[Msg] list_layout(
  children~ : Array[@core.View[Msg]],
  spacing? : Double = 0.0,
  kind? : String = "List",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => "list:\{spacing}",
    children=() => children,
    layout=ctx => {
      let mut width = 0.0
      let mut height = 0.0
      let frames : Array[@core.Rect] = []
      for index, size in ctx.child_sizes {
        if index > 0 {
          height = height + spacing
        }
        frames.push(
          @core.Rect::new(x=0.0, y=height, width=size.width, height=size.height),
        )
        width = view_max_double(width, size.width)
        height = height + size.height
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
        child_frames=frames,
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn[Msg] scroll_container(
  child~ : @core.View[Msg],
  offset? : @core.Point = @core.Point::new(x=0.0, y=0.0),
  viewport? : @core.Size? = None,
  state? : @core.ScrollState? = None,
  on_scroll? : ((@core.Point) -> Msg)? = None,
  kind? : String = "Scroll",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      let current = scroll_offset(offset, state)
      "scroll:\{current.x}:\{current.y}:\{view_size_option_revision(viewport)}:\{state is Some(_)}:\{on_scroll is Some(_)}"
    },
    children=() => [child],
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      let viewport_size = viewport.unwrap_or(first_child_size(ctx.child_sizes))
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(viewport_size),
        child_frames=[
          scroll_child_frame(
            frame=@core.Rect::new(
              x=0.0,
              y=0.0,
              width=viewport_size.width,
              height=viewport_size.height,
            ),
            offset=scroll_offset(offset, state),
            viewport=viewport_size,
            child_size=first_child_size(ctx.child_sizes),
          ),
        ],
      )
    },
    paint=ctx => {
      let viewport_size = viewport.unwrap_or(ctx.frame.size)
      {
        commands: [
          @core.DrawCommand::PushClip(
            @core.Rect::new(
              x=ctx.frame.origin.x,
              y=ctx.frame.origin.y,
              width=viewport_size.width,
              height=viewport_size.height,
            ),
          ),
        ],
        child_layers: [],
        post_commands: [@core.DrawCommand::PopClip],
        overlay_commands: [],
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if ctx.frame.contains(event.position) &&
            (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
            match (state, on_scroll) {
              (Some(state), Some(handler)) => {
                state.scroll_to(
                  x=0.0,
                  y=max_scroll_offset(
                    0.0,
                    state.offset().y - event.wheel_delta.y,
                  ),
                )
                view_event_result(
                  changed=true,
                  activated=true,
                  captured=true,
                  dirty=@core.ViewDirtyHint::ViewLayoutDirty,
                  messages=[handler(event.wheel_delta)],
                )
              }
              (Some(state), None) => {
                state.scroll_to(
                  x=0.0,
                  y=max_scroll_offset(
                    0.0,
                    state.offset().y - event.wheel_delta.y,
                  ),
                )
                view_event_result(
                  changed=true,
                  captured=true,
                  dirty=@core.ViewDirtyHint::ViewLayoutDirty,
                )
              }
              (None, Some(handler)) =>
                view_event_result(
                  changed=true,
                  activated=true,
                  captured=true,
                  dirty=@core.ViewDirtyHint::ViewPaintDirty,
                  messages=[handler(event.wheel_delta)],
                )
              (None, None) => @core.ViewEventResult::ignored()
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn first_child_size(sizes : Array[@core.Size]) -> @core.Size {
  match sizes {
    [size, ..] => size
    [] => @core.Size::new(width=0.0, height=0.0)
  }
}

///|
fn frame_constraints_for_measure(
  constraints : @core.Constraints,
  width~ : Double?,
  height~ : Double?,
) -> @core.Constraints {
  match (width, height) {
    (Some(width), Some(height)) => constraints.tighten(width~, height~).loosen()
    (Some(width), None) => constraints.tighten(width~).loosen()
    (None, Some(height)) => constraints.tighten(height~).loosen()
    (None, None) => constraints.loosen()
  }
}

///|
fn resolve_frame_size(
  child : @core.Size,
  width~ : Double?,
  height~ : Double?,
  min_width~ : Double?,
  min_height~ : Double?,
  max_width~ : Double?,
  max_height~ : Double?,
) -> @core.Size {
  let width = width.unwrap_or(child.width)
  let height = height.unwrap_or(child.height)
  let min_width = min_width.unwrap_or(0.0)
  let min_height = min_height.unwrap_or(0.0)
  let max_width = max_width.unwrap_or(width)
  let max_height = max_height.unwrap_or(height)
  @core.Size::new(width~, height~).clamp({
    min: @core.Size::new(width=min_width, height=min_height),
    max: @core.Size::new(
      width=view_max_double(min_width, max_width),
      height=view_max_double(min_height, max_height),
    ),
  })
}

///|
fn container_paint(
  frame : @core.Rect,
  background~ : @core.Brush?,
  border~ : @core.BorderStyle?,
  corner_radius~ : Double,
  shadow~ : @core.ShadowStyle?,
  scheme~ : @core.ColorScheme,
) -> @core.ViewPaintPlan {
  let commands : Array[@core.DrawCommand] = []
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  emit_elevation_shadow(commands, rounded, shadow, scheme)
  match background {
    Some(brush) =>
      commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, brush))
    None => ()
  }
  match border {
    Some(style) =>
      if style.width > 0.0 {
        commands.push(
          @core.DrawCommand::StrokeRoundedRectBrush(
            rounded,
            style.brush,
            style.width,
          ),
        )
      }
    None => ()
  }
  @core.ViewPaintPlan::commands(commands)
}

///|
fn grid_row_count(count : Int, columns : Int) -> Int {
  if count == 0 {
    0
  } else {
    (count + columns - 1) / columns
  }
}

///|
fn scroll_offset(
  offset : @core.Point,
  state : @core.ScrollState?,
) -> @core.Point {
  match state {
    Some(state) => state.offset()
    None => offset
  }
}

///|
fn scroll_child_frame(
  frame~ : @core.Rect,
  offset~ : @core.Point,
  viewport~ : @core.Size,
  child_size~ : @core.Size,
) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x - offset.x,
    y=frame.origin.y - offset.y,
    width=view_max_double(viewport.width, child_size.width),
    height=view_max_double(viewport.height, child_size.height),
  )
}

///|
fn max_scroll_offset(min : Double, value : Double) -> Double {
  if value < min {
    min
  } else {
    value
  }
}

///|
fn view_double_option_revision(value : Double?) -> String {
  match value {
    Some(value) => "\{value}"
    None => "none"
  }
}

///|
fn view_size_option_revision(value : @core.Size?) -> String {
  match value {
    Some(value) => "\{value.width}x\{value.height}"
    None => "auto"
  }
}
