///|
test "image decoder plugin chain prefers plugins and falls back" {
  @common.image_decoder_plugin_clear()
  defer @common.image_decoder_plugin_clear()

  let fallback_calls : Ref[Int] = Ref(0)
  let fallback = @render.RendererImageDecoder::new(decode=(source, _bytes) => {
    fallback_calls.val = fallback_calls.val + 1
    @render.ImageResourceLoadCompletion::failed(source, diagnostic="no decoder")
  })

  // An empty registry must reproduce the untouched fallback behaviour.
  let chained = @common.image_decoder_plugin_chain(fallback)
  let outcome = chained.decode("a.png", None)
  inspect(fallback_calls.val, content="1")
  assert_true(outcome.status == ImageLoadFailed)

  // A plugin that claims the source short-circuits the fallback.
  @common.image_decoder_plugin_register(
    @render.RendererImageDecoder::new(decode=(source, _bytes) => {
      @render.ImageResourceLoadCompletion::ready(source, width=4, height=2)
    }),
  )
  inspect(@common.image_decoder_plugin_count(), content="1")

  let chained_claimed = @common.image_decoder_plugin_chain(fallback)
  let claimed = chained_claimed.decode("b.svg", None)
  inspect(fallback_calls.val, content="1")
  assert_true(claimed.status == ImageLoadReady)
  inspect(claimed.width, content="4")
  inspect(claimed.height, content="2")

  // A plugin that declines the source lets the chain continue to the fallback.
  @common.image_decoder_plugin_clear()
  @common.image_decoder_plugin_register(
    @render.RendererImageDecoder::new(decode=(source, _bytes) => {
      @render.ImageResourceLoadCompletion::failed(source, diagnostic="declined")
    }),
  )
  let chained_declined = @common.image_decoder_plugin_chain(fallback)
  let declined = chained_declined.decode("c.png", None)
  inspect(fallback_calls.val, content="2")
  assert_true(declined.status == ImageLoadFailed)
}

///|
test "image source providers match by prefix in registration order" {
  @common.image_source_provider_clear()
  defer @common.image_source_provider_clear()

  // An empty registry resolves nothing, leaving callers on their own path.
  guard @common.image_source_provider_read("https://example.com/a.png") is None else {
    fail("expected an empty registry to match nothing")
  }

  @common.image_source_provider_register(prefix="https://", read=_source => {
    Some(b"payload")
  })
  inspect(@common.image_source_provider_count(), content="1")

  guard @common.image_source_provider_read("https://example.com/a.png")
    is Some(bytes) else {
    fail("expected the https provider to serve the source")
  }
  inspect(bytes.length(), content="7")

  guard @common.image_source_provider_read("file:///tmp/a.png") is None else {
    fail("expected a non-matching scheme to fall through")
  }

  // A later, more specific prefix is consulted only after the earlier match.
  @common.image_source_provider_register(prefix="https://example.com/", read=_source => {
    Some(b"specific")
  })
  inspect(@common.image_source_provider_count(), content="2")
  guard @common.image_source_provider_read("https://example.com/a.png")
    is Some(bytes2) else {
    fail("expected a match")
  }
  inspect(bytes2.length(), content="7")

  // A matching provider that cannot produce bytes falls through to the next.
  @common.image_source_provider_clear()
  @common.image_source_provider_register(prefix="https://", read=_source => None)
  @common.image_source_provider_register(prefix="https://", read=_source => {
    Some(b"fallback")
  })
  guard @common.image_source_provider_read("https://example.com/a.png")
    is Some(bytes3) else {
    fail("expected the second provider to serve the source")
  }
  inspect(bytes3.length(), content="8")
}
