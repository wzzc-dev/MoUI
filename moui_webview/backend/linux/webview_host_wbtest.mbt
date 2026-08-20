///|
/// Linux keeps a small host-contract suite so the platform package exercises
/// the shared controller/bridge state machine without requiring WebKitGTK.
test "linux webview fallback reports unavailable without WebKitGTK" {
  let capabilities = linux_webview_capabilities()
  if linux_webview_native_available() == 0 {
    inspect(capabilities.available, content="false")
    inspect(capabilities.native_embedding, content="false")
    assert_true(capabilities.description.contains("libwebkit2gtk-4.1-dev"))
  } else {
    inspect(capabilities.available, content="true")
    inspect(capabilities.commands, content="true")
    inspect(capabilities.messaging, content="true")
  }
}

///|
test "linux webview placement contains appearance only" {
  let spec = @host.WebViewSpec::new(id="main", title="Example")
  let placement = spec.platform_view_placement(
    frame=@core.Rect::new(x=12.0, y=24.0, width=320.0, height=180.0),
  )
  assert_true(placement.property_or("url", "").is_empty())
  assert_true(placement.property_or("policy", "").is_empty())
  let frame = linux_webview_platform_frame(placement, 32.0)
  inspect(frame.origin.x, content="12")
  inspect(frame.origin.y, content="56")
  inspect(frame.size.width, content="320")
  inspect(frame.size.height, content="180")
}

///|
test "linux webview controller commands preserve FIFO and navigation ids" {
  let host = @host.WebViewHost::new()
  let origin = @host.WebViewOrigin::parse("https://example.test")
  let security = @host.WebViewSecurityPolicy::new(
    allowed_origins=match origin {
      Some(value) => [value]
      None => []
    },
    allowed_channels=[@host.WebViewChannelPolicy::new(name="probe")],
  )
  let controller = match
    host.create_controller(
      id="main",
      config=@host.WebViewControllerConfig::new(security~),
    ) {
    Ok(value) => value
    Err(_) => fail("controller creation failed")
  }
  let _ = controller.navigate("https://example.test").start(_ => ())
  let commands : Array[(Int, UInt64, UInt64, String)] = []
  let drained = host.drain_commands(command => {
    commands.push(@host.webview_encode_native_command(command))
  })
  inspect(drained, content="1")
  inspect(commands[0].0, content="0")
  inspect(commands[0].3, content="https://example.test")
  assert_true(commands[0].1 > 0UL)
  assert_true(commands[0].2 > 0UL)
}

///|
test "linux webview bridge rejects unsupported versions" {
  let result = @host.WebViewBridgeEnvelope::parse(
    "{\"schemaVersion\":2,\"kind\":\"hello\",\"navigationId\":\"1\"}",
  )
  match result {
    Err(error) => inspect(error.code, content="unsupported-version")
    Ok(_) => fail("unsupported bridge version was accepted")
  }
}

///|
test "linux webview configuration updates the registered controller" {
  let host = @host.WebViewHost::new()
  let origin = @host.WebViewOrigin::parse("https://example.test").unwrap()
  let controller = host
    .create_controller(
      id="configured",
      config=@host.WebViewControllerConfig::new(
        security=@host.WebViewSecurityPolicy::new(allowed_origins=[origin]),
      ),
    )
    .unwrap()
  let _ = controller
    .configure(
      @host.WebViewControllerConfig::new(
        security=@host.WebViewSecurityPolicy::new(allowed_origins=[origin]),
        capabilities=["bridge-v1"],
      ),
    )
    .start(_ => ())
  let config = host.native_config("configured").unwrap()
  assert_true(config.document_start_script.contains("mouiBridge"))
  assert_true(config.revision > 1UL)
}

///|
test "linux webview rejects a host patch outside the security origin set" {
  let origin = @host.WebViewOrigin::parse("https://example.test").unwrap()
  let other = @host.WebViewOrigin::parse("https://other.test").unwrap()
  let patch = @host.HostPatchBundle::new(id="invalid", version="1", allowed_origins=[
    other,
  ])
  let result = @host.WebViewHost::new().create_controller(
    id="main",
    config=@host.WebViewControllerConfig::new(
      security=@host.WebViewSecurityPolicy::new(allowed_origins=[origin]),
      host_patches=[patch],
    ),
  )
  match result {
    Err(error) => inspect(error.code, content="host-patch-origin-denied")
    Ok(_) => fail("out-of-policy HostPatch was accepted")
  }
}
