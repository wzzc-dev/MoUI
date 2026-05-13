(() => {
  const _M0FPB19int__to__string__js = (x, radix) => {
    return x.toString(radix);
  };
  const _M0MPB7JSArray4push = (arr, val) => { arr.push(val); };
  function _M0TP310wzzc_2ddev4moui4core4Size(param0, param1) {
    this.width = param0;
    this.height = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core15PointerDispatch(param0, param1, param2) {
    this.node = param0;
    this.changed = param1;
    this.activated = param2;
  }
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
  function _M0TP310wzzc_2ddev4moui4core10ButtonData(param0, param1, param2, param3) {
    this.text = param0;
    this.size = param1;
    this.state = param2;
    this.on_click = param3;
  }
  function _M0TP310wzzc_2ddev4moui4core5Point(param0, param1) {
    this.x = param0;
    this.y = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core4Rect(param0, param1) {
    this.origin = param0;
    this.size = param1;
  }
  function _M0TP310wzzc_2ddev4moui4core11PaddingData(param0, param1) {
    this.insets = param0;
    this.child = param1;
  }
  function _M0TPB8MutLocalGbE(param0) {
    this.val = param0;
  }
  function _M0TP310wzzc_2ddev4moui4core8FlexData(param0, param1, param2) {
    this.axis = param0;
    this.spacing = param1;
    this.children = param2;
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
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand5Clear(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand5Clear.prototype.$tag = 0;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand8FillRect(param0, param1) {
    this._0 = param0;
    this._1 = param1;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand8FillRect.prototype.$tag = 1;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText.prototype.$tag = 2;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand8PushClip(param0) {
    this._0 = param0;
  }
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand8PushClip.prototype.$tag = 3;
  function _M0DTP310wzzc_2ddev4moui4core11DrawCommand7PopClip() {}
  _M0DTP310wzzc_2ddev4moui4core11DrawCommand7PopClip.prototype.$tag = 4;
  function _M0TP310wzzc_2ddev4moui4core7TextRun(param0, param1, param2, param3) {
    this.text = param0;
    this.frame = param1;
    this.font = param2;
    this.color = param3;
  }
  function _M0TP310wzzc_2ddev4moui4core12PointerEvent(param0, param1, param2) {
    this.position = param0;
    this.phase = param1;
    this.button = param2;
  }
  function _M0TP310wzzc_2ddev4moui4core12RuntimeState(param0, param1, param2, param3) {
    this.root = param0;
    this.size = param1;
    this.needs_redraw = param2;
    this.needs_rebuild = param3;
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
  const _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__draw__text = (renderer, text, x, y, width, height, family, size, weight, r, g, b, a) => {
    renderer?.drawText?.(text, x, y, width, height, family, size, weight, r, g, b, a);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__fill__rect = (renderer, x, y, width, height, r, g, b, a) => {
    renderer?.fillRect?.(x, y, width, height, r, g, b, a);
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu21js__webgpu__pop__clip = (renderer) => {
    renderer?.popClip?.();
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu19js__webgpu__present = (renderer) => {
    renderer?.present?.();
  };
  const _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__push__clip = (renderer, x, y, width, height) => {
    renderer?.pushClip?.(x, y, width, height);
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
  function _M0TP310wzzc_2ddev4moui4core9LabelData(param0, param1, param2) {
    this.text = param0;
    this.size = param1;
    this.color = param2;
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
  function _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11DrawCommandE(self, value) {
    _M0MPB7JSArray4push(self, value);
  }
  function _M0IPC13int3IntPB4Show10to__string(self) {
    return _M0MPC13int3Int18to__string_2einner(self, 10);
  }
  function _M0IP310wzzc_2ddev4moui4core12PointerPhasePB2Eq5equal(_x_378, _x_379) {
    switch (_x_378) {
      case 0: {
        if (_x_379 === 0) {
          return true;
        } else {
          return false;
        }
      }
      case 1: {
        if (_x_379 === 1) {
          return true;
        } else {
          return false;
        }
      }
      case 2: {
        if (_x_379 === 2) {
          return true;
        } else {
          return false;
        }
      }
      default: {
        if (_x_379 === 3) {
          return true;
        } else {
          return false;
        }
      }
    }
  }
  function _M0IP310wzzc_2ddev4moui4core11ButtonStatePB2Eq5equal(_x_184, _x_185) {
    switch (_x_184) {
      case 0: {
        if (_x_185 === 0) {
          return true;
        } else {
          return false;
        }
      }
      case 1: {
        if (_x_185 === 1) {
          return true;
        } else {
          return false;
        }
      }
      default: {
        if (_x_185 === 2) {
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
  function _M0MP310wzzc_2ddev4moui4core4Rect8contains(self, point) {
    return point.x >= self.origin.x && (point.y >= self.origin.y && (point.x <= self.origin.x + self.size.width && point.y <= self.origin.y + self.size.height));
  }
  function _M0FP310wzzc_2ddev4moui4core23handle__button__pointer(data, event, frame) {
    const inside = _M0MP310wzzc_2ddev4moui4core4Rect8contains(frame, event.position);
    const was_pressed = _M0IP310wzzc_2ddev4moui4core11ButtonStatePB2Eq5equal(data.state, 2);
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
    return new _M0TP310wzzc_2ddev4moui4core15PointerDispatch(new _M0DTP310wzzc_2ddev4moui4core8ViewNode6Button(new _M0TP310wzzc_2ddev4moui4core10ButtonData(data.text, data.size, next, data.on_click)), _M0IP016_24default__implPB2Eq10not__equalGRP310wzzc_2ddev4moui4core11ButtonStateE(next, data.state) || activated, activated);
  }
  function _M0MP310wzzc_2ddev4moui4core5Point3new(x, y) {
    return new _M0TP310wzzc_2ddev4moui4core5Point(x, y);
  }
  function _M0MP310wzzc_2ddev4moui4core4Rect3new(x, y, width, height) {
    return new _M0TP310wzzc_2ddev4moui4core4Rect(_M0MP310wzzc_2ddev4moui4core5Point3new(x, y), _M0MP310wzzc_2ddev4moui4core4Size3new(width, height));
  }
  function _M0FP310wzzc_2ddev4moui4core30flex__child__frame__with__main(data, frame, index, main) {
    const offset = (index + 0) * (main + data.spacing);
    const _bind = data.axis;
    if (_bind === 0) {
      return _M0MP310wzzc_2ddev4moui4core4Rect3new(frame.origin.x + offset, frame.origin.y, main, frame.size.height);
    } else {
      return _M0MP310wzzc_2ddev4moui4core4Rect3new(frame.origin.x, frame.origin.y + offset, frame.size.width, main);
    }
  }
  function _M0FP310wzzc_2ddev4moui4core11max__double(a, b) {
    return a > b ? a : b;
  }
  function _M0FP310wzzc_2ddev4moui4core18flex__child__frame(data, frame, index) {
    const count = data.children.length;
    if (count === 0) {
      return _M0MP310wzzc_2ddev4moui4core4Rect3new(frame.origin.x, frame.origin.y, 0, 0);
    } else {
      const total_spacing = data.spacing * (count + 0 - 1);
      const _bind = data.axis;
      let main;
      if (_bind === 0) {
        main = _M0FP310wzzc_2ddev4moui4core11max__double(0, frame.size.width - total_spacing) / (count + 0);
      } else {
        main = _M0FP310wzzc_2ddev4moui4core11max__double(0, frame.size.height - total_spacing) / (count + 0);
      }
      return _M0FP310wzzc_2ddev4moui4core30flex__child__frame__with__main(data, frame, index, main);
    }
  }
  function _M0MP310wzzc_2ddev4moui4core4Rect5inset(self, insets) {
    return _M0MP310wzzc_2ddev4moui4core4Rect3new(self.origin.x + insets.left, self.origin.y + insets.top, _M0FP310wzzc_2ddev4moui4core11max__double(0, self.size.width - insets.left - insets.right), _M0FP310wzzc_2ddev4moui4core11max__double(0, self.size.height - insets.top - insets.bottom));
  }
  function _M0MP310wzzc_2ddev4moui4core8ViewNode15handle__pointer(self, event, frame) {
    let data;
    _L: {
      let data$2;
      _L$2: {
        let data$3;
        _L$3: {
          _L$4: {
            switch (self.$tag) {
              case 0: {
                break _L$4;
              }
              case 1: {
                break _L$4;
              }
              case 2: {
                const _Button = self;
                const _data = _Button._0;
                data$3 = _data;
                break _L$3;
              }
              case 3: {
                const _Flex = self;
                const _data$2 = _Flex._0;
                data$2 = _data$2;
                break _L$2;
              }
              default: {
                const _Padding = self;
                const _data$3 = _Padding._0;
                data = _data$3;
                break _L;
              }
            }
          }
          return new _M0TP310wzzc_2ddev4moui4core15PointerDispatch(self, false, false);
        }
        return _M0FP310wzzc_2ddev4moui4core23handle__button__pointer(data$3, event, frame);
      }
      return _M0FP310wzzc_2ddev4moui4core21handle__flex__pointer(data$2, event, frame);
    }
    const child_frame = _M0MP310wzzc_2ddev4moui4core4Rect5inset(frame, data.insets);
    const result = _M0MP310wzzc_2ddev4moui4core8ViewNode15handle__pointer(data.child, event, child_frame);
    return new _M0TP310wzzc_2ddev4moui4core15PointerDispatch(new _M0DTP310wzzc_2ddev4moui4core8ViewNode7Padding(new _M0TP310wzzc_2ddev4moui4core11PaddingData(data.insets, result.node)), result.changed, result.activated);
  }
  function _M0FP310wzzc_2ddev4moui4core21handle__flex__pointer(data, event, frame) {
    const children = [];
    const changed = new _M0TPB8MutLocalGbE(false);
    const activated = new _M0TPB8MutLocalGbE(false);
    const _bind = data.children;
    const _bind$2 = _bind.length;
    let _tmp = 0;
    while (true) {
      const index = _tmp;
      if (index < _bind$2) {
        const child = _bind[index];
        const child_frame = _M0FP310wzzc_2ddev4moui4core18flex__child__frame(data, frame, index);
        const result = _M0MP310wzzc_2ddev4moui4core8ViewNode15handle__pointer(child, event, child_frame);
        _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11DrawCommandE(children, result.node);
        changed.val = changed.val || result.changed;
        activated.val = activated.val || result.activated;
        _tmp = index + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return new _M0TP310wzzc_2ddev4moui4core15PointerDispatch(new _M0DTP310wzzc_2ddev4moui4core8ViewNode4Flex(new _M0TP310wzzc_2ddev4moui4core8FlexData(data.axis, data.spacing, children)), changed.val, activated.val);
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
  function _M0MP310wzzc_2ddev4moui4core8ViewNode5paint(self, frame, commands) {
    let _tmp = self;
    let _tmp$2 = frame;
    let _tmp$3 = commands;
    _L: while (true) {
      const self$2 = _tmp;
      const frame$2 = _tmp$2;
      const commands$2 = _tmp$3;
      let data;
      _L$2: {
        let data$2;
        _L$3: {
          let data$3;
          _L$4: {
            let data$4;
            _L$5: {
              switch (self$2.$tag) {
                case 0: {
                  return;
                }
                case 1: {
                  const _Label = self$2;
                  const _data = _Label._0;
                  data$4 = _data;
                  break _L$5;
                }
                case 2: {
                  const _Button = self$2;
                  const _data$2 = _Button._0;
                  data$3 = _data$2;
                  break _L$4;
                }
                case 3: {
                  const _Flex = self$2;
                  const _data$3 = _Flex._0;
                  data$2 = _data$3;
                  break _L$3;
                }
                default: {
                  const _Padding = self$2;
                  const _data$4 = _Padding._0;
                  data = _data$4;
                  break _L$2;
                }
              }
            }
            _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11DrawCommandE(commands$2, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText(new _M0TP310wzzc_2ddev4moui4core7TextRun(data$4.text, frame$2, _M0MP310wzzc_2ddev4moui4core8FontSpec11new_2einner("system-ui, sans-serif", 16, 500), data$4.color)));
            return;
          }
          const _bind = data$3.state;
          let color;
          switch (_bind) {
            case 0: {
              color = _M0MP310wzzc_2ddev4moui4core5Color4gray();
              break;
            }
            case 1: {
              color = _M0MP310wzzc_2ddev4moui4core5Color12rgba_2einner(0.72, 0.78, 0.92, 1);
              break;
            }
            default: {
              color = _M0MP310wzzc_2ddev4moui4core5Color4blue();
            }
          }
          _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11DrawCommandE(commands$2, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand8FillRect(frame$2, color));
          let text_color;
          _L$5: {
            _L$6: {
              const _bind$2 = data$3.state;
              switch (_bind$2) {
                case 2: {
                  text_color = _M0MP310wzzc_2ddev4moui4core5Color5white();
                  break;
                }
                case 0: {
                  break _L$6;
                }
                default: {
                  break _L$6;
                }
              }
              break _L$5;
            }
            text_color = _M0MP310wzzc_2ddev4moui4core5Color5black();
          }
          _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11DrawCommandE(commands$2, new _M0DTP310wzzc_2ddev4moui4core11DrawCommand8DrawText(new _M0TP310wzzc_2ddev4moui4core7TextRun(data$3.text, frame$2, _M0MP310wzzc_2ddev4moui4core8FontSpec11new_2einner("system-ui, sans-serif", 16, 600), text_color)));
          return;
        }
        _M0FP310wzzc_2ddev4moui4core11paint__flex(data$2, frame$2, commands$2);
        return;
      }
      const child_frame = _M0MP310wzzc_2ddev4moui4core4Rect5inset(frame$2, data.insets);
      _tmp = data.child;
      _tmp$2 = child_frame;
      continue;
    }
  }
  function _M0FP310wzzc_2ddev4moui4core11paint__flex(data, frame, commands) {
    const count = data.children.length;
    if (count === 0) {
      return;
    } else {
      const total_spacing = data.spacing * (count + 0 - 1);
      const _bind = data.axis;
      let main;
      if (_bind === 0) {
        main = _M0FP310wzzc_2ddev4moui4core11max__double(0, frame.size.width - total_spacing) / (count + 0);
      } else {
        main = _M0FP310wzzc_2ddev4moui4core11max__double(0, frame.size.height - total_spacing) / (count + 0);
      }
      const _bind$2 = data.children;
      const _bind$3 = _bind$2.length;
      let _tmp = 0;
      while (true) {
        const index = _tmp;
        if (index < _bind$3) {
          const child = _bind$2[index];
          const child_frame = _M0FP310wzzc_2ddev4moui4core30flex__child__frame__with__main(data, frame, index, main);
          _M0MP310wzzc_2ddev4moui4core8ViewNode5paint(child, child_frame, commands);
          _tmp = index + 1 | 0;
          continue;
        } else {
          return;
        }
      }
    }
  }
  function _M0MP310wzzc_2ddev4moui4core12PointerEvent11new_2einner(position, phase, button) {
    return new _M0TP310wzzc_2ddev4moui4core12PointerEvent(position, phase, button);
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState3new(root, size) {
    return new _M0TP310wzzc_2ddev4moui4core12RuntimeState(root, size, true, false);
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState9set__root(self, root) {
    self.root = root;
    self.needs_rebuild = false;
    self.needs_redraw = true;
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
      return;
    }
    const bounds = _M0MP310wzzc_2ddev4moui4core4Rect3new(0, 0, self.size.width, self.size.height);
    const result = _M0MP310wzzc_2ddev4moui4core8ViewNode15handle__pointer(self.root, event$2, bounds);
    self.root = result.node;
    self.needs_redraw = self.needs_redraw || result.changed;
    self.needs_rebuild = self.needs_rebuild || result.activated;
  }
  function _M0MP310wzzc_2ddev4moui4core12RuntimeState21build__draw__commands(self) {
    const commands = [new _M0DTP310wzzc_2ddev4moui4core11DrawCommand5Clear(_M0MP310wzzc_2ddev4moui4core5Color5white())];
    _M0MP310wzzc_2ddev4moui4core8ViewNode5paint(self.root, _M0MP310wzzc_2ddev4moui4core4Rect3new(0, 0, self.size.width, self.size.height), commands);
    return commands;
  }
  function _M0MP310wzzc_2ddev4moui7backend10AppRuntime3new(root, size) {
    return new _M0TP310wzzc_2ddev4moui7backend10AppRuntime(_M0MP310wzzc_2ddev4moui4core12RuntimeState3new(root, size));
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
    _M0MPC15array5Array4pushGRP310wzzc_2ddev4moui4core11DrawCommandE(self.calls, call);
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
        let rect;
        _L: {
          _L$2: {
            let run;
            _L$3: {
              _L$4: {
                let rect$2;
                let color;
                _L$5: {
                  _L$6: {
                    let color$2;
                    _L$7: {
                      _L$8: {
                        switch (command.$tag) {
                          case 0: {
                            const _Clear = command;
                            const _color = _Clear._0;
                            color$2 = _color;
                            break _L$8;
                          }
                          case 1: {
                            const _FillRect = command;
                            const _rect = _FillRect._0;
                            const _color$2 = _FillRect._1;
                            rect$2 = _rect;
                            color = _color$2;
                            break _L$6;
                          }
                          case 2: {
                            const _DrawText = command;
                            const _run = _DrawText._0;
                            run = _run;
                            break _L$4;
                          }
                          case 3: {
                            const _PushClip = command;
                            const _rect$2 = _PushClip._0;
                            rect = _rect$2;
                            break _L$2;
                          }
                          default: {
                            _M0FP410wzzc_2ddev4moui6render6webgpu21js__webgpu__pop__clip(renderer);
                            _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "pop_clip");
                          }
                        }
                        break _L$7;
                      }
                      _M0FP410wzzc_2ddev4moui6render6webgpu17js__webgpu__clear(renderer, color$2.r, color$2.g, color$2.b, color$2.a);
                      _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "clear");
                    }
                    break _L$5;
                  }
                  _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__fill__rect(renderer, rect$2.origin.x, rect$2.origin.y, rect$2.size.width, rect$2.size.height, color.r, color.g, color.b, color.a);
                  _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "rect");
                }
                break _L$3;
              }
              _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__draw__text(renderer, run.text, run.frame.origin.x, run.frame.origin.y, run.frame.size.width, run.frame.size.height, run.font.family, run.font.size, run.font.weight, run.color.r, run.color.g, run.color.b, run.color.a);
              _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "text");
            }
            break _L;
          }
          _M0FP410wzzc_2ddev4moui6render6webgpu22js__webgpu__push__clip(renderer, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
          _M0FP410wzzc_2ddev4moui6render6webgpu11trace__call(trace, "push_clip");
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
  function _M0FP310wzzc_2ddev4moui5views14column_2einner(children, spacing) {
    return new _M0DTP310wzzc_2ddev4moui4core8ViewNode4Flex(new _M0TP310wzzc_2ddev4moui4core8FlexData(1, spacing, children));
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
    return _M0FP310wzzc_2ddev4moui5views14column_2einner([_M0FP310wzzc_2ddev4moui5views13label_2einner("MoUI Counter", 160, 32), _M0FP310wzzc_2ddev4moui5views13label_2einner(`Count: ${_M0IPC13int3IntPB4Show10to__string(self.count)}`, 160, 32), _M0FP310wzzc_2ddev4moui5views13label_2einner(`Count: ${_M0IPC13int3IntPB4Show10to__string(self.count)}`, 160, 32), _M0FP310wzzc_2ddev4moui5views25button__on__click_2einner("Increment", () => {
      _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp9increment(self);
    }, 180, 44)], 12);
  }
  function _M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp15runtime_2einner(self, width, height) {
    return _M0MP310wzzc_2ddev4moui7backend10AppRuntime3new(_M0MP410wzzc_2ddev4moui8examples12counter__app10CounterApp4root(self), _M0MP310wzzc_2ddev4moui4core4Size3new(width, height));
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
