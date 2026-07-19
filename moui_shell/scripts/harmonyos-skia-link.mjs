export const validateHarmonyosSkiaLinkCompatibility = ({
  renderer,
  linkFlags,
}) => {
  const usesDynamicSkia = /(?:^|\s)-lskia(?:\s|$)/.test(linkFlags);
  const usesStaticGaneshExtension = /(?:^|\s)\S*libskia_ganesh_ext\.a(?:\s|$)/.test(linkFlags);
  if (renderer === "skia-gpu" && usesDynamicSkia && usesStaticGaneshExtension) {
    throw new Error(
      "HarmonyOS skia-gpu cannot link the locked dynamic Skia provider: " +
        "libskia_ganesh_ext.a references internal symbols hidden by libskia.so. " +
        "Unset MOUI_SKIA_LINK_MODE or set it to static until the shared provider " +
        "integrates Ganesh or exports the required symbols.",
    );
  }
};
