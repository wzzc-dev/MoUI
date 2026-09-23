///|
test "Transform::identity" {
  let t = @graphics.Transform::identity()
  let (x, y) = t.apply(10.0, 20.0)
  assert_eq(x, 10.0)
  assert_eq(y, 20.0)
}

///|
test "Transform::translate" {
  let t = @graphics.Transform::translate(tx=5.0, ty=10.0)
  let (x, y) = t.apply(10.0, 20.0)
  assert_eq(x, 15.0)
  assert_eq(y, 30.0)
}

///|
test "Transform::scale" {
  let t = @graphics.Transform::scale(sx=2.0, sy=3.0)
  let (x, y) = t.apply(10.0, 20.0)
  assert_eq(x, 20.0)
  assert_eq(y, 60.0)
}

///|
test "Transform::inverse roundtrips points" {
  let t = @graphics.Transform::translate(tx=1.0, ty=2.0).multiply(
    @graphics.Transform::scale(sx=2.0, sy=3.0),
  )
  match t.inverse() {
    Some(inverse) => {
      let (device_x, device_y) = t.apply(4.0, 5.0)
      let (local_x, local_y) = inverse.apply(device_x, device_y)
      assert_true((local_x - 4.0).abs() < 0.000000001)
      assert_true((local_y - 5.0).abs() < 0.000000001)
    }
    None => abort("expected invertible transform")
  }
}

///|
test "Transform::inverse rejects singular transforms" {
  assert_true(@graphics.Transform::scale(sx=0.0, sy=1.0).inverse() == None)
}
