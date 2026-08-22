///|
using @views {button, card, center, column, row, text}

///|
let fixed_step : Double = 1.0 / 60.0

///|
pub struct Model {
  binding : @moui_3d.ThreeDViewportBinding
  base_scene : @moui_3d.Scene
  snapshot : @moui_3d.ViewportSnapshot
  world : @moui_3d_physics_rapier.RapierWorld
  dynamic_body : @moui_3d_physics.BodyId
  ground_collider : @moui_3d_physics.ColliderId
  playing : Bool
  simulation_time : Double
  accumulator : Double
  ray_hit : @moui_3d_physics.RayHit?
  picked_node : @moui_3d.NodeId?
  dragging : Bool
  last_pointer_x : Double
  last_pointer_y : Double
}

///|
pub(all) enum Msg {
  Viewport(@moui_3d.ViewportEvent)
  TogglePlayback
  Reset
  Step
  Advance(Double)
}

///|
pub fn Model::new() -> Model {
  Model::new_with_binding(@moui_3d.ThreeDViewportBinding::new())
}

///|
pub fn Model::new_with_binding(
  binding : @moui_3d.ThreeDViewportBinding,
) -> Model {
  let scene = physics_scene()
  let camera = @moui_3d.OrbitCamera::new().fit(scene.bounds(), padding=1.35)
  let (world, dynamic_body, _dynamic_collider, _ground_body, ground_collider) = new_world()
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=1L,
    scene~,
    camera~,
  )
  ignore(binding.publish(snapshot))
  let model = {
    binding,
    base_scene: scene,
    snapshot,
    world,
    dynamic_body,
    ground_collider,
    playing: false,
    simulation_time: 0.0,
    accumulator: 0.0,
    ray_hit: None,
    picked_node: None,
    dragging: false,
    last_pointer_x: 0.0,
    last_pointer_y: 0.0,
  }
  refresh(model)
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  match message {
    TogglePlayback => { ..model, playing: !model.playing }
    Reset => reset_simulation(model)
    Step => if model.playing { model } else { simulate(model, fixed_step) }
    Advance(delta_seconds) =>
      if model.playing {
        simulate(model, delta_seconds)
      } else {
        model
      }
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
        @moui_3d.ViewportEvent::Pick(node) =>
          { ..model, picked_node: Some(node) }
        @moui_3d.ViewportEvent::Resize(_)
        | @moui_3d.ViewportEvent::Focus(_)
        | @moui_3d.ViewportEvent::RendererStatus => model
      }
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let position = model.world
    .body_translation(model.dynamic_body)
    .unwrap_or(@moui_3d.Vec3::zero())
  let backend = @moui_3d_physics_rapier.backend_id()
  let playback = if model.playing { "playing" } else { "paused" }
  let collision = if position.y() <= 0.56 {
    "ground contact"
  } else {
    "falling"
  }
  let ray = match model.ray_hit {
    None => "ray: no hit"
    Some(hit) =>
      "ray: collider \{hit.collider().value()} at \{hit.distance().to_string()}m"
  }
  let picked = match model.picked_node {
    None => "no pick"
    Some(node) => "picked node \{node.value()}"
  }
  let renderer_status = match model.binding.status() {
    @moui_3d.ViewportStatus::Loading => "GPU renderer status: loading"
    @moui_3d.ViewportStatus::Ready => "GPU renderer status: host connected"
    @moui_3d.ViewportStatus::Unavailable(reason) =>
      "GPU renderer unavailable: \{reason}"
    @moui_3d.ViewportStatus::Failed(reason) => "GPU renderer failed: \{reason}"
  }
  center(
    card(
      column([
        text("MoUI 3D Physics Viewer").title(),
        text(
          "Rapier \{backend} | \{playback} | t=\{model.simulation_time.to_string()}s | \{collision} | \{picked}",
        ).caption(),
        row(
          [
            button(
              if model.playing {
                "Pause"
              } else {
                "Play"
              },
              on_click=TogglePlayback,
            ),
            button("Step", on_click=Step, variant=@views.ButtonVariant::Tonal),
            button("Reset", on_click=Reset, variant=@views.ButtonVariant::Tonal),
          ],
          spacing=6.0,
        ),
        @moui_3d.three_d_viewport(
          binding=model.binding,
          snapshot=model.snapshot,
          semantics_label="3D physics viewport",
          on_event=Some(event => Msg::Viewport(event)),
        ),
        text(
          "sphere y=\{position.y().to_string()} | \{ray} | \{renderer_status}",
        ).caption(),
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
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new_with_binding(binding), update~, view~, subscriptions=model => {
    if !model.playing {
      @moui.Subscription::none()
    } else {
      match environment.timer() {
        None => @moui.Subscription::none()
        Some(timer) =>
          timer.subscription(
            interval_ms=16.0,
            key="three-d-physics-viewer:simulation",
            label="3D physics simulation",
            map=frame => Advance(frame.delta_ms / 1000.0),
          )
      }
    }
  })
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
fn simulate(model : Model, delta_seconds : Double) -> Model {
  let delta = delta_seconds.max(0.0).min(0.25)
  let world = model.world
  let mut remaining = model.accumulator + delta
  let mut steps = 0
  while remaining >= fixed_step && steps < 16 {
    ignore(world.step(fixed_step))
    remaining -= fixed_step
    steps += 1
  }
  refresh({
    ..model,
    world,
    accumulator: remaining,
    simulation_time: model.simulation_time + steps.to_double() * fixed_step,
  })
}

///|
fn reset_simulation(model : Model) -> Model {
  let scene = physics_scene()
  let (world, dynamic_body, _dynamic_collider, _ground_body, ground_collider) = new_world()
  refresh({
    ..model,
    base_scene: scene,
    world,
    dynamic_body,
    ground_collider,
    playing: false,
    simulation_time: 0.0,
    accumulator: 0.0,
    ray_hit: None,
    picked_node: None,
  })
}

///|
fn refresh(model : Model) -> Model {
  let position = model.world
    .body_translation(model.dynamic_body)
    .unwrap_or(@moui_3d.Vec3::zero())
  let rotation = model.world
    .body_rotation(model.dynamic_body)
    .unwrap_or(@moui_3d.Quat::identity())
  let scene = model.base_scene.apply_animation_samples([
    @moui_3d.AnimationSample::new(
      node=@moui_3d.NodeId::new(0),
      path=@moui_3d.AnimationPath::Translation,
      value=[position.x(), position.y(), position.z()],
    ),
    @moui_3d.AnimationSample::new(
      node=@moui_3d.NodeId::new(0),
      path=@moui_3d.AnimationPath::Rotation,
      value=[rotation.x(), rotation.y(), rotation.z(), rotation.w()],
    ),
  ])
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=model.snapshot.scene_revision() + 1L,
    scene~,
    camera=model.snapshot.camera(),
  )
  ignore(model.binding.publish(snapshot))
  let ray = model.world.cast_ray(
    @moui_3d.Ray::new(
      origin=@moui_3d.Vec3::new(
        x=position.x() + 1.0,
        y=position.y() + 0.6,
        z=position.z(),
      ),
      direction=@moui_3d.Vec3::new(x=0.0, y=-1.0, z=0.0),
    ),
    10.0,
  )
  { ..model, snapshot, ray_hit: ray }
}

///|
fn new_world() -> (
  @moui_3d_physics_rapier.RapierWorld,
  @moui_3d_physics.BodyId,
  @moui_3d_physics.ColliderId,
  @moui_3d_physics.BodyId,
  @moui_3d_physics.ColliderId,
) {
  let world = @moui_3d_physics_rapier.RapierWorld::new()
  let ground_body = world.create_body(
    @moui_3d_physics.BodyDesc::new(
      body_type=@moui_3d_physics.BodyType::Fixed,
      position=@moui_3d.Vec3::new(x=0.0, y=-0.5, z=0.0),
    ),
  )
  let ground_collider = world
    .create_collider(
      @moui_3d_physics.ColliderDesc::new(
        shape=@moui_3d_physics.Shape::Cuboid(
          @moui_3d.Vec3::new(x=2.8, y=0.5, z=2.8),
        ),
        body=Some(ground_body),
        friction=0.8,
      ),
    )
    .unwrap()
  let dynamic_body = world.create_body(
    @moui_3d_physics.BodyDesc::new(
      position=@moui_3d.Vec3::new(x=0.0, y=4.0, z=0.0),
      rotation=@moui_3d.Quat::from_axis_angle(
        axis=@moui_3d.Vec3::new(x=0.0, y=0.0, z=1.0),
        angle=0.22,
      ),
    ),
  )
  let dynamic_collider = world
    .create_collider(
      @moui_3d_physics.ColliderDesc::new(
        shape=@moui_3d_physics.Shape::Ball(0.5),
        body=Some(dynamic_body),
        friction=0.7,
        restitution=0.85,
      ),
    )
    .unwrap()
  (world, dynamic_body, dynamic_collider, ground_body, ground_collider)
}

///|
fn physics_scene() -> @moui_3d.Scene {
  let scene = @moui_3d.Scene::empty()
  ignore(
    add_sphere(
      scene,
      name="Dynamic sphere",
      radius=0.5,
      position=@moui_3d.Vec3::new(x=0.0, y=4.0, z=0.0),
      rotation=@moui_3d.Quat::from_axis_angle(
        axis=@moui_3d.Vec3::new(x=0.0, y=0.0, z=1.0),
        angle=0.22,
      ),
      color=@moui_3d.Vec4::new(x=0.94, y=0.34, z=0.12, w=1.0),
    ),
  )
  ignore(
    add_box(
      scene,
      name="Fixed ground",
      half_extents=@moui_3d.Vec3::new(x=2.8, y=0.5, z=2.8),
      position=@moui_3d.Vec3::new(x=0.0, y=-0.5, z=0.0),
      rotation=@moui_3d.Quat::identity(),
      colors=Array::make(6, @moui_3d.Vec4::new(x=0.26, y=0.30, z=0.36, w=1.0)),
    ),
  )
  scene
}

///|
fn add_sphere(
  scene : @moui_3d.Scene,
  name~ : String,
  radius~ : Double,
  position~ : @moui_3d.Vec3,
  rotation~ : @moui_3d.Quat,
  color~ : @moui_3d.Vec4,
) -> @moui_3d.NodeId {
  let material = scene.add_material(
    @moui_3d.Material::pbr(base_color=color, metallic=0.05, roughness=0.62),
  )
  let segments = 24
  let rings = 12
  let vertices : Array[@moui_3d.Vertex] = []
  for ring in 0..<=rings {
    let theta = @math.PI * ring.to_double() / rings.to_double()
    let sin_theta = @math.sin(theta)
    let cos_theta = @math.cos(theta)
    for segment in 0..<=segments {
      let phi = 2.0 * @math.PI * segment.to_double() / segments.to_double()
      let normal = @moui_3d.Vec3::new(
        x=sin_theta * @math.sin(phi),
        y=cos_theta,
        z=sin_theta * @math.cos(phi),
      )
      vertices.push(
        @moui_3d.Vertex::new(position=normal.scale(radius), normal~),
      )
    }
  }
  let indices : Array[Int] = []
  for ring in 0..<rings {
    for segment in 0..<segments {
      let first = ring * (segments + 1) + segment
      let second = first + segments + 1
      indices.push(first)
      indices.push(second)
      indices.push(first + 1)
      indices.push(second)
      indices.push(second + 1)
      indices.push(first + 1)
    }
  }
  let mesh_id = scene.add_mesh(
    @moui_3d.Mesh::new(name="\{name} mesh", primitives=[
      @moui_3d.Primitive::new(vertices~, indices~, material=Some(material)),
    ]),
  )
  scene.add_node(
    @moui_3d.Node::new(
      name~,
      local_transform=@moui_3d.Mat4::translation(position).mul(
        rotation.to_mat4(),
      ),
      mesh=Some(mesh_id),
    ),
  )
}

///|
fn add_box(
  scene : @moui_3d.Scene,
  name~ : String,
  half_extents~ : @moui_3d.Vec3,
  position~ : @moui_3d.Vec3,
  rotation~ : @moui_3d.Quat,
  colors~ : Array[@moui_3d.Vec4],
) -> @moui_3d.NodeId {
  let materials = colors.map(color => {
    scene.add_material(
      @moui_3d.Material::pbr(base_color=color, metallic=0.05, roughness=0.72),
    )
  })
  let primitives : Array[@moui_3d.Primitive] = []
  for face in 0..<6 {
    let (positions, normal) = box_face(face, half_extents)
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
  let mesh_id = scene.add_mesh(
    @moui_3d.Mesh::new(name="\{name} mesh", primitives~),
  )
  scene.add_node(
    @moui_3d.Node::new(
      name~,
      local_transform=@moui_3d.Mat4::translation(position).mul(
        rotation.to_mat4(),
      ),
      mesh=Some(mesh_id),
    ),
  )
}

///|
fn box_face(
  face : Int,
  half_extents : @moui_3d.Vec3,
) -> (Array[@moui_3d.Vec3], @moui_3d.Vec3) {
  let x = half_extents.x()
  let y = half_extents.y()
  let z = half_extents.z()
  let n = (x, y, z) => @moui_3d.Vec3::new(x~, y~, z~)
  match face {
    0 =>
      ([n(-x, -y, z), n(x, -y, z), n(x, y, z), n(-x, y, z)], n(0.0, 0.0, 1.0))
    1 =>
      (
        [n(x, -y, -z), n(-x, -y, -z), n(-x, y, -z), n(x, y, -z)],
        n(0.0, 0.0, -1.0),
      )
    2 =>
      ([n(x, -y, z), n(x, -y, -z), n(x, y, -z), n(x, y, z)], n(1.0, 0.0, 0.0))
    3 =>
      (
        [n(-x, -y, -z), n(-x, -y, z), n(-x, y, z), n(-x, y, -z)],
        n(-1.0, 0.0, 0.0),
      )
    4 =>
      ([n(-x, y, z), n(x, y, z), n(x, y, -z), n(-x, y, -z)], n(0.0, 1.0, 0.0))
    _ =>
      (
        [n(-x, -y, -z), n(x, -y, -z), n(x, -y, z), n(-x, -y, z)],
        n(0.0, -1.0, 0.0),
      )
  }
}
