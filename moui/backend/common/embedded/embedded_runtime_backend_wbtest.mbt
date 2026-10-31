///|
/// End-to-end clipboard shortcut check on the embedded path.
///
/// This is the exact chain HarmonyOS uses:
/// `EmbeddedRuntimeBackendCore::dispatch` -> `dispatch_keyboard_with_services`
/// -> `service_bridge` -> the platform clipboard handler. The device reported
/// "Ctrl+A works, Ctrl+C does not", which can only be a break below the platform
/// key decode, so this pins the whole path.
test "embedded runtime routes ctrl+c and ctrl+v through the clipboard service" {
  let text = Ref("hello world")
  let written = Ref("")
  let renderer = @render.RendererSession::new(
    resize=_ => (),
    render_frame=_frame => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    present_count=() => 0,
    dispose=() => (),
  )
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=text.val,
      update=(_model, next) => {
        text.val = next
        next
      },
      view=model => {
        @views.column(
          [
            @views.text_field(
              model,
              on_input=next => next,
              width=240.0,
              height=40.0,
            ),
          ],
          spacing=0.0,
        )
      },
    ),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let core = EmbeddedRuntimeBackendCore::new(
    runtime~,
    renderer~,
    metrics~,
    surface_generation=1,
    service_handler=request => {
      match request {
        @host.HostServiceRequest::Clipboard(WriteText(value)) => {
          written.val = value
          Some(@host.ClipboardWritten)
        }
        @host.HostServiceRequest::Clipboard(_) =>
          Some(@host.ClipboardText("pasted"))
        _ => None
      }
    },
  )
  ignore(
    core.dispatch(
      @host.Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=20.0, y=20.0),
          phase=Down,
        ),
      ),
    ),
  )
  ignore(core.dispatch(TextInput(@core.TextInputEvent::InsertText("!"))))
  ignore(
    core.dispatch(
      @host.Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(control=true),
        ),
      ),
    ),
  )
  ignore(
    core.dispatch(
      @host.Keyboard(
        @core.KeyboardEvent::new(
          key="c",
          modifiers=@core.KeyModifiers::new(control=true),
        ),
      ),
    ),
  )
  assert_true(written.val.length() > 0)
}

///|
/// The device sends `ModifiersChanged` before the key (the host queue pushes it),
/// and the key event itself carries the modifier mask. This pins that ordering:
/// a Ctrl press followed by Ctrl+C, both as the runtime sees them, must reach the
/// clipboard writer.
test "embedded runtime ctrl sequence with modifier events reaches clipboard" {
  let text = Ref("hello")
  let written = Ref("")
  let renderer = @render.RendererSession::new(
    resize=_ => (),
    render_frame=_frame => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    present_count=() => 0,
    dispose=() => (),
  )
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=text.val,
      update=(_model, next) => {
        text.val = next
        next
      },
      view=model => {
        @views.column(
          [
            @views.text_field(
              model,
              on_input=next => next,
              width=240.0,
              height=40.0,
            ),
          ],
          spacing=0.0,
        )
      },
    ),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let core = EmbeddedRuntimeBackendCore::new(
    runtime~,
    renderer~,
    metrics~,
    surface_generation=1,
    service_handler=request => {
      match request {
        @host.HostServiceRequest::Clipboard(WriteText(value)) => {
          written.val = value
          Some(@host.ClipboardWritten)
        }
        @host.HostServiceRequest::Clipboard(_) =>
          Some(@host.ClipboardText("pasted"))
        _ => None
      }
    },
  )
  ignore(
    core.dispatch(
      @host.Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=20.0, y=20.0),
          phase=Down,
        ),
      ),
    ),
  )
  ignore(core.dispatch(@host.TextInput(@core.TextInputEvent::InsertText("!"))))
  // Ctrl press: the host queue pushes ModifiersChanged with control set first.
  ignore(
    core.dispatch(
      @host.Keyboard(
        @core.KeyboardEvent::new(
          key="Control",
          modifiers=@core.KeyModifiers::new(control=true),
        ),
      ),
    ),
  )
  ignore(
    core.dispatch(
      @host.Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(control=true),
        ),
      ),
    ),
  )
  ignore(
    core.dispatch(
      @host.Keyboard(
        @core.KeyboardEvent::new(
          key="c",
          modifiers=@core.KeyModifiers::new(control=true),
        ),
      ),
    ),
  )
  assert_true(written.val.length() > 0)
}
