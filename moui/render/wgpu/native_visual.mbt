///|
priv enum NativeDrawItem {
  NativeVisual(Int, Int, NativeScissor?)
  NativeText(Int, Int, NativeScissor?)
  NativeImage(Int, Int, NativeScissor?, NativeImageRun)
  NativeLayer(NativeLayerRun)
  NativeShaderEffect(NativeShaderEffectRun)
}

///|
priv struct NativeDrawPlan {
  visual_vertices : Array[VisualVertex]
  text_vertices : Array[TextVertex]
  image_vertices : Array[ImageVertex]
  items : Array[NativeDrawItem]
  atlas_dirty : Bool
}

///|
priv struct NativeScissor {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
priv struct NativePaintState {
  opacity : Double
  transform : @core.Transform2D
  clip : @core.Rect?
  clip_radius : Double
  clip_empty : Bool
}

///|
priv struct NativeImageRun {
  source : String
  frame : @core.Rect
  opacity : Double
  fit : @core.ImageFit
  transform : @core.Transform2D
}

///|
priv struct NativeLayerRun {
  plan : NativeDrawPlan
  opacity : Double
  blend_mode : @core.BlendMode
  mask : NativeLayerMask?
  filter : @core.FilterEffect?
  scissor : NativeScissor?
}

///|
priv struct NativeLayerMask {
  rect : @core.Rect
  radius : Double
  rounded : Bool
}

///|
priv struct NativeShaderEffectRun {
  name : String
  frame : @core.Rect
  uniforms : Array[Double]
  fallback : @core.Brush
  opacity : Double
  transform : @core.Transform2D
  scissor : NativeScissor?
}

///|
priv struct VisualVertex {
  x : Double
  y : Double
  local_x : Double
  local_y : Double
  width : Double
  height : Double
  radius : Double
  mode : Double
  stroke_width : Double
  blur_radius : Double
  start_x : Double
  start_y : Double
  end_x : Double
  end_y : Double
  r0 : Double
  g0 : Double
  b0 : Double
  a0 : Double
  r1 : Double
  g1 : Double
  b1 : Double
  a1 : Double
}

///|
priv struct AdvancedVertex {
  x : Double
  y : Double
  u : Double
  v : Double
  opacity : Double
  blend_mode : Double
  shader_kind : Double
  effect_amount : Double
  local_x : Double
  local_y : Double
  filter_kind : Double
  filter_amount : Double
  r0 : Double
  g0 : Double
  b0 : Double
  a0 : Double
  r1 : Double
  g1 : Double
  b1 : Double
  a1 : Double
  matrix : Array[Double]
  rect_width : Double
  rect_height : Double
  mask_radius : Double
  mask_kind : Double
}
