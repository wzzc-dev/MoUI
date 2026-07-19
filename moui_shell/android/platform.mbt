///|
pub(all) struct AndroidNativeSurface {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn AndroidNativeSurface::new(raw~ : UInt64) -> AndroidNativeSurface {
  { raw, }
}

///|
pub fn AndroidNativeSurface::none() -> AndroidNativeSurface {
  { raw: 0UL }
}

///|
pub fn AndroidNativeSurface::raw(self : AndroidNativeSurface) -> UInt64 {
  self.raw
}

///|
pub fn android_descriptor() -> @embedding.ShellPlatformDescriptor {
  {
    platform: Android,
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
