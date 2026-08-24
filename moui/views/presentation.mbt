///|
/// A presentation kind describes the interaction and semantic role of a
/// surface. The runtime may use this value when selecting focus and host
/// presentation behavior.
pub(all) enum PresentationKind {
  Popover
  Dialog
  Sheet
  Tooltip
  ContextMenu
} derive(Eq, Debug)

///|
/// An anchor is either a stable view key or a point in the viewport.
pub(all) enum PresentationAnchor {
  StableKey(String)
  Viewport(@core.Point)
} derive(Eq, Debug)

///|
/// Candidate placement around an anchor. Candidates are tried in order.
pub(all) enum PresentationPlacementCandidate {
  AboveStart
  AboveCenter
  AboveEnd
  BelowStart
  BelowCenter
  BelowEnd
  LeftStart
  LeftCenter
  LeftEnd
  RightStart
  RightCenter
  RightEnd
  Center
} derive(Eq, Debug)

///|
/// Placement policy shared by view-level and host presentations.
pub(all) struct PresentationPlacement {
  anchor : PresentationAnchor
  candidates : Array[PresentationPlacementCandidate]
  viewport_insets : @core.Insets
  clamp_to_viewport : Bool
} derive(Eq, Debug)

///|
/// Whether a presentation blocks background interaction and semantics.
pub(all) enum PresentationModality {
  NonModal
  Modal
} derive(Eq, Debug)

///|
/// System and pointer dismissal policy. Sending a message is intentionally
/// separate from the modal input barrier: a modal can block input without
/// being dismissible.
pub(all) struct PresentationDismissPolicy[Msg] {
  outside_tap : Bool
  escape : Bool
  system_back : Bool
  host_close : Bool
  message : Msg?
}

///|
/// Host routing preference. Unavailable native hosts must fall back to the
/// view-level surface unless `NativeRequired` is selected.
pub(all) enum PresentationHostPolicy {
  ViewOnly
  PreferNative
  NativeRequired
} derive(Eq, Debug)

///|
/// Whether this policy should issue a host request when the platform reports
/// native modal capability. A failed request must still use the view surface.
pub fn PresentationHostPolicy::requests_native(
  self : PresentationHostPolicy,
  capability_available : Bool,
) -> Bool {
  if !capability_available {
    false
  } else {
    match self {
      ViewOnly => false
      PreferNative => true
      NativeRequired => true
    }
  }
}

///|
/// Pending and rejected host requests retain the view-level surface. Only an
/// accepted request may switch the same presentation to native-only.
pub fn PresentationHostPolicy::shows_view_surface(
  self : PresentationHostPolicy,
  native_accepted : Bool,
) -> Bool {
  match self {
    ViewOnly => true
    PreferNative | NativeRequired => !native_accepted
  }
}

///|
/// Standard presentation transition. Runtime/theme motion may sample this;
/// reduced-motion hosts should complete it immediately.
pub(all) enum PresentationTransition {
  Fade
  Scale
  Slide
  None
} derive(Eq, Debug)

///|
/// Convert the presentation-level vocabulary to the shared motion primitive.
/// Runtime hosts can sample the same spec with their frame clock and reduced
/// motion preference; view-only composition uses the terminal sample.
pub fn PresentationTransition::spec(
  self : PresentationTransition,
) -> @core.TransitionSpec {
  match self {
    Fade => @core.TransitionSpec::fade()
    Scale => @core.TransitionSpec::scale(from_scale=0.96)
    Slide =>
      @core.TransitionSpec::slide(from_offset=@core.Point::new(x=0.0, y=12.0))
    None => @core.TransitionSpec::new()
  }
}

///|
/// A TEA-owned presentation declaration. The list passed to `overlay_host`
/// is ordered from back to front; dismiss and input always operate from the
/// front-most entry.
pub struct PresentationSpec[Msg] {
  id : String
  kind : PresentationKind
  anchor : PresentationAnchor
  placement : PresentationPlacement
  content : @core.View[Msg]
  modality : PresentationModality
  dismiss : PresentationDismissPolicy[Msg]
  host_policy : PresentationHostPolicy
  transition : PresentationTransition
  presented : Bool
}

///|
/// Construct a presentation declaration. App model state owns `presented` and
/// the content; runtime/host state is deliberately not stored here.
pub fn[Msg] PresentationSpec::new(
  id~ : String,
  kind~ : PresentationKind,
  content~ : @core.View[Msg],
  anchor? : PresentationAnchor = PresentationAnchor::Viewport(
    @core.Point::new(x=0.0, y=0.0),
  ),
  placement? : PresentationPlacement? = None,
  modality? : PresentationModality = PresentationModality::NonModal,
  dismiss? : PresentationDismissPolicy[Msg] = PresentationDismissPolicy::none(),
  host_policy? : PresentationHostPolicy = PresentationHostPolicy::ViewOnly,
  transition? : PresentationTransition = PresentationTransition::Fade,
  presented? : Bool = true,
) -> PresentationSpec[Msg] {
  let resolved_placement = placement.unwrap_or(
    PresentationPlacement::at(anchor),
  )
  {
    id,
    kind,
    anchor,
    placement: resolved_placement,
    content,
    modality,
    dismiss,
    host_policy,
    transition,
    presented,
  }
}

///|
/// Return a non-dismissible policy. This is useful for modal progress and
/// authentication surfaces that must block input until the app closes them.
pub fn[Msg] PresentationDismissPolicy::none() -> PresentationDismissPolicy[Msg] {
  {
    outside_tap: false,
    escape: false,
    system_back: false,
    host_close: false,
    message: None,
  }
}

///|
/// Construct a policy with independent outside/Escape/Back/host switches.
pub fn[Msg] PresentationDismissPolicy::new(
  outside_tap? : Bool = false,
  escape? : Bool = true,
  system_back? : Bool = true,
  host_close? : Bool = true,
  message? : Msg? = None,
) -> PresentationDismissPolicy[Msg] {
  { outside_tap, escape, system_back, host_close, message }
}

///|
pub fn PresentationPlacement::at(
  anchor : PresentationAnchor,
) -> PresentationPlacement {
  {
    anchor,
    candidates: [PresentationPlacementCandidate::BelowStart],
    viewport_insets: @core.Insets::all(8.0),
    clamp_to_viewport: true,
  }
}

///|
pub fn PresentationPlacement::new(
  anchor~ : PresentationAnchor,
  candidates? : Array[PresentationPlacementCandidate] = [
    PresentationPlacementCandidate::BelowStart,
  ],
  viewport_insets? : @core.Insets = @core.Insets::all(8.0),
  clamp_to_viewport? : Bool = true,
) -> PresentationPlacement {
  { anchor, candidates: candidates.copy(), viewport_insets, clamp_to_viewport }
}

///|
pub fn PresentationPlacement::viewport(
  candidates? : Array[PresentationPlacementCandidate] = [
    PresentationPlacementCandidate::Center,
  ],
  viewport_insets? : @core.Insets = @core.Insets::all(8.0),
) -> PresentationPlacement {
  PresentationPlacement::new(
    anchor=PresentationAnchor::Viewport(@core.Point::new(x=0.0, y=0.0)),
    candidates~,
    viewport_insets~,
  )
}

///|
/// Resolve a placement from an anchor frame and viewport. Candidates are
/// attempted in declaration order; when none fit, the first candidate is
/// clamped to the inset viewport.
pub fn PresentationPlacement::resolve(
  self : PresentationPlacement,
  anchor_frame : @core.Rect,
  viewport : @core.Rect,
  content_size : @core.Size,
) -> @core.Rect {
  let available = @core.Rect::new(
    x=viewport.origin.x + self.viewport_insets.left,
    y=viewport.origin.y + self.viewport_insets.top,
    width=@common.view_max_double(
      0.0,
      viewport.size.width -
      self.viewport_insets.left -
      self.viewport_insets.right,
    ),
    height=@common.view_max_double(
      0.0,
      viewport.size.height -
      self.viewport_insets.top -
      self.viewport_insets.bottom,
    ),
  )
  let mut first = @core.Rect::new(
    x=available.origin.x,
    y=available.origin.y,
    width=content_size.width,
    height=content_size.height,
  )
  for candidate in self.candidates {
    let proposed = presentation_candidate_rect(
      candidate, anchor_frame, content_size,
    )
    if first.origin.x == available.origin.x &&
      first.origin.y == available.origin.y {
      first = proposed
    }
    if available.contains(
        @core.Point::new(x=proposed.origin.x, y=proposed.origin.y),
      ) &&
      proposed.max_x() <= available.max_x() &&
      proposed.max_y() <= available.max_y() {
      return proposed
    }
  }
  if self.clamp_to_viewport {
    clamp_presentation_rect(first, available)
  } else {
    first
  }
}

///|
fn presentation_candidate_rect(
  candidate : PresentationPlacementCandidate,
  anchor : @core.Rect,
  size : @core.Size,
) -> @core.Rect {
  let x = match candidate {
    AboveStart | BelowStart | LeftStart | RightStart => anchor.origin.x
    AboveCenter | BelowCenter | LeftCenter | RightCenter | Center =>
      anchor.origin.x + (anchor.size.width - size.width) / 2.0
    AboveEnd | BelowEnd | LeftEnd | RightEnd => anchor.max_x() - size.width
  }
  let y = match candidate {
    AboveStart | AboveCenter | AboveEnd => anchor.origin.y - size.height
    BelowStart | BelowCenter | BelowEnd => anchor.max_y()
    LeftStart | LeftCenter | LeftEnd => anchor.origin.y
    RightStart | RightCenter | RightEnd => anchor.origin.y
    Center => anchor.origin.y + (anchor.size.height - size.height) / 2.0
  }
  let adjusted_x = match candidate {
    LeftStart | LeftCenter | LeftEnd => anchor.origin.x - size.width
    RightStart | RightCenter | RightEnd => anchor.max_x()
    _ => x
  }
  @core.Rect::new(x=adjusted_x, y~, width=size.width, height=size.height)
}

///|
fn clamp_presentation_rect(
  rect : @core.Rect,
  bounds : @core.Rect,
) -> @core.Rect {
  let max_x = bounds.max_x() - rect.size.width
  let max_y = bounds.max_y() - rect.size.height
  @core.Rect::new(
    x=rect.origin.x.clamp(
      min=bounds.origin.x,
      max=@common.view_max_double(bounds.origin.x, max_x),
    ),
    y=rect.origin.y.clamp(
      min=bounds.origin.y,
      max=@common.view_max_double(bounds.origin.y, max_y),
    ),
    width=@common.view_min_double(rect.size.width, bounds.size.width),
    height=@common.view_min_double(rect.size.height, bounds.size.height),
  )
}

///|
pub fn PresentationAnchor::stable_key(key : String) -> PresentationAnchor {
  PresentationAnchor::StableKey(key)
}

///|
pub fn PresentationAnchor::viewport_point(
  point : @core.Point,
) -> PresentationAnchor {
  PresentationAnchor::Viewport(point)
}

///|
pub fn[Msg] PresentationSpec::id(self : PresentationSpec[Msg]) -> String {
  self.id
}

///|
pub fn[Msg] PresentationSpec::kind(
  self : PresentationSpec[Msg],
) -> PresentationKind {
  self.kind
}

///|
pub fn[Msg] PresentationSpec::anchor(
  self : PresentationSpec[Msg],
) -> PresentationAnchor {
  self.anchor
}

///|
pub fn[Msg] PresentationSpec::placement(
  self : PresentationSpec[Msg],
) -> PresentationPlacement {
  self.placement
}

///|
pub fn[Msg] PresentationSpec::content(
  self : PresentationSpec[Msg],
) -> @core.View[Msg] {
  self.content
}

///|
pub fn[Msg] PresentationSpec::modality(
  self : PresentationSpec[Msg],
) -> PresentationModality {
  self.modality
}

///|
pub fn[Msg] PresentationSpec::dismiss_policy(
  self : PresentationSpec[Msg],
) -> PresentationDismissPolicy[Msg] {
  self.dismiss
}

///|
pub fn[Msg] PresentationSpec::host_policy(
  self : PresentationSpec[Msg],
) -> PresentationHostPolicy {
  self.host_policy
}

///|
pub fn[Msg] PresentationSpec::transition(
  self : PresentationSpec[Msg],
) -> PresentationTransition {
  self.transition
}

///|
pub fn[Msg] PresentationSpec::presented(self : PresentationSpec[Msg]) -> Bool {
  self.presented
}

///|
pub fn[Msg] PresentationDismissPolicy::allows_outside_tap(
  self : PresentationDismissPolicy[Msg],
) -> Bool {
  self.outside_tap
}

///|
pub fn[Msg] PresentationDismissPolicy::allows_escape(
  self : PresentationDismissPolicy[Msg],
) -> Bool {
  self.escape
}

///|
pub fn[Msg] PresentationDismissPolicy::allows_system_back(
  self : PresentationDismissPolicy[Msg],
) -> Bool {
  self.system_back
}

///|
pub fn[Msg] PresentationDismissPolicy::allows_host_close(
  self : PresentationDismissPolicy[Msg],
) -> Bool {
  self.host_close
}

///|
pub fn[Msg] PresentationDismissPolicy::message(
  self : PresentationDismissPolicy[Msg],
) -> Msg? {
  self.message
}

///|
/// The sole composition entrypoint for app presentations. The order of
/// `presentations` is preserved and the last active presentation is painted
/// top-most. Inactive entries do not add layout or hit-test children.
pub fn[Msg] overlay_host(
  base : @core.View[Msg],
  presentations : Array[PresentationSpec[Msg]],
) -> @core.View[Msg] {
  let deepest_modal = deepest_modal_index(presentations)
  let base_child = if deepest_modal >= 0 { base.hide_semantics() } else { base }
  let children : Array[@core.View[Msg]] = [base_child]
  for index, presentation in presentations {
    if presentation.presented {
      if presentation.modality is PresentationModality::Modal {
        children.push(presentation_barrier(presentation))
      }
      children.push(
        presentation_surface(
          presentation,
          visible_semantics=deepest_modal < 0 || index >= deepest_modal,
        ),
      )
    }
  }
  @core.View::from_node(
    OverlayHostNode::{ presentations: presentations.copy() },
    children=_node => children,
    event=(node, context) => node.event_result(context),
  )
}

///|
fn[Msg] deepest_modal_index(
  presentations : Array[PresentationSpec[Msg]],
) -> Int {
  let mut result = -1
  for index, presentation in presentations {
    if presentation.presented &&
      presentation.modality is PresentationModality::Modal {
      result = index
    }
  }
  result
}

///|
priv struct OverlayHostNode[Msg] {
  presentations : Array[PresentationSpec[Msg]]
}

///|
impl[Msg] @core.ViewNode for OverlayHostNode[Msg] with fn identity(_self) {
  @core.ViewIdentity::new(kind="OverlayHost")
}

///|
impl[Msg] @core.ViewNode for OverlayHostNode[Msg] with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl[Msg] @core.ViewNode for OverlayHostNode[Msg] with fn layout(self, ctx) {
  let viewport = ctx.constraints.constrain(ctx.constraints.max)
  let viewport_rect = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=viewport.width,
    height=viewport.height,
  )
  let frames : Array[@core.Rect] = [
    @core.Rect::new(x=0.0, y=0.0, width=viewport.width, height=viewport.height),
  ]
  let mut child_index = 1
  for presentation in self.presentations {
    if presentation.presented {
      if presentation.modality is PresentationModality::Modal {
        frames.push(
          @core.Rect::new(
            x=0.0,
            y=0.0,
            width=viewport.width,
            height=viewport.height,
          ),
        )
        child_index = child_index + 1
      }
      let measured = if child_index < ctx.child_sizes.length() {
        ctx.child_sizes[child_index]
      } else {
        @core.Size::new(width=0.0, height=0.0)
      }
      let anchor_frame = presentation_anchor_frame(
        presentation.anchor,
        viewport_rect,
        ctx.anchor_frames,
      )
      let frame = match presentation.kind {
        PresentationKind::Dialog =>
          @core.Rect::new(
            x=(viewport.width - measured.width) / 2.0,
            y=(viewport.height - measured.height) / 2.0,
            width=measured.width,
            height=measured.height,
          )
        PresentationKind::Sheet =>
          @core.Rect::new(
            x=(viewport.width - measured.width) / 2.0,
            y=viewport.height - measured.height,
            width=measured.width,
            height=measured.height,
          )
        _ =>
          presentation.placement.resolve(anchor_frame, viewport_rect, measured)
      }
      frames.push(frame)
      child_index = child_index + 1
    }
  }
  @core.ViewLayoutResult::new(size=viewport, child_frames=frames)
}

///|
impl[Msg] @core.ViewNode for OverlayHostNode[Msg] with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
fn presentation_anchor_frame(
  anchor : PresentationAnchor,
  viewport : @core.Rect,
  anchor_frames : Array[(String, @core.Rect)],
) -> @core.Rect {
  match anchor {
    PresentationAnchor::Viewport(point) =>
      @core.Rect::new(x=point.x, y=point.y, width=0.0, height=0.0)
    PresentationAnchor::StableKey(key) => {
      for entry in anchor_frames {
        if entry.0 == key {
          return entry.1
        }
      }
      // The first layout has no completed anchor snapshot yet. Keep the
      // existing deterministic fallback and converge on the next pass.
      @core.Rect::new(
        x=viewport.origin.x + viewport.size.width / 2.0,
        y=viewport.origin.y + viewport.size.height / 2.0,
        width=0.0,
        height=0.0,
      )
    }
  }
}

///|
fn[Msg] OverlayHostNode::event_result(
  self : OverlayHostNode[Msg],
  context : @core.ViewEventContext,
) -> @core.ViewEventResult[Msg] {
  match context.event {
    @core.AppEvent::Keyboard(event) =>
      if event.pressed &&
        (
          event.key == "Escape" ||
          event.key == "Back" ||
          event.key == "HostClose"
        ) {
        let mut index = self.presentations.length() - 1
        while index >= 0 {
          let presentation = self.presentations[index]
          let allowed = if event.key == "Escape" {
            presentation.dismiss.escape
          } else if event.key == "Back" {
            presentation.dismiss.system_back
          } else {
            presentation.dismiss.host_close
          }
          if presentation.presented && allowed {
            match presentation.dismiss.message {
              Some(message) => return @core.ViewEventResult::message(message)
              None =>
                return {
                  ..@core.ViewEventResult::ignored(),
                  changed: true,
                  captured: true,
                }
            }
          }
          index = index - 1
        }
        @core.ViewEventResult::ignored()
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] presentation_barrier(
  presentation : PresentationSpec[Msg],
) -> @core.View[Msg] {
  @core.View::from_node(
    PresentationBarrier::{
      id: presentation.id,
      message: if presentation.dismiss.outside_tap {
        presentation.dismiss.message
      } else {
        None
      },
    },
    event=(node, context) => {
      match context.event {
        @core.AppEvent::Pointer(event) =>
          if event.phase == @core.PointerPhase::Down {
            match node.message {
              Some(message) => @core.ViewEventResult::message(message)
              None =>
                {
                  ..@core.ViewEventResult::ignored(),
                  changed: true,
                  captured: true,
                  dirty: @core.ViewDirtyHint::ViewPaintDirty,
                }
            }
          } else {
            // A modal barrier consumes every pointer phase, even when it has no
            // dismiss message, so background content cannot observe the event.
            {
              ..@core.ViewEventResult::ignored(),
              changed: true,
              captured: true,
            }
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
fn[Msg] presentation_surface(
  presentation : PresentationSpec[Msg],
  visible_semantics~ : Bool,
) -> @core.View[Msg] {
  let mut content = presentation.content
  match presentation.kind {
    PresentationKind::Dialog | PresentationKind::Sheet =>
      content = content
        .semantics_role(@core.SemanticsRole::Dialog)
        .semantics_state(
          modal=presentation.modality is PresentationModality::Modal,
        )
        .focus_trap()
    _ => ()
  }
  match presentation.transition {
    PresentationTransition::None => ()
    _ =>
      content = content.transition(
        spec=presentation.transition.spec(),
        progress=1.0,
      )
  }
  if !visible_semantics {
    content = content.hide_semantics()
  }
  @core.View::from_node(
    PresentationSurfaceGuard::{
      id: presentation.id,
      dismiss: presentation.dismiss.message,
    },
    children=_node => [content],
    event=(node, context) => node.event_result(context),
    semantics_actions=node => {
      match node.dismiss {
        Some(message) =>
          [
            @core.ViewSemanticsActionHandler::dismiss(_ctx => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          ]
        None => []
      }
    },
  )
}

///|
priv struct PresentationSurfaceGuard[Msg] {
  id : String
  dismiss : Msg?
}

///|
impl[Msg] @core.ViewNode for PresentationSurfaceGuard[Msg] with fn identity(
  self,
) {
  @core.ViewIdentity::new(kind="PresentationSurface", key=Some(self.id))
}

///|
impl[Msg] @core.ViewNode for PresentationSurfaceGuard[Msg] with fn declaration(
  _self,
) {
  @core.ViewDeclaration::constant()
}

///|
impl[Msg] @core.ViewNode for PresentationSurfaceGuard[Msg] with fn layout(
  _self,
  ctx,
) {
  let child_size = match ctx.child_sizes.get(0) {
    Some(size) => size
    None => @core.Size::new(width=0.0, height=0.0)
  }
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(child_size), child_frames=[
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=child_size.width,
      height=child_size.height,
    ),
  ])
}

///|
impl[Msg] @core.ViewNode for PresentationSurfaceGuard[Msg] with fn semantics(
  _self,
) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
fn[Msg] PresentationSurfaceGuard::event_result(
  _self : PresentationSurfaceGuard[Msg],
  context : @core.ViewEventContext,
) -> @core.ViewEventResult[Msg] {
  match context.event {
    @core.AppEvent::Pointer(event) =>
      if context.frame.contains(event.position) {
        { ..@core.ViewEventResult::ignored(), changed: true, captured: true }
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
priv struct PresentationBarrier[Msg] {
  id : String
  message : Msg?
}

///|
impl[Msg] @core.ViewNode for PresentationBarrier[Msg] with fn identity(self) {
  @core.ViewIdentity::new(kind="PresentationBarrier", key=Some(self.id))
}

///|
impl[Msg] @core.ViewNode for PresentationBarrier[Msg] with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl[Msg] @core.ViewNode for PresentationBarrier[Msg] with fn layout(_self, ctx) {
  let size = ctx.constraints.constrain(ctx.constraints.max)
  @core.ViewLayoutResult::new(size~)
}

///|
impl[Msg] @core.ViewNode for PresentationBarrier[Msg] with fn paint(_self, _ctx) {
  {
    ..@core.ViewPaintPlan::empty(),
    commands: [
      @core.DrawCommand::FillRect(
        _ctx.frame,
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.22),
      ),
    ],
    overlay_commands: [
      @core.DrawCommand::FillRect(
        _ctx.frame,
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      ),
    ],
  }
}

///|
impl[Msg] @core.ViewNode for PresentationBarrier[Msg] with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(composition=@core.SemanticsComposition::Hidden)
}
