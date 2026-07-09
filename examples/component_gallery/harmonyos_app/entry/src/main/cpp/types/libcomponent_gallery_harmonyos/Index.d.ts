export const attachSurface: (
  surfaceHandle: number,
  width: number,
  height: number,
  scaleFactor: number
) => boolean;
export const resize: (
  width: number,
  height: number,
  scaleFactor: number
) => boolean;
export const dispatchPointer: (
  phase: number,
  x: number,
  y: number,
  timeMs: number
) => boolean;
export const dispatchScroll: (
  x: number,
  y: number,
  deltaX: number,
  deltaY: number,
  phase: number
) => boolean;
export const renderFrame: () => boolean;
export const detachSurface: () => boolean;
