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
export const frameTick: (timeMs: number) => boolean;
export const takeHostUpdates: () => string;
export const dispatchTextInput: (kind: number, text: string, start: number, end: number) => boolean;
export const dispatchCommand: (kind: number) => boolean;
export const dispatchAccessibility: (elementId: number, action: number, value: string) => boolean;
export const completeClipboard: (id: number, kind: number, text: string, bytes: ArrayBuffer) => boolean;
export const detachSurface: () => boolean;
