///|
test "3D renderer session applies latest frame and rejects stale revisions" {
  let calls = Ref(0)
  let descriptor = ThreeDRendererDescriptor::new(
    id="test",
    backend=ThreeDRendererBackend::NativeWgpu,
    status=ThreeDRendererStatus::Available,
  )
  let session = ThreeDRendererSession::new(descriptor~, resize=_ => (), render=_ => {
    calls.val = calls.val + 1
    ThreeDRenderResult::Presented
  })
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=1L,
    scene=@moui_3d.Scene::empty(),
    camera=@moui_3d.OrbitCamera::new(),
  )
  let size = ThreeDViewportSize::new(width=64, height=64)
  assert_eq(
    session.render(ThreeDFrame::new(revision=2L, snapshot~, size~)),
    ThreeDRenderResult::Presented,
  )
  assert_eq(
    session.render(ThreeDFrame::new(revision=1L, snapshot~, size~)),
    ThreeDRenderResult::Queued,
  )
  assert_eq(calls.val, 1)
}

///|
test "resource graph creates once and removes retired keys" {
  let graph = ThreeDResourceGraph::new()
  let mesh = ThreeDResourceKey::new(kind=ThreeDResourceKind::Mesh, value=7L)
  let first = graph.sync(
    ThreeDResourceDiff::new(revision=1L, changes=[
      ThreeDResourceChange::Update(mesh),
    ]),
  )
  assert_eq(first.changes(), [ThreeDResourceChange::Create(mesh)])
  let second = graph.sync(
    ThreeDResourceDiff::new(revision=1L, changes=[
      ThreeDResourceChange::Update(mesh),
    ]),
  )
  assert_eq(second.changes().length(), 0)
  let updated = graph.sync(
    ThreeDResourceDiff::new(revision=2L, changes=[
      ThreeDResourceChange::Update(mesh),
    ]),
  )
  assert_eq(updated.changes(), [ThreeDResourceChange::Update(mesh)])
  let third = graph.sync(ThreeDResourceDiff::new(revision=3L, changes=[]))
  assert_eq(third.changes(), [ThreeDResourceChange::Remove(mesh)])
}

///|
test "render packet reports sampler residency for material textures" {
  let scene = @moui_3d.Scene::empty()
  let sampler = scene.add_sampler(@moui_3d.Sampler::new())
  let texture = scene.add_texture(
    @moui_3d.Texture::uri("albedo.png", sampler=Some(sampler)),
  )
  let material = scene.add_material(
    @moui_3d.Material::pbr(base_color_texture=Some(texture)),
  )
  let mesh = scene.add_mesh(
    @moui_3d.Mesh::new(primitives=[
      @moui_3d.Primitive::new(
        vertices=[
          @moui_3d.Vertex::new(position=@moui_3d.Vec3::new(x=0.0, y=0.0, z=0.0)),
          @moui_3d.Vertex::new(position=@moui_3d.Vec3::new(x=1.0, y=0.0, z=0.0)),
          @moui_3d.Vertex::new(position=@moui_3d.Vec3::new(x=0.0, y=1.0, z=0.0)),
        ],
        indices=[0, 1, 2],
        material=Some(material),
      ),
    ]),
  )
  ignore(scene.add_node(@moui_3d.Node::new(mesh=Some(mesh))))
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=4L,
    scene~,
    camera=@moui_3d.OrbitCamera::new(),
  )
  let packet = ThreeDRenderPacket::from_snapshot(
    snapshot,
    ThreeDViewportSize::new(width=64, height=64),
  )
  let has_sampler = packet
    .resources()
    .changes()
    .contains(
      ThreeDResourceChange::Update(
        ThreeDResourceKey::new(
          kind=ThreeDResourceKind::Sampler,
          value=sampler.value().to_int64(),
        ),
      ),
    )
  assert_true(has_sampler)
  assert_true(packet.resource_payload().contains("sampler:0"))
}

///|
test "render packet carries skin and morph resource metadata" {
  let scene = @moui_3d.Scene::empty()
  let skin = scene.add_skin(
    @moui_3d.Skin::new(joints=[@moui_3d.NodeId::new(0)]),
  )
  let mesh = scene.add_mesh(
    @moui_3d.Mesh::new(primitives=[
      @moui_3d.Primitive::new(
        vertices=[
          @moui_3d.Vertex::new(
            position=@moui_3d.Vec3::zero(),
            joints=(0, 0, 0, 0),
            weights=@moui_3d.Vec4::new(x=1.0, y=0.0, z=0.0, w=0.0),
          ),
          @moui_3d.Vertex::new(position=@moui_3d.Vec3::new(x=1.0, y=0.0, z=0.0)),
          @moui_3d.Vertex::new(position=@moui_3d.Vec3::new(x=0.0, y=1.0, z=0.0)),
        ],
        indices=[0, 1, 2],
        morph_targets=[
          [
            @moui_3d.VertexDelta::new(
              position=@moui_3d.Vec3::new(x=0.1, y=0.0, z=0.0),
            ),
            @moui_3d.VertexDelta::new(),
            @moui_3d.VertexDelta::new(),
          ],
        ],
      ),
    ]),
  )
  ignore(scene.add_node(@moui_3d.Node::new(mesh=Some(mesh), skin=Some(skin))))
  let packet = ThreeDRenderPacket::from_snapshot(
    @moui_3d.ViewportSnapshot::new(
      scene_revision=5L,
      scene~,
      camera=@moui_3d.OrbitCamera::new(),
    ),
    ThreeDViewportSize::new(width=64, height=64),
  )
  assert_true(packet.items()[0].skin() is Some(0))
  assert_eq(packet.items()[0].morph_targets().length(), 1)
  assert_true(packet.resource_payload().contains("skin:0"))
}

///|
test "unavailable provider can be followed by a working provider" {
  let unavailable = ThreeDRendererProvider::new(
    descriptor=ThreeDRendererDescriptor::new(
      id="missing",
      backend=ThreeDRendererBackend::WebGpu,
      status=ThreeDRendererStatus::Unavailable("no adapter"),
    ),
    bind=() => None,
  )
  let available = ThreeDRendererProvider::new(
    descriptor=ThreeDRendererDescriptor::new(
      id="working",
      backend=ThreeDRendererBackend::NativeWgpu,
      status=ThreeDRendererStatus::Available,
    ),
    bind=() => {
      Some(
        ThreeDRendererSession::new(
          descriptor=ThreeDRendererDescriptor::new(
            id="working",
            backend=ThreeDRendererBackend::NativeWgpu,
            status=ThreeDRendererStatus::Available,
          ),
          resize=_ => (),
          render=_ => ThreeDRenderResult::Presented,
        ),
      )
    },
  )
  assert_true(resolve_provider([unavailable, available]) is Some(_))
}

///|
test "viewport connection reuses size, rebinds surfaces and propagates status" {
  let binds = Ref(0)
  let resizes = Ref(0)
  let disposes = Ref(0)
  let invalidates = Ref(0)
  let render_result = Ref(ThreeDRenderResult::Presented)
  let descriptor = ThreeDRendererDescriptor::new(
    id="connection-test",
    backend=ThreeDRendererBackend::NativeWgpu,
    status=ThreeDRendererStatus::Available,
  )
  let provider = ThreeDRendererProvider::new(descriptor~, bind=() => None, bind_surface=(
    _handle,
    _size,
  ) => {
    binds.val = binds.val + 1
    Some(
      ThreeDRendererSession::new(
        descriptor~,
        resize=_ => resizes.val = resizes.val + 1,
        render=_ => render_result.val,
        dispose=() => disposes.val = disposes.val + 1,
      ),
    )
  })
  let binding = @moui_3d.ThreeDViewportBinding::new()
  let snapshot = @moui_3d.ViewportSnapshot::new(
    scene_revision=3L,
    scene=@moui_3d.Scene::empty(),
    camera=@moui_3d.OrbitCamera::new(),
  )
  ignore(binding.publish(snapshot))
  binding.set_status(@moui_3d.ViewportStatus::Loading)
  let host = @moui_3d.ThreeDViewportHost::new(binding~)
  connect_viewport_host(provider, host)
  host.set_invalidate_handler(() => invalidates.val = invalidates.val + 1)
  let placement = @core.PlatformViewPlacement::new(
    id="moui-3d-viewport",
    kind="moui_3d_viewport",
    frame=@core.Rect::new(x=0.0, y=0.0, width=320.0, height=200.0),
  )
  let frame = @core.DrawFrame::new(
    commands=[],
    platform_views=[placement],
    damage=@core.DamageRegion::full("connection test"),
  )
  host.sync_platform_view(1UL, placement, 11UL, frame, 0.0, scale_factor=2.0)
  host.sync_platform_view(1UL, placement, 11UL, frame, 0.0, scale_factor=2.0)
  assert_eq(binds.val, 1)
  assert_eq(resizes.val, 0)
  assert_eq(binding.status(), @moui_3d.ViewportStatus::Ready)
  render_result.val = ThreeDRenderResult::Failed("device lost")
  host.sync_platform_view(1UL, placement, 11UL, frame, 0.0, scale_factor=1.0)
  assert_eq(resizes.val, 1)
  assert_eq(binding.status(), @moui_3d.ViewportStatus::Failed("device lost"))
  render_result.val = ThreeDRenderResult::Presented
  host.sync_platform_view(1UL, placement, 12UL, frame, 0.0)
  assert_eq(binds.val, 2)
  assert_eq(disposes.val, 1)
  host.dispose_platform_views(1UL)
  assert_eq(disposes.val, 2)
  assert_eq(invalidates.val, 3)
}
