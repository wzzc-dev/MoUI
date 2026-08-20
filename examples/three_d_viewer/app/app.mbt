///|
using @views {card, center, column, text}

///|
/// A small procedural scene keeps the example runnable without file/network I/O.
pub struct Model {
  binding : @moui_3d.ThreeDViewportBinding
  snapshot : @moui_3d.ViewportSnapshot
  dragging : Bool
  last_pointer_x : Double
  last_pointer_y : Double
}

///|
pub(all) enum Msg {
  Noop
  Viewport(@moui_3d.ViewportEvent)
}

///|
pub fn Model::new() -> Model {
  Model::new_with_binding(@moui_3d.ThreeDViewportBinding::new())
}

///|
pub fn Model::new_with_binding(
  binding : @moui_3d.ThreeDViewportBinding,
) -> Model {
  let scene = cube_scene()
  let camera = @moui_3d.OrbitCamera::new().fit(scene.bounds())
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=1L,
    scene~,
    camera~,
  )
  ignore(binding.publish(snapshot))
  {
    binding,
    snapshot,
    dragging: false,
    last_pointer_x: 0.0,
    last_pointer_y: 0.0,
  }
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  match message {
    Noop => model
    Viewport(event) =>
      match event {
        @moui_3d.ViewportEvent::PointerDown(point) =>
          {
            ..model,
            dragging: true,
            last_pointer_x: point.x,
            last_pointer_y: point.y,
          }
        @moui_3d.ViewportEvent::PointerMove(point) =>
          if !model.dragging {
            model
          } else {
            let dx = point.x - model.last_pointer_x
            let dy = point.y - model.last_pointer_y
            let camera = model.snapshot.camera().orbit(dx * 0.01, dy * 0.01)
            {
              ..with_camera(model, camera),
              dragging: true,
              last_pointer_x: point.x,
              last_pointer_y: point.y,
            }
          }
        @moui_3d.ViewportEvent::PointerUp(_) => { ..model, dragging: false }
        @moui_3d.ViewportEvent::Wheel(amount) => {
          let magnitude = amount.abs().min(100.0) * 0.01
          let factor = if amount >= 0.0 {
            1.0 + magnitude
          } else {
            1.0 / (1.0 + magnitude)
          }
          with_camera(model, model.snapshot.camera().zoom(factor))
        }
        @moui_3d.ViewportEvent::Resize(_)
        | @moui_3d.ViewportEvent::Focus(_)
        | @moui_3d.ViewportEvent::Pick(_)
        | @moui_3d.ViewportEvent::RendererStatus => model
      }
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let status = match model.binding.status() {
    @moui_3d.ViewportStatus::Loading => "GPU renderer status: loading"
    @moui_3d.ViewportStatus::Ready => "GPU renderer status: host connected"
    @moui_3d.ViewportStatus::Unavailable(reason) =>
      "GPU renderer unavailable: \{reason}"
    @moui_3d.ViewportStatus::Failed(reason) => "GPU renderer failed: \{reason}"
  }
  center(
    card(
      column([
        text("MoUI 3D Viewer").title(),
        text("Interactive orbit cube with CPU picking").caption(),
        @moui_3d.three_d_viewport(
          binding=model.binding,
          snapshot=model.snapshot,
          semantics_label="3D model viewport",
          on_event=Some(event => Msg::Viewport(event)),
        ),
        text(status).caption(),
      ]),
    ),
  )
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}

///|
pub fn program_with_binding(
  binding : @moui_3d.ThreeDViewportBinding,
) -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new_with_binding(binding), update~, view~)
}

///|
fn with_camera(model : Model, camera : @moui_3d.OrbitCamera) -> Model {
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=model.snapshot.scene_revision() + 1L,
    scene=model.snapshot.scene(),
    camera~,
  )
  ignore(model.binding.publish(snapshot))
  { ..model, snapshot, }
}

///|
/// Build a deliberately faceted cube so the native and WebGPU examples make
/// the 3D surface obvious instead of looking like a flat triangle.
fn cube_scene() -> @moui_3d.Scene {
  let scene = @moui_3d.Scene::empty()
  let colors = [
    @moui_3d.Vec4::new(x=0.86, y=0.25, z=0.22, w=1.0),
    @moui_3d.Vec4::new(x=0.22, y=0.48, z=0.92, w=1.0),
    @moui_3d.Vec4::new(x=0.22, y=0.72, z=0.38, w=1.0),
    @moui_3d.Vec4::new(x=0.92, y=0.68, z=0.18, w=1.0),
    @moui_3d.Vec4::new(x=0.66, y=0.28, z=0.84, w=1.0),
    @moui_3d.Vec4::new(x=0.18, y=0.76, z=0.78, w=1.0),
  ]
  let materials = colors.map(color => {
    scene.add_material(
      @moui_3d.Material::pbr(base_color=color, metallic=0.05, roughness=0.72),
    )
  })
  let primitives : Array[@moui_3d.Primitive] = []
  for face in 0..<6 {
    let (positions, normal) = cube_face(face)
    primitives.push(
      @moui_3d.Primitive::new(
        vertices=positions.map(position => {
          @moui_3d.Vertex::new(position~, normal~)
        }),
        indices=[0, 1, 2, 0, 2, 3],
        material=Some(materials[face]),
      ),
    )
  }
  let mesh = @moui_3d.Mesh::new(name="Orbit cube", primitives~)
  let mesh_id = scene.add_mesh(mesh)
  ignore(scene.add_node(@moui_3d.Node::new(name="Cube", mesh=Some(mesh_id))))
  scene
}

///|
fn cube_face(face : Int) -> (Array[@moui_3d.Vec3], @moui_3d.Vec3) {
  let n = (x, y, z) => @moui_3d.Vec3::new(x~, y~, z~)
  match face {
    0 =>
      (
        [
          n(-1.0, -1.0, 1.0),
          n(1.0, -1.0, 1.0),
          n(1.0, 1.0, 1.0),
          n(-1.0, 1.0, 1.0),
        ],
        n(0.0, 0.0, 1.0),
      )
    1 =>
      (
        [
          n(1.0, -1.0, -1.0),
          n(-1.0, -1.0, -1.0),
          n(-1.0, 1.0, -1.0),
          n(1.0, 1.0, -1.0),
        ],
        n(0.0, 0.0, -1.0),
      )
    2 =>
      (
        [
          n(1.0, -1.0, 1.0),
          n(1.0, -1.0, -1.0),
          n(1.0, 1.0, -1.0),
          n(1.0, 1.0, 1.0),
        ],
        n(1.0, 0.0, 0.0),
      )
    3 =>
      (
        [
          n(-1.0, -1.0, -1.0),
          n(-1.0, -1.0, 1.0),
          n(-1.0, 1.0, 1.0),
          n(-1.0, 1.0, -1.0),
        ],
        n(-1.0, 0.0, 0.0),
      )
    4 =>
      (
        [
          n(-1.0, 1.0, 1.0),
          n(1.0, 1.0, 1.0),
          n(1.0, 1.0, -1.0),
          n(-1.0, 1.0, -1.0),
        ],
        n(0.0, 1.0, 0.0),
      )
    _ =>
      (
        [
          n(-1.0, -1.0, -1.0),
          n(1.0, -1.0, -1.0),
          n(1.0, -1.0, 1.0),
          n(-1.0, -1.0, 1.0),
        ],
        n(0.0, -1.0, 0.0),
      )
  }
}
