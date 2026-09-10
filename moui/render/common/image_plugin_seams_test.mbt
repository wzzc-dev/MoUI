///|
test "image decoder plugin chain prefers plugins and falls back" {
  image_decoder_plugin_clear()
  defer image_decoder_plugin_clear()

  let fallback_calls : Ref[Int] = Ref(0)
  let fallback = @render.RendererImageDecoder::new(decode=(source, _bytes) => {
    fallback_calls.val = fallback_calls.val + 1
    @render.ImageResourceLoadCompletion::failed(source, diagnostic="no decoder")
  })

  // An empty registry must reproduce the untouched fallback behaviour.
  let chained = image_decoder_plugin_chain(fallback)
  let outcome = chained.decode("a.png", None)
  inspect(fallback_calls.val, content="1")
  assert_true(
    outcome.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )

  // A plugin that claims the source short-circuits the fallback.
  image_decoder_plugin_register(
    @render.RendererImageDecoder::new(decode=(source, _bytes) => {
      @render.ImageResourceLoadCompletion::ready(source, width=4, height=2)
    }),
  )
  inspect(image_decoder_plugin_count(), content="1")

  let chained_claimed = image_decoder_plugin_chain(fallback)
  let claimed = chained_claimed.decode("b.svg", None)
  inspect(fallback_calls.val, content="1")
  assert_true(
    claimed.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
  )
  inspect(claimed.width, content="4")
  inspect(claimed.height, content="2")

  // A plugin that declines the source lets the chain continue to the fallback.
  image_decoder_plugin_clear()
  image_decoder_plugin_register(
    @render.RendererImageDecoder::new(decode=(source, _bytes) => {
      @render.ImageResourceLoadCompletion::failed(source, diagnostic="declined")
    }),
  )
  let chained_declined = image_decoder_plugin_chain(fallback)
  let declined = chained_declined.decode("c.png", None)
  inspect(fallback_calls.val, content="2")
  assert_true(
    declined.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )
}

///|
test "image source providers match by prefix in registration order" {
  image_source_provider_clear()
  defer image_source_provider_clear()

  // An empty registry resolves nothing, leaving callers on their own path.
  guard image_source_provider_read("https://example.com/a.png") is None else {
    fail("expected an empty registry to match nothing")
  }

  image_source_provider_register(
    prefix="https://",
    read=_source => Some(b"payload"),
  )
  inspect(image_source_provider_count(), content="1")

  guard image_source_provider_read("https://example.com/a.png") is Some(bytes) else {
    fail("expected the https provider to serve the source")
  }
  inspect(bytes.length(), content="7")

  guard image_source_provider_read("file:///tmp/a.png") is None else {
    fail("expected a non-matching scheme to fall through")
  }

  // A later, more specific prefix is consulted only after the earlier match.
  image_source_provider_register(
    prefix="https://example.com/",
    read=_source => Some(b"specific"),
  )
  inspect(image_source_provider_count(), content="2")
  guard image_source_provider_read("https://example.com/a.png") is Some(bytes2) else {
    fail("expected a match")
  }
  inspect(bytes2.length(), content="7")

  // A matching provider that cannot produce bytes falls through to the next.
  image_source_provider_clear()
  image_source_provider_register(prefix="https://", read=_source => None)
  image_source_provider_register(
    prefix="https://",
    read=_source => Some(b"fallback"),
  )
  guard image_source_provider_read("https://example.com/a.png") is Some(bytes3) else {
    fail("expected the second provider to serve the source")
  }
  inspect(bytes3.length(), content="8")
}
