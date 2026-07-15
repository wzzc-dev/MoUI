import { NodeController } from '@kit.ArkUI';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x4D4F;
const TAG: string = 'MoUIHarmony';
const HOST_WIRE_SCHEMA_VERSION: number = 1;

function platformViewKey(kind: string, id: string): string {
  return `${kind.length}:${kind}${id}`;
}

export interface MoUIPoint {
  x: number;
  y: number;
}

export interface MoUISize {
  width: number;
  height: number;
}

export interface MoUIRect {
  origin: MoUIPoint;
  size: MoUISize;
}

export interface MoUIProperty {
  key: string;
  value: string;
}

export interface MoUIPlatformViewPlacementPayload {
  id: string;
  kind: string;
  frame: MoUIRect;
  clip?: MoUIRect | null;
  properties: MoUIProperty[];
}

export interface MoUIPlatformViewSnapshotPayload {
  revision: number;
  placements: MoUIPlatformViewPlacementPayload[];
}

export interface MoUIPlatformViewEvent {
  name: string;
  value: string;
  detail: string;
  flag: boolean;
}

interface PlatformViewResponseEnvelopePayload {
  kind: string;
  revision: number;
  viewKind: string;
  id: string;
  event: MoUIPlatformViewEvent;
}

interface PlatformChannelResponseEnvelopePayload {
  kind: string;
  requestId: number;
  status: MoUIHostServiceStatus;
  payload: string;
}

interface PlatformViewResponseEnvelope {
  schemaVersion: number;
  sessionGeneration: number;
  response: PlatformViewResponseEnvelopePayload;
}

interface PlatformChannelResponseEnvelope {
  schemaVersion: number;
  sessionGeneration: number;
  response: PlatformChannelResponseEnvelopePayload;
}

export class MoUIPlatformViewPlacement {
  readonly id: string;
  readonly kind: string;
  readonly frame: MoUIRect;
  readonly clip?: MoUIRect;
  readonly properties: Map<string, string>;

  constructor(payload: MoUIPlatformViewPlacementPayload) {
    this.id = payload.id;
    this.kind = payload.kind;
    this.frame = payload.frame;
    this.clip = payload.clip ?? undefined;
    this.properties = new Map<string, string>();
    payload.properties.forEach((property: MoUIProperty) => {
      this.properties.set(property.key, property.value);
    });
  }
}

export class MoUIPlatformViewEventSink {
  private readonly sendEvent: (event: MoUIPlatformViewEvent) => boolean;

  constructor(sendEvent: (event: MoUIPlatformViewEvent) => boolean) {
    this.sendEvent = sendEvent;
  }

  send(name: string, value: string = '', detail: string = '', flag: boolean = false): boolean {
    if (name.length === 0) {
      return false;
    }
    return this.sendEvent({ name: name, value: value, detail: detail, flag: flag });
  }
}

export interface MoUIPlatformViewFactory {
  create(id: string, events: MoUIPlatformViewEventSink): NodeController;
  update(controller: NodeController, placement: MoUIPlatformViewPlacement): void;
  dispose(controller: NodeController): void;
}

export interface MoUIHostServiceRequest {
  channel: string;
  operation: string;
  payload: string;
}

export type MoUIHostServiceStatus = 'ok' | 'error' | 'unavailable';

export interface MoUIHostServiceResponse {
  status: MoUIHostServiceStatus;
  payload: string;
}

export interface MoUIHostServiceTask {
  cancel(): void;
}

export class MoUIHostServiceCompletion {
  private finished: boolean = false;
  private deliver?: (response: MoUIHostServiceResponse) => void;

  constructor(deliver: (response: MoUIHostServiceResponse) => void) {
    this.deliver = deliver;
  }

  complete(response: MoUIHostServiceResponse): boolean {
    if (this.finished || this.deliver === undefined) {
      return false;
    }
    const callback = this.deliver;
    this.finished = true;
    this.deliver = undefined;
    callback(response);
    return true;
  }

  ok(payload: string = ''): boolean {
    return this.complete({ status: 'ok', payload: payload });
  }

  error(payload: string = ''): boolean {
    return this.complete({ status: 'error', payload: payload });
  }

  unavailable(payload: string = ''): boolean {
    return this.complete({ status: 'unavailable', payload: payload });
  }

  invalidate(): void {
    this.finished = true;
    this.deliver = undefined;
  }

  isFinished(): boolean {
    return this.finished;
  }
}

export interface MoUIHostServiceHandler {
  handle(request: MoUIHostServiceRequest, completion: MoUIHostServiceCompletion): MoUIHostServiceTask | undefined;
}

export interface MoUIPlugin {
  readonly id: string;
  install(registry: MoUIPluginRegistry): void;
}

export class MoUIPluginRegistry {
  static readonly shared: MoUIPluginRegistry = new MoUIPluginRegistry();
  private readonly installedPluginIds: Set<string> = new Set<string>();
  private readonly platformViewFactories: Map<string, MoUIPlatformViewFactory> =
    new Map<string, MoUIPlatformViewFactory>();
  private readonly hostServiceHandlers: Map<string, MoUIHostServiceHandler> =
    new Map<string, MoUIHostServiceHandler>();

  install(plugins: MoUIPlugin[]): void {
    plugins.forEach((plugin: MoUIPlugin) => {
      if (this.installedPluginIds.has(plugin.id)) {
        return;
      }
      if (plugin.id.length === 0 || plugin.id.startsWith('moui.')) {
        throw new Error(`invalid or reserved plugin id: ${plugin.id}`);
      }
      this.installedPluginIds.add(plugin.id);
      plugin.install(this);
    });
  }

  registerPlatformView(kind: string, factory: MoUIPlatformViewFactory): void {
    if (kind.length === 0 || kind.startsWith('moui.')) {
      throw new Error(`invalid or reserved PlatformView kind: ${kind}`);
    }
    if (this.platformViewFactories.has(kind)) {
      throw new Error(`duplicate PlatformView kind: ${kind}`);
    }
    this.platformViewFactories.set(kind, factory);
  }

  registerHostService(channel: string, handler: MoUIHostServiceHandler): void {
    if (channel.length === 0 || channel.startsWith('moui.')) {
      throw new Error(`invalid or reserved Host Service channel: ${channel}`);
    }
    if (this.hostServiceHandlers.has(channel)) {
      throw new Error(`duplicate Host Service channel: ${channel}`);
    }
    this.hostServiceHandlers.set(channel, handler);
  }

  platformViewFactory(kind: string): MoUIPlatformViewFactory | undefined {
    return this.platformViewFactories.get(kind);
  }

  hostServiceHandler(channel: string): MoUIHostServiceHandler | undefined {
    return this.hostServiceHandlers.get(channel);
  }
}

export class MoUIHostedPlatformView {
  readonly key: string;
  readonly kind: string;
  readonly id: string;
  readonly controller: NodeController;
  readonly token: number;
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;
  childX: number = 0;
  childY: number = 0;
  childWidth: number = 0;
  childHeight: number = 0;
  zIndex: number = 0;

  constructor(kind: string, id: string, controller: NodeController, token: number) {
    this.key = platformViewKey(kind, id);
    this.kind = kind;
    this.id = id;
    this.controller = controller;
    this.token = token;
  }
}

export class MoUIPlatformViewController {
  private readonly dispatchEnvelope: (encoded: string) => boolean;
  private readonly hosted: Map<string, MoUIHostedPlatformView> = new Map<string, MoUIHostedPlatformView>();
  private sessionGeneration: number = 0;
  private revision: number = -1;
  private nextToken: number = 1;

  constructor(dispatchEnvelope: (encoded: string) => boolean) {
    this.dispatchEnvelope = dispatchEnvelope;
  }

  sync(payload: MoUIPlatformViewSnapshotPayload, generation: number): MoUIHostedPlatformView[] {
    if (generation <= 0) {
      return this.values();
    }
    if (generation !== this.sessionGeneration) {
      this.clear();
      this.sessionGeneration = generation;
    }
    if (payload.revision <= this.revision) {
      return this.values();
    }
    this.revision = payload.revision;
    const activeKeys: Set<string> = new Set<string>();
    payload.placements.forEach((raw: MoUIPlatformViewPlacementPayload) => {
      const placement = new MoUIPlatformViewPlacement(raw);
      const key = platformViewKey(placement.kind, placement.id);
      activeKeys.add(key);
      let hosted = this.hosted.get(key);
      if (hosted === undefined) {
        const factory = MoUIPluginRegistry.shared.platformViewFactory(placement.kind);
        if (factory === undefined) {
          hilog.warn(DOMAIN, TAG, 'PlatformView factory unavailable kind=%{public}s', placement.kind);
          return;
        }
        const token = this.nextToken++;
        const events = new MoUIPlatformViewEventSink((event: MoUIPlatformViewEvent): boolean => {
          return this.dispatchEvent(key, token, event);
        });
        hosted = new MoUIHostedPlatformView(placement.kind, placement.id, factory.create(placement.id, events), token);
        this.hosted.set(key, hosted);
      }
      this.applyLayout(hosted, placement);
      const factory = MoUIPluginRegistry.shared.platformViewFactory(placement.kind);
      if (factory !== undefined) {
        factory.update(hosted.controller, placement);
      }
    });
    const stale: string[] = [];
    this.hosted.forEach((_value: MoUIHostedPlatformView, key: string) => {
      if (!activeKeys.has(key)) {
        stale.push(key);
      }
    });
    stale.forEach((key: string) => this.remove(key));
    const ordered: MoUIHostedPlatformView[] = [];
    payload.placements.forEach((placement: MoUIPlatformViewPlacementPayload) => {
      const hosted = this.hosted.get(platformViewKey(placement.kind, placement.id));
      if (hosted !== undefined && hosted.width > 0 && hosted.height > 0) {
        hosted.zIndex = ordered.length + 1;
        ordered.push(hosted);
      }
    });
    return ordered;
  }

  clear(): void {
    const keys: string[] = [];
    this.hosted.forEach((_value: MoUIHostedPlatformView, key: string) => keys.push(key));
    keys.forEach((key: string) => this.remove(key));
    this.revision = -1;
    this.sessionGeneration = 0;
  }

  private values(): MoUIHostedPlatformView[] {
    const values: MoUIHostedPlatformView[] = [];
    this.hosted.forEach((value: MoUIHostedPlatformView) => values.push(value));
    return values;
  }

  private remove(key: string): void {
    const hosted = this.hosted.get(key);
    if (hosted === undefined) {
      return;
    }
    this.hosted.delete(key);
    const factory = MoUIPluginRegistry.shared.platformViewFactory(hosted.kind);
    if (factory !== undefined) {
      factory.dispose(hosted.controller);
    }
  }

  private dispatchEvent(key: string, token: number, event: MoUIPlatformViewEvent): boolean {
    const hosted = this.hosted.get(key);
    if (hosted === undefined || hosted.token !== token || this.sessionGeneration <= 0 || this.revision <= 0) {
      return false;
    }
    const envelope: PlatformViewResponseEnvelope = {
      schemaVersion: HOST_WIRE_SCHEMA_VERSION,
      sessionGeneration: this.sessionGeneration,
      response: {
        kind: 'platform-view',
        revision: this.revision,
        viewKind: hosted.kind,
        id: hosted.id,
        event: event
      }
    };
    return this.dispatchEnvelope(JSON.stringify(envelope));
  }

  private applyLayout(hosted: MoUIHostedPlatformView, placement: MoUIPlatformViewPlacement): void {
    const frame = placement.frame;
    let left = frame.origin.x;
    let top = frame.origin.y;
    let right = left + Math.max(0, frame.size.width);
    let bottom = top + Math.max(0, frame.size.height);
    if (placement.clip !== undefined) {
      const clip = placement.clip;
      left = Math.max(left, clip.origin.x);
      top = Math.max(top, clip.origin.y);
      right = Math.min(right, clip.origin.x + Math.max(0, clip.size.width));
      bottom = Math.min(bottom, clip.origin.y + Math.max(0, clip.size.height));
    }
    hosted.x = left;
    hosted.y = top;
    hosted.width = Math.max(0, right - left);
    hosted.height = Math.max(0, bottom - top);
    hosted.childX = frame.origin.x - left;
    hosted.childY = frame.origin.y - top;
    hosted.childWidth = Math.max(0, frame.size.width);
    hosted.childHeight = Math.max(0, frame.size.height);
  }
}

export interface PlatformChannelPayload {
  channel: string;
  operation: string;
  payload: string;
}

export interface PlatformChannelUpdate {
  id: number;
  payload: PlatformChannelPayload;
}

class PendingHostService {
  readonly completion: MoUIHostServiceCompletion;
  task?: MoUIHostServiceTask;

  constructor(completion: MoUIHostServiceCompletion) {
    this.completion = completion;
  }

  cancel(): void {
    this.completion.invalidate();
    if (this.task !== undefined) {
      this.task.cancel();
      this.task = undefined;
    }
  }
}

export class MoUIHostServices {
  private readonly dispatchEnvelope: (encoded: string) => boolean;
  private readonly pending: Map<string, PendingHostService> = new Map<string, PendingHostService>();

  constructor(dispatchEnvelope: (encoded: string) => boolean) {
    this.dispatchEnvelope = dispatchEnvelope;
  }

  dispatch(update: PlatformChannelUpdate, generation: number): boolean {
    if (generation <= 0 || update.id <= 0) {
      return false;
    }
    const key = `${generation}:${update.id}`;
    if (this.pending.has(key)) {
      hilog.warn(DOMAIN, TAG, 'duplicate PlatformChannel request key=%{public}s', key);
      return false;
    }
    const completion = new MoUIHostServiceCompletion((response: MoUIHostServiceResponse): void => {
      this.finish(key, generation, update.id, response);
    });
    const pending = new PendingHostService(completion);
    this.pending.set(key, pending);
    const payload = update.payload;
    if (payload.channel.length === 0 || payload.operation.length === 0) {
      return completion.error('invalid platform channel request');
    }
    const handler = MoUIPluginRegistry.shared.hostServiceHandler(payload.channel);
    if (handler === undefined) {
      return completion.unavailable(`platform channel is unavailable: ${payload.channel}`);
    }
    try {
      const task = handler.handle({
        channel: payload.channel,
        operation: payload.operation,
        payload: payload.payload
      }, completion);
      if (completion.isFinished() || this.pending.get(key) !== pending) {
        if (task !== undefined) {
          task.cancel();
        }
      } else {
        pending.task = task;
      }
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'platform channel handler failed';
      return completion.error(message);
    }
  }

  reset(): void {
    const values: PendingHostService[] = [];
    this.pending.forEach((value: PendingHostService) => values.push(value));
    this.pending.clear();
    values.forEach((value: PendingHostService) => value.cancel());
  }

  private finish(
    key: string,
    generation: number,
    requestId: number,
    response: MoUIHostServiceResponse
  ): void {
    if (!this.pending.has(key)) {
      return;
    }
    this.pending.delete(key);
    const envelope: PlatformChannelResponseEnvelope = {
      schemaVersion: HOST_WIRE_SCHEMA_VERSION,
      sessionGeneration: generation,
      response: {
        kind: 'platform-channel',
        requestId: requestId,
        status: response.status,
        payload: response.payload
      }
    };
    if (!this.dispatchEnvelope(JSON.stringify(envelope))) {
      hilog.warn(DOMAIN, TAG, 'late/rejected PlatformChannel completion key=%{public}s', key);
    }
  }
}
