(() => {
  const _M0FPB19int__to__string__js = (x, radix) => {
    return x.toString(radix);
  };
  const _M0MPB7JSArray4push = (arr, val) => { arr.push(val); };
  function $bound_check(arr, index) {
    if (index < 0 || index >= arr.length) throw new Error("Index out of bounds");
  }
  class $PanicError extends Error {}
  function $panic() {
    throw new $PanicError();
  }
  function _M0TP310wzzc_2ddev4moui4core4Size(param0, param1) {
    this.width = param0;
    this.height = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core15CrossAxisOffset(param0, param1) {
    this.offset = param0;
    this.size = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core11FlexOffsets(param0, param1) {
    this.leading = param0;
    this.gap = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core5Point(param0, param1) {
    this.x = param0;
    this.y = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core4Rect(param0, param1) {
    this.origin = param0;
    this.size = param1;
  }
  function _M0TPB8MutLocalGdE(param0) {
    this.val = param0;
  }
  function _M0TP310wzzc_2ddev4moui4core5Color(param0, param1, param2, param3) {
    this.r = param0;
    this.g = param1;
    this.b = param2;
    this.a = param3;
  }
  function _M0TP310wzzc_2ddev4moui4core8FontSpec(param0, param1, param2) {
    this.family = param0;
    this.size = param1;
    this.weight = param2;
  }
  function _M0TP310wzzc_2ddev4moui4core11RoundedRect(param0, param1) {
    this.rect = param0;
    this.radius = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core9ViewStyle(param0, param1, param2, param3) {
    this.font = param0;
    this.foreground = param1;
    this.background = param2;
    this.corner_radius = param3;
  }
  function _M0DTPC16option6OptionGdE4None() {}
  _M0DTPC16option6OptionGdE4None.prototype.$tag = 0;
  const _M0DTPC16option6OptionGdE4None__ = new _M0DTPC16option6OptionGdE4None();
  function _M0DTPC16option6OptionGdE4Some(param0) {
    this._0 = param0;
  }
  _M0DTPC16option6OptionGdE4Some.prototype.$tag = 1;
  function _M0TP310wzzc_2ddev4moui4core10DirtyFlags(param0, param1, param2) {
    this.needs_build = param0;
    this.needs_layout = param1;
    this.needs_paint = param2;
  }
  function _M0TP310wzzc_2ddev4moui4core9ElementId(param0) {
    this.value = param0;
  }
  function _M0TPB8MutLocalGiE(param0) {
    this.val = param0;
  }
  function _M0TP310wzzc_2ddev4moui4core11MountResult(param0, param1) {
    this.node = param0;
    this.next_id = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core11ElementNode(param0, param1, param2, param3, param4, param5) {
    this.id = param0;
    this.key = param1;
    this.spec = param2;
    this.children = param3;
    this.dirty = param4;
    this.button_state = param5;
  }
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand5Clear(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand5Clear.prototype.$tag = 0;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand8FillRect(param0, param1) {
    this._0 = param0;
    this._1 = param1;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand8FillRect.prototype.$tag = 1;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand10StrokeRect(param0, param1, param2) {
    this._0 = param0;
    this._1 = param1;
    this._2 = param2;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand10StrokeRect.prototype.$tag = 2;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand15FillRoundedRect(param0, param1) {
    this._0 = param0;
    this._1 = param1;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand15FillRoundedRect.prototype.$tag = 3;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand17StrokeRoundedRect(param0, param1, param2) {
    this._0 = param0;
    this._1 = param1;
    this._2 = param2;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand17StrokeRoundedRect.prototype.$tag = 4;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText.prototype.$tag = 5;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand9DrawImage(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand9DrawImage.prototype.$tag = 6;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand8PushClip(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand8PushClip.prototype.$tag = 7;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand7PopClip() {}
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand7PopClip.prototype.$tag = 8;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand13PushTransform(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand13PushTransform.prototype.$tag = 9;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand12PopTransform() {}
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand12PopTransform.prototype.$tag = 10;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand11PushOpacity(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand11PushOpacity.prototype.$tag = 11;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand10PopOpacity() {}
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand10PopOpacity.prototype.$tag = 12;
  function _M0TP310wzzc_2ddev4moui4core7TextRun(param0, param1, param2, param3) {
    this.text = param0;
    this.frame = param1;
    this.font = param2;
    this.color = param3;
  }
  function _M0TP310wzzc_2ddev4moui4core10RenderNode(param0, param1, param2, param3, param4) {
    this.element_id = param0;
    this.frame = param1;
    this.children = param2;
    this.hit_testable = param3;
    this.paint_commands = param4;
  }
  function _M0TP310wzzc_2ddev4moui4core12PointerEvent(param0, param1, param2) {
    this.position = param0;
    this.phase = param1;
    this.button = param2;
  }
  function _M0DTP310wzzc_2ddev4moui4core8ViewSpec9EmptySpec() {}
  _M0DTP310wzzc_2ddev4moui4core8ViewSpec9EmptySpec.prototype.$tag = 0;
  const _M0DTP310wzzc_2ddev4moui4core8ViewSpec9EmptySpec__ = new _M0DTP310wzzc_2ddev4moui4core8ViewSpec9EmptySpec();
  function _M0DTP310wzzc_2ddev4moui4core8ViewSpec8TextSpec(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewSpec8TextSpec.prototype.$tag = 1;
  function _M0DTP310wzzc_2ddev4moui4core8ViewSpec10ButtonSpec(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewSpec10ButtonSpec.prototype.$tag = 2;
  function _M0DTP310wzzc_2ddev4moui4core8ViewSpec8FlexSpec(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewSpec8FlexSpec.prototype.$tag = 3;
  function _M0DTP310wzzc_2ddev4moui4core8ViewSpec11PaddingSpec(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewSpec11PaddingSpec.prototype.$tag = 4;
  function _M0DTP310wzzc_2ddev4moui4core8ViewSpec13ContainerSpec(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewSpec13ContainerSpec.prototype.$tag = 5;
  function _M0DTP310wzzc_2ddev4moui4core8ViewSpec10SpacerSpec(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewSpec10SpacerSpec.prototype.$tag = 6;
  function _M0TP310wzzc_2ddev4moui4core12TextViewSpec(param0, param1, param2, param3, param4) {
    this.key = param0;
    this.text = param1;
    this.size = param2;
    this.font = param3;
    this.color = param4;
  }
  function _M0TP310wzzc_2ddev4moui4core14ButtonViewSpec(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9) {
    this.key = param0;
    this.text = param1;
    this.size = param2;
    this.font = param3;
    this.foreground = param4;
    this.background = param5;
    this.hovered_background = param6;
    this.pressed_background = param7;
    this.corner_radius = param8;
    this.on_click = param9;
  }
  function _M0TP310wzzc_2ddev4moui4core12FlexViewSpec(param0, param1, param2, param3, param4, param5) {
    this.key = param0;
    this.axis = param1;
    this.spacing = param2;
    this.main_axis_alignment = param3;
    this.cross_axis_alignment = param4;
    this.children = param5;
  }
  function _M0TP310wzzc_2ddev4moui4core15PaddingViewSpec(param0, param1, param2) {
    this.key = param0;
    this.insets = param1;
    this.child = param2;
  }
  function _M0TP310wzzc_2ddev4moui4core17ContainerViewSpec(param0, param1, param2, param3, param4) {
    this.key = param0;
    this.size = param1;
    this.background = param2;
    this.corner_radius = param3;
    this.child = param4;
  }
  function _M0TP310wzzc_2ddev4moui4core14SpacerViewSpec(param0, param1) {
    this.key = param0;
    this.min_length = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core15ReconcileResult(param0, param1) {
    this.node = param0;
    this.next_id = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core23ChildrenReconcileResult(param0, param1) {
    this.children = param0;
    this.next_id = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core18ElementEventResult(param0, param1) {
    this.changed = param0;
    this.activated = param1;
  }
  function _M0TPB8MutLocalGbE(param0) {
    this.val = param0;
  }
  function _M0TP310wzzc_2ddev4moui4core12RuntimeState(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9) {
    this.root_spec = param0;
    this.element_tree = param1;
    this.render_tree = param2;
    this.size = param3;
    this.needs_redraw = param4;
    this.needs_rebuild = param5;
    this.needs_layout = param6;
    this.needs_paint = param7;
    this.next_element_id = param8;
    this.root_builder = param9;
  }
  function _M0TP310wzzc_2ddev4moui7backend10AppRuntime(param0) {
    this.state = param0;
  }
  const _M0FP410wzzc_2ddev4moui6render6webgpu18js__webgpu__resize = (renderer, width, height) => {
    renderer?.resize?.(width, height);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu17js__webgpu__begin = (renderer, width, height) => {
    renderer?.begin?.(width, height);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu17js__webgpu__clear = (renderer, r, g, b, a) => {
    renderer?.clear?.(r, g, b, a);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu23js__webgpu__draw__image = (renderer, source, x, y, width, height, opacity) => {
    renderer?.drawImage?.(source, x, y, width, height, opacity);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__draw__text = (renderer, text, x, y, width, height, family, size, weight, r, g, b, a) => {
    renderer?.drawText?.(text, x, y, width, height, family, size, weight, r, g, b, a);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__fill__rect = (renderer, x, y, width, height, r, g, b, a) => {
    renderer?.fillRect?.(x, y, width, height, r, g, b, a);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu31js__webgpu__fill__rounded__rect = (renderer, x, y, width, height, radius, r, g, b, a) => {
    if (renderer?.fillRoundedRect) {
      renderer.fillRoundedRect(x, y, width, height, radius, r, g, b, a);
    } else {
      renderer?.fillRect?.(x, y, width, height, r, g, b, a);
    }
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu21js__webgpu__pop__clip = (renderer) => {
    renderer?.popClip?.();
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu24js__webgpu__pop__opacity = (renderer) => {
    renderer?.popOpacity?.();
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu26js__webgpu__pop__transform = (renderer) => {
    renderer?.popTransform?.();
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu19js__webgpu__present = (renderer) => {
    renderer?.present?.();
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__push__clip = (renderer, x, y, width, height) => {
    renderer?.pushClip?.(x, y, width, height);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu25js__webgpu__push__opacity = (renderer, opacity) => {
    renderer?.pushOpacity?.(opacity);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu27js__webgpu__push__transform = (renderer, a, b, c, d, tx, ty) => {
    renderer?.pushTransform?.(a, b, c, d, tx, ty);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu24js__webgpu__stroke__rect = (renderer, x, y, width, height, r, g, b, a, strokeWidth) => {
    renderer?.strokeRect?.(x, y, width, height, r, g, b, a, strokeWidth);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu33js__webgpu__stroke__rounded__rect = (renderer, x, y, width, height, radius, r, g, b, a, strokeWidth) => {
    renderer?.strokeRoundedRect?.(x, y, width, height, radius, r, g, b, a, strokeWidth);
  };
  const _M0FP410wzzc_2ddev4moui7backend3web23boot__context__renderer = (context) => context.renderer;
  const _M0FP410wzzc_2ddev4moui7backend3web20boot__context__width = (context) => {
    if (typeof context.width === "function") return context.width();
    return context.canvas?.clientWidth ?? context.canvas?.width ?? 0;
  };
  const _M0FP410wzzc_2ddev4moui7backend3web21boot__context__height = (context) => {
    if (typeof context.height === "function") return context.height();
    return context.canvas?.clientHeight ?? context.canvas?.height ?? 0;
  };
  function _M0TP410wzzc_2ddev4moui7backend3web6WebApp(param0, param1, param2, param3, param4) {
    this.runtime = param0;
    this.renderer = param1;
    this.rebuild = param2;
    this.redraw_requested = param3;
    this.redraw_count = param4;
  }
  function _M0DTP310wzzc_2ddev4moui4core8AppEvent7Pointer(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8AppEvent7Pointer.prototype.$tag = 0;
  function _M0DTP310wzzc_2ddev4moui4core8AppEvent8Keyboard(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8AppEvent8Keyboard.prototype.$tag = 1;
  function _M0DTP310wzzc_2ddev4moui4core8AppEvent6Resize(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8AppEvent6Resize.prototype.$tag = 2;
  function _M0DTP310wzzc_2ddev4moui4core8AppEvent6Redraw(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8AppEvent6Redraw.prototype.$tag = 3;
  function _M0DTP310wzzc_2ddev4moui4core8AppEvent14CloseRequested() {}
  _M0DTP310wzzc_2ddev4moui4core8AppEvent14CloseRequested.prototype.$tag = 4;
  const _M0FP410wzzc_2ddev4moui7backend3web17bind__dom__events = (context, onResize, onPointerMove, onPointerDown, onPointerUp, onPointerCancel) => {
    const canvas = context.canvas;
    if (!canvas) return;
    const point = (event) => {
      const rect = canvas.getBoundingClientRect();
      return [event.clientX - rect.left, event.clientY - rect.top];
    };
    const resize = () => onResize();
    globalThis.addEventListener?.("resize", resize);
    if (globalThis.ResizeObserver) {
      const observer = new ResizeObserver(resize);
      observer.observe(canvas);
      context.resizeObserver = observer;
    }
    canvas.addEventListener("pointermove", (event) => {
      const [x, y] = point(event);
      onPointerMove(x, y);
    });
    canvas.addEventListener("pointerdown", (event) => {
      canvas.setPointerCapture?.(event.pointerId);
      const [x, y] = point(event);
      onPointerDown(x, y, event.button ?? 0);
    });
    canvas.addEventListener("pointerup", (event) => {
      const [x, y] = point(event);
      onPointerUp(x, y, event.button ?? 0);
    });
    canvas.addEventListener("pointercancel", () => onPointerCancel());
  };
  function _M0TP410wzzc_2ddev4moui7backend3web14WebEventResult(param0, param1, param2) {
    this.needs_rebuild = param0;
    this.needs_redraw = param1;
    this.redraw_requested = param2;
  }
  const _M0FP410wzzc_2ddev4moui7backend3web25request__animation__frame = (callback) => {
    const raf = globalThis.requestAnimationFrame ?? ((cb) => setTimeout(cb, 16));
    raf(() => callback());
  };
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode5Empty() {}
  _M0DTP310wzzc_2ddev4moui4core8ViewNode5Empty.prototype.$tag = 0;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode5Label(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode5Label.prototype.$tag = 1;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode6Button(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode6Button.prototype.$tag = 2;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode4Flex(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode4Flex.prototype.$tag = 3;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode7Padding(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode7Padding.prototype.$tag = 4;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode9Container(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode9Container.prototype.$tag = 5;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode6Spacer(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode6Spacer.prototype.$tag = 6;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode6Styled(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode6Styled.prototype.$tag = 7;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode5Keyed(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode5Keyed.prototype.$tag = 8;
  function _M0DTP310wzzc_2ddev4moui4core8ViewNode15EnvironmentNode(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core8ViewNode15EnvironmentNode.prototype.$tag = 9;
  function _M0TP310wzzc_2ddev4moui4core9LabelData(param0, param1, param2) {
    this.text = param0;
    this.size = param1;
    this.color = param2;
  }
  function _M0TP310wzzc_2ddev4moui4core8FlexData(param0, param1, param2, param3, param4) {
    this.axis = param0;
    this.spacing = param1;
    this.main_axis_alignment = param2;
    this.cross_axis_alignment = param3;
    this.children = param4;
  }
  function _M0TP310wzzc_2ddev4moui4core10ButtonData(param0, param1, param2, param3) {
    this.text = param0;
    this.size = param1;
    this.state = param2;
    this.on_click = param3;
  }
  function _M0TP410wzzc_2ddev4moui8examples12counter__app10CounterApp(param0) {
    this.count = param0;
  }
  const _M0FP410wzzc_2ddev4moui8examples12counter__web18has__boot__context = () => globalThis.__mouiBootContext !== undefined;
  const _M0FP410wzzc_2ddev4moui8examples12counter__web13boot__context = () => globalThis.__mouiBootContext;
  const _M0FP410wzzc_2ddev4moui8examples12counter__web12has__started = () => globalThis.__mouiStarted === true;
  const _M0FP410wzzc_2ddev4moui8examples12counter__web13mark__started = () => {
    globalThis.__mouiStarted = true;
  };
  function _M0IP016_24default__implPB2Eq10not__equalGRP310wzzc_2ddev4moui4core11ButtonStateE(x, y) {
    return !_M0IP310wzzc_2ddev4moui4core11ButtonStatePB2Eq5equal(x, y);
  }
  function _M0MPC13int3Int18to__string_2einner(self, radix) {
    return _M0FPB19int__to__string__js(self, radix);
  }
  function _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(self, value) {
    _M0MPB7JSArray4push(self, value);
  }
  function _M0MPC15array5Array4pushGbE(self, value) {
    _M0MPB7JSArray4push(self, value);
  }
  function _M0IPC13int3IntPB4Show10to__string(self) {
    return _M0MPC13int3Int18to__string_2einner(self, 10);
  }
  function _M0IPC16option6OptionPB2Eq5equalGRP310wzzc_2ddev4moui4core3KeyE(self, other) {
    if (self === undefined) {
      return other === undefined;
    } else {
      const _Some = self;
      const _x = _Some;
      if (other === undefined) {
        return false;
      } else {
        const _Some$2 = other;
        const _y = _Some$2;
        return _M0IP310wzzc_2ddev4moui4core3KeyPB2Eq5equal(_x, _y);
      }
    }
  }
  function _M0MPC16option6Option10unwrap__orGRP310wzzc_2ddev4moui4core8FontSpecE(self, default_) {
    if (self === undefined) {
      return default_;
    } else {
      const _Some = self;
      return _Some;
    }
  }
  function _M0MPC16option6Option10unwrap__orGdE(self, default_) {
    if (self.$tag === 0) {
      return default_;
    } else {
      const _Some = self;
      return _Some._0;
    }
  }
  function _M0MPC15array5Array3setGbE(self, index, value) {
    const len = self.length;
    if (index >= 0 && index < len) {
      $bound_check(self, index);
      self[index] = value;
      return;
    } else {
      $panic();
      return;
    }
  }
  function _M0MPC15array5Array3mapGRP310wzzc_2ddev4moui4core11ElementNodeRP310wzzc_2ddev4moui4core4SizeE(self, f) {
    const arr = new Array(self.length);
    const _bind = self.length;
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < _bind) {
        const v = self[i];
        arr[i] = f(v);
        _tmp = i + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return arr;
  }
  function _M0MPC15array5Array3mapGRP310wzzc_2ddev4moui4core8ViewNodeRP310wzzc_2ddev4moui4core8ViewSpecE(self, f) {
    const arr = new Array(self.length);
    const _bind = self.length;
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < _bind) {
        const v = self[i];
        arr[i] = f(v);
        _tmp = i + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return arr;
  }
  function _M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(self, index) {
    const len = self.length;
    if (index >= 0 && index < len) {
      $bound_check(self, index);
      return self[index];
    } else {
      return $panic();
    }
  }
  function _M0MPC15array5Array2atGbE(self, index) {
    const len = self.length;
    if (index >= 0 && index < len) {
      $bound_check(self, index);
      return self[index];
    } else {
      return $panic();
    }
  }
  function _M0IP310wzzc_2ddev4moui4core12PointerPhasePB2Eq5equal(_x_894, _x_895) {
    switch (_x_894) {
      case 0: {
        if (_x_895 === 0) {
          return true;
        } else {
          return false;
        }
      }
      case 1: {
        if (_x_895 === 1) {
          return true;
        } else {
          return false;
        }
      }
      case 2: {
        if (_x_895 === 2) {
          return true;
        } else {
          return false;
        }
      }
      default: {
        if (_x_895 === 3) {
          return true;
        } else {
          return false;
        }
      }
    }
  }
  function _M0IP310wzzc_2ddev4moui4core3KeyPB2Eq5equal(_x_567, _x_568) {
    return _x_567.value === _x_568.value;
  }
  function _M0IP310wzzc_2ddev4moui4core11ButtonStatePB2Eq5equal(_x_484, _x_485) {
    switch (_x_484) {
      case 0: {
        if (_x_485 === 0) {
          return true;
        } else {
          return false;
        }
      }
      case 1: {
        if (_x_485 === 1) {
          return true;
        } else {
          return false;
        }
      }
      default: {
        if (_x_485 === 2) {
          return true;
        } else {
          return false;
        }
      }
    }
  }
  function _M0MP310wzzc_2ddev4moui4core4Size3new(width, height) {
    return new _M0TP310wzzc_2ddev4moui4core4Size(width, height);
  }
  function _M0MP310wzzc_2ddev4moui4core4Size7inflate(self, insets) {
    return _M0MP310wzzc_2ddev4moui4core4Size3new(self.width + insets.left + insets.right, self.height + insets.top + insets.bottom);
  }
  function _M0MP310wzzc_2ddev4moui4core4Rect8contains(self, point) {
    return point.x >= self.origin.x && (point.y >= self.origin.y && (point.x <= self.origin.x + self.size.width && point.y <= self.origin.y + self.size.height));
  }
  function _M0FP310wzzc_2ddev4moui4core11max__double(a, b) {
    return a > b ? a : b;
  }
  function _M0FP310wzzc_2ddev4moui4core19cross__axis__offset(alignment, available, child) {
    switch (alignment) {
      case 0: {
        return new _M0TP310wzzc_2ddev4moui4core15CrossAxisOffset(0, child);
      }
      case 1: {
        return new _M0TP310wzzc_2ddev4moui4core15CrossAxisOffset(_M0FP310wzzc_2ddev4moui4core11max__double(0, available - child) / 2, child);
      }
      case 2: {
        return new _M0TP310wzzc_2ddev4moui4core15CrossAxisOffset(_M0FP310wzzc_2ddev4moui4core11max__double(0, available - child), child);
      }
      default: {
        return new _M0TP310wzzc_2ddev4moui4core15CrossAxisOffset(0, available);
      }
    }
  }
  function _M0FP310wzzc_2ddev4moui4core13flex__offsets(alignment, remaining, base_gap, count) {
    switch (alignment) {
      case 0: {
        return new _M0TP310wzzc_2ddev4moui4core11FlexOffsets(0, base_gap);
      }
      case 1: {
        return new _M0TP310wzzc_2ddev4moui4core11FlexOffsets(remaining / 2, base_gap);
      }
      case 2: {
        return new _M0TP310wzzc_2ddev4moui4core11FlexOffsets(remaining, base_gap);
      }
      case 3: {
        return count > 1 ? new _M0TP310wzzc_2ddev4moui4core11FlexOffsets(0, base_gap + remaining / (count + 0 - 1)) : new _M0TP310wzzc_2ddev4moui4core11FlexOffsets(0, base_gap);
      }
      case 4: {
        const extra = remaining / (count + 0);
        return new _M0TP310wzzc_2ddev4moui4core11FlexOffsets(extra / 2, base_gap + extra);
      }
      default: {
        const extra$2 = remaining / (count + 0 + 1);
        return new _M0TP310wzzc_2ddev4moui4core11FlexOffsets(extra$2, base_gap + extra$2);
      }
    }
  }
  function _M0MP310wzzc_2ddev4moui4core5Point3new(x, y) {
    return new _M0TP310wzzc_2ddev4moui4core5Point(x, y);
  }
  function _M0MP310wzzc_2ddev4moui4core4Rect3new(x, y, width, height) {
    return new _M0TP310wzzc_2ddev4moui4core4Rect(_M0MP310wzzc_2ddev4moui4core5Point3new(x, y), _M0MP310wzzc_2ddev4moui4core4Size3new(width, height));
  }
  function _M0FP310wzzc_2ddev4moui4core19flex__child__frames(axis, spacing, main_axis_alignment, cross_axis_alignment, child_sizes, bounds) {
    const count = child_sizes.length;
    const frames = [];
    if (count === 0) {
      return frames;
    } else {
      const total_spacing = spacing * (count + 0 - 1);
      const child_main_total = new _M0TPB8MutLocalGdE(0);
      const _bind = child_sizes.length;
      let _tmp = 0;
      while (true) {
        const _ = _tmp;
        if (_ < _bind) {
          const size = child_sizes[_];
          let child_main;
          if (axis === 0) {
            child_main = size.width;
          } else {
            child_main = size.height;
          }
          child_main_total.val = child_main_total.val + child_main;
          _tmp = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      let available_main;
      if (axis === 0) {
        available_main = bounds.size.width;
      } else {
        available_main = bounds.size.height;
      }
      const remaining = _M0FP310wzzc_2ddev4moui4core11max__double(0, available_main - child_main_total.val - total_spacing);
      const offsets = _M0FP310wzzc_2ddev4moui4core13flex__offsets(main_axis_alignment, remaining, spacing, count);
      const cursor = new _M0TPB8MutLocalGdE(offsets.leading);
      const _bind$2 = child_sizes.length;
      let _tmp$2 = 0;
      while (true) {
        const _ = _tmp$2;
        if (_ < _bind$2) {
          const size = child_sizes[_];
          let main_size;
          if (axis === 0) {
            main_size = size.width;
          } else {
            main_size = size.height;
          }
          let cross_size;
          if (axis === 0) {
            cross_size = size.height;
          } else {
            cross_size = size.width;
          }
          let cross_available;
          if (axis === 0) {
            cross_available = bounds.size.height;
          } else {
            cross_available = bounds.size.width;
          }
          const cross = _M0FP310wzzc_2ddev4moui4core19cross__axis__offset(cross_axis_alignment, cross_available, cross_size);
          let frame;
          if (axis === 0) {
            frame = _M0MP310wzzc_2ddev4moui4core4Rect3new(bounds.origin.x + cursor.val, bounds.origin.y + cross.offset, main_size, cross.size);
          } else {
            frame = _M0MP310wzzc_2ddev4moui4core4Rect3new(bounds.origin.x + cross.offset, bounds.origin.y + cursor.val, cross.size, main_size);
          }
          _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(frames, frame);
          cursor.val = cursor.val + main_size + offsets.gap;
          _tmp$2 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      return frames;
    }
  }
  function _M0MP310wzzc_2ddev4moui4core4Rect5inset(self, insets) {
    return _M0MP310wzzc_2ddev4moui4core4Rect3new(self.origin.x + insets.left, self.origin.y + insets.top, _M0FP310wzzc_2ddev4moui4core11max__double(0, self.size.width - insets.left - insets.right), _M0FP310wzzc_2ddev4moui4core11max__double(0, self.size.height - insets.top - insets.bottom));
  }
  function _M0FP310wzzc_2ddev4moui4core14option__preferGRP310wzzc_2ddev4moui4core5ColorE(value, fallback) {
    return value === undefined ? fallback : value;
  }
  function _M0FP310wzzc_2ddev4moui4core14option__preferGdE(value, fallback) {
    if (value.$tag === 1) {
      return value;
    } else {
      return fallback;
    }
  }
  function _M0MP310wzzc_2ddev4moui4core5Color12rgba_2einner(r, g, b, a) {
    return new _M0TP310wzzc_2ddev4moui4core5Color(r, g, b, a);
  }
  function _M0MP310wzzc_2ddev4moui4core5Color5black() {
    return _M0MP310wzzc_2ddev4moui4core5Color12rgba_2einner(0, 0, 0, 1);
  }
  function _M0MP310wzzc_2ddev4moui4core5Color4blue() {
    return _M0MP310wzzc_2ddev4moui4core5Color12rgba_2einner(0.12, 0.36, 0.95, 1);
  }
  function _M0MP310wzzc_2ddev4moui4core5Color4gray() {
    return _M0MP310wzzc_2ddev4moui4core5Color12rgba_2einner(0.82, 0.84, 0.88, 1);
  }
  function _M0MP310wzzc_2ddev4moui4core5Color5white() {
    return _M0MP310wzzc_2ddev4moui4core5Color12rgba_2einner(1, 1, 1, 1);
  }
  function _M0MP310wzzc_2ddev4moui4core8FontSpec11new_2einner(family, size, weight) {
    return new _M0TP310wzzc_2ddev4moui4core8FontSpec(family, size, weight);
  }
  function _M0MP310wzzc_2ddev4moui4core11RoundedRect11new_2einner(rect, radius) {
    return new _M0TP310wzzc_2ddev4moui4core11RoundedRect(rect, radius);
  }
  function _M0MP310wzzc_2ddev4moui4core9ViewStyle11from__theme(theme) {
    return new _M0TP310wzzc_2ddev4moui4core9ViewStyle(theme.font, theme.foreground, theme.background, new _M0DTPC16option6OptionGdE4Some(theme.corner_radius));
  }
  function _M0MP310wzzc_2ddev4moui4core9ViewStyle5merge(self, next) {
    return new _M0TP310wzzc_2ddev4moui4core9ViewStyle(_M0FP310wzzc_2ddev4moui4core14option__preferGRP310wzzc_2ddev4moui4core5ColorE(next.font, self.font), _M0FP310wzzc_2ddev4moui4core14option__preferGRP310wzzc_2ddev4moui4core5ColorE(next.foreground, self.foreground), _M0FP310wzzc_2ddev4moui4core14option__preferGRP310wzzc_2ddev4moui4core5ColorE(next.background, self.background), _M0FP310wzzc_2ddev4moui4core14option__preferGdE(next.corner_radius, self.corner_radius));
  }
  function _M0MP310wzzc_2ddev4moui4core9ViewStyle5empty() {
    return new _M0TP310wzzc_2ddev4moui4core9ViewStyle(undefined, undefined, undefined, _M0DTPC16option6OptionGdE4None__);
  }
  function _M0MP310wzzc_2ddev4moui4core10DirtyFlags3all() {
    return new _M0TP310wzzc_2ddev4moui4core10DirtyFlags(true, true, true);
  }
  function _M0MP310wzzc_2ddev4moui4core9ElementId3new(value) {
    return new _M0TP310wzzc_2ddev4moui4core9ElementId(value);
  }
  function _M0MP310wzzc_2ddev4moui4core8ViewSpec3key(self) {
    let data;
    _L: {
      let data$2;
      _L$2: {
        let data$3;
        _L$3: {
          let data$4;
          _L$4: {
            let data$5;
            _L$5: {
              let data$6;
              _L$6: {
                switch (self.$tag) {
                  case 0: {
                    return undefined;
                  }
                  case 1: {
                    const _TextSpec = self;
                    const _data = _TextSpec._0;
                    data$6 = _data;
                    break _L$6;
                  }
                  case 2: {
                    const _ButtonSpec = self;
                    const _data$2 = _ButtonSpec._0;
                    data$5 = _data$2;
                    break _L$5;
                  }
                  case 3: {
                    const _FlexSpec = self;
                    const _data$3 = _FlexSpec._0;
                    data$4 = _data$3;
                    break _L$4;
                  }
                  case 4: {
                    const _PaddingSpec = self;
                    const _data$4 = _PaddingSpec._0;
                    data$3 = _data$4;
                    break _L$3;
                  }
                  case 5: {
                    const _ContainerSpec = self;
                    const _data$5 = _ContainerSpec._0;
                    data$2 = _data$5;
                    break _L$2;
                  }
                  default: {
                    const _SpacerSpec = self;
                    const _data$6 = _SpacerSpec._0;
                    data = _data$6;
                    break _L;
                  }
                }
              }
              return data$6.key;
            }
            return data$5.key;
          }
          return data$4.key;
        }
        return data$3.key;
      }
      return data$2.key;
    }
    return data.key;
  }
  function _M0FP310wzzc_2ddev4moui4core29mount__view__spec__with__next(spec, next_id) {
    const id = _M0MP310wzzc_2ddev4moui4core9ElementId3new(next_id);
    const next = new _M0TPB8MutLocalGiE(next_id + 1 | 0);
    const children = [];
    let data;
    _L: {
      _L$2: {
        let data$2;
        _L$3: {
          _L$4: {
            let data$3;
            _L$5: {
              _L$6: {
                switch (spec.$tag) {
                  case 3: {
                    const _FlexSpec = spec;
                    const _data = _FlexSpec._0;
                    data$3 = _data;
                    break _L$6;
                  }
                  case 4: {
                    const _PaddingSpec = spec;
                    const _data$2 = _PaddingSpec._0;
                    data$2 = _data$2;
                    break _L$4;
                  }
                  case 5: {
                    const _ContainerSpec = spec;
                    const _data$3 = _ContainerSpec._0;
                    data = _data$3;
                    break _L$2;
                  }
                }
                break _L$5;
              }
              const _bind = data$3.children;
              const _bind$2 = _bind.length;
              let _tmp = 0;
              while (true) {
                const _ = _tmp;
                if (_ < _bind$2) {
                  const child_spec = _bind[_];
                  const mounted = _M0FP310wzzc_2ddev4moui4core29mount__view__spec__with__next(child_spec, next.val);
                  _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, mounted.node);
                  next.val = mounted.next_id;
                  _tmp = _ + 1 | 0;
                  continue;
                } else {
                  break;
                }
              }
            }
            break _L$3;
          }
          const mounted = _M0FP310wzzc_2ddev4moui4core29mount__view__spec__with__next(data$2.child, next.val);
          _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, mounted.node);
          next.val = mounted.next_id;
        }
        break _L;
      }
      let child;
      _L$3: {
        _L$4: {
          const _bind = data.child;
          if (_bind === undefined) {
          } else {
            const _Some = _bind;
            const _child = _Some;
            child = _child;
            break _L$4;
          }
          break _L$3;
        }
        const mounted = _M0FP310wzzc_2ddev4moui4core29mount__view__spec__with__next(child, next.val);
        _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, mounted.node);
        next.val = mounted.next_id;
      }
    }
    return new _M0TP310wzzc_2ddev4moui4core11MountResult(new _M0TP310wzzc_2ddev4moui4core11ElementNode(id, _M0MP310wzzc_2ddev4moui4core8ViewSpec3key(spec), spec, children, _M0MP310wzzc_2ddev4moui4core10DirtyFlags3all(), 0), next.val);
  }
  function _M0FP310wzzc_2ddev4moui4core22element__hit__testable(spec) {
    let data;
    _L: {
      switch (spec.$tag) {
        case 2: {
          return true;
        }
        case 5: {
          const _ContainerSpec = spec;
          const _data = _ContainerSpec._0;
          data = _data;
          break _L;
        }
        default: {
          return false;
        }
      }
    }
    const _bind = data.background;
    return !(_bind === undefined);
  }
  function _M0MP310wzzc_2ddev4moui4core10DirtyFlags5clear(self) {
    self.needs_build = false;
    self.needs_layout = false;
    self.needs_paint = false;
  }
  function _M0MP310wzzc_2ddev4moui4core11ElementNode15intrinsic__size(self) {
    let _tmp = self;
    _L: while (true) {
      const self$2 = _tmp;
      let data;
      _L$2: {
        let data$2;
        _L$3: {
          let data$3;
          _L$4: {
            let data$4;
            _L$5: {
              let data$5;
              _L$6: {
                let data$6;
                _L$7: {
                  const _bind = self$2.spec;
                  switch (_bind.$tag) {
                    case 0: {
                      return _M0MP310wzzc_2ddev4moui4core4Size3new(0, 0);
                    }
                    case 1: {
                      const _TextSpec = _bind;
                      const _data = _TextSpec._0;
                      data$6 = _data;
                      break _L$7;
                    }
                    case 2: {
                      const _ButtonSpec = _bind;
                      const _data$2 = _ButtonSpec._0;
                      data$5 = _data$2;
                      break _L$6;
                    }
                    case 6: {
                      const _SpacerSpec = _bind;
                      const _data$3 = _SpacerSpec._0;
                      data$4 = _data$3;
                      break _L$5;
                    }
                    case 4: {
                      const _PaddingSpec = _bind;
                      const _data$4 = _PaddingSpec._0;
                      data$3 = _data$4;
                      break _L$4;
                    }
                    case 5: {
                      const _ContainerSpec = _bind;
                      const _data$5 = _ContainerSpec._0;
                      data$2 = _data$5;
                      break _L$3;
                    }
                    default: {
                      const _FlexSpec = _bind;
                      const _data$6 = _FlexSpec._0;
                      data = _data$6;
                      break _L$2;
                    }
                  }
                }
                return data$6.size;
              }
              return data$5.size;
            }
            return _M0MP310wzzc_2ddev4moui4core4Size3new(data$4.min_length, data$4.min_length);
          }
          return self$2.children.length > 0 ? _M0MP310wzzc_2ddev4moui4core4Size7inflate(_M0MP310wzzc_2ddev4moui4core11ElementNode15intrinsic__size(_M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(self$2.children, 0)), data$3.insets) : _M0MP310wzzc_2ddev4moui4core4Size7inflate(_M0MP310wzzc_2ddev4moui4core4Size3new(0, 0), data$3.insets);
        }
        const _bind = data$2.size;
        if (_bind === undefined) {
          if (self$2.children.length > 0) {
            _tmp = _M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(self$2.children, 0);
            continue;
          } else {
            return _M0MP310wzzc_2ddev4moui4core4Size3new(0, 0);
          }
        } else {
          const _Some = _bind;
          const _size = _Some;
          return _size;
        }
      }
      return _M0FP310wzzc_2ddev4moui4core20measure__flex__sizes(data.axis, data.spacing, self$2.children);
    }
  }
  function _M0FP310wzzc_2ddev4moui4core20measure__flex__sizes(axis, spacing, children) {
    const main = new _M0TPB8MutLocalGdE(0);
    const cross = new _M0TPB8MutLocalGdE(0);
    const _bind = children.length;
    let _tmp = 0;
    while (true) {
      const index = _tmp;
      if (index < _bind) {
        const child = children[index];
        const size = _M0MP310wzzc_2ddev4moui4core11ElementNode15intrinsic__size(child);
        if (axis === 0) {
          main.val = main.val + size.width;
          cross.val = _M0FP310wzzc_2ddev4moui4core11max__double(cross.val, size.height);
        } else {
          main.val = main.val + size.height;
          cross.val = _M0FP310wzzc_2ddev4moui4core11max__double(cross.val, size.width);
        }
        if (index > 0) {
          main.val = main.val + spacing;
        }
        _tmp = index + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    if (axis === 0) {
      return _M0MP310wzzc_2ddev4moui4core4Size3new(main.val, cross.val);
    } else {
      return _M0MP310wzzc_2ddev4moui4core4Size3new(cross.val, main.val);
    }
  }
  function _M0MP310wzzc_2ddev4moui4core11ElementNode6render(self, bounds) {
    const children = [];
    const commands = [];
    let data;
    _L: {
      _L$2: {
        let data$2;
        _L$3: {
          _L$4: {
            let data$3;
            _L$5: {
              _L$6: {
                let data$4;
                _L$7: {
                  _L$8: {
                    let data$5;
                    _L$9: {
                      _L$10: {
                        const _bind = self.spec;
                        switch (_bind.$tag) {
                          case 0: {
                            break;
                          }
                          case 6: {
                            break;
                          }
                          case 1: {
                            const _TextSpec = _bind;
                            const _data = _TextSpec._0;
                            data$5 = _data;
                            break _L$10;
                          }
                          case 2: {
                            const _ButtonSpec = _bind;
                            const _data$2 = _ButtonSpec._0;
                            data$4 = _data$2;
                            break _L$8;
                          }
                          case 3: {
                            const _FlexSpec = _bind;
                            const _data$3 = _FlexSpec._0;
                            data$3 = _data$3;
                            break _L$6;
                          }
                          case 4: {
                            const _PaddingSpec = _bind;
                            const _data$4 = _PaddingSpec._0;
                            data$2 = _data$4;
                            break _L$4;
                          }
                          default: {
                            const _ContainerSpec = _bind;
                            const _data$5 = _ContainerSpec._0;
                            data = _data$5;
                            break _L$2;
                          }
                        }
                        break _L$9;
                      }
                      _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(commands, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText(new _M0TP310wzzc_2ddev4moui4core7TextRun(data$5.text, bounds, data$5.font, data$5.color)));
                    }
                    break _L$7;
                  }
                  const _bind = self.button_state;
                  let background;
                  switch (_bind) {
                    case 0: {
                      background = data$4.background;
                      break;
                    }
                    case 1: {
                      background = data$4.hovered_background;
                      break;
                    }
                    default: {
                      background = data$4.pressed_background;
                    }
                  }
                  if (data$4.corner_radius > 0) {
                    _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(commands, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand15FillRoundedRect(_M0MP310wzzc_2ddev4moui4core11RoundedRect11new_2einner(bounds, data$4.corner_radius), background));
                  } else {
                    _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(commands, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand8FillRect(bounds, background));
                  }
                  let foreground;
                  _L$9: {
                    _L$10: {
                      const _bind$2 = self.button_state;
                      switch (_bind$2) {
                        case 2: {
                          foreground = _M0MP310wzzc_2ddev4moui4core5Color5white();
                          break;
                        }
                        case 0: {
                          break _L$10;
                        }
                        default: {
                          break _L$10;
                        }
                      }
                      break _L$9;
                    }
                    foreground = data$4.foreground;
                  }
                  _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(commands, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText(new _M0TP310wzzc_2ddev4moui4core7TextRun(data$4.text, bounds, data$4.font, foreground)));
                }
                break _L$5;
              }
              const frames = _M0FP310wzzc_2ddev4moui4core19flex__child__frames(data$3.axis, data$3.spacing, data$3.main_axis_alignment, data$3.cross_axis_alignment, _M0MPC15array5Array3mapGRP310wzzc_2ddev4moui4core11ElementNodeRP310wzzc_2ddev4moui4core4SizeE(self.children, (child) => _M0MP310wzzc_2ddev4moui4core11ElementNode15intrinsic__size(child)), bounds);
              const _bind = self.children;
              const _bind$2 = _bind.length;
              let _tmp = 0;
              while (true) {
                const index = _tmp;
                if (index < _bind$2) {
                  const child = _bind[index];
                  _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, _M0MP310wzzc_2ddev4moui4core11ElementNode6render(child, _M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(frames, index)));
                  _tmp = index + 1 | 0;
                  continue;
                } else {
                  break;
                }
              }
            }
            break _L$3;
          }
          const child_frame = _M0MP310wzzc_2ddev4moui4core4Rect5inset(bounds, data$2.insets);
          if (self.children.length > 0) {
            _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, _M0MP310wzzc_2ddev4moui4core11ElementNode6render(_M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(self.children, 0), child_frame));
          }
        }
        break _L;
      }
      let frame;
      let size;
      _L$3: {
        _L$4: {
          const _bind = data.size;
          if (_bind === undefined) {
            frame = bounds;
          } else {
            const _Some = _bind;
            const _size = _Some;
            size = _size;
            break _L$4;
          }
          break _L$3;
        }
        frame = _M0MP310wzzc_2ddev4moui4core4Rect3new(bounds.origin.x, bounds.origin.y, size.width, size.height);
      }
      let color;
      _L$4: {
        _L$5: {
          const _bind = data.background;
          if (_bind === undefined) {
          } else {
            const _Some = _bind;
            const _color = _Some;
            color = _color;
            break _L$5;
          }
          break _L$4;
        }
        if (data.corner_radius > 0) {
          _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(commands, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand15FillRoundedRect(_M0MP310wzzc_2ddev4moui4core11RoundedRect11new_2einner(frame, data.corner_radius), color));
        } else {
          _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(commands, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand8FillRect(frame, color));
        }
      }
      if (self.children.length > 0) {
        _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, _M0MP310wzzc_2ddev4moui4core11ElementNode6render(_M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(self.children, 0), frame));
      }
    }
    _M0MP310wzzc_2ddev4moui4core10DirtyFlags5clear(self.dirty);
    return new _M0TP310wzzc_2ddev4moui4core10RenderNode(self.id, bounds, children, _M0FP310wzzc_2ddev4moui4core22element__hit__testable(self.spec), commands);
  }
  function _M0MP310wzzc_2ddev4moui4core12PointerEvent11new_2einner(position, phase, button) {
    return new _M0TP310wzzc_2ddev4moui4core12PointerEvent(position, phase, button);
  }
  function _M0MP310wzzc_2ddev4moui4core10DirtyFlags11mark__build(self) {
    self.needs_build = true;
    self.needs_layout = true;
    self.needs_paint = true;
  }
  function _M0MP310wzzc_2ddev4moui4core10DirtyFlags11mark__paint(self) {
    self.needs_paint = true;
  }
  function _M0MP310wzzc_2ddev4moui4core8ViewSpec4kind(self) {
    switch (self.$tag) {
      case 0: {
        return 0;
      }
      case 1: {
        return 1;
      }
      case 2: {
        return 2;
      }
      case 3: {
        return 3;
      }
      case 4: {
        return 4;
      }
      case 5: {
        return 5;
      }
      default: {
        return 6;
      }
    }
  }
  function _M0MP310wzzc_2ddev4moui4core8ViewSpec14same__identity(self, next) {
    return _M0MP310wzzc_2ddev4moui4core8ViewSpec4kind(self) === _M0MP310wzzc_2ddev4moui4core8ViewSpec4kind(next) && _M0IPC16option6OptionPB2Eq5equalGRP310wzzc_2ddev4moui4core3KeyE(_M0MP310wzzc_2ddev4moui4core8ViewSpec3key(self), _M0MP310wzzc_2ddev4moui4core8ViewSpec3key(next));
  }
  function _M0MP310wzzc_2ddev4moui4core8ViewNode8to__spec(self) {
    return _M0MP310wzzc_2ddev4moui4core8ViewNode21to__spec__with__style(self, _M0MP310wzzc_2ddev4moui4core9ViewStyle5empty(), undefined);
  }
  function _M0MP310wzzc_2ddev4moui4core8ViewNode21to__spec__with__style(self, style, key) {
    let _tmp = self;
    let _tmp$2 = style;
    let _tmp$3 = key;
    _L: while (true) {
      const self$2 = _tmp;
      const style$2 = _tmp$2;
      const key$2 = _tmp$3;
      let data;
      _L$2: {
        let data$2;
        _L$3: {
          let data$3;
          _L$4: {
            let data$4;
            _L$5: {
              let data$5;
              _L$6: {
                let data$6;
                _L$7: {
                  let data$7;
                  _L$8: {
                    let data$8;
                    _L$9: {
                      let data$9;
                      _L$10: {
                        switch (self$2.$tag) {
                          case 0: {
                            return _M0DTP310wzzc_2ddev4moui4core8ViewSpec9EmptySpec__;
                          }
                          case 1: {
                            const _Label = self$2;
                            const _data = _Label._0;
                            data$9 = _data;
                            break _L$10;
                          }
                          case 2: {
                            const _Button = self$2;
                            const _data$2 = _Button._0;
                            data$8 = _data$2;
                            break _L$9;
                          }
                          case 3: {
                            const _Flex = self$2;
                            const _data$3 = _Flex._0;
                            data$7 = _data$3;
                            break _L$8;
                          }
                          case 4: {
                            const _Padding = self$2;
                            const _data$4 = _Padding._0;
                            data$6 = _data$4;
                            break _L$7;
                          }
                          case 5: {
                            const _Container = self$2;
                            const _data$5 = _Container._0;
                            data$5 = _data$5;
                            break _L$6;
                          }
                          case 6: {
                            const _Spacer = self$2;
                            const _data$6 = _Spacer._0;
                            data$4 = _data$6;
                            break _L$5;
                          }
                          case 7: {
                            const _Styled = self$2;
                            const _data$7 = _Styled._0;
                            data$3 = _data$7;
                            break _L$4;
                          }
                          case 8: {
                            const _Keyed = self$2;
                            const _data$8 = _Keyed._0;
                            data$2 = _data$8;
                            break _L$3;
                          }
                          default: {
                            const _EnvironmentNode = self$2;
                            const _data$9 = _EnvironmentNode._0;
                            data = _data$9;
                            break _L$2;
                          }
                        }
                      }
                      return new _M0DTP310wzzc_2ddev4moui4core8ViewSpec8TextSpec(new _M0TP310wzzc_2ddev4moui4core12TextViewSpec(key$2, data$9.text, data$9.size, _M0MPC16option6Option10unwrap__orGRP310wzzc_2ddev4moui4core8FontSpecE(style$2.font, _M0MP310wzzc_2ddev4moui4core8FontSpec11new_2einner("system-ui, sans-serif", 16, 500)), _M0MPC16option6Option10unwrap__orGRP310wzzc_2ddev4moui4core8FontSpecE(style$2.foreground, data$9.color)));
                    }
                    return new _M0DTP310wzzc_2ddev4moui4core8ViewSpec10ButtonSpec(new _M0TP310wzzc_2ddev4moui4core14ButtonViewSpec(key$2, data$8.text, data$8.size, _M0MPC16option6Option10unwrap__orGRP310wzzc_2ddev4moui4core8FontSpecE(style$2.font, _M0MP310wzzc_2ddev4moui4core8FontSpec11new_2einner("system-ui, sans-serif", 16, 600)), _M0MPC16option6Option10unwrap__orGRP310wzzc_2ddev4moui4core8FontSpecE(style$2.foreground, _M0MP310wzzc_2ddev4moui4core5Color5black()), _M0MPC16option6Option10unwrap__orGRP310wzzc_2ddev4moui4core8FontSpecE(style$2.background, _M0MP310wzzc_2ddev4moui4core5Color4gray()), _M0MP310wzzc_2ddev4moui4core5Color12rgba_2einner(0.72, 0.78, 0.92, 1), _M0MP310wzzc_2ddev4moui4core5Color4blue(), _M0MPC16option6Option10unwrap__orGdE(style$2.corner_radius, 0), data$8.on_click));
                  }
                  return new _M0DTP310wzzc_2ddev4moui4core8ViewSpec8FlexSpec(new _M0TP310wzzc_2ddev4moui4core12FlexViewSpec(key$2, data$7.axis, data$7.spacing, data$7.main_axis_alignment, data$7.cross_axis_alignment, _M0MPC15array5Array3mapGRP310wzzc_2ddev4moui4core8ViewNodeRP310wzzc_2ddev4moui4core8ViewSpecE(data$7.children, (child) => _M0MP310wzzc_2ddev4moui4core8ViewNode21to__spec__with__style(child, style$2, undefined))));
                }
                return new _M0DTP310wzzc_2ddev4moui4core8ViewSpec11PaddingSpec(new _M0TP310wzzc_2ddev4moui4core15PaddingViewSpec(key$2, data$6.insets, _M0MP310wzzc_2ddev4moui4core8ViewNode8to__spec(data$6.child)));
              }
              return new _M0DTP310wzzc_2ddev4moui4core8ViewSpec13ContainerSpec(new _M0TP310wzzc_2ddev4moui4core17ContainerViewSpec(key$2, data$5.size, _M0FP310wzzc_2ddev4moui4core14option__preferGRP310wzzc_2ddev4moui4core5ColorE(data$5.background, style$2.background), data$5.corner_radius, _M0MP310wzzc_2ddev4moui4core8ViewNode8to__spec(data$5.child)));
            }
            return new _M0DTP310wzzc_2ddev4moui4core8ViewSpec10SpacerSpec(new _M0TP310wzzc_2ddev4moui4core14SpacerViewSpec(key$2, data$4.min_length));
          }
          _tmp = data$3.child;
          _tmp$2 = _M0MP310wzzc_2ddev4moui4core9ViewStyle5merge(style$2, data$3.style);
          continue;
        }
        _tmp = data$2.child;
        _tmp$3 = data$2.key;
        continue;
      }
      _tmp = data.child;
      _tmp$2 = _M0MP310wzzc_2ddev4moui4core9ViewStyle5merge(style$2, _M0MP310wzzc_2ddev4moui4core9ViewStyle11from__theme(data.environment.theme));
      continue;
    }
  }
  function _M0FP310wzzc_2ddev4moui4core12child__specs(spec) {
    let data;
    _L: {
      let data$2;
      _L$2: {
        let data$3;
        _L$3: {
          switch (spec.$tag) {
            case 3: {
              const _FlexSpec = spec;
              const _data = _FlexSpec._0;
              data$3 = _data;
              break _L$3;
            }
            case 4: {
              const _PaddingSpec = spec;
              const _data$2 = _PaddingSpec._0;
              data$2 = _data$2;
              break _L$2;
            }
            case 5: {
              const _ContainerSpec = spec;
              const _data$3 = _ContainerSpec._0;
              data = _data$3;
              break _L;
            }
            default: {
              return [];
            }
          }
        }
        return data$3.children;
      }
      return [data$2.child];
    }
    let child;
    _L$2: {
      const _bind = data.child;
      if (_bind === undefined) {
        return [];
      } else {
        const _Some = _bind;
        const _child = _Some;
        child = _child;
        break _L$2;
      }
    }
    return [child];
  }
  function _M0FP310wzzc_2ddev4moui4core21find__reusable__child(old_children, used, child_spec, index) {
    let key;
    _L: {
      const _bind = _M0MP310wzzc_2ddev4moui4core8ViewSpec3key(child_spec);
      if (_bind === undefined) {
        _L$2: {
          if (index < old_children.length) {
            if (!_M0MPC15array5Array2atGbE(used, index)) {
              const _bind$2 = _M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(old_children, index).key;
              if (_bind$2 === undefined) {
                if (_M0MP310wzzc_2ddev4moui4core8ViewSpec4kind(_M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(old_children, index).spec) === _M0MP310wzzc_2ddev4moui4core8ViewSpec4kind(child_spec)) {
                  return index;
                } else {
                  break _L$2;
                }
              } else {
                break _L$2;
              }
            } else {
              break _L$2;
            }
          } else {
            break _L$2;
          }
        }
        return undefined;
      } else {
        const _Some = _bind;
        const _key = _Some;
        key = _key;
        break _L;
      }
    }
    const _bind = old_children.length;
    let _tmp = 0;
    while (true) {
      const old_index = _tmp;
      if (old_index < _bind) {
        const old_child = old_children[old_index];
        if (!_M0MPC15array5Array2atGbE(used, old_index) && (_M0IPC16option6OptionPB2Eq5equalGRP310wzzc_2ddev4moui4core3KeyE(old_child.key, key) && _M0MP310wzzc_2ddev4moui4core8ViewSpec4kind(old_child.spec) === _M0MP310wzzc_2ddev4moui4core8ViewSpec4kind(child_spec))) {
          return old_index;
        }
        _tmp = old_index + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return undefined;
  }
  function _M0FP310wzzc_2ddev4moui4core30reconcile__element__with__next(old, next_spec, next_id) {
    if (!_M0MP310wzzc_2ddev4moui4core8ViewSpec14same__identity(old.spec, next_spec)) {
      const mounted = _M0FP310wzzc_2ddev4moui4core29mount__view__spec__with__next(next_spec, next_id);
      return new _M0TP310wzzc_2ddev4moui4core15ReconcileResult(mounted.node, mounted.next_id);
    } else {
      const children_result = _M0FP310wzzc_2ddev4moui4core19reconcile__children(old.children, next_spec, next_id);
      old.spec = next_spec;
      old.key = _M0MP310wzzc_2ddev4moui4core8ViewSpec3key(old.spec);
      old.children = children_result.children;
      _M0MP310wzzc_2ddev4moui4core10DirtyFlags11mark__build(old.dirty);
      return new _M0TP310wzzc_2ddev4moui4core15ReconcileResult(old, children_result.next_id);
    }
  }
  function _M0FP310wzzc_2ddev4moui4core19reconcile__children(old_children, next_spec, next_id) {
    const next_specs = _M0FP310wzzc_2ddev4moui4core12child__specs(next_spec);
    const children = [];
    const used = [];
    const _bind = old_children.length;
    let _tmp = 0;
    while (true) {
      const _ = _tmp;
      if (_ < _bind) {
        _M0MPC15array5Array4pushGbE(used, false);
        _tmp = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const next = new _M0TPB8MutLocalGiE(next_id);
    const _bind$2 = next_specs.length;
    let _tmp$2 = 0;
    while (true) {
      const index = _tmp$2;
      if (index < _bind$2) {
        const child_spec = next_specs[index];
        const old_index = _M0FP310wzzc_2ddev4moui4core21find__reusable__child(old_children, used, child_spec, index);
        let old_index$2;
        _L: {
          _L$2: {
            if (old_index === undefined) {
              const mounted = _M0FP310wzzc_2ddev4moui4core29mount__view__spec__with__next(child_spec, next.val);
              _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, mounted.node);
              next.val = mounted.next_id;
            } else {
              const _Some = old_index;
              const _old_index = _Some;
              old_index$2 = _old_index;
              break _L$2;
            }
            break _L;
          }
          _M0MPC15array5Array3setGbE(used, old_index$2, true);
          const result = _M0FP310wzzc_2ddev4moui4core30reconcile__element__with__next(_M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(old_children, old_index$2), child_spec, next.val);
          _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(children, result.node);
          next.val = result.next_id;
        }
        _tmp$2 = index + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return new _M0TP310wzzc_2ddev4moui4core23ChildrenReconcileResult(children, next.val);
  }
  function _M0FP310wzzc_2ddev4moui4core32handle__button__element__pointer(element, data, event, frame) {
    const inside = _M0MP310wzzc_2ddev4moui4core4Rect8contains(frame, event.position);
    const was_pressed = _M0IP310wzzc_2ddev4moui4core11ButtonStatePB2Eq5equal(element.button_state, 2);
    const _bind = event.phase;
    let next;
    switch (_bind) {
      case 0: {
        next = inside ? 1 : 0;
        break;
      }
      case 1: {
        next = inside ? 2 : 0;
        break;
      }
      case 2: {
        next = inside ? 1 : 0;
        break;
      }
      default: {
        next = 0;
      }
    }
    const activated = _M0IP310wzzc_2ddev4moui4core12PointerPhasePB2Eq5equal(event.phase, 2) && (inside && was_pressed);
    if (activated) {
      let handler;
      _L: {
        _L$2: {
          const _bind$2 = data.on_click;
          if (_bind$2 === undefined) {
          } else {
            const _Some = _bind$2;
            const _handler = _Some;
            handler = _handler;
            break _L$2;
          }
          break _L;
        }
        handler();
      }
    }
    const changed = _M0IP016_24default__implPB2Eq10not__equalGRP310wzzc_2ddev4moui4core11ButtonStateE(next, element.button_state) || activated;
    element.button_state = next;
    if (changed) {
      _M0MP310wzzc_2ddev4moui4core10DirtyFlags11mark__paint(element.dirty);
    }
    return new _M0TP310wzzc_2ddev4moui4core18ElementEventResult(changed, activated);
  }
  function _M0MP310wzzc_2ddev4moui4core11ElementNode17dispatch__pointer(self, event, render) {
    _L: {
      _L$2: {
        let data;
        _L$3: {
          const _bind = self.spec;
          switch (_bind.$tag) {
            case 2: {
              const _ButtonSpec = _bind;
              const _data = _ButtonSpec._0;
              data = _data;
              break _L$3;
            }
            case 3: {
              break _L$2;
            }
            case 4: {
              break _L$2;
            }
            case 5: {
              break _L$2;
            }
            case 0: {
              break _L;
            }
            case 1: {
              break _L;
            }
            default: {
              break _L;
            }
          }
        }
        return _M0FP310wzzc_2ddev4moui4core32handle__button__element__pointer(self, data, event, render.frame);
      }
      const changed = new _M0TPB8MutLocalGbE(false);
      const activated = new _M0TPB8MutLocalGbE(false);
      const _bind = self.children;
      const _bind$2 = _bind.length;
      let _tmp = 0;
      while (true) {
        const index = _tmp;
        if (index < _bind$2) {
          const child = _bind[index];
          if (index < render.children.length) {
            const result = _M0MP310wzzc_2ddev4moui4core11ElementNode17dispatch__pointer(child, event, _M0MPC15array5Array2atGRP310wzzc_2ddev4moui4core11ElementNodeE(render.children, index));
            changed.val = changed.val || result.changed;
            activated.val = activated.val || result.activated;
          }
          _tmp = index + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      if (changed.val) {
        _M0MP310wzzc_2ddev4moui4core10DirtyFlags11mark__paint(self.dirty);
      }
      return new _M0TP310wzzc_2ddev4moui4core18ElementEventResult(changed.val, activated.val);
    }
    return new _M0TP310wzzc_2ddev4moui4core18ElementEventResult(false, false);
  }
  function _M0MP310wzzc_2ddev4moui4core10RenderNode23collect__draw__commands(self, commands) {
    const _bind = self.paint_commands;
    const _bind$2 = _bind.length;
    let _tmp = 0;
    while (true) {
      const _ = _tmp;
      if (_ < _bind$2) {
        const command = _bind[_];
        _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(commands, command);
        _tmp = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const _bind$3 = self.children;
    const _bind$4 = _bind$3.length;
    let _tmp$2 = 0;
    while (true) {
      const _ = _tmp$2;
      if (_ < _bind$4) {
        const child = _bind$3[_];
        _M0MP310wzzc_2ddev4moui4core10RenderNode23collect__draw__commands(child, commands);
        _tmp$2 = _ + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState12new__dynamic(root, size) {
    const spec = _M0MP310wzzc_2ddev4moui4core8ViewNode8to__spec(root());
    const mounted = _M0FP310wzzc_2ddev4moui4core29mount__view__spec__with__next(spec, 1);
    const render_tree = _M0MP310wzzc_2ddev4moui4core11ElementNode6render(mounted.node, _M0MP310wzzc_2ddev4moui4core4Rect3new(0, 0, size.width, size.height));
    return new _M0TP310wzzc_2ddev4moui4core12RuntimeState(spec, mounted.node, render_tree, size, true, false, false, false, mounted.next_id, root);
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState21render__current__tree(self) {
    self.render_tree = _M0MP310wzzc_2ddev4moui4core11ElementNode6render(self.element_tree, _M0MP310wzzc_2ddev4moui4core4Rect3new(0, 0, self.size.width, self.size.height));
    self.needs_layout = false;
    self.needs_paint = false;
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState12layout__pass(self) {
    _M0MP310wzzc_2ddev4moui4core12RuntimeState21render__current__tree(self);
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState7rebuild(self) {
    const result = _M0FP310wzzc_2ddev4moui4core30reconcile__element__with__next(self.element_tree, self.root_spec, self.next_element_id);
    self.element_tree = result.node;
    self.next_element_id = result.next_id;
    self.needs_rebuild = false;
    self.needs_layout = true;
    self.needs_paint = true;
    _M0MP310wzzc_2ddev4moui4core12RuntimeState12layout__pass(self);
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState15set__root__spec(self, root) {
    self.root_spec = root;
    _M0MP310wzzc_2ddev4moui4core12RuntimeState7rebuild(self);
    self.needs_redraw = true;
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState9set__root(self, root) {
    _M0MP310wzzc_2ddev4moui4core12RuntimeState15set__root__spec(self, _M0MP310wzzc_2ddev4moui4core8ViewNode8to__spec(root));
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState20ensure__render__tree(self) {
    if (self.needs_layout || self.needs_paint) {
      _M0MP310wzzc_2ddev4moui4core12RuntimeState21render__current__tree(self);
      return;
    } else {
      return;
    }
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState21build__draw__commands(self) {
    const commands = [new _M0DTP310wzzc_2ddev4moui4core11DrawCommand5Clear(_M0MP310wzzc_2ddev4moui4core5Color5white())];
    _M0MP310wzzc_2ddev4moui4core12RuntimeState20ensure__render__tree(self);
    _M0MP310wzzc_2ddev4moui4core10RenderNode23collect__draw__commands(self.render_tree, commands);
    return commands;
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState21rebuild__if__possible(self) {
    if (self.needs_rebuild) {
      let builder;
      _L: {
        const _bind = self.root_builder;
        if (_bind === undefined) {
          return;
        } else {
          const _Some = _bind;
          const _builder = _Some;
          builder = _builder;
          break _L;
        }
      }
      self.root_spec = _M0MP310wzzc_2ddev4moui4core8ViewNode8to__spec(builder());
      _M0MP310wzzc_2ddev4moui4core12RuntimeState7rebuild(self);
      self.needs_redraw = true;
      return;
    } else {
      return;
    }
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState15dispatch__event(self, event) {
    let event$2;
    _L: {
      let size;
      _L$2: {
        switch (event.$tag) {
          case 2: {
            const _Resize = event;
            const _size = _Resize._0;
            size = _size;
            break _L$2;
          }
          case 3: {
            self.needs_redraw = false;
            return;
          }
          case 0: {
            const _Pointer = event;
            const _event = _Pointer._0;
            event$2 = _event;
            break _L;
          }
          case 1: {
            self.needs_redraw = true;
            return;
          }
          default: {
            return;
          }
        }
      }
      self.size = size;
      self.needs_redraw = true;
      self.needs_layout = true;
      self.needs_paint = true;
      return;
    }
    _M0MP310wzzc_2ddev4moui4core12RuntimeState20ensure__render__tree(self);
    const result = _M0MP310wzzc_2ddev4moui4core11ElementNode17dispatch__pointer(self.element_tree, event$2, self.render_tree);
    self.needs_redraw = self.needs_redraw || result.changed;
    self.needs_rebuild = self.needs_rebuild || result.activated;
    self.needs_paint = self.needs_paint || result.changed;
    _M0MP310wzzc_2ddev4moui4core12RuntimeState21rebuild__if__possible(self);
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime12new__dynamic(root, size) {
    return new _M0TP310wzzc_2ddev4moui7backend10AppRuntime(_M0MP310wzzc_2ddev4moui4core12RuntimeState12new__dynamic(root, size));
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime15dispatch__event(self, event) {
    _M0MP310wzzc_2ddev4moui4core12RuntimeState15dispatch__event(self.state, event);
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime9set__root(self, root) {
    _M0MP310wzzc_2ddev4moui4core12RuntimeState9set__root(self.state, root);
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime14draw__commands(self) {
    return _M0MP310wzzc_2ddev4moui4core12RuntimeState21build__draw__commands(self.state);
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime4size(self) {
    return self.state.size;
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime13needs__redraw(self) {
    return self.state.needs_redraw;
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime14needs__rebuild(self) {
    return self.state.needs_rebuild;
  }
  function _M0MP410wzzc_2ddev4moui6render6webgpu17RenderBridgeTrace4push(self, call) {
    _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11ElementNodeE(self.calls, call);
  }
  function _M0MP410wzzc_2ddev4moui6render6webgpu14WebGpuRenderer6resize(self, size) {
    _M0FP410wzzc_2ddev4moui6render6webgpu18js__webgpu__resize(self, size.width, size.height);
  }
  function _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, call) {
    let trace$2;
    _L: {
      if (trace === undefined) {
        return;
      } else {
        const _Some = trace;
        const _trace = _Some;
        trace$2 = _trace;
        break _L;
      }
    }
    _M0MP410wzzc_2ddev4moui6render6webgpu17RenderBridgeTrace4push(trace$2, call);
  }
  function _M0FP410wzzc_2ddev4moui6render6webgpu16render__commands(renderer, commands, size, trace) {
    _M0FP410wzzc_2ddev4moui6render6webgpu17js__webgpu__begin(renderer, size.width, size.height);
    _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "begin");
    const _bind = commands.length;
    let _tmp = 0;
    while (true) {
      const _ = _tmp;
      if (_ < _bind) {
        const command = commands[_];
        let opacity;
        _L: {
          _L$2: {
            let transform;
            _L$3: {
              _L$4: {
                let rect;
                _L$5: {
                  _L$6: {
                    let run;
                    _L$7: {
                      _L$8: {
                        let run$2;
                        _L$9: {
                          _L$10: {
                            let color;
                            let rounded;
                            let width;
                            _L$11: {
                              _L$12: {
                                let rounded$2;
                                let color$2;
                                _L$13: {
                                  _L$14: {
                                    let color$3;
                                    let rect$2;
                                    let width$2;
                                    _L$15: {
                                      _L$16: {
                                        let rect$3;
                                        let color$4;
                                        _L$17: {
                                          _L$18: {
                                            let color$5;
                                            _L$19: {
                                              _L$20: {
                                                switch (command.$tag) {
                                                  case 0: {
                                                    const _Clear = command;
                                                    const _color = _Clear._0;
                                                    color$5 = _color;
                                                    break _L$20;
                                                  }
                                                  case 1: {
                                                    const _FillRect = command;
                                                    const _rect = _FillRect._0;
                                                    const _color$2 = _FillRect._1;
                                                    rect$3 = _rect;
                                                    color$4 = _color$2;
                                                    break _L$18;
                                                  }
                                                  case 2: {
                                                    const _StrokeRect = command;
                                                    const _rect$2 = _StrokeRect._0;
                                                    const _color$3 = _StrokeRect._1;
                                                    const _width = _StrokeRect._2;
                                                    color$3 = _color$3;
                                                    rect$2 = _rect$2;
                                                    width$2 = _width;
                                                    break _L$16;
                                                  }
                                                  case 3: {
                                                    const _FillRoundedRect = command;
                                                    const _rounded = _FillRoundedRect._0;
                                                    const _color$4 = _FillRoundedRect._1;
                                                    rounded$2 = _rounded;
                                                    color$2 = _color$4;
                                                    break _L$14;
                                                  }
                                                  case 4: {
                                                    const _StrokeRoundedRect = command;
                                                    const _rounded$2 = _StrokeRoundedRect._0;
                                                    const _color$5 = _StrokeRoundedRect._1;
                                                    const _width$2 = _StrokeRoundedRect._2;
                                                    color = _color$5;
                                                    rounded = _rounded$2;
                                                    width = _width$2;
                                                    break _L$12;
                                                  }
                                                  case 5: {
                                                    const _DrawText = command;
                                                    const _run = _DrawText._0;
                                                    run$2 = _run;
                                                    break _L$10;
                                                  }
                                                  case 6: {
                                                    const _DrawImage = command;
                                                    const _run$2 = _DrawImage._0;
                                                    run = _run$2;
                                                    break _L$8;
                                                  }
                                                  case 7: {
                                                    const _PushClip = command;
                                                    const _rect$3 = _PushClip._0;
                                                    rect = _rect$3;
                                                    break _L$6;
                                                  }
                                                  case 8: {
                                                    _M0FP410wzzc_2ddev4moui6render6webgpu21js__webgpu__pop__clip(renderer);
                                                    _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "pop_clip");
                                                    break;
                                                  }
                                                  case 9: {
                                                    const _PushTransform = command;
                                                    const _transform = _PushTransform._0;
                                                    transform = _transform;
                                                    break _L$4;
                                                  }
                                                  case 10: {
                                                    _M0FP410wzzc_2ddev4moui6render6webgpu26js__webgpu__pop__transform(renderer);
                                                    _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "pop_transform");
                                                    break;
                                                  }
                                                  case 11: {
                                                    const _PushOpacity = command;
                                                    const _opacity = _PushOpacity._0;
                                                    opacity = _opacity;
                                                    break _L$2;
                                                  }
                                                  default: {
                                                    _M0FP410wzzc_2ddev4moui6render6webgpu24js__webgpu__pop__opacity(renderer);
                                                    _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "pop_opacity");
                                                  }
                                                }
                                                break _L$19;
                                              }
                                              _M0FP410wzzc_2ddev4moui6render6webgpu17js__webgpu__clear(renderer, color$5.r, color$5.g, color$5.b, color$5.a);
                                              _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "clear");
                                            }
                                            break _L$17;
                                          }
                                          _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__fill__rect(renderer, rect$3.origin.x, rect$3.origin.y, rect$3.size.width, rect$3.size.height, color$4.r, color$4.g, color$4.b, color$4.a);
                                          _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "rect");
                                        }
                                        break _L$15;
                                      }
                                      _M0FP410wzzc_2ddev4moui6render6webgpu24js__webgpu__stroke__rect(renderer, rect$2.origin.x, rect$2.origin.y, rect$2.size.width, rect$2.size.height, color$3.r, color$3.g, color$3.b, color$3.a, width$2);
                                      _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "stroke_rect");
                                    }
                                    break _L$13;
                                  }
                                  _M0FP410wzzc_2ddev4moui6render6webgpu31js__webgpu__fill__rounded__rect(renderer, rounded$2.rect.origin.x, rounded$2.rect.origin.y, rounded$2.rect.size.width, rounded$2.rect.size.height, rounded$2.radius, color$2.r, color$2.g, color$2.b, color$2.a);
                                  _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "rounded_rect");
                                }
                                break _L$11;
                              }
                              _M0FP410wzzc_2ddev4moui6render6webgpu33js__webgpu__stroke__rounded__rect(renderer, rounded.rect.origin.x, rounded.rect.origin.y, rounded.rect.size.width, rounded.rect.size.height, rounded.radius, color.r, color.g, color.b, color.a, width);
                              _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "stroke_rounded_rect");
                            }
                            break _L$9;
                          }
                          _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__draw__text(renderer, run$2.text, run$2.frame.origin.x, run$2.frame.origin.y, run$2.frame.size.width, run$2.frame.size.height, run$2.font.family, run$2.font.size, run$2.font.weight, run$2.color.r, run$2.color.g, run$2.color.b, run$2.color.a);
                          _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "text");
                        }
                        break _L$7;
                      }
                      _M0FP410wzzc_2ddev4moui6render6webgpu23js__webgpu__draw__image(renderer, run.source, run.frame.origin.x, run.frame.origin.y, run.frame.size.width, run.frame.size.height, run.opacity);
                      _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "image");
                    }
                    break _L$5;
                  }
                  _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__push__clip(renderer, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
                  _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "push_clip");
                }
                break _L$3;
              }
              _M0FP410wzzc_2ddev4moui6render6webgpu27js__webgpu__push__transform(renderer, transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty);
              _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "push_transform");
            }
            break _L;
          }
          _M0FP410wzzc_2ddev4moui6render6webgpu25js__webgpu__push__opacity(renderer, opacity);
          _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "push_opacity");
        }
        _tmp = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    _M0FP410wzzc_2ddev4moui6render6webgpu19js__webgpu__present(renderer);
    _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "present");
  }
  function _M0MP410wzzc_2ddev4moui6render6webgpu14WebGpuRenderer6render(self, commands, size) {
    _M0FP410wzzc_2ddev4moui6render6webgpu16render__commands(self, commands, size, undefined);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext8renderer(self) {
    return _M0FP410wzzc_2ddev4moui7backend3web23boot__context__renderer(self);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext5width(self) {
    return _M0FP410wzzc_2ddev4moui7backend3web20boot__context__width(self);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext6height(self) {
    return _M0FP410wzzc_2ddev4moui7backend3web21boot__context__height(self);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp3new(runtime, renderer, rebuild) {
    return new _M0TP410wzzc_2ddev4moui7backend3web6WebApp(runtime, renderer, rebuild, false, 0);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp11render__now(self) {
    self.redraw_requested = false;
    _M0MP410wzzc_2ddev4moui6render6webgpu14WebGpuRenderer6render(self.renderer, _M0MP310wzzc_2ddev4moui7backend10AppRuntime14draw__commands(self.runtime), _M0MP310wzzc_2ddev4moui7backend10AppRuntime4size(self.runtime));
    _M0MP310wzzc_2ddev4moui7backend10AppRuntime15dispatch__event(self.runtime, new _M0DTP310wzzc_2ddev4moui4core8AppEvent6Redraw(3));
    self.redraw_count = self.redraw_count + 1 | 0;
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp5start(self) {
    _M0MP410wzzc_2ddev4moui7backend3web6WebApp11render__now(self);
  }
  function _M0FP410wzzc_2ddev4moui7backend3web13event__result(app) {
    return new _M0TP410wzzc_2ddev4moui7backend3web14WebEventResult(_M0MP310wzzc_2ddev4moui7backend10AppRuntime14needs__rebuild(app.runtime), _M0MP310wzzc_2ddev4moui7backend10AppRuntime13needs__redraw(app.runtime), app.redraw_requested);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp15request__redraw(self) {
    if (!self.redraw_requested) {
      self.redraw_requested = true;
      _M0FP410wzzc_2ddev4moui7backend3web25request__animation__frame(() => {
        _M0MP410wzzc_2ddev4moui7backend3web6WebApp11render__now(self);
      });
      return;
    } else {
      return;
    }
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp17dispatch__pointer(self, x, y, phase, button) {
    _M0MP310wzzc_2ddev4moui7backend10AppRuntime15dispatch__event(self.runtime, new _M0DTP310wzzc_2ddev4moui4core8AppEvent7Pointer(_M0MP310wzzc_2ddev4moui4core12PointerEvent11new_2einner(_M0MP310wzzc_2ddev4moui4core5Point3new(x, y), phase, button)));
    if (_M0MP310wzzc_2ddev4moui7backend10AppRuntime14needs__rebuild(self.runtime)) {
      const _func = self.rebuild;
      _func(self.runtime);
    }
    if (_M0MP310wzzc_2ddev4moui7backend10AppRuntime13needs__redraw(self.runtime)) {
      _M0MP410wzzc_2ddev4moui7backend3web6WebApp15request__redraw(self);
    }
    return _M0FP410wzzc_2ddev4moui7backend3web13event__result(self);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp15pointer__cancel(self) {
    return _M0MP410wzzc_2ddev4moui7backend3web6WebApp17dispatch__pointer(self, -1, -1, 3, 0);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp21pointer__down_2einner(self, x, y, button) {
    return _M0MP410wzzc_2ddev4moui7backend3web6WebApp17dispatch__pointer(self, x, y, 1, button);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp13pointer__move(self, x, y) {
    return _M0MP410wzzc_2ddev4moui7backend3web6WebApp17dispatch__pointer(self, x, y, 0, 0);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp19pointer__up_2einner(self, x, y, button) {
    return _M0MP410wzzc_2ddev4moui7backend3web6WebApp17dispatch__pointer(self, x, y, 2, button);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp6resize(self, width, height) {
    _M0MP410wzzc_2ddev4moui6render6webgpu14WebGpuRenderer6resize(self.renderer, _M0MP310wzzc_2ddev4moui4core4Size3new(width, height));
    _M0MP310wzzc_2ddev4moui7backend10AppRuntime15dispatch__event(self.runtime, new _M0DTP310wzzc_2ddev4moui4core8AppEvent6Resize(_M0MP310wzzc_2ddev4moui4core4Size3new(width, height)));
    _M0MP410wzzc_2ddev4moui7backend3web6WebApp15request__redraw(self);
    return _M0FP410wzzc_2ddev4moui7backend3web13event__result(self);
  }
  function _M0MP410wzzc_2ddev4moui7backend3web6WebApp19attach__dom__events(self, context) {
    _M0FP410wzzc_2ddev4moui7backend3web17bind__dom__events(context, () => {
      _M0MP410wzzc_2ddev4moui7backend3web6WebApp6resize(self, _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext5width(context), _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext6height(context));
    }, (x, y) => {
      _M0MP410wzzc_2ddev4moui7backend3web6WebApp13pointer__move(self, x, y);
    }, (x, y, button) => {
      _M0MP410wzzc_2ddev4moui7backend3web6WebApp21pointer__down_2einner(self, x, y, button);
    }, (x, y, button) => {
      _M0MP410wzzc_2ddev4moui7backend3web6WebApp19pointer__up_2einner(self, x, y, button);
    }, () => {
      _M0MP410wzzc_2ddev4moui7backend3web6WebApp15pointer__cancel(self);
    });
  }
  function _M0FP310wzzc_2ddev4moui5views13label_2einner(text, width, height) {
    return new _M0DTP310wzzc_2ddev4moui4core8ViewNode5Label(new _M0TP310wzzc_2ddev4moui4core9LabelData(text, _M0MP310wzzc_2ddev4moui4core4Size3new(width, height), _M0MP310wzzc_2ddev4moui4core5Color5black()));
  }
  function _M0FP310wzzc_2ddev4moui5views14column_2einner(children, spacing, main_axis_alignment, cross_axis_alignment) {
    return new _M0DTP310wzzc_2ddev4moui4core8ViewNode4Flex(new _M0TP310wzzc_2ddev4moui4core8FlexData(1, spacing, main_axis_alignment, cross_axis_alignment, children));
  }
  function _M0FP310wzzc_2ddev4moui5views6column(children, spacing$46$opt, main_axis_alignment$46$opt, cross_axis_alignment$46$opt) {
    let spacing;
    if (spacing$46$opt.$tag === 1) {
      const _Some = spacing$46$opt;
      spacing = _Some._0;
    } else {
      spacing = 0;
    }
    let main_axis_alignment;
    if (main_axis_alignment$46$opt === undefined) {
      main_axis_alignment = 0;
    } else {
      const _Some = main_axis_alignment$46$opt;
      main_axis_alignment = _Some;
    }
    let cross_axis_alignment;
    if (cross_axis_alignment$46$opt === undefined) {
      cross_axis_alignment = 3;
    } else {
      const _Some = cross_axis_alignment$46$opt;
      cross_axis_alignment = _Some;
    }
    return _M0FP310wzzc_2ddev4moui5views14column_2einner(children, spacing, main_axis_alignment, cross_axis_alignment);
  }
  function _M0FP310wzzc_2ddev4moui5views12button__base(text, on_click, width, height) {
    return new _M0DTP310wzzc_2ddev4moui4core8ViewNode6Button(new _M0TP310wzzc_2ddev4moui4core10ButtonData(text, _M0MP310wzzc_2ddev4moui4core4Size3new(width, height), 0, on_click));
  }
  function _M0FP310wzzc_2ddev4moui5views25button__on__click_2einner(text, on_click, width, height) {
    return _M0FP310wzzc_2ddev4moui5views12button__base(text, on_click, width, height);
  }
  function _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp3new() {
    return new _M0TP410wzzc_2ddev4moui8examples12counter__app10CounterApp(0);
  }
  function _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp9increment(self) {
    self.count = self.count + 1 | 0;
  }
  function _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp4root(self) {
    return _M0FP310wzzc_2ddev4moui5views6column([_M0FP310wzzc_2ddev4moui5views13label_2einner("MoUI Counter", 160, 32), _M0FP310wzzc_2ddev4moui5views13label_2einner(`Count: ${_M0IPC13int3IntPB4Show10to__string(self.count)}`, 160, 32), _M0FP310wzzc_2ddev4moui5views25button__on__click_2einner("Increment", () => {
      _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp9increment(self);
    }, 180, 44)], new _M0DTPC16option6OptionGdE4Some(12), undefined, undefined);
  }
  function _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp15runtime_2einner(self, width, height) {
    return _M0MP310wzzc_2ddev4moui7backend10AppRuntime12new__dynamic(() => _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp4root(self), _M0MP310wzzc_2ddev4moui4core4Size3new(width, height));
  }
  function _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp13sync__runtime(self, runtime) {
    if (_M0MP310wzzc_2ddev4moui7backend10AppRuntime14needs__rebuild(runtime)) {
      _M0MP310wzzc_2ddev4moui7backend10AppRuntime9set__root(runtime, _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp4root(self));
      return;
    } else {
      return;
    }
  }
  function _M0FP410wzzc_2ddev4moui8examples12counter__web19start__counter__web(context) {
    const app_state = _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp3new();
    const runtime = _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp15runtime_2einner(app_state, _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext5width(context), _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext6height(context));
    const app = _M0MP410wzzc_2ddev4moui7backend3web6WebApp3new(runtime, _M0MP410wzzc_2ddev4moui7backend3web14WebBootContext8renderer(context), (runtime$2) => {
      _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp13sync__runtime(app_state, runtime$2);
    });
    _M0MP410wzzc_2ddev4moui7backend3web6WebApp19attach__dom__events(app, context);
    _M0MP410wzzc_2ddev4moui7backend3web6WebApp5start(app);
    return app;
  }
  (() => {
    if (_M0FP410wzzc_2ddev4moui8examples12counter__web18has__boot__context() && !_M0FP410wzzc_2ddev4moui8examples12counter__web12has__started()) {
      _M0FP410wzzc_2ddev4moui8examples12counter__web13mark__started();
      _M0FP410wzzc_2ddev4moui8examples12counter__web19start__counter__web(_M0FP410wzzc_2ddev4moui8examples12counter__web13boot__context());
      return;
    } else {
      return;
    }
  })();
  globalThis.start_counter_web = _M0FP410wzzc_2ddev4moui8examples12counter__web19start__counter__web;
})();
//# sourceMappingURL=counter_web.js.map
