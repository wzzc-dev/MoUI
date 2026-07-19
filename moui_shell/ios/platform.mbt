///|
pub(all) struct IosNativeView {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn IosNativeView::new(raw~ : UInt64) -> IosNativeView {
  { raw, }
}

///|
pub fn IosNativeView::none() -> IosNativeView {
  { raw: 0UL }
}

///|
pub fn IosNativeView::raw(self : IosNativeView) -> UInt64 {
  self.raw
}

///|
pub fn ios_descriptor() -> @embedding.ShellPlatformDescriptor {
  {
    platform: Ios,
    shell_api_version: @embedding.shell_api_version(),
    embedding_api_version: @embedding.embedding_api_version(),
    capabilities: [
      Surface,
      Pointer,
      Scroll,
      FrameScheduling,
      TextInput,
      Clipboard,
      Accessibility,
      PlatformViews,
      HostChannel,
    ],
  }
}
