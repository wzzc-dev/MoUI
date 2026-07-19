///|
fn test_runtime_callbacks(
  configured : Ref[Int],
  destroyed : Ref[Int],
) -> EmbeddingRuntimeCallbacks {
  EmbeddingRuntimeCallbacks::new(
    renderer_configure=_ => {
      configured.val = configured.val + 1
      true
    },
    renderer_status_json=() => "{\"runtime\":true}",
    take_host_updates_json=() => "[]",
    take_host_update_envelope_json=() => {
      "{\"schemaVersion\":1,\"sessionGeneration\":1,\"updates\":[]}"
    },
    dispatch_host_response_envelope_json=_ => true,
    dispatch_text_input=(_, _, _, _) => true,
    dispatch_command=_ => true,
    dispatch_accessibility=(_, _, _) => true,
    complete_clipboard=(_, _, _, _) => true,
    complete_clipboard_v1=(_, _, _, _, _) => true,
    attach_surface=(_, _, _, _) => true,
    resize=(_, _, _) => true,
    dispatch_pointer=(_, _, _, _) => true,
    dispatch_scroll=(_, _, _, _, _) => true,
    frame_tick=_ => true,
    render_frame=() => true,
    detach_surface=() => (),
    destroy_application=() => destroyed.val = destroyed.val + 1,
  )
}

///|
test "shell-owned ABI dispatch rejects uninstalled calls and replaces callbacks" {
  moui_embedding_destroy_application()
  assert_false(runtime_installed())
  assert_false(moui_embedding_renderer_configure("auto"))
  inspect(moui_embedding_renderer_status_json(), content="{}")

  let first_configured = Ref(0)
  let first_destroyed = Ref(0)
  install_runtime(test_runtime_callbacks(first_configured, first_destroyed))
  assert_true(runtime_installed())
  assert_true(moui_embedding_renderer_configure("auto"))
  inspect(first_configured.val, content="1")
  assert_true(moui_embedding_attach_surface(1UL, 100, 80, 2.0))

  let second_configured = Ref(0)
  let second_destroyed = Ref(0)
  install_runtime(test_runtime_callbacks(second_configured, second_destroyed))
  inspect(first_destroyed.val, content="1")
  assert_true(moui_embedding_renderer_configure("skia-raster"))
  inspect(second_configured.val, content="1")
  moui_embedding_destroy_application()
  inspect(second_destroyed.val, content="1")
  assert_false(runtime_installed())
}
