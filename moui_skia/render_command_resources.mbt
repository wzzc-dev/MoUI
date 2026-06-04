///|
priv struct RenderCommandResourceCounts {
  image_resource_count : Int
  shader_resource_count : Int
  filter_resource_count : Int
  path_resource_count : Int
  text_resource_count : Int
}

///|
fn RenderCommand::resource_counts(
  self : RenderCommand,
) -> RenderCommandResourceCounts {
  let mut image_resource_count = 0
  let mut shader_resource_count = 0
  let mut filter_resource_count = 0
  let mut path_resource_count = 0
  let mut text_resource_count = 0
  for descriptor in self.resource_descriptors() {
    match descriptor.key.kind {
      ImageResource => image_resource_count += 1
      ShaderResource => shader_resource_count += 1
      PathResource => path_resource_count += 1
      ColorFilterResource | ImageFilterResource | MaskFilterResource =>
        filter_resource_count += 1
      TypefaceResource | FontResource | TextRunResource =>
        text_resource_count += 1
      _ => ()
    }
  }
  {
    image_resource_count,
    shader_resource_count,
    filter_resource_count,
    path_resource_count,
    text_resource_count,
  }
}

///|
pub fn RenderCommand::resource_count_for_kind(
  self : RenderCommand,
  kind : RendererResourceKind,
) -> Int {
  let mut count = 0
  for descriptor in self.resource_descriptors() {
    if descriptor.key.kind == kind {
      count += 1
    }
  }
  count
}

///|
pub fn RenderCommand::filter_resource_count(self : RenderCommand) -> Int {
  self.resource_counts().filter_resource_count
}

///|
pub fn RenderCommand::text_resource_count(self : RenderCommand) -> Int {
  self.resource_counts().text_resource_count
}

///|
pub fn RenderCommand::text_run_resource_key(
  self : RenderCommand,
) -> RendererResourceKey? {
  match self {
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      Some(descriptor.resource_key(text, font_key~))
    DrawCanvasShapedGlyphRunUtf8(text, glyph_run, _, _) =>
      Some(glyph_run.resource_key(text))
    _ => None
  }
}

///|
pub fn RenderCommand::resource_descriptor(
  self : RenderCommand,
) -> RendererResourceDescriptor? {
  match self {
    DrawCanvasPath(path, _) => Some(path.resource_descriptor())
    ClipCanvasPath(path, _) => Some(path.resource_descriptor())
    DrawCanvasPaintShader(shader, _) => Some(shader.resource_descriptor())
    DrawCanvasRectShader(_, shader, _) => Some(shader.resource_descriptor())
    DrawCanvasRoundRectShader(_, _, _, shader, _) =>
      Some(shader.resource_descriptor())
    DrawCanvasImage(image, _) => Some(image.resource_descriptor())
    DrawCanvasImageRect(image, _, _, _, _) => Some(image.resource_descriptor())
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      Some(descriptor.resource_descriptor(text, font_key~))
    DrawCanvasShapedGlyphRunUtf8(text, glyph_run, _, _) =>
      Some(glyph_run.resource_descriptor(text))
    DeclareRenderResource(descriptor) => Some(descriptor)
    _ => None
  }
}

///|
pub fn RenderCommand::resource_descriptors(
  self : RenderCommand,
) -> Array[RendererResourceDescriptor] {
  match self {
    SaveCanvasLayer(_, _, color_filter, image_filter, mask_filter) =>
      render_filter_resource_descriptors(
        color_filter, image_filter, mask_filter,
      )
    ClipCanvasPath(path, _) => [path.resource_descriptor()]
    DrawCanvasPaintShader(shader, _) => [shader.resource_descriptor()]
    DrawCanvasPath(path, _) => [path.resource_descriptor()]
    DrawCanvasRectShader(_, shader, _) => [shader.resource_descriptor()]
    DrawCanvasRoundRectShader(_, _, _, shader, _) =>
      [shader.resource_descriptor()]
    DrawCanvasPathShader(path, shader, _) =>
      [path.resource_descriptor(), shader.resource_descriptor()]
    DrawCanvasImage(image, _) => [image.resource_descriptor()]
    DrawCanvasImageRect(image, _, _, _, _) => [image.resource_descriptor()]
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      descriptor.resource_plan(text, font_key~).descriptors
    DrawCanvasShapedGlyphRunUtf8(text, glyph_run, _, _) =>
      glyph_run.resource_plan(text).descriptors
    DeclareRenderResource(descriptor) => [descriptor]
    _ => []
  }
}

///|
fn render_filter_resource_descriptors(
  color_filter : ColorFilterDescriptor?,
  image_filter : ImageFilterDescriptor?,
  mask_filter : MaskFilterDescriptor?,
) -> Array[RendererResourceDescriptor] {
  let descriptors : Array[RendererResourceDescriptor] = []
  match color_filter {
    None => ()
    Some(descriptor) => descriptors.push(descriptor.resource_descriptor())
  }
  match image_filter {
    None => ()
    Some(descriptor) => descriptors.push(descriptor.resource_descriptor())
  }
  match mask_filter {
    None => ()
    Some(descriptor) => descriptors.push(descriptor.resource_descriptor())
  }
  descriptors
}

///|
pub fn RenderCommandList::text_run_resource_keys(
  self : RenderCommandList,
) -> Array[RendererResourceKey] {
  let keys : Array[RendererResourceKey] = Array::new()
  for command in self.commands {
    match command.text_run_resource_key() {
      None => ()
      Some(key) => keys.push(key)
    }
  }
  keys
}

///|
fn renderer_resource_descriptor_list_contains_key(
  descriptors : Array[RendererResourceDescriptor],
  key : RendererResourceKey,
) -> Bool {
  let mut found = false
  for descriptor in descriptors {
    if descriptor.key == key {
      found = true
    }
  }
  found
}

///|
pub fn RenderCommandList::resource_descriptors(
  self : RenderCommandList,
) -> Array[RendererResourceDescriptor] {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  let target_descriptor = self.pass.resource_descriptor()
  if !target_descriptor.key.is_empty() {
    descriptors.push(target_descriptor)
  }
  for command in self.commands {
    for descriptor in command.resource_descriptors() {
      if !descriptor.key.is_empty() &&
        !renderer_resource_descriptor_list_contains_key(
          descriptors,
          descriptor.key,
        ) {
        descriptors.push(descriptor)
      }
    }
  }
  descriptors
}

///|
pub fn RenderCommandList::resource_plan(
  self : RenderCommandList,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.resource_descriptors())
}
