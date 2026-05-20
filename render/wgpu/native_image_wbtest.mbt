///|
test "UV calculation for contain fit - image wider than frame" {
  let image_size = @core.Size::new(width=200.0, height=100.0)
  let frame_size = @core.Size::new(width=100.0, height=100.0)
  let result = calculate_image_uv(image_size, frame_size, @core.ImageFit::Contain)
  inspect(result.u0, content="0")
  inspect(result.v0, content="0.25")
  inspect(result.u1, content="1")
  inspect(result.v1, content="0.75")
}

///|
test "UV calculation for contain fit - image taller than frame" {
  let image_size = @core.Size::new(width=100.0, height=200.0)
  let frame_size = @core.Size::new(width=100.0, height=100.0)
  let result = calculate_image_uv(image_size, frame_size, @core.ImageFit::Contain)
  inspect(result.u0, content="0.25")
  inspect(result.v0, content="0")
  inspect(result.u1, content="0.75")
  inspect(result.v1, content="1")
}

///|
test "UV calculation for contain fit - image same ratio as frame" {
  let image_size = @core.Size::new(width=100.0, height=100.0)
  let frame_size = @core.Size::new(width=100.0, height=100.0)
  let result = calculate_image_uv(image_size, frame_size, @core.ImageFit::Contain)
  inspect(result.u0, content="0")
  inspect(result.v0, content="0")
  inspect(result.u1, content="1")
  inspect(result.v1, content="1")
}

///|
test "UV calculation for cover fit - image wider than frame" {
  let image_size = @core.Size::new(width=200.0, height=100.0)
  let frame_size = @core.Size::new(width=100.0, height=100.0)
  let result = calculate_image_uv(image_size, frame_size, @core.ImageFit::Cover)
  inspect(result.u0, content="0.25")
  inspect(result.v0, content="0")
  inspect(result.u1, content="0.75")
  inspect(result.v1, content="1")
}

///|
test "UV calculation for cover fit - image taller than frame" {
  let image_size = @core.Size::new(width=100.0, height=200.0)
  let frame_size = @core.Size::new(width=100.0, height=100.0)
  let result = calculate_image_uv(image_size, frame_size, @core.ImageFit::Cover)
  inspect(result.u0, content="0")
  inspect(result.v0, content="0.25")
  inspect(result.u1, content="1")
  inspect(result.v1, content="0.75")
}

///|
test "UV calculation for cover fit - image same ratio as frame" {
  let image_size = @core.Size::new(width=100.0, height=100.0)
  let frame_size = @core.Size::new(width=100.0, height=100.0)
  let result = calculate_image_uv(image_size, frame_size, @core.ImageFit::Cover)
  inspect(result.u0, content="0")
  inspect(result.v0, content="0")
  inspect(result.u1, content="1")
  inspect(result.v1, content="1")
}

///|
test "image vertex generation" {
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=80.0)
  let u0 = 0.1
  let v0 = 0.2
  let u1 = 0.9
  let v1 = 0.8
  let screen_size = @core.Size::new(width=320.0, height=240.0)
  let vertices = generate_image_vertices(frame, u0, v0, u1, v1, screen_size)
  inspect(vertices.length(), content="6")
  
  // Check first triangle
  inspect(vertices[0].x, content="10")
  inspect(vertices[0].y, content="20")
  inspect(vertices[0].u, content="0.1")
  inspect(vertices[0].v, content="0.2")
  
  inspect(vertices[1].x, content="10")
  inspect(vertices[1].y, content="100")
  inspect(vertices[1].u, content="0.1")
  inspect(vertices[1].v, content="0.8")
  
  inspect(vertices[2].x, content="110")
  inspect(vertices[2].y, content="100")
  inspect(vertices[2].u, content="0.9")
  inspect(vertices[2].v, content="0.8")
  
  // Check second triangle
  inspect(vertices[3].x, content="10")
  inspect(vertices[3].y, content="20")
  inspect(vertices[3].u, content="0.1")
  inspect(vertices[3].v, content="0.2")
  
  inspect(vertices[4].x, content="110")
  inspect(vertices[4].y, content="100")
  inspect(vertices[4].u, content="0.9")
  inspect(vertices[4].v, content="0.8")
  
  inspect(vertices[5].x, content="110")
  inspect(vertices[5].y, content="20")
  inspect(vertices[5].u, content="0.9")
  inspect(vertices[5].v, content="0.2")
}
