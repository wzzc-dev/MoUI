///|
pub(all) struct HarmonyosNativeSurface {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn HarmonyosNativeSurface::new(raw~ : UInt64) -> HarmonyosNativeSurface {
  { raw, }
}

///|
pub fn HarmonyosNativeSurface::none() -> HarmonyosNativeSurface {
  { raw: 0UL }
}

///|
pub fn HarmonyosNativeSurface::raw(self : HarmonyosNativeSurface) -> UInt64 {
  self.raw
}

///|
pub fn harmonyos_descriptor() -> @embedding.ShellPlatformDescriptor {
  {
    platform: Harmonyos,
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
