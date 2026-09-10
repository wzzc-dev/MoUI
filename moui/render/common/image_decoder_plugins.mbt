///|
/// Ordered image-decoder plugin registry.
///
/// The renderer-neutral contract carries exactly one `RendererImageDecoder`
/// per renderer session, but a host may need more than one decode strategy:
/// a backend normally decodes only the raster formats its codec library
/// understands, while a document can also reference vector formats. A plugin
/// registers the extra strategy here and the renderer composition root chains
/// it in front of its built-in decoder.
///
/// Plugins are consulted in registration order. A plugin that does not claim a
/// source returns a failed completion and the chain continues; the backend's
/// own decoder always runs last, so an empty registry reproduces the original
/// decode behaviour exactly.
let image_decoder_plugins : Ref[Array[@render.RendererImageDecoder]] = Ref([])

///|
/// Register an additional decoder. Plugins registered later are consulted
/// after those registered earlier, and always before the fallback decoder.
pub fn image_decoder_plugin_register(
  decoder : @render.RendererImageDecoder,
) -> Unit {
  image_decoder_plugins.val = image_decoder_plugins.val + [decoder]
}

///|
/// Drop every registered decoder, restoring the untouched fallback path.
pub fn image_decoder_plugin_clear() -> Unit {
  image_decoder_plugins.val = []
}

///|
/// Number of currently registered decoders, for diagnostics and tests.
pub fn image_decoder_plugin_count() -> Int {
  image_decoder_plugins.val.length()
}

///|
/// Build a decoder that tries every registered plugin, then any `builtin`
/// decoder, and finally delegates to `fallback`.
///
/// `builtin` carries decoders the framework ships with — formats the backend
/// codec library cannot handle but which need no host support. They rank below
/// app-registered plugins, so an application can still override them, and
/// above `fallback`, which stays the backend's own codec.
pub fn image_decoder_plugin_chain(
  fallback : @render.RendererImageDecoder,
  builtin? : Array[@render.RendererImageDecoder] = [],
) -> @render.RendererImageDecoder {
  @render.RendererImageDecoder::new(decode=(source, bytes) => {
    for plugin in image_decoder_plugins.val {
      let completion = plugin.decode(source, bytes)
      if completion.status ==
        @render.ImageResourceLoadCompletionStatus::ImageLoadReady {
        return completion
      }
    }
    for decoder in builtin {
      let completion = decoder.decode(source, bytes)
      if completion.status ==
        @render.ImageResourceLoadCompletionStatus::ImageLoadReady {
        return completion
      }
    }
    fallback.decode(source, bytes)
  })
}
