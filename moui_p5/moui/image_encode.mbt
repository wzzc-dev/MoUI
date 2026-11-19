///|
/// Encodes a p5 image (optionally tinted) as a `DrawImage` data URI. The PNG
/// bytes come from `Image::to_png_bytes`, shared with `Image::save`.
fn p5_image_source(image : @p5.Image, tint : @p5.Color?) -> String {
  let image = match tint {
    Some(color) => image.tinted(color)
    None => image
  }
  "data:image/png;base64," + @base64.encode(image.to_png_bytes(), padding=true)
}
