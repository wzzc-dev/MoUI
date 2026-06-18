///|
fn WorkbenchModel::composer(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let content : Array[@moui.View[WorkbenchMsg]] = [
    text_field(
      self.prompt,
      on_input=value => PromptChanged(value),
      on_submit=Some(DispatchPrompt),
      placeholder="给 Agent 一个任务",
      variant=Plain,
      theme~,
      width=layout.composer_input_width,
      height=42.0,
    ),
  ]
  if self.should_show_composer_request_row() {
    content.push(self.composer_request_row(layout, theme))
  }
  if self.should_show_composer_route_row() {
    content.push(self.composer_route_row(layout, theme))
  }
  if self.should_show_composer_scope_row() {
    content.push(self.composer_scope_row(layout, theme))
  }
  if self.should_show_agent_control_row() {
    content.push(self.agent_control_row(theme))
  }
  if self.should_show_composer_command_row() {
    content.push(self.composer_command_row(layout, theme))
  }
  if self.should_show_composer_action_row() {
    content.push(self.composer_action_row(theme))
  }
  container(
    column(content, spacing=6.0, align=Stretch),
    width=layout.composer_width,
    height=self.composer_height(layout),
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::composer_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  let mut height = layout.composer_height
  if self.should_show_agent_control_row() {
    height = height + 36.0
  }
  if self.should_show_composer_request_row() {
    height = height + 36.0
  }
  if self.should_show_composer_route_row() {
    height = height + 36.0
  }
  if self.should_show_composer_scope_row() {
    height = height + 36.0
  }
  if self.should_show_composer_command_row() {
    height = height + 36.0
  }
  if self.should_show_composer_action_row() {
    height = height + 42.0
  }
  height
}

///|
fn WorkbenchModel::should_show_composer_route_row(
  self : WorkbenchModel,
) -> Bool {
  self.agent_composer_route_summary().has_visible_route()
}

///|
fn WorkbenchModel::composer_route_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let summary = self.agent_composer_route_summary()
  let detail_width = workbench_max_double(
    1.0,
    layout.composer_input_width - 54.0 - 8.0,
  )
  row(
    [
      badge(
        "Agent",
        tone=agent_activity_queue_badge_tone(summary.tone),
        theme~,
        width=54.0,
      ),
      text(
        compact_label(
          summary.detail,
          max_chars=readable_line_char_limit(detail_width),
        ),
        role=Caption,
        theme~,
        width=detail_width,
        height=30.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::should_show_composer_request_row(
  self : WorkbenchModel,
) -> Bool {
  self.agent_composer_request_summary().has_visible_request()
}

///|
fn WorkbenchModel::composer_request_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let summary = self.agent_composer_request_summary()
  let action_width = if summary.action_message is Some(_) { 64.0 } else { 0.0 }
  let detail_width = workbench_max_double(
    1.0,
    layout.composer_input_width - 54.0 - action_width - 24.0,
  )
  let controls : Array[@moui.View[WorkbenchMsg]] = [
    badge(
      summary.badge_label,
      tone=agent_activity_queue_badge_tone(summary.tone),
      theme~,
      width=54.0,
    ),
    text(
      compact_label(
        summary.title + " · " + summary.detail,
        max_chars=readable_line_char_limit(detail_width),
      ),
      role=Caption,
      theme~,
      width=detail_width,
      height=30.0,
    ),
  ]
  match summary.action_message {
    Some(message) =>
      controls.push(
        button(
          summary.action_label,
          on_click=message,
          variant=Outline,
          theme~,
          width=64.0,
          height=30.0,
        ),
      )
    None => ()
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::should_show_agent_control_row(self : WorkbenchModel) -> Bool {
  self.composer_controls_expanded &&
  !self.is_composer_slash_prompt() &&
  (
    agent_backend_profiles().length() > 1 ||
    self.active_agent_backend_capabilities().supports_session_refresh ||
    self.active_agent_backend_capabilities().supports_new_session
  )
}

///|
fn WorkbenchModel::agent_control_row(
  self : WorkbenchModel,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let capabilities = self.active_agent_backend_capabilities()
  let controls : Array[@moui.View[WorkbenchMsg]] = [
    text("Agent", role=Caption, theme~, width=42.0, height=30.0),
    self.backend_selector_cell(theme),
  ]
  controls.push(spacer(min_length=8.0, weight=1.0))
  if capabilities.supports_session_refresh {
    controls.push(
      button(
        "刷新",
        on_click=RefreshSession,
        variant=Ghost,
        theme~,
        width=54.0,
        height=30.0,
      ),
    )
  }
  if capabilities.supports_new_session {
    controls.push(
      button(
        "新会话",
        on_click=NewSession,
        variant=Ghost,
        theme~,
        width=66.0,
        height=30.0,
      ),
    )
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::should_show_composer_scope_row(
  self : WorkbenchModel,
) -> Bool {
  !self.is_composer_slash_prompt() &&
  (
    self.composer_controls_expanded ||
    self.active_agent_profile() is Some(_) ||
    !self.context_is_default()
  )
}

///|
fn WorkbenchModel::context_is_default(self : WorkbenchModel) -> Bool {
  self.expanded_context.length() == 2 &&
  self.context_is_selected("repo") &&
  self.context_is_selected("examples")
}

///|
fn WorkbenchModel::composer_scope_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  ignore(layout)
  let controls : Array[@moui.View[WorkbenchMsg]] = [
    text("范围", role=Caption, theme~, width=42.0, height=30.0),
    self.context_chip("仓库", "repo", theme, width=50.0),
    self.context_chip("示例", "examples", theme, width=50.0),
    self.context_chip("证据", "evidence", theme, width=50.0),
    self.context_chip("会话", "session", theme, width=50.0),
  ]
  if self.composer_controls_expanded || self.active_agent_profile() is Some(_) {
    controls.push(spacer(min_length=8.0, weight=1.0))
    for profile in workbench_agent_profiles() {
      controls.push(
        button(
          profile.label,
          on_click=SelectAgent(profile.id),
          variant=if self.selected_agent_id == profile.id {
            Outline
          } else {
            Ghost
          },
          theme~,
          width=64.0,
          height=30.0,
        ),
      )
    }
  } else {
    controls.push(spacer(min_length=8.0, weight=1.0))
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::composer_action_row(
  self : WorkbenchModel,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let controls : Array[@moui.View[WorkbenchMsg]] = []
  if self.should_show_composer_options_toggle() {
    controls.push(
      button(
        if self.composer_controls_expanded {
          "收起"
        } else {
          "选项"
        },
        on_click=ToggleComposerControls,
        variant=Ghost,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
  }
  if self.should_show_composer_secondary_actions() {
    controls.push(
      button(
        self.steering_mode_label(),
        on_click=ToggleSteeringMode,
        variant=Outline,
        theme~,
        width=82.0,
        height=34.0,
      ),
    )
    controls.push(
      button(
        self.follow_up_mode_label(),
        on_click=ToggleFollowUpMode,
        variant=Outline,
        theme~,
        width=82.0,
        height=34.0,
      ),
    )
  }
  controls.push(spacer(min_length=10.0, weight=1.0))
  if self.has_composer_prompt() &&
    !self.is_composer_slash_prompt() &&
    self.should_show_composer_secondary_actions() {
    controls.push(
      button(
        "引导",
        on_click=DispatchSteering,
        variant=Outline,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
    controls.push(
      button(
        "跟进",
        on_click=DispatchFollowUp,
        variant=Outline,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
  }
  if self.has_composer_prompt() {
    controls.push(
      button(
        "发送",
        on_click=DispatchPrompt,
        variant=Primary,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::should_show_composer_action_row(
  self : WorkbenchModel,
) -> Bool {
  self.has_composer_prompt() ||
  self.should_show_composer_options_toggle() ||
  self.should_show_composer_secondary_actions()
}

///|
fn WorkbenchModel::should_show_composer_options_toggle(
  self : WorkbenchModel,
) -> Bool {
  !self.is_composer_slash_prompt() &&
  (self.has_composer_prompt() || self.composer_controls_expanded)
}

///|
fn WorkbenchModel::should_show_composer_secondary_actions(
  self : WorkbenchModel,
) -> Bool {
  let settings = self.active_agent_input_settings()
  !self.is_composer_slash_prompt() &&
  self.active_agent_backend_capabilities().supports_input_modes &&
  (self.composer_controls_expanded || settings.has_visible_input_modes())
}

///|
fn WorkbenchModel::has_composer_prompt(self : WorkbenchModel) -> Bool {
  self.prompt.trim().to_owned() != ""
}

///|
fn WorkbenchModel::is_composer_slash_prompt(self : WorkbenchModel) -> Bool {
  self.composer_slash_query() is Some(_)
}

///|
fn WorkbenchModel::composer_command_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let suggestions = self.composer_command_suggestions()
  let limit = workbench_min_int(suggestions.length(), 3)
  let button_width = workbench_clamp_double(
    (layout.composer_input_width - 42.0 - 16.0) / 3.0,
    96.0,
    142.0,
  )
  let controls : Array[@moui.View[WorkbenchMsg]] = [
    text("命令", role=Caption, theme~, width=42.0, height=30.0),
  ]
  for index in 0..<limit {
    let command = suggestions[index]
    controls.push(
      button(
        command.composer_label(button_width),
        on_click=InvokeCommand(command.name),
        variant=Ghost,
        theme~,
        width=button_width,
        height=30.0,
      ),
    )
  }
  controls.push(spacer(min_length=8.0, weight=1.0))
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::should_show_composer_command_row(
  self : WorkbenchModel,
) -> Bool {
  !self.composer_command_suggestions().is_empty()
}

///|
fn WorkbenchModel::composer_command_suggestions(
  self : WorkbenchModel,
) -> Array[AgentCommandInfo] {
  let suggestions : Array[AgentCommandInfo] = []
  if !self.active_agent_backend_capabilities().supports_command_catalog {
    return suggestions
  }
  match self.composer_slash_query() {
    Some(query) =>
      for command in self.active_agent_command_catalog() {
        if command.matches_composer_query(query) {
          suggestions.push(command)
        }
      }
    None => ()
  }
  suggestions
}

///|
fn WorkbenchModel::composer_slash_query(self : WorkbenchModel) -> String? {
  let clean = self.prompt.trim().to_owned()
  let chars = clean.to_array()
  if chars.length() == 0 || chars[0] != '/' {
    None
  } else {
    Some(String::from_array(chars[1:]).trim().to_owned().to_lower())
  }
}

///|
fn AgentCommandInfo::matches_composer_query(
  self : AgentCommandInfo,
  query : String,
) -> Bool {
  query == "" ||
  self.name.to_lower().contains(query) ||
  self.description.to_lower().contains(query) ||
  self.source.to_lower().contains(query)
}

///|
fn AgentCommandInfo::composer_label(
  self : AgentCommandInfo,
  width : Double,
) -> String {
  compact_label("/" + self.name, max_chars=readable_line_char_limit(width))
}

///|
fn compact_label(value : String, max_chars~ : Int) -> String {
  let chars = value.to_array()
  if chars.length() <= max_chars {
    value
  } else {
    let end = workbench_max_int(1, max_chars - 3)
    String::from_array(chars[0:end]) + "..."
  }
}

///|
fn WorkbenchModel::context_chip(
  self : WorkbenchModel,
  label : String,
  id : String,
  theme : @moui.Theme,
  width~ : Double,
) -> @moui.View[WorkbenchMsg] {
  button(
    label,
    on_click=ToggleContext(id),
    variant=if self.context_is_selected(id) { Outline } else { Ghost },
    theme~,
    width~,
    height=30.0,
  )
}

///|
fn WorkbenchModel::steering_mode_label(self : WorkbenchModel) -> String {
  "引导 " + mode_short_label(self.active_agent_input_settings().steering_mode)
}

///|
fn WorkbenchModel::follow_up_mode_label(self : WorkbenchModel) -> String {
  "跟进 " +
  mode_short_label(self.active_agent_input_settings().follow_up_mode)
}

///|
fn mode_short_label(mode : String) -> String {
  if mode == "all" {
    "全部"
  } else {
    "单条"
  }
}

///|
fn WorkbenchModel::sidebar_section_label(
  self : WorkbenchModel,
  label : String,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  ignore(self)
  text(
    label,
    role=Caption,
    theme~,
    width=layout.sidebar_inner_width,
    height=30.0,
  )
}

///|
fn main_scrollbar(
  theme : @moui.Theme,
  viewport_height~ : Double,
  content_height~ : Double,
  offset_y~ : Double,
) -> @moui.View[WorkbenchMsg] {
  let width = 12.0
  custom_layout(
    measure=_ => @moui.Size::new(width~, height=viewport_height),
    paint=frame => {
      let max_scroll = workbench_max_double(
        0.0,
        content_height - viewport_height,
      )
      if max_scroll <= 0.0 {
        return []
      }
      let track_width = 4.0
      let track = @core.Rect::new(
        x=frame.origin.x + (frame.size.width - track_width) / 2.0,
        y=frame.origin.y,
        width=track_width,
        height=frame.size.height,
      )
      let thumb_height = workbench_clamp_double(
        frame.size.height * frame.size.height / content_height,
        36.0,
        frame.size.height,
      )
      let thumb_y = frame.origin.y +
        (frame.size.height - thumb_height) *
        workbench_clamp_double(offset_y, 0.0, max_scroll) /
        max_scroll
      let thumb = @core.Rect::new(
        x=track.origin.x,
        y=thumb_y,
        width=track_width,
        height=thumb_height,
      )
      [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=track, radius=2.0),
          @core.Brush::solid(theme.palette.outline.multiply_alpha(0.18)),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=thumb, radius=2.0),
          @core.Brush::solid(theme.palette.primary.multiply_alpha(0.58)),
        ),
      ]
    },
    semantics_label="Mo Workbench main scrollbar",
  )
}
