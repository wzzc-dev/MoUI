///|
/// Optional host-side overrides for platform-owned state that lives outside
/// the MoUI runtime tree.
///
/// A dev-hot bridge keeps the app `Program` in a reloadable plugin image, so
/// the host runtime it drives has no app view tree of its own. These hooks let
/// the bridge supply committed semantics, text-input state, semantics-action
/// dispatch, and plugin-owned frame fields decoded from the plugin's frame
/// instead of reading the (empty) host runtime.
pub(all) struct HostDriverHooks {
  /// Serve `AppRuntime::read_semantics` from host state. `None` keeps the
  /// runtime-owned stream.
  read_semantics : ((@core.SemanticsGeneration?) -> Result[
    SemanticsRead,
    SemanticsReadError,
  ])?
  /// Route a semantics action to the app that owns the tree. `None` keeps
  /// runtime-owned dispatch.
  perform_semantics_action : ((PerformSemanticsActionRequest) -> Result[
    SemanticsActionReceipt,
    SemanticsActionDispatchError,
  ])?
  /// The focused text input the host should project to the platform IME.
  /// `None` keeps `AppRuntime::focused_text_input`.
  focused_text_input : (() -> @core.TextInputState)?
  /// Rewrite the frame the host runtime just painted. A bridge host uses this
  /// to carry plugin-owned fields (clear color, platform views, overlay
  /// bounds, committed semantics) onto the frame presented by the host.
  augment_frame : ((@core.DrawFrame) -> @core.DrawFrame)?
}

///|
/// Build hooks from only the channels a bridge host overrides. Unset channels
/// stay absent so the driver falls back to the runtime-owned path instead of
/// returning a default that silently drops state.
pub fn HostDriverHooks::new(
  read_semantics~ : ((@core.SemanticsGeneration?) -> Result[
    SemanticsRead,
    SemanticsReadError,
  ])?,
  perform_semantics_action~ : ((PerformSemanticsActionRequest) -> Result[
    SemanticsActionReceipt,
    SemanticsActionDispatchError,
  ])?,
  focused_text_input~ : (() -> @core.TextInputState)?,
  augment_frame~ : ((@core.DrawFrame) -> @core.DrawFrame)?,
) -> HostDriverHooks {
  {
    read_semantics,
    perform_semantics_action,
    focused_text_input,
    augment_frame,
  }
}
