export const frameTick: (timeMs: number) => boolean;
export const takeHostUpdates: () => string;
export const dispatchHostResponseEnvelope: (envelopeJson: string) => boolean;
export const dispatchTextInput: (kind: number, text: string, start: number, end: number) => boolean;
export const dispatchCommand: (kind: number) => boolean;
export const dispatchAccessibility: (elementId: number, action: number, value: string) => boolean;
export const completeClipboard: (
  sessionGeneration: number,
  id: number,
  kind: number,
  text: string,
  bytes: ArrayBuffer
) => boolean;
export const destroyApplication: () => boolean;
