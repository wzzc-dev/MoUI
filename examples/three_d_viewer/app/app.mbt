///|
using @views {button, card, center, column, row, text}

///|
/// The example loads a checked-in glTF fixture and keeps a procedural fallback
/// so the app remains diagnosable when fixture parsing is intentionally broken.
pub struct Model {
  binding : @moui_3d.ThreeDViewportBinding
  base_scene : @moui_3d.Scene
  snapshot : @moui_3d.ViewportSnapshot
  player : @moui_3d.AnimationPlayer
  selected_clip : Int
  picked_node : @moui_3d.NodeId?
  fixture_loaded : Bool
  orbit_time : Double
  dragging : Bool
  last_pointer_x : Double
  last_pointer_y : Double
}

///|
pub(all) enum Msg {
  Noop
  Viewport(@moui_3d.ViewportEvent)
  TogglePlayback
  SeekStart
  SelectClip(Int)
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
  let (scene, fixture_loaded) = fixture_scene()
  let camera = @moui_3d.OrbitCamera::new().fit(scene.bounds())
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=1L,
    scene~,
    camera~,
  )
  ignore(binding.publish(snapshot))
  let player = @moui_3d.AnimationPlayer::new()
  if scene.animations().length() > 0 {
    player.set_clip(scene.animations()[0])
  }
  {
    binding,
    base_scene: scene,
    snapshot,
    player,
    selected_clip: 0,
    picked_node: None,
    fixture_loaded,
    orbit_time: 0.0,
    dragging: false,
    last_pointer_x: 0.0,
    last_pointer_y: 0.0,
  }
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  match message {
    Noop => model
    TogglePlayback => {
      if model.player.playing() {
        model.player.pause()
      } else {
        model.player.play()
      }
      refresh_animation(model)
    }
    SeekStart => {
      model.player.seek(0.0)
      model.player.pause()
      refresh_animation({ ..model, orbit_time: 0.0 })
    }
    SelectClip(index) => {
      let clips = model.snapshot.scene().animations()
      if index >= 0 && index < clips.length() {
        model.player.set_clip(clips[index])
        refresh_animation({ ..model, selected_clip: index, orbit_time: 0.0 })
      } else {
        model
      }
    }
    Advance(delta_seconds) => {
      let was_playing = model.player.playing()
      model.player.advance(delta_seconds)
      // Loop the selected clip while playback is active. Without this reset
      // the fixture reaches its final keyframe once and then appears frozen.
      if model.player.playing() {
        let clips = model.base_scene.animations()
        if model.selected_clip >= 0 && model.selected_clip < clips.length() {
          let duration = clips[model.selected_clip].duration()
          if duration > 0.0 && model.player.time() >= duration {
            model.player.seek(0.0)
          }
        }
      }
      let orbit_time = if was_playing && delta_seconds > 0.0 {
        wrap_orbit_time(model.orbit_time + delta_seconds)
      } else {
        model.orbit_time
      }
      refresh_animation({ ..model, orbit_time, })
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
        @moui_3d.ViewportEvent::Resize(_)
        | @moui_3d.ViewportEvent::Focus(_)
        | @moui_3d.ViewportEvent::RendererStatus => model
        @moui_3d.ViewportEvent::Pick(node) =>
          { ..model, picked_node: Some(node) }
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
  let playback = if model.player.playing() { "playing" } else { "paused" }
  let animation_time = "t=\{model.player.time().to_string()}s"
  let picked = match model.picked_node {
    Some(node) => "picked node \{node.value()}"
    None => "no pick"
  }
  center(
    card(
      column([
        text("MoUI 3D Viewer").title(),
        text(
          "Local glTF fixture | clip \{model.selected_clip} | \{playback} | \{animation_time} | \{picked}",
        ).caption(),
        row(
          [
            button(
              if model.player.playing() {
                "Pause"
              } else {
                "Play"
              },
              on_click=TogglePlayback,
            ),
            button(
              "Seek start",
              on_click=SeekStart,
              variant=@views.ButtonVariant::Tonal,
            ),
            button(
              "Clip 0",
              on_click=SelectClip(0),
              variant=@views.ButtonVariant::Tonal,
            ),
          ],
          spacing=6.0,
        ),
        @moui_3d.three_d_viewport(
          binding=model.binding,
          snapshot=model.snapshot,
          semantics_label="3D model viewport",
          on_event=Some(event => Msg::Viewport(event)),
        ),
        text(
          status +
          (if model.fixture_loaded {
            " | fixture loaded"
          } else {
            " | fixture fallback"
          }),
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
    playback_subscription(model, environment.timer())
  })
}

///|
/// Keep the animation clock alive only while playback is active. The host
/// timer supplies elapsed time, so native and browser runs use the same model
/// update path and tests can still drive `Advance` directly.
fn playback_subscription(
  model : Model,
  timer : @services.TimerSource?,
) -> @moui.Subscription[Msg] {
  if !model.player.playing() {
    return @moui.Subscription::none()
  }
  match timer {
    Some(source) =>
      source.subscription(
        interval_ms=16.0,
        key="three-d-viewer:playback",
        label="3D viewer animation playback",
        map=frame => Advance(frame.delta_ms / 1000.0),
      )
    None => @moui.Subscription::none()
  }
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
/// Rebuild the snapshot from authored node transforms on every animation
/// change. This prevents sampling from accumulating a previous frame's pose.
fn refresh_animation(model : Model) -> Model {
  let animated_scene = model.base_scene.apply_animation_samples(
    orbit_samples(model),
  )
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=model.snapshot.scene_revision() + 1L,
    scene=animated_scene,
    camera=model.snapshot.camera(),
  )
  ignore(model.binding.publish(snapshot))
  { ..model, snapshot, }
}

///|
/// Generate a slow, continuous 3D orbit for the fixture node. The checked-in
/// glTF clip remains the playback clock, while this presentation path uses a
/// separate elapsed time so the one-second fixture clip cannot make the cube
/// spin once per second or jump back to its initial pose on every loop.
fn orbit_samples(model : Model) -> Array[@moui_3d.AnimationSample] {
  let samples = model.player.sample()
  let phase = model.orbit_time * orbit_angular_speed()
  let orbit_x = 0.42 * @math.sin(phase)
  let orbit_y = 0.18 * @math.sin(phase)
  let orbit_z = 0.34 * (1.0 - @math.cos(phase))
  let translated = samples.map(sample => {
    match sample.path() {
      @moui_3d.AnimationPath::Translation if sample.node().value() == 0 =>
        @moui_3d.AnimationSample::new(node=sample.node(), path=sample.path(), value=[
          orbit_x, orbit_y, orbit_z,
        ])
      _ => sample
    }
  })
  let yaw = @moui_3d.Quat::from_axis_angle(
    axis=@moui_3d.Vec3::new(x=0.0, y=1.0, z=0.0),
    angle=phase,
  )
  let pitch = @moui_3d.Quat::from_axis_angle(
    axis=@moui_3d.Vec3::new(x=1.0, y=0.0, z=0.0),
    angle=0.10 * @math.sin(phase),
  )
  let rotation = yaw.mul(pitch)
  translated.push(
    @moui_3d.AnimationSample::new(
      node=@moui_3d.NodeId::new(0),
      path=@moui_3d.AnimationPath::Rotation,
      value=[rotation.x(), rotation.y(), rotation.z(), rotation.w()],
    ),
  )
  translated
}

///|
/// Keep the presentation orbit continuous even though the authored fixture
/// animation is intentionally only one second long.
fn orbit_angular_speed() -> Double {
  0.8
}

///|
fn wrap_orbit_time(value : Double) -> Double {
  let period = 2.0 * @math.PI / orbit_angular_speed()
  if value < 0.0 {
    0.0
  } else if value >= period {
    value - @math.floor(value / period) * period
  } else {
    value
  }
}

///|
fn fixture_scene() -> (@moui_3d.Scene, Bool) {
  let scene = @moui_3d.load_gltf_scene(fixture_gltf) catch {
    _ => return (cube_scene(), false)
  }
  (scene, true)
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
