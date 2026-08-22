///|
pub(all) enum XrSessionMode {
  Inline
  ImmersiveVr
  ImmersiveAr
} derive(Eq, Debug, ToJson)

///|
pub(all) enum XrBackend {
  WebXr
  OpenXr
} derive(Eq, Debug, ToJson)

///|
pub(all) struct XrView {
  view : @moui_3d.Mat4
  projection : @moui_3d.Mat4
  viewport_x : Int
  viewport_y : Int
  viewport_width : Int
  viewport_height : Int
} derive(Debug)

///|
pub fn XrView::new(
  view~ : @moui_3d.Mat4,
  projection~ : @moui_3d.Mat4,
  viewport_x~ : Int,
  viewport_y~ : Int,
  viewport_width~ : Int,
  viewport_height~ : Int,
) -> XrView {
  { view, projection, viewport_x, viewport_y, viewport_width, viewport_height }
}

///|
pub fn XrView::view(self : XrView) -> @moui_3d.Mat4 {
  self.view
}

///|
pub fn XrView::projection(self : XrView) -> @moui_3d.Mat4 {
  self.projection
}

///|
pub fn XrView::viewport_width(self : XrView) -> Int {
  self.viewport_width
}

///|
pub fn XrView::viewport_height(self : XrView) -> Int {
  self.viewport_height
}

///|
pub(all) struct XrPose {
  position : @moui_3d.Vec3
  orientation : @moui_3d.Quat
} derive(Eq, Debug, ToJson)

///|
pub fn XrPose::new(
  position~ : @moui_3d.Vec3,
  orientation~ : @moui_3d.Quat,
) -> XrPose {
  { position, orientation }
}

///|
pub fn XrPose::position(self : XrPose) -> @moui_3d.Vec3 {
  self.position
}

///|
pub fn XrPose::orientation(self : XrPose) -> @moui_3d.Quat {
  self.orientation
}

///|
pub(all) struct XrInputSource {
  id : String
  handedness : String
  grip : XrPose?
  target_ray : XrPose?
} derive(Debug)

///|
pub fn XrInputSource::new(
  id~ : String,
  handedness? : String = "none",
  grip? : XrPose? = None,
  target_ray? : XrPose? = None,
) -> XrInputSource {
  { id, handedness, grip, target_ray }
}

///|
pub fn XrInputSource::id(self : XrInputSource) -> String {
  self.id
}

///|
pub fn XrInputSource::handedness(self : XrInputSource) -> String {
  self.handedness
}

///|
pub fn XrInputSource::grip(self : XrInputSource) -> XrPose? {
  self.grip
}

///|
pub fn XrInputSource::target_ray(self : XrInputSource) -> XrPose? {
  self.target_ray
}

///|
pub(all) struct XrFrame {
  timestamp : Double
  views : Array[XrView]
  input_sources : Array[XrInputSource]
} derive(Debug)

///|
pub fn XrFrame::new(
  timestamp~ : Double,
  views~ : Array[XrView],
  input_sources? : Array[XrInputSource] = [],
) -> XrFrame {
  { timestamp, views: views.copy(), input_sources: input_sources.copy() }
}

///|
pub fn XrFrame::timestamp(self : XrFrame) -> Double {
  self.timestamp
}

///|
pub fn XrFrame::views(self : XrFrame) -> Array[XrView] {
  self.views.copy()
}

///|
pub fn XrFrame::input_sources(self : XrFrame) -> Array[XrInputSource] {
  self.input_sources.copy()
}

///|
pub(all) enum XrResult {
  Presented
  Unavailable(String)
  Failed(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct XrProviderDescriptor {
  backend : XrBackend
  id : String
  status : String
} derive(Eq, Debug, ToJson)

///|
pub fn XrProviderDescriptor::new(
  backend~ : XrBackend,
  id~ : String,
  status~ : String,
) -> XrProviderDescriptor {
  { backend, id, status }
}

///|
pub fn XrProviderDescriptor::backend(self : XrProviderDescriptor) -> XrBackend {
  self.backend
}

///|
pub fn XrProviderDescriptor::id(self : XrProviderDescriptor) -> String {
  self.id
}

///|
pub fn XrProviderDescriptor::status(self : XrProviderDescriptor) -> String {
  self.status
}
