///|
/// Shared image placement geometry. Skia and Sun each maintained their own
/// contain/cover/stretch/scale-down/fit-width/fit-height placement logic with
/// identical decision math but different source-crop representations (Skia
/// normalized UV, Sun integer pixel rect). This module owns the geometry
/// once; renderers keep their native crop conversion for zero behavior change.

///|
/// Which source axis is cropped by `visible` (the fraction of the source that
/// remains visible). `None` means the full source is sampled.
pub enum ImageCropAxis {
  None
  Horizontal
  Vertical
}

///|
pub struct ImagePlacement {
  frame : @core.Rect
  crop_axis : ImageCropAxis
  visible : Double
}

///|
pub fn image_placement(
  frame : @core.Rect,
  image_size : @core.Size,
  fit : @core.ImageFit,
) -> ImagePlacement {
  if image_size.width <= 0.0 ||
    image_size.height <= 0.0 ||
    frame.size.width <= 0.0 ||
    frame.size.height <= 0.0 {
    return { frame, crop_axis: ImageCropAxis::None, visible: 1.0 }
  }
  let image_ratio = image_size.width / image_size.height
  let frame_ratio = frame.size.width / frame.size.height
  match fit {
    @core.ImageFit::Stretch => { frame, crop_axis: ImageCropAxis::None, visible: 1.0 }
    @core.ImageFit::ScaleDown =>
      if image_size.width <= frame.size.width &&
        image_size.height <= frame.size.height {
        {
          frame: @core.Rect::new(
            x=frame.origin.x + (frame.size.width - image_size.width) / 2.0,
            y=frame.origin.y + (frame.size.height - image_size.height) / 2.0,
            width=image_size.width,
            height=image_size.height,
          ),
          crop_axis: ImageCropAxis::None,
          visible: 1.0,
        }
      } else {
        image_contain_placement(frame, image_size)
      }
    @core.ImageFit::FitWidth =>
      image_fit_width_placement(frame, image_ratio)
    @core.ImageFit::FitHeight =>
      image_fit_height_placement(frame, image_ratio)
    @core.ImageFit::Contain => image_contain_placement(frame, image_size)
    @core.ImageFit::Cover =>
      if image_ratio > frame_ratio {
        {
          frame,
          crop_axis: ImageCropAxis::Horizontal,
          visible: frame_ratio / image_ratio,
        }
      } else {
        {
          frame,
          crop_axis: ImageCropAxis::Vertical,
          visible: image_ratio / frame_ratio,
        }
      }
  }
}

///|
fn image_fit_width_placement(
  frame : @core.Rect,
  image_ratio : Double,
) -> ImagePlacement {
  let scaled_height = frame.size.width / image_ratio
  if scaled_height <= frame.size.height {
    {
      frame: @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + (frame.size.height - scaled_height) / 2.0,
        width=frame.size.width,
        height=scaled_height,
      ),
      crop_axis: ImageCropAxis::None,
      visible: 1.0,
    }
  } else {
    {
      frame,
      crop_axis: ImageCropAxis::Vertical,
      visible: frame.size.height / scaled_height,
    }
  }
}

///|
fn image_fit_height_placement(
  frame : @core.Rect,
  image_ratio : Double,
) -> ImagePlacement {
  let scaled_width = frame.size.height * image_ratio
  if scaled_width <= frame.size.width {
    {
      frame: @core.Rect::new(
        x=frame.origin.x + (frame.size.width - scaled_width) / 2.0,
        y=frame.origin.y,
        width=scaled_width,
        height=frame.size.height,
      ),
      crop_axis: ImageCropAxis::None,
      visible: 1.0,
    }
  } else {
    {
      frame,
      crop_axis: ImageCropAxis::Horizontal,
      visible: frame.size.width / scaled_width,
    }
  }
}

///|
fn image_contain_placement(
  frame : @core.Rect,
  image_size : @core.Size,
) -> ImagePlacement {
  let scale = (frame.size.width / image_size.width).min(
    frame.size.height / image_size.height,
  )
  let width = image_size.width * scale
  let height = image_size.height * scale
  {
    frame: @core.Rect::new(
      x=frame.origin.x + (frame.size.width - width) / 2.0,
      y=frame.origin.y + (frame.size.height - height) / 2.0,
      width~,
      height~,
    ),
    crop_axis: ImageCropAxis::None,
    visible: 1.0,
  }
}
