///|
test "macos startup surface size preserves runtime logical dimensions" {
  let size = runtime_size_to_window_surface_size(
    @core.Size::new(width=800.0, height=600.0),
  )
  assert_eq(size.to_logical(2.0), @dpi.LogicalSize::LogicalSize(800.0, 600.0))
  assert_eq(size.to_physical(2.0), @dpi.PhysicalSize::PhysicalSize(1600, 1200))
}

///|
test "macos menu command payload records utf8 byte lengths" {
  let encoded = @utf8.decode_lossy(
    encode_menu_commands([
      @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Paste,
        label="粘贴",
        enabled=false,
      ),
    ])[:],
    ignore_bom=false,
  )
  inspect(encoded, content="1:4:Copy\n0:6:粘贴")
}
