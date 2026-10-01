///|
pub struct SunPixelFrame {
  priv width : Int
  priv height : Int
  priv row_bytes : Int
  priv scale_factor : Double
  priv pixels : FixedArray[Byte]
  priv bytes : Bytes
} derive(Debug)

///|
pub extend SunPixelFrame with Debug::{to_repr}

///|
pub struct SunPresentTarget {
  description : String
  present : (SunPixelFrame) -> Bool
}

///|
pub struct SunUnsupportedCommandDiagnostic {
  priv command : String
  priv reason : String
} derive(Eq, Debug, ToJson)

///|
pub extend SunUnsupportedCommandDiagnostic with Debug::{to_repr}

///|
pub extend SunUnsupportedCommandDiagnostic with Eq::{not_equal, equal}

///|
pub extend SunUnsupportedCommandDiagnostic with ToJson::{to_json}

///|
pub fn SunPresentTarget::new(
  description~ : String,
  present~ : (SunPixelFrame) -> Bool,
) -> SunPresentTarget {
  { description, present, }
}

///|
pub fn SunPixelFrame::width(self : SunPixelFrame) -> Int {
  self.width
}

///|
pub fn SunPixelFrame::height(self : SunPixelFrame) -> Int {
  self.height
}

///|
pub fn SunPixelFrame::row_bytes(self : SunPixelFrame) -> Int {
  self.row_bytes
}

///|
pub fn SunPixelFrame::scale_factor(self : SunPixelFrame) -> Double {
  self.scale_factor
}

///|
pub fn SunPixelFrame::pixels(self : SunPixelFrame) -> FixedArray[Byte] {
  self.pixels
}

///|
pub fn SunPixelFrame::bytes(self : SunPixelFrame) -> Bytes {
  self.bytes
}

///|
pub fn SunUnsupportedCommandDiagnostic::command(
  self : SunUnsupportedCommandDiagnostic,
) -> String {
  self.command
}

///|
pub fn SunUnsupportedCommandDiagnostic::reason(
  self : SunUnsupportedCommandDiagnostic,
) -> String {
  self.reason
}
