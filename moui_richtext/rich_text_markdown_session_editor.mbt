///|
fn markdown_session_clamped_scroll_y(
  session : MarkdownDocumentSession,
  font : @core.FontSpec,
  source_mode~ : Bool,
  scroll_y : Double,
  viewport_height : Double,
  content_width? : Double = 0.0,
) -> Double {
  if viewport_height <= 0.0 {
    return max_double(0.0, scroll_y)
  }
  let content_height = session.estimated_content_height(
      base=font,
      source_mode~,
      content_width~,
    ) +
    96.0
  let max_scroll = max_double(0.0, content_height - viewport_height)
  clamp_double(scroll_y, 0.0, max_scroll)
}

///|
fn markdown_session_display_session(
  session : MarkdownDocumentSession,
  display_text : String,
) -> MarkdownDocumentSession {
  if display_text == session.source() {
    session
  } else {
    // Composition is live: paints and host IME polls re-derive this
    // session with the same display text until the candidate changes,
    // so memoize the full parse instead of re-parsing every poll.
    markdown_document_session_parse_cached(display_text)
  }
}

///|
fn markdown_session_visible_window(
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  font : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  content_width? : Double = 0.0,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> MarkdownDocumentRichTextWindow {
  let scroll_y = markdown_session_clamped_scroll_y(
    session,
    font,
    source_mode~,
    visible_scroll_y,
    visible_viewport_height,
    content_width~,
  )
  let window = session.rich_text_window(
    selection,
    base=font,
    source_mode~,
    focus_mode~,
    base_dir~,
    scroll_y~,
    viewport_height=visible_viewport_height,
    overscan=visible_overscan,
    content_width~,
  )
  // Paint, caret, hit-test, selection, and the measured-height feed all
  // consume this one soft-wrapped document, so a click lands the caret
  // exactly where the text was drawn (ADR 0001).
  if source_mode || content_width <= 0.0 {
    window
  } else {
    {
      ..window,
      document: rich_text_document_soft_wrap(
        window.document,
        content_width,
        font,
        text_system,
      ),
    }
  }
}

///|
/// Input transform bound to a session: hands the chain the session's
/// current block structure and text store so code-block detection reads
/// block ranges instead of re-parsing the whole document per keystroke.
fn markdown_session_input_transform_for(
  session : MarkdownDocumentSession,
  split_paragraph_on_enter~ : Bool,
) -> (String, Int, @core.TextRange?, String) -> RichTextInputTransform? {
  let context : MarkdownEditorInputContext = {
    blocks: session.editor_blocks,
    store: session.text_store,
  }
  fn(
    source : String,
    caret : Int,
    range : @core.TextRange?,
    inserted : String,
  ) {
    markdown_editor_transform_input(
      source,
      caret,
      range,
      inserted,
      context=Some(context),
      split_paragraph_on_enter~,
    )
  }
}

///|
fn[Msg] markdown_session_on_input_edit(
  session : MarkdownDocumentSession,
  on_transaction : (MarkdownEditTransaction) -> Msg,
) -> (String, Int, @core.TextRange?, RichTextInputEdit?) -> Msg {
  (next_source, caret, next_selection, edit) => {
    let transaction = match edit {
      // The control knows the exact range it replaced; carrying it
      // out skips the whole-document prefix/suffix diff that
      // `from_sources` performs to recover it.
      Some(edit) =>
        MarkdownEditTransaction::from_edit(
          session.source(),
          next_source,
          edit.start,
          deleted=edit.deleted,
          replacement=edit.replacement,
          caret~,
          selection=next_selection,
          reason=TextInput,
        )
      None =>
        MarkdownEditTransaction::from_sources(
          session.source(),
          next_source,
          caret~,
          selection=next_selection,
          reason=TextInput,
        )
    }
    on_transaction(transaction)
  }
}

///|
fn markdown_session_editor_paint(
  ctx : @core.ViewPaintContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> (@core.ViewPaintPlan, Double) {
  let commands : Array[@core.DrawCommand] = []
  let overlay_commands : Array[@core.DrawCommand] = []
  let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=corner_radius)
  commands.push(FillRoundedRectBrush(rounded, background))
  append_rich_text_border(
    commands,
    rounded,
    if ctx.focused {
      focused_border
    } else {
      border
    },
  )
  let text = session.source()
  let display_text = rich_text_with_composition(
    text,
    ctx.text_control,
    focused=ctx.focused,
  )
  let display_session = markdown_session_display_session(session, display_text)
  let content = rich_text_editor_content_rect(ctx.frame)
  commands.push(PushClip(content))
  let child_layers : Array[@core.ViewPaintLayer] = []
  let mut geometry_compensation = 0.0
  if display_text == "" {
    commands.push(
      DrawText(
        @core.TextRun::new(
          text=placeholder,
          frame=content,
          font~,
          color=placeholder_color,
          align=TextStart,
        ),
      ),
    )
  } else {
    let mut window = markdown_session_visible_window(
      display_session,
      selection,
      font,
      source_mode~,
      focus_mode~,
      base_dir~,
      visible_scroll_y~,
      visible_viewport_height~,
      visible_overscan~,
      content_width=content.size.width,
      text_system=ctx.text_system,
    )
    if display_text == session.source() &&
      !source_mode &&
      content.size.width > 0.0 {
      geometry_compensation = markdown_session_record_measured_block_heights(
        session,
        window,
        content_width=content.size.width,
        base=font,
        base_dir~,
        text_system=ctx.text_system,
        visible_scroll_y~,
      )
      // Measurement commits geometry during paint. Recompute the window for
      // this same frame after an above-anchor change so its prefix and block
      // positions use the same geometry as the compensated scroll offset.
      // Without this second lookup, one frame combines new heights with the
      // old top padding and reads as a small rebound before the next repaint.
      if geometry_compensation != 0.0 {
        window = markdown_session_visible_window(
          display_session,
          selection,
          font,
          source_mode~,
          focus_mode~,
          base_dir~,
          visible_scroll_y=visible_scroll_y + geometry_compensation,
          visible_viewport_height~,
          visible_overscan~,
          content_width=content.size.width,
          text_system=ctx.text_system,
        )
      }
    }
    // Derive the paint-space content rect only after measurement has settled
    // the final window. Keeping the rect from the pre-measurement window
    // combines the new prefix with the old offset and produces a one-frame
    // reverse-looking jump when a block above the anchor grows or shrinks.
    let window_content = window.content_rect(content)
    // Position blocks inside the offset `window_content`, but cull against
    // the original `content` viewport. Without this, the non-windowed cull
    // uses `window_content.origin.y + height` which is shifted up by
    // `top_padding - scroll_y`, cutting off the bottom of the viewport.
    append_rich_text_document_layers(
      child_layers,
      window.document,
      window_content,
      font,
      foreground,
      text_system=ctx.text_system,
      clip_rect=Some(content),
      // Blocks are already pre-positioned into paint space, so the band is the
      // clip plus overscan and no extra scroll. Passing the viewport height is
      // what turns the windowed path on; without it the builder falls back to
      // culling whole blocks against the clip, which never culls a block
      // taller than the viewport — and a soft-wrapped paragraph holding a
      // whole novel is exactly that.
      visible_scroll_y=0.0,
      visible_viewport_height=content.size.height,
    )
    if ctx.focused {
      // The clipped window may not contain the caret (parked off-screen
      // while the user scrolls). The document walk pins such a caret to
      // the first rendered line — the "caret at the very front" defect —
      // so the session-level estimate, which answers for any offset,
      // stands in whenever the window does not cover the caret.
      let paint_caret = @core.clamp_int(
        rich_text_visual_caret(text, ctx.text_control, focused=true),
        0,
        text_length(display_text),
      )
      let caret_rect_override = if markdown_session_window_covers_caret(
          window, paint_caret,
        ) {
        None
      } else {
        Some(
          markdown_session_estimated_caret_rect(
            display_session,
            paint_caret,
            content,
            font,
            source_mode~,
            scroll_y=window.scroll_y,
            base_dir~,
            text_system=ctx.text_system,
          ),
        )
      }
      append_rich_text_editor_overlay(
        overlay_commands,
        text~,
        display_text~,
        document=window.document,
        content=window_content,
        font~,
        cursor_color~,
        control=ctx.text_control,
        text_system=ctx.text_system,
        clip_rect=Some(content),
        caret_rect_override~,
      )
    }
  }
  // PopClip must go in post_commands (not commands) so that child_layers —
  // which are rendered between commands and post_commands — stay inside the
  // content clip. Without this, overscan blocks bleed past the editor frame
  // and overlap the chrome/status bar during scrolling.
  (
    {
      commands,
      child_layers,
      post_commands: [PopClip],
      overlay_commands,
      repaint_boundary: false,
      animating: false,
    },
    geometry_compensation,
  )
}

///|
fn[Msg] markdown_session_editor_event(
  ctx : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  on_transaction~ : (MarkdownEditTransaction) -> Msg,
  font~ : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  accepts_tab_input~ : Bool,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double, Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> @core.ViewEventResult[Msg] {
  let value = session.source()
  let on_input_edit = markdown_session_on_input_edit(session, on_transaction)
  match ctx.event {
    Pointer(event) =>
      markdown_session_pointer_event(
        ctx,
        session~,
        selection~,
        font~,
        source_mode~,
        focus_mode~,
        base_dir~,
        on_selection_change~,
        on_prefix_click~,
        on_command_click~,
        event~,
        visible_scroll_y~,
        on_scroll~,
        visible_viewport_height~,
        visible_overscan~,
      )
    Keyboard(event) => {
      // ArrowUp/ArrowDown 需要用 visible_window 的 document 来正确计算
      // 视觉位置（考虑 scroll offset），所以在这里预处理，而不是走
      // rich_text_keyboard_event 的通用 format(text) 路径。
      if event.pressed && (event.key == "ArrowUp" || event.key == "ArrowDown") {
        let text = session.source()
        let window = markdown_session_visible_window(
          session,
          selection,
          font,
          source_mode~,
          focus_mode~,
          base_dir~,
          visible_scroll_y~,
          visible_viewport_height~,
          visible_overscan~,
          content_width=rich_text_editor_content_rect(ctx.frame).size.width,
          text_system=ctx.text_system,
        )
        let content = window.content_rect(
          rich_text_editor_content_rect(ctx.frame),
        )
        return rich_text_vertical_caret_move_result(
          ctx,
          text,
          window.document,
          content,
          font,
          up=event.key == "ArrowUp",
          extend_selection=event.modifiers.shift,
          on_selection_change,
        )
      }
      rich_text_keyboard_event(
        ctx,
        value~,
        format=_source => {
          session.rich_text(
            selection,
            base=font,
            source_mode~,
            focus_mode~,
            base_dir~,
          )
        },
        font~,
        on_input=None,
        on_input_edit=Some(on_input_edit),
        on_selection_change~,
        input_transform=Some(
          markdown_session_input_transform_for(
            session,
            split_paragraph_on_enter=!source_mode,
          ),
        ),
        accepts_tab_input~,
        event~,
      )
    }
    TextInput(event) =>
      rich_text_input_event(
        ctx,
        value~,
        on_input=None,
        on_input_edit=Some(on_input_edit),
        on_selection_change~,
        input_transform=Some(
          markdown_session_input_transform_for(
            session,
            split_paragraph_on_enter=!source_mode,
          ),
        ),
        event~,
        record_history=true,
      )
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] markdown_session_pointer_event(
  ctx : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  font~ : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  event~ : @core.PointerEvent,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double, Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> @core.ViewEventResult[Msg] {
  // Secondary/middle presses reach the view tree now that host backends route
  // right-button downs for per-target context menus. A right press only places
  // the caret (see the Down branch), so the menu the host builds next describes
  // what was pressed; every other button and phase is ignored, which keeps a
  // right-drag from selecting and leaves the wheel path (button 0) untouched.
  if event.button != 0 && !(event.button == 1 && event.phase == Down) {
    return @core.ViewEventResult::ignored()
  }
  let inside = ctx.frame.contains(event.position)
  let content_width = rich_text_editor_content_rect(ctx.frame).size.width
  if inside && (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
    return markdown_session_scroll_event(
      event~,
      on_scroll~,
      clock_ms=ctx.now_ms,
    )
  }
  match event.phase {
    Down =>
      if inside {
        let text = session.source()
        let window = markdown_session_visible_window(
          session,
          selection,
          font,
          source_mode~,
          focus_mode~,
          base_dir~,
          visible_scroll_y~,
          visible_viewport_height~,
          visible_overscan~,
          content_width~,
          text_system=ctx.text_system,
        )
        let content = window.content_rect(
          rich_text_editor_content_rect(ctx.frame),
        )
        // A right press moves the caret the way mature editors do, so the
        // context menu the host builds next describes the text that was
        // pressed. A press inside the current selection keeps it: that is what
        // makes "Bold" in the menu apply to the selected run. The result
        // reports `activated=false` on purpose — the enclosing
        // `on_secondary_tap` observer must still run, so the app records its
        // menu target from the same press — and leaves no selection anchor
        // behind, so a right-drag never grows a selection.
        if event.button == 1 {
          let caret = rich_text_document_source_offset_at_point(
            window.document,
            event.position,
            content,
            font,
            ctx.text_system,
          ).unwrap_or(text_length(text))
          if rich_text_selection_covers(selection.selection, caret) {
            return view_event_result(focused=true)
          }
          return view_event_result(
            changed=true,
            focused=true,
            text_control=Some({
              ..ctx.text_control,
              caret,
              selection: None,
              text_selection_anchor: None,
              text_selection_origin: None,
              composition: None,
              composition_cursor: None,
            }),
            dirty=ViewPaintDirty,
            messages=selection_messages(on_selection_change, caret, None),
          )
        }
        let command_modifiers = event.modifiers.meta || event.modifiers.control
        match (command_modifiers, on_command_click) {
          (true, Some(handler)) => {
            let offset = rich_text_document_source_offset_at_point(
              window.document,
              event.position,
              content,
              font,
              ctx.text_system,
            ).unwrap_or(text_length(text))
            view_event_result(
              changed=true,
              focused=true,
              captured=true,
              text_control=Some(ctx.text_control),
              dirty=ViewPaintDirty,
              messages=[handler(offset)],
            )
          }
          _ => {
            let prefix_messages = match on_prefix_click {
              Some(handler) =>
                match
                  rich_text_document_prefix_source_offset_at_point(
                    window.document,
                    event.position,
                    content,
                    font,
                    ctx.text_system,
                  ) {
                  Some(offset) => [handler(offset)]
                  None => []
                }
              None => []
            }
            let caret = rich_text_document_source_offset_at_point(
              window.document,
              event.position,
              content,
              font,
              ctx.text_system,
            ).unwrap_or(text_length(text))
            let next_control = {
              ..ctx.text_control,
              caret,
              selection: None,
              text_selection_anchor: Some(caret),
              text_selection_origin: Some(event.position),
              composition: None,
              composition_cursor: None,
            }
            view_event_result(
              changed=true,
              focused=true,
              captured=true,
              text_control=Some(next_control),
              dirty=ViewPaintDirty,
              messages=prefix_messages +
                selection_messages(on_selection_change, caret, None),
            )
          }
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    Move =>
      match ctx.text_control.text_selection_anchor {
        Some(anchor) => {
          let text = session.source()
          // A Move on the gesture's own down point is the click's event
          // stream, not pointer travel: the view may have scrolled
          // (typewriter centering) or expanded hidden markers in between,
          // and re-deriving the caret from the screen point would then
          // fabricate a selection. Same point => nothing moves.
          let stationary = match ctx.text_control.text_selection_origin {
            Some(origin) =>
              (event.position.x - origin.x).abs() <= 1.0 &&
              (event.position.y - origin.y).abs() <= 1.0
            None => false
          }
          if stationary {
            view_event_result(
              focused=true,
              captured=true,
              text_control=Some(ctx.text_control),
            )
          } else {
            // Hit-test against the document frozen at the gesture anchor,
            // not the live selection: a growing selection keeps revealing
            // new markers mid-drag, which would shift the mapping under
            // the pointer and inflate the selection on its own.
            let window = markdown_session_visible_window(
              session,
              { caret: anchor, selection: None, },
              font,
              source_mode~,
              focus_mode~,
              base_dir~,
              visible_scroll_y~,
              visible_viewport_height~,
              visible_overscan~,
              content_width~,
              text_system=ctx.text_system,
            )
            let content = window.content_rect(
              rich_text_editor_content_rect(ctx.frame),
            )
            let caret = rich_text_document_source_offset_at_point(
              window.document,
              event.position,
              content,
              font,
              ctx.text_system,
            ).unwrap_or(text_length(text))
            let next_selection = if caret == anchor {
              None
            } else {
              Some(@core.TextRange::new(start=anchor, end=caret))
            }
            let changed = ctx.text_control.caret != caret ||
              ctx.text_control.selection != next_selection
            if changed {
              view_event_result(
                changed=true,
                focused=true,
                captured=true,
                text_control=Some({
                  ..ctx.text_control,
                  caret,
                  selection: next_selection,
                  composition: None,
                  composition_cursor: None,
                }),
                dirty=ViewPaintDirty,
                messages=selection_messages(
                  on_selection_change, caret, next_selection,
                ),
              )
            } else {
              view_event_result(
                focused=true,
                captured=true,
                text_control=Some(ctx.text_control),
              )
            }
          }
        }
        None => @core.ViewEventResult::ignored()
      }
    Up =>
      if ctx.text_control.text_selection_anchor is Some(_) {
        view_event_result(
          changed=true,
          focused=true,
          captured=true,
          text_control=Some({
            ..ctx.text_control,
            text_selection_anchor: None,
            text_selection_origin: None,
          }),
          dirty=ViewPaintDirty,
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
/// Forward a wheel event to the app as (raw delta, animation-clock ms). The
/// delta is deliberately NOT resolved into an absolute offset against
/// `visible_scroll_y`: that prop is the position at the last view build,
/// which lags the eased offset mid-glide, so an absolute offset computed
/// here would land behind the displayed position and snap the scroll
/// backward on momentum tail events. The app applies the delta to its own
/// current position and owns the clamping.
///
/// The clock value is the runtime animation clock (`ctx.now_ms`) — the same
/// timeline the glide is evaluated on at paint time — so an app can stamp a
/// new glide with it and get a self-consistent animation. The pointer
/// contract's own `time_ms` is not used: the input path does not populate
/// it (it stays 0.0).
fn[Msg] markdown_session_scroll_event(
  event~ : @core.PointerEvent,
  on_scroll~ : ((Double, Double) -> Msg)?,
  clock_ms~ : Double,
) -> @core.ViewEventResult[Msg] {
  match on_scroll {
    Some(handler) => {
      let delta_y = event.wheel_delta.y
      view_event_result(
        changed=delta_y != 0.0,
        activated=delta_y != 0.0,
        captured=true,
        dirty=ViewPaintDirty,
        messages=if delta_y != 0.0 { [handler(delta_y, clock_ms)] } else { [] },
      )
    }
    None => @core.ViewEventResult::ignored()
  }
}

///|
/// Feed the scroll geometry with the pixel heights actually laid out for
/// the visible block window. Heights are computed from the pre-reveal
/// rich blocks (cache-hot at this point) so temporary marker reveals do
/// not leak into the content-keyed measurements. Blank gap blocks are the
/// one exception: they render collapsed (a 0.4em separator vs a full writing
/// line, see `markdown_editor_collapse_inactive_blank_gaps`), which is
/// structural WYSIWYG geometry rather than a transient reveal. Measuring
/// the uncollapsed block overstates every paragraph separator by ~1.55em
/// (≈26px at 17px body text); the spurious growth above the anchor is then
/// published as geometry compensation, and the next wheel event re-keys
/// from the shifted offset — scrolling up through blanks reads as a small
/// rollback. Blank gaps therefore measure the painted (collapsed) window
/// block, which already carries the correct separator/writing-line state
/// including the caret-active case.
fn markdown_session_record_measured_block_heights(
  session : MarkdownDocumentSession,
  window : MarkdownDocumentRichTextWindow,
  content_width~ : Double,
  base~ : @core.FontSpec,
  base_dir~ : String?,
  text_system~ : @core.TextSystem,
  visible_scroll_y~ : Double,
) -> Double {
  if window.visible_start < 0 {
    return 0.0
  }
  // Keep the range that was used to produce this window. A measurement can
  // change the document's max offset even when it is below the anchor; if the
  // user was at the bottom, that range change must be folded into the same
  // compensation transaction instead of letting the next paint clamp behind
  // the current glide.
  let old_max_scroll = max_double(
    0.0,
    window.content_height + 96.0 - window.viewport_height,
  )
  let was_at_bottom = old_max_scroll > 0.0 &&
    visible_scroll_y >= old_max_scroll - 1.0
  let updates : Array[(Int, Double)] = []
  for offset, window_block in window.document.blocks {
    match session.editor_blocks.get(window.visible_start + offset) {
      Some(editor_block) => {
        // Skip a block the line window sliced. Measuring it would materialise
        // the whole block — for an oversized block that is the entire
        // document, on every paint — and would publish a height that covers
        // only the visible lines, pulling the scroll geometry out of line with
        // what is drawn. The block keeps its indexed estimate, which is what
        // the window itself used to choose the band.
        // "Covers less source than the session block" is the exact signature
        // of a line-window slice. Comparing offsets for inequality was too
        // loose: revealing a marker or an HTML block legitimately shifts or
        // widens a block's range, and treating those as slices skipped
        // measurements the geometry depends on.
        let sliced = markdown_document_block_needs_line_window(
            session,
            base,
            window.visible_start + offset,
            window.viewport_height,
          ) &&
          (match window_block.source_range {
            Some(range) =>
              range.end - range.start <
              editor_block.source_range.end - editor_block.source_range.start
            None => false
          })
        if sliced {
          continue
        }
        // Measured heights must come from the block's real inline runs.
        let editor_block = markdown_editor_block_materialized(
          session.source(),
          source_length=session.source_length,
          source_digest=session.source_digest,
          editor_block,
        )
        let height = if rich_text_block_is_blank_gap(window_block) {
          // Collapsed WYSIWYG height (separator margin or writing line),
          // already soft-wrapped in the window; re-wrapping is a no-op for
          // run-less gaps. Using the uncollapsed rebuild here would record
          // a full line box for every separator.
          rich_text_block_total_height(
            window_block,
            base,
            text_system,
            block_width=content_width,
          )
        } else {
          rich_text_block_total_height(
            rich_text_block_soft_wrap(
              markdown_editor_block_to_rich_text(
                session.source(),
                editor_block,
                base,
                base_dir~,
              ),
              content_width,
              base,
              text_system,
            ),
            base,
            text_system,
            block_width=content_width,
          )
        }
        let identity = session.blocks.get(window.visible_start + offset)
        let _ = rich_text_record_block_measured_height(
          base,
          width=content_width,
          block_id=match identity {
            Some(session_block) => session_block.id
            None => window.visible_start + offset
          },
          block_revision=match identity {
            Some(session_block) => session_block.revision
            None => 0
          },
          height~,
          source_digest=Some(session.document_identity.to_uint64()),
        )
        // Avoid feeding identical measurements back into the geometry. This
        // is especially important for retained paints: an unchanged height
        // must not look like a fresh update that can be compensated again.
        let block_index = window.visible_start + offset
        let old = markdown_document_block_height_at(
          session,
          base,
          content_width~,
          block_index,
        )
        if (height - old).abs() > 0.0001 {
          updates.push((block_index, height))
        }
      }
      None => ()
    }
  }
  // Apply the complete visible-window batch after all measurements have been
  // collected. Only changes above the first visible block move the viewport.
  let offset = visible_scroll_y
  let anchor_index = markdown_document_anchor_index(
    session,
    base,
    content_width~,
    offset~,
  )
  let mut compensation = 0.0
  for update in updates {
    let index = update.0
    let height = update.1
    let old = markdown_document_block_height_at(
      session,
      base,
      content_width~,
      index,
    )
    markdown_document_apply_measured_height(
      session,
      base,
      block_index=index,
      width=content_width,
      height~,
    )
    if index < anchor_index {
      compensation = compensation + height - old
    }
  }
  // A fresh document starts with an empty negative geometry entry. Once this
  // batch has populated the measured-height table, materialize the live
  // geometry exactly once so subsequent paints point-update it instead of
  // re-publishing the same delta forever.
  if !updates.is_empty() {
    ignore(markdown_document_block_geometry(session, base, content_width~))
  }
  if !updates.is_empty() {
    let new_content_height = session.estimated_content_height(
      base~,
      source_mode=false,
      content_width~,
    )
    let new_max_scroll = max_double(
      0.0,
      new_content_height + 96.0 - window.viewport_height,
    )
    if was_at_bottom {
      // Bottom anchoring wins over a block anchor: the scrollbar thumb and
      // the final line stay attached to the viewport edge as content grows or
      // shrinks anywhere in the document.
      compensation = new_max_scroll - visible_scroll_y
    } else if visible_scroll_y > new_max_scroll {
      // A range shrink away from the bottom still cannot leave the displayed
      // point outside the new scrollable interval.
      compensation = new_max_scroll - visible_scroll_y
    }
  }
  markdown_scroll_publish_geometry_compensation(compensation)
  compensation
}

///|
fn markdown_session_estimated_caret_inset_x(
  session : MarkdownDocumentSession,
  source_caret : Int,
  font~ : @core.FontSpec,
  base_dir~ : String?,
  content_width~ : Double,
  text_system~ : @core.TextSystem,
) -> Double {
  match
    markdown_editor_block_index_at_offset(session.editor_blocks, source_caret) {
    None => 0.0
    Some(block_index) => {
      let editor_block = session.editor_blocks[block_index]
      let block_start = editor_block.source_range.start
      let scan_end = markdown_editor_min_int(
        source_caret,
        editor_block.source_range.end,
      )
      // A caret can resolve to a block it sits before (the index lookup
      // clamps); pin the range so the substring below always has start <= end.
      let scan_end = if scan_end < block_start { block_start } else { scan_end }
      // The caret's own line start comes from the document's cached line scan
      // in O(log n), with no copy of the text before the caret and no
      // approximation: the window then begins exactly at that line.
      //
      // The bounded scan below stays as the fallback for a source the line
      // scan has not seen. It was the only path before, and it approximates
      // when the caret's line is longer than the window.
      let (window_start, line_start) = match
        markdown_editor_line_at_offset(session.source(), scan_end) {
        Some((_, start)) if start >= block_start && start <= scan_end =>
          (start, 0)
        _ => {
          let start = if scan_end > block_start + 4096 {
            scan_end - 4096
          } else {
            block_start
          }
          let window = markdown_editor_substring(
            session.source(),
            start,
            scan_end,
          )
          let mut offset = if start > block_start { -1 } else { 0 }
          for index, ch in window {
            if ch == '\n' {
              offset = index + 1
            }
          }
          (start, offset)
        }
      }
      let window = markdown_editor_substring(
        session.source(),
        window_start,
        scan_end,
      )
      // Caret geometry only needs the caret's own line, so materialise the
      // caret's neighbourhood rather than the whole block. A block can hold
      // the entire document — a soft-wrapped paragraph with no blank lines —
      // and parsing all of it on every click is what made clicking a large
      // document stall. The full block is still used when the window holds no
      // line break, which means the caret's line is longer than the window and
      // the exact answer still matters.
      let rich_source_block = if line_start >= 0 {
        let slice_end = if scan_end + 4096 < editor_block.source_range.end {
          scan_end + 4096
        } else {
          editor_block.source_range.end
        }
        {
          block: {
            ..editor_block.block,
            text: markdown_editor_substring(
              session.source(),
              window_start,
              slice_end,
            ),
            inlines: [],
          },
          source_range: { start: window_start, end: slice_end, },
          content_range: { start: window_start, end: slice_end, },
        }
      } else {
        editor_block
      }
      // Caret geometry needs the block's real inline runs.
      let rich_block = markdown_editor_block_to_rich_text(
        session.source(),
        markdown_editor_block_materialized(
          session.source(),
          source_length=session.source_length,
          source_digest=session.source_digest,
          rich_source_block,
        ),
        font,
        base_dir~,
      )
      let block_font = rich_block.font.unwrap_or(font)
      let line_text = if line_start >= 0 {
        markdown_editor_substring(
          window,
          line_start,
          markdown_editor_text_length(window),
        )
      } else {
        // No newline inside the window and it does not reach the block start,
        // so the line begins earlier: scan the whole block range exactly.
        let before_caret = markdown_editor_substring(
          session.source(),
          block_start,
          scan_end,
        )
        let mut exact_start = 0
        for index, ch in before_caret {
          if ch == '\n' {
            exact_start = index + 1
          }
        }
        markdown_editor_substring(
          before_caret,
          exact_start,
          markdown_editor_text_length(before_caret),
        )
      }
      // The caret rect fallback maps canonical source text; hidden inline
      // markers make this an over-estimate, so clamp to the content width.
      let line_width = min_double(
        rich_text_width(line_text, block_font, text_system),
        max_double(0.0, content_width - rich_block.inset.left),
      )
      rich_block.inset.left +
      rich_text_block_marker_lane(rich_block, block_font, text_system) +
      line_width
    }
  }
}

///|
/// Whether the window's document actually contains `caret`. A window
/// clipped to the visible band does not, and asking its document for such
/// a caret returns a rect pinned to the first rendered line instead of
/// failing — callers must fall back to the session-level estimate.
fn markdown_session_window_covers_caret(
  window : MarkdownDocumentRichTextWindow,
  caret : Int,
) -> Bool {
  match (window.document.blocks.get(0), window.document.blocks.last()) {
    (Some(first), Some(last)) =>
      match (first.source_range, last.source_range) {
        (Some(start), Some(end)) => caret >= start.start && caret <= end.end
        _ => true
      }
    _ => false
  }
}

///|
fn markdown_session_input_state(
  text~ : String,
  frame~ : @core.Rect,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  font~ : @core.FontSpec,
  control~ : @core.TextControlStateContext,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  text_system~ : @core.TextSystem,
) -> @core.TextInputState {
  let control = {
    ..control,
    caret: selection.caret,
    selection: selection.selection,
  }
  let caret = @core.clamp_int(control.caret, 0, session.source_length)
  if frame.size.width <= 0.0 || frame.size.height <= 0.0 {
    return {
      focused: true,
      text,
      caret,
      selection: control.selection,
      composition: control.composition,
      composition_cursor: control.composition_cursor,
      frame,
      caret_rect: @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y,
        width=1.0,
        height=font.size,
      ),
    }
  }
  let display_text = rich_text_with_composition(text, control, focused=true)
  let display_session = markdown_session_display_session(session, display_text)
  let visual_caret = match control.composition {
    Some(_) =>
      @core.clamp_int(
        rich_text_visual_caret(text, control, focused=true),
        0,
        text_length(display_text),
      )
    None => caret
  }
  let window = markdown_session_visible_window(
    display_session,
    { caret: visual_caret, selection: control.selection, },
    font,
    source_mode~,
    focus_mode~,
    base_dir~,
    visible_scroll_y~,
    visible_viewport_height~,
    visible_overscan~,
    content_width=rich_text_editor_content_rect(frame).size.width,
    text_system~,
  )
  let base_content = rich_text_editor_content_rect(frame)
  let content = window.content_rect(base_content)
  // The window may be clipped to the visible band, in which case a caret
  // outside that band is simply not in `window.document`. Asking the document
  // for such a caret does not come back empty — it returns a rect pinned to the
  // first rendered line, which painted the caret at the start of the block
  // instead of at its own offset. Only consult the document when it actually
  // covers the caret; otherwise let the session's height index answer, since it
  // knows every offset regardless of the window.
  let caret_in_window = markdown_session_window_covers_caret(
    window, visual_caret,
  )
  let window_caret_rect = if caret_in_window {
    rich_text_document_caret_rect_at_source(
      window.document,
      visual_caret,
      content,
      font,
      text_system~,
    )
  } else {
    None
  }
  let caret_rect = match window_caret_rect {
    Some(rect) => rect
    None =>
      markdown_session_estimated_caret_rect(
        display_session,
        visual_caret,
        base_content,
        font,
        source_mode~,
        scroll_y=window.scroll_y,
        base_dir~,
        text_system~,
      )
  }
  {
    focused: true,
    text,
    caret,
    selection: control.selection,
    composition: control.composition,
    composition_cursor: control.composition_cursor,
    frame,
    caret_rect,
  }
}

///|
fn markdown_session_estimated_caret_rect(
  session : MarkdownDocumentSession,
  source_caret : Int,
  content : @core.Rect,
  font : @core.FontSpec,
  source_mode~ : Bool,
  scroll_y~ : Double,
  base_dir~ : String?,
  text_system~ : @core.TextSystem,
) -> @core.Rect {
  let source_y = session.source_offset_y(
    source_caret,
    base=font,
    source_mode~,
    content_width=content.size.width,
  )
  let inset_x = markdown_session_estimated_caret_inset_x(
    session,
    source_caret,
    font~,
    base_dir~,
    content_width=content.size.width,
    text_system~,
  )
  @core.Rect::new(
    x=content.origin.x + inset_x,
    y=content.origin.y + source_y - scroll_y + 4.0,
    width=1.5,
    height=max_double(10.0, font.size * 1.55 - 8.0),
  )
}

///|
fn[Msg] markdown_session_editor_command(
  ctx : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  on_transaction~ : (MarkdownEditTransaction) -> Msg,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  font~ : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  intent : @core.CommandIntent,
  paste_text~ : String?,
) -> @core.ViewTextCommandResult[Msg] {
  let value = session.source()
  let on_input_edit = markdown_session_on_input_edit(session, on_transaction)
  let format_selection = match intent {
    Copy | Cut => ({ caret: -1, selection: None, } : MarkdownEditorSelection)
    _ => selection
  }
  let format = display_source => {
    if display_source == session.source() {
      session.rich_text(
        format_selection,
        base=font,
        source_mode~,
        focus_mode~,
        base_dir~,
      )
    } else if source_mode {
      markdown_editor_format_source_mode(display_source, font)
    } else {
      markdown_editor_format_for_writing_mode(
        display_source,
        format_selection,
        base=font,
        focus_mode~,
        base_dir~,
      )
    }
  }
  rich_text_editor_command(
    ctx,
    value~,
    format~,
    on_input=None,
    on_input_edit=Some(on_input_edit),
    on_selection_change~,
    input_transform=Some(
      markdown_session_input_transform_for(
        session,
        split_paragraph_on_enter=!source_mode,
      ),
    ),
    intent,
    paste_text~,
  )
}
