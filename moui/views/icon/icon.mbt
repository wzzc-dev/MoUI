/// Built-in icon glyphs. IconName enum lives in style/style_api.mbt.

///|
/// 24x24 viewBox stroke path data for each icon.
pub fn icon_path(name : @style.IconName) -> Array[@core.PathVerb] {
  match name {
    Check =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=13.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=6.0)),
      ]
    Close =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=18.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=18.0)),
      ]
    ChevronDown =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=9.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=15.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=9.0)),
      ]
    ChevronRight =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=18.0)),
      ]
    ChevronLeft =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=15.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=18.0)),
      ]
    Plus =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=19.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
      ]
    Minus =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
      ]
    Search =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=11.0, y=11.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=21.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=15.0, y=15.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=15.0),
          @core.Point::new(x=10.0, y=12.0),
          @core.Point::new(x=10.0, y=12.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=10.0, y=12.0),
          @core.Point::new(x=10.0, y=6.0),
          @core.Point::new(x=14.0, y=6.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=14.0, y=6.0),
          @core.Point::new(x=18.0, y=6.0),
          @core.Point::new(x=18.0, y=12.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=18.0, y=12.0),
          @core.Point::new(x=18.0, y=15.0),
          @core.Point::new(x=15.0, y=15.0),
        ),
      ]
    ArrowRight =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=13.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=13.0, y=18.0)),
      ]
    Settings =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=15.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=15.0),
          @core.Point::new(x=12.0, y=16.5),
          @core.Point::new(x=12.0, y=16.5),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=16.5),
          @core.Point::new(x=7.5, y=16.5),
          @core.Point::new(x=7.5, y=16.5),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=7.5, y=16.5),
          @core.Point::new(x=7.5, y=15.0),
          @core.Point::new(x=7.5, y=15.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=7.5, y=15.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=7.5)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=7.5),
          @core.Point::new(x=12.0, y=9.0),
          @core.Point::new(x=12.0, y=9.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=9.0),
          @core.Point::new(x=16.5, y=9.0),
          @core.Point::new(x=16.5, y=9.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=16.5, y=9.0),
          @core.Point::new(x=16.5, y=7.5),
          @core.Point::new(x=16.5, y=7.5),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=16.5, y=7.5)),
      ]
    Trash =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=3.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=4.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=8.0, y=4.0),
          @core.Point::new(x=8.0, y=3.0),
          @core.Point::new(x=9.0, y=3.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=9.0, y=3.0),
          @core.Point::new(x=15.0, y=3.0),
          @core.Point::new(x=16.0, y=3.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=16.0, y=3.0),
          @core.Point::new(x=16.0, y=4.0),
          @core.Point::new(x=16.0, y=4.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=21.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=5.0, y=21.0),
          @core.Point::new(x=5.0, y=22.0),
          @core.Point::new(x=6.0, y=22.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=6.0, y=22.0),
          @core.Point::new(x=18.0, y=22.0),
          @core.Point::new(x=18.0, y=22.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=18.0, y=22.0),
          @core.Point::new(x=19.0, y=22.0),
          @core.Point::new(x=19.0, y=21.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=6.0)),
      ]
    Info =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=16.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=8.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=22.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=22.0),
          @core.Point::new(x=6.5, y=22.0),
          @core.Point::new(x=2.0, y=17.5),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=2.0, y=17.5),
          @core.Point::new(x=2.0, y=6.5),
          @core.Point::new(x=6.5, y=2.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=6.5, y=2.0),
          @core.Point::new(x=17.5, y=2.0),
          @core.Point::new(x=22.0, y=6.5),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=22.0, y=6.5),
          @core.Point::new(x=22.0, y=17.5),
          @core.Point::new(x=17.5, y=22.0),
        ),
        @core.PathVerb::Close,
      ]
    FileNew =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=14.0, y=2.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=8.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=2.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=2.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=22.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=20.0, y=22.0),
          @core.Point::new(x=20.0, y=22.0),
          @core.Point::new(x=19.0, y=22.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=19.0, y=22.0),
          @core.Point::new(x=5.0, y=22.0),
          @core.Point::new(x=4.0, y=22.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=4.0, y=22.0),
          @core.Point::new(x=4.0, y=2.0),
          @core.Point::new(x=4.0, y=2.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=2.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=15.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=15.0)),
      ]
    FolderOpen =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=3.0, y=7.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=3.0, y=7.0),
          @core.Point::new(x=3.0, y=6.0),
          @core.Point::new(x=4.0, y=6.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=11.0, y=9.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=9.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=20.0, y=9.0),
          @core.Point::new(x=21.0, y=9.0),
          @core.Point::new(x=21.0, y=10.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=17.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=14.0)),
      ]
    Save =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=17.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=17.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=7.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=3.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=5.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=21.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=21.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=19.0, y=8.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=19.0, y=8.0),
          @core.Point::new(x=19.0, y=7.5),
          @core.Point::new(x=18.7, y=7.3),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=15.7, y=4.3)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=15.7, y=4.3),
          @core.Point::new(x=15.5, y=4.0),
          @core.Point::new(x=15.0, y=4.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=5.0, y=4.0)),
        @core.PathVerb::Close,
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=17.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=11.0)),
      ]
    Clipboard =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=3.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=3.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=18.0, y=3.0),
          @core.Point::new(x=18.5, y=3.0),
          @core.Point::new(x=18.5, y=3.5),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=18.5, y=22.5)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=18.5, y=22.5),
          @core.Point::new(x=18.5, y=23.0),
          @core.Point::new(x=18.0, y=23.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=23.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=6.0, y=23.0),
          @core.Point::new(x=5.5, y=23.0),
          @core.Point::new(x=5.5, y=22.5),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=5.5, y=3.5)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=5.5, y=3.5),
          @core.Point::new(x=5.5, y=3.0),
          @core.Point::new(x=6.0, y=3.0),
        ),
        @core.PathVerb::Close,
      ]
    Bold =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=20.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=4.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=4.0),
          @core.Point::new(x=18.0, y=4.0),
          @core.Point::new(x=18.0, y=12.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=18.0, y=12.0),
          @core.Point::new(x=18.0, y=20.0),
          @core.Point::new(x=12.0, y=20.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=20.0)),
      ]
    Italic =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=4.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=20.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=20.0)),
      ]
    CodeInline =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=16.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=22.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=16.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=2.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=18.0)),
      ]
    Link =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=13.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=10.0, y=13.0),
          @core.Point::new(x=10.0, y=18.0),
          @core.Point::new(x=14.0, y=18.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=14.0, y=18.0),
          @core.Point::new(x=18.0, y=18.0),
          @core.Point::new(x=18.0, y=13.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=18.0, y=13.0),
          @core.Point::new(x=18.0, y=9.0),
          @core.Point::new(x=14.0, y=9.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=9.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=14.0, y=11.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=14.0, y=11.0),
          @core.Point::new(x=14.0, y=6.0),
          @core.Point::new(x=10.0, y=6.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=10.0, y=6.0),
          @core.Point::new(x=6.0, y=6.0),
          @core.Point::new(x=6.0, y=11.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=6.0, y=11.0),
          @core.Point::new(x=6.0, y=15.0),
          @core.Point::new(x=10.0, y=15.0),
        ),
        @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=15.0)),
      ]
    Heading =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=20.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=18.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=20.0)),
      ]
    ListBullet =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=8.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=18.0)),
      ]
    ListOrdered =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=4.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=8.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=10.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=14.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=17.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=20.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=20.0)),
      ]
    ListTask =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=18.0, y=18.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=8.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=6.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=13.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=13.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=16.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=6.0, y=16.0)),
      ]
    Quote =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=3.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=7.0, y=18.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=7.0, y=18.0),
          @core.Point::new(x=7.0, y=12.0),
          @core.Point::new(x=7.0, y=6.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=3.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=11.0, y=6.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=17.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=18.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=21.0, y=18.0),
          @core.Point::new(x=21.0, y=12.0),
          @core.Point::new(x=21.0, y=6.0),
        ),
        @core.PathVerb::MoveTo(@core.Point::new(x=17.0, y=18.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=11.0, y=6.0)),
      ]
    Table =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=3.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=21.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=3.0, y=21.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=3.0, y=3.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=3.0, y=9.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=9.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=3.0, y=15.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=21.0, y=15.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=21.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=15.0, y=3.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=15.0, y=21.0)),
      ]
    Eye =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=1.0, y=12.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=1.0, y=12.0),
          @core.Point::new(x=5.0, y=4.0),
          @core.Point::new(x=12.0, y=4.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=4.0),
          @core.Point::new(x=19.0, y=4.0),
          @core.Point::new(x=23.0, y=12.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=23.0, y=12.0),
          @core.Point::new(x=19.0, y=20.0),
          @core.Point::new(x=12.0, y=20.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=20.0),
          @core.Point::new(x=5.0, y=20.0),
          @core.Point::new(x=1.0, y=12.0),
        ),
        @core.PathVerb::Close,
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=15.0)),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=15.0),
          @core.Point::new(x=15.0, y=15.0),
          @core.Point::new(x=15.0, y=12.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=15.0, y=12.0),
          @core.Point::new(x=15.0, y=9.0),
          @core.Point::new(x=12.0, y=9.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=12.0, y=9.0),
          @core.Point::new(x=9.0, y=9.0),
          @core.Point::new(x=9.0, y=12.0),
        ),
        @core.PathVerb::CubicTo(
          @core.Point::new(x=9.0, y=12.0),
          @core.Point::new(x=9.0, y=15.0),
          @core.Point::new(x=12.0, y=15.0),
        ),
      ]
    Focus =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=2.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=14.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=22.0, y=12.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=2.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=10.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=14.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=22.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=12.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=12.0)),
      ]
    Columns =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=12.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=19.0)),
      ]
    Sidebar =>
      [
        @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=19.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=5.0)),
        @core.PathVerb::MoveTo(@core.Point::new(x=9.0, y=5.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=9.0, y=19.0)),
      ]
  }
}

///|
/// Scale a single normalized 24x24 path point into the icon's paint frame.
pub fn icon_scale_point(
  point : @core.Point,
  origin_x : Double,
  origin_y : Double,
  scale : Double,
) -> @core.Point {
  @core.Point::new(x=origin_x + point.x * scale, y=origin_y + point.y * scale)
}

///|
/// Scale a full 24x24 verb list into the icon's paint frame.
pub fn icon_scale_verbs(
  verbs : Array[@core.PathVerb],
  origin_x : Double,
  origin_y : Double,
  scale : Double,
) -> Array[@core.PathVerb] {
  let scaled : Array[@core.PathVerb] = []
  for verb in verbs {
    match verb {
      @core.PathVerb::MoveTo(point) =>
        scaled.push(
          @core.PathVerb::MoveTo(
            icon_scale_point(point, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::LineTo(point) =>
        scaled.push(
          @core.PathVerb::LineTo(
            icon_scale_point(point, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::QuadTo(control, end) =>
        scaled.push(
          @core.PathVerb::QuadTo(
            icon_scale_point(control, origin_x, origin_y, scale),
            icon_scale_point(end, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::CubicTo(c1, c2, end) =>
        scaled.push(
          @core.PathVerb::CubicTo(
            icon_scale_point(c1, origin_x, origin_y, scale),
            icon_scale_point(c2, origin_x, origin_y, scale),
            icon_scale_point(end, origin_x, origin_y, scale),
          ),
        )
      @core.PathVerb::Close => scaled.push(@core.PathVerb::Close)
    }
  }
  scaled
}

///|
/// A vector icon rendered from normalized 24x24 stroke path data.
pub fn[Msg] icon(
  name : @style.IconName,
  size? : Double = 20.0,
  color? : @core.Color,
  weight? : Double = 1.6,
) -> @core.View[Msg] {
  let verbs = icon_path(name)
  let label = icon_label(name)
  let resolved_color = match color {
    Some(value) => value
    None => @style.default_theme().palette.foreground
  }
  @core.View::from_node(Icon::{
    label,
    size,
    color: resolved_color,
    weight,
    verbs,
  })
}

///|
priv struct Icon {
  label : String
  size : Double
  color : @core.Color
  weight : Double
  verbs : Array[@core.PathVerb] // declaration-exempt: derived from `name` at construction; `label = icon_label(name)` is injective and keyed in paint
}

///|
impl @core.ViewNode for Icon with fn identity(_self) {
  @core.ViewIdentity::new(kind="Icon")
}

///|
impl @core.ViewNode for Icon with fn declaration(self) {
  @common.view_declaration(
    layout=@common.view_exact_channel(@core.DeclarationKey::double(self.size)),
    paint=@common.view_exact_channel(
      @common.view_record_key("Icon.paint", [
        ("label", @core.DeclarationKey::string(self.label)),
        ("size", @core.DeclarationKey::double(self.size)),
        ("color", @common.view_color_key(self.color)),
        ("weight", @core.DeclarationKey::double(self.weight)),
      ]),
    ),
    semantics=@common.view_exact_channel(
      @core.DeclarationKey::string(self.label),
    ),
  )
}

///|
impl @core.ViewNode for Icon with fn layout(self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=self.size, height=self.size),
    ),
  )
}

///|
impl @core.ViewNode for Icon with fn paint(self, context) {
  let side = @common.view_min_double(
    context.frame.size.width,
    context.frame.size.height,
  )
  let scale = side / 24.0
  let origin_x = context.frame.origin.x +
    (context.frame.size.width - side) / 2.0
  let origin_y = context.frame.origin.y +
    (context.frame.size.height - side) / 2.0
  let scaled = icon_scale_verbs(self.verbs, origin_x, origin_y, scale)
  @core.ViewPaintPlan::commands([
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=scaled,
        stroke=Some(@core.Brush::solid(self.color)),
        stroke_width=self.weight,
      ),
    ),
  ])
}

///|
impl @core.ViewNode for Icon with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Text,
    label=self.label,
  )
}

///|
/// Human-readable label for an icon.
pub fn icon_label(name : @style.IconName) -> String {
  match name {
    Check => "Check"
    Close => "Close"
    ChevronDown => "Chevron down"
    ChevronRight => "Chevron right"
    ChevronLeft => "Chevron left"
    Plus => "Plus"
    Minus => "Minus"
    Search => "Search"
    ArrowRight => "Arrow right"
    Settings => "Settings"
    Trash => "Trash"
    Info => "Info"
    FileNew => "New file"
    FolderOpen => "Open"
    Save => "Save"
    Clipboard => "Clipboard"
    Bold => "Bold"
    Italic => "Italic"
    CodeInline => "Code"
    Link => "Link"
    Heading => "Heading"
    ListBullet => "Bullet list"
    ListOrdered => "Ordered list"
    ListTask => "Task list"
    Quote => "Quote"
    Table => "Table"
    Eye => "Eye"
    Focus => "Focus"
    Columns => "Columns"
    Sidebar => "Sidebar"
  }
}
