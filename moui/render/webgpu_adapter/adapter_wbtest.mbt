///|
test "wgpu web adapter encodes image fit host codes" {
  inspect(image_fit_host_code(@core.ImageFit::Contain), content="0")
  inspect(image_fit_host_code(@core.ImageFit::Cover), content="1")
  inspect(image_fit_host_code(@core.ImageFit::Stretch), content="2")
  inspect(image_fit_host_code(@core.ImageFit::ScaleDown), content="3")
  inspect(image_fit_host_code(@core.ImageFit::FitWidth), content="4")
  inspect(image_fit_host_code(@core.ImageFit::FitHeight), content="5")
}
