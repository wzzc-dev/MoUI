///|
test "wgpu web adapter encodes image fit host codes" {
  inspect(image_fit_host_code(@core.ImageFit::Contain), content="0")
  inspect(image_fit_host_code(@core.ImageFit::Cover), content="1")
  inspect(image_fit_host_code(@core.ImageFit::Stretch), content="2")
}
