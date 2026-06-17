///|
pub fn[Msg] custom(
  kind? : String = "Custom",
  key? : String? = None,
  measure~ : (@core.WidgetLayoutContext) -> @core.WidgetLayoutResult,
  paint? : (@core.WidgetPaintContext) -> @core.WidgetPaintPlan = _ctx => {
    @core.WidgetPaintPlan::empty()
  },
  event? : (@core.WidgetEventContext) -> @core.WidgetEventResult[Msg] = _ctx => {
    @core.WidgetEventResult::ignored()
  },
  semantics? : () -> @core.WidgetSemanticsInfo = () => {
    @core.WidgetSemanticsInfo::new()
  },
  focusable? : Bool = false,
) -> @core.View[Msg] {
  @core.View::widget(
    @core.Widget::new(
      identity=() => @core.WidgetIdentity::new(kind~, key~),
      layout=measure,
      paint~,
      event~,
      semantics~,
      focusable=() => focusable,
    ),
  )
}

///|
pub fn[Msg] custom_children_layout(
  children~ : Array[@core.View[Msg]],
  measure~ : (@core.CustomLayoutContext) -> @core.Size,
  place~ : (@core.CustomPlacementContext) -> Array[@core.Rect],
  paint? : (@core.Rect) -> Array[@core.DrawCommand] = _frame => [],
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
  kind? : String = "CustomLayout",
  key? : String? = None,
) -> @core.View[Msg] {
  let cache = @core.CustomLayoutCache::new()
  @core.View::widget(
    @core.Widget::new(
      identity=() => @core.WidgetIdentity::new(kind~, key~),
      children=() => children,
      layout=ctx => {
        let cache_key = custom_layout_cache_key(ctx.child_sizes)
        let child_baselines = custom_layout_default_baselines(ctx.child_sizes)
        let context = @core.CustomLayoutContext::{
          constraints: ctx.constraints,
          child_sizes: ctx.child_sizes,
          child_baselines,
          child_priorities: custom_layout_default_priorities(ctx.child_sizes),
          child_alignment_guides: custom_layout_alignment_guides(
            ctx.child_sizes,
            child_baselines,
          ),
          cache,
          cache_key,
          layout_direction: @core.LayoutDirection::LeftToRight,
          safe_area: @core.Insets::symmetric(),
          viewport: None,
        }
        let size = measure(context)
        let absolute_frame = @core.Rect::new(
          x=0.0,
          y=0.0,
          width=size.width,
          height=size.height,
        )
        let placement_context = @core.CustomPlacementContext::{
          frame: absolute_frame,
          measured_size: size,
          child_sizes: ctx.child_sizes,
          child_baselines,
          child_priorities: custom_layout_default_priorities(ctx.child_sizes),
          child_alignment_guides: custom_layout_alignment_guides(
            ctx.child_sizes,
            child_baselines,
          ),
          cache,
          cache_key,
          layout_direction: @core.LayoutDirection::LeftToRight,
          safe_area: @core.Insets::symmetric(),
          viewport: Some(size),
        }
        @core.WidgetLayoutResult::new(
          size~,
          child_frames=place(placement_context).map(frame => {
            @core.Rect::new(
              x=frame.origin.x - absolute_frame.origin.x,
              y=frame.origin.y - absolute_frame.origin.y,
              width=frame.size.width,
              height=frame.size.height,
            )
          }),
        )
      },
      paint=ctx => @core.WidgetPaintPlan::commands(paint(ctx.frame)),
      semantics=() => {
        @core.WidgetSemanticsInfo::new(
          role=semantics_role,
          label=semantics_label,
          value=semantics_label,
        )
      },
    ),
  )
}

///|
pub fn[Msg] rect(
  width~ : Double,
  height~ : Double,
  color~ : @core.Color,
  kind? : String = "Rect",
  key? : String? = None,
  on_tap? : Msg? = None,
) -> @core.View[Msg] {
  custom(
    kind~,
    key~,
    measure=ctx => {
      @core.WidgetLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=ctx => {
      @core.WidgetPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, color),
      ])
    },
    event=ctx => {
      match (ctx.event, on_tap) {
        (@core.AppEvent::Pointer(event), Some(message)) =>
          if event.phase == @core.PointerPhase::Up &&
            ctx.frame.contains(event.position) {
            @core.WidgetEventResult::message(message)
          } else {
            @core.WidgetEventResult::ignored()
          }
        _ => @core.WidgetEventResult::ignored()
      }
    },
  )
}

///|
fn custom_layout_cache_key(sizes : Array[@core.Size]) -> String {
  let mut key = "widget-custom-layout"
  for size in sizes {
    key = "\{key};\{size.width}x\{size.height}"
  }
  key
}

///|
fn custom_layout_default_baselines(sizes : Array[@core.Size]) -> Array[Double?] {
  sizes.map(size => Some(size.height * 0.8))
}

///|
fn custom_layout_default_priorities(sizes : Array[@core.Size]) -> Array[Double] {
  sizes.map(_size => 0.0)
}

///|
fn custom_layout_alignment_guides(
  sizes : Array[@core.Size],
  baselines : Array[Double?],
) -> Array[@core.AlignmentGuideSet] {
  let guides : Array[@core.AlignmentGuideSet] = []
  for index, size in sizes {
    let baseline = if index < baselines.length() {
      baselines[index]
    } else {
      None
    }
    guides.push(
      @core.AlignmentGuideSet::from_size(size, first_baseline=baseline),
    )
  }
  guides
}
