import { FrameNode, NodeController, UIContext } from '@kit.ArkUI';
import pasteboard from '@ohos.pasteboard';
import hilog from '@ohos.hilog';

import {
  MoUIHostServiceCompletion,
  MoUIHostServiceHandler,
  MoUIHostServiceRequest,
  MoUIHostServiceTask,
  MoUIPlatformViewEventSink,
  MoUIPlatformViewFactory,
  MoUIPlatformViewPlacement,
  MoUIPlugin,
  MoUIPluginRegistry,
  MoUIRuntimeInputDispatcher,
  MoUISemanticsNodeSnapshot,
  MoUISemanticsObserver,
  MoUISemanticsSnapshot
} from '../../../../moui/MoUIPlugins';

const DOMAIN: number = 0x4D4F;
const TAG: string = 'MoUIHarmony';
const PLUGIN_ID: string = 'dev.wzzc.moui.shell.test-probe';
const PLATFORM_VIEW_KIND: string = `${PLUGIN_ID}.view`;
const HOST_CHANNEL: string = `${PLUGIN_ID}.channel`;
const TEST_PROBE_GATE: string = 'moui.shell.testProbe';
const SERVICE_TEXT_LABEL: string = 'Service probe text';
const SERVICE_ACTION_LABEL: string = 'Activate service probe';
const SERVICE_PROBE_TEXT: string = 'ime-shell-probe';

class ProbeState {
  static readonly shared: ProbeState = new ProbeState();
  platformViewCreate: number = 0;
  platformViewResize: number = 0;
  platformViewClip: number = 0;
  platformViewEvent: number = 0;
  platformViewDispose: number = 0;
  hostChannelSuccess: number = 0;
  hostChannelError: number = 0;
  hostChannelCancel: number = 0;
  hostChannelExactlyOnce: number = 0;
  hostChannelLateAfterDispose: number = 0;
  serviceSmokeFired: number = 0;
  serviceSmokeCompleted: number = 0;

  increment(counter: string): void {
    switch (counter) {
      case 'platformViewCreate': this.platformViewCreate += 1; break;
      case 'platformViewResize': this.platformViewResize += 1; break;
      case 'platformViewClip': this.platformViewClip += 1; break;
      case 'platformViewEvent': this.platformViewEvent += 1; break;
      case 'platformViewDispose': this.platformViewDispose += 1; break;
      case 'hostChannelSuccess': this.hostChannelSuccess += 1; break;
      case 'hostChannelError': this.hostChannelError += 1; break;
      case 'hostChannelCancel': this.hostChannelCancel += 1; break;
      case 'hostChannelExactlyOnce': this.hostChannelExactlyOnce += 1; break;
      case 'hostChannelLateAfterDispose': this.hostChannelLateAfterDispose += 1; break;
      case 'serviceSmokeFired': this.serviceSmokeFired += 1; break;
      case 'serviceSmokeCompleted': this.serviceSmokeCompleted += 1; break;
      default: return;
    }
    hilog.info(DOMAIN, TAG, 'moui-shell test-probe snapshot=%{public}s', this.snapshot());
  }

  snapshot(): string {
    return JSON.stringify({
      platformViewCreate: this.platformViewCreate,
      platformViewResize: this.platformViewResize,
      platformViewClip: this.platformViewClip,
      platformViewEvent: this.platformViewEvent,
      platformViewDispose: this.platformViewDispose,
      hostChannelSuccess: this.hostChannelSuccess,
      hostChannelError: this.hostChannelError,
      hostChannelCancel: this.hostChannelCancel,
      hostChannelExactlyOnce: this.hostChannelExactlyOnce,
      hostChannelLateAfterDispose: this.hostChannelLateAfterDispose,
      serviceSmokeFired: this.serviceSmokeFired,
      serviceSmokeCompleted: this.serviceSmokeCompleted
    });
  }
}

class ProbeServiceSmoke implements MoUISemanticsObserver {
  private readonly registry: MoUIPluginRegistry;
  private fired: boolean = false;

  constructor(registry: MoUIPluginRegistry) {
    this.registry = registry;
  }

  install(): void {
    this.registry.capabilities.semantics.observe(this);
  }

  onSemantics(snapshot: MoUISemanticsSnapshot, runtimeInput: MoUIRuntimeInputDispatcher): void {
    if (!this.launchOptionEnabled(this.registry.launchOption(TEST_PROBE_GATE)) ||
      this.fired || ProbeState.shared.serviceSmokeFired > 0) {
      return;
    }
    const textField = this.findNode(snapshot.nodes, SERVICE_TEXT_LABEL, 'TextField');
    const action = this.findNode(snapshot.nodes, SERVICE_ACTION_LABEL, 'Button');
    if (textField === undefined || action === undefined) {
      return;
    }
    this.fired = true;
    ProbeState.shared.increment('serviceSmokeFired');
    hilog.info(DOMAIN, TAG,
      'moui-shell service smoke begin textFieldId=%{public}d actionId=%{public}d',
      textField.elementId, action.elementId);
    const textFocusAccepted = runtimeInput.dispatchAccessibility(textField.elementId, 1);
    let accepted = textFocusAccepted;
    const setTextAccepted = runtimeInput.dispatchAccessibility(textField.elementId, 2, SERVICE_PROBE_TEXT);
    accepted = setTextAccepted && accepted;
    const imeCommitAccepted = runtimeInput.dispatchTextInput(1, SERVICE_PROBE_TEXT, 0, 0);
    accepted = imeCommitAccepted && accepted;
    if (imeCommitAccepted) {
      hilog.info(DOMAIN, TAG, 'moui-shell service ime edit kind=commit smoke=1');
    }
    const selectionAccepted = runtimeInput.dispatchTextInput(2, '', 0, SERVICE_PROBE_TEXT.length);
    accepted = selectionAccepted && accepted;
    const copyAccepted = runtimeInput.dispatchCommand(0);
    accepted = copyAccepted && accepted;
    if (copyAccepted) {
      hilog.info(DOMAIN, TAG, 'moui-shell service smoke copy');
    }
    try {
      const board = pasteboard.getSystemPasteboard();
      board.setDataSync(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, 'clipboard-service-probe'));
    } catch (error) {
      accepted = false;
      const message = error instanceof Error ? error.message : 'clipboard seed failed';
      hilog.warn(DOMAIN, TAG, 'moui-shell service smoke seed clipboard failed: %{public}s', message);
    }
    const pasteAccepted = runtimeInput.dispatchCommand(2);
    accepted = pasteAccepted && accepted;
    if (pasteAccepted) {
      hilog.info(DOMAIN, TAG, 'moui-shell service smoke paste');
    }
    const cutAccepted = runtimeInput.dispatchCommand(1);
    accepted = cutAccepted && accepted;
    if (cutAccepted) {
      hilog.info(DOMAIN, TAG, 'moui-shell service smoke cut');
    }
    const actionFocusAccepted = runtimeInput.dispatchAccessibility(action.elementId, 1);
    accepted = actionFocusAccepted && accepted;
    if (actionFocusAccepted) {
      hilog.info(DOMAIN, TAG, 'moui-shell service accessibility focus id=%{public}d', action.elementId);
    }
    const actionActivateAccepted = runtimeInput.dispatchAccessibility(action.elementId, 0);
    accepted = actionActivateAccepted && accepted;
    if (actionActivateAccepted) {
      hilog.info(DOMAIN, TAG,
        'moui-shell service accessibility action=activate id=%{public}d', action.elementId);
    }
    if (accepted && runtimeInput.isActive) {
      ProbeState.shared.increment('serviceSmokeCompleted');
    }
    hilog.info(DOMAIN, TAG, 'moui-shell service smoke end accepted=%{public}d', accepted ? 1 : 0);
  }

  private findNode(
    nodes: MoUISemanticsNodeSnapshot[],
    label: string,
    role: string
  ): MoUISemanticsNodeSnapshot | undefined {
    for (let index = 0; index < nodes.length; index += 1) {
      if (nodes[index].label === label && nodes[index].role === role) {
        return nodes[index];
      }
    }
    return undefined;
  }

  private launchOptionEnabled(value?: string): boolean {
    const normalized = value?.trim().toLowerCase();
    return normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on';
  }
}

class ProbeNodeController extends NodeController {
  readonly events: MoUIPlatformViewEventSink;
  lastWidth: number = -1;
  lastHeight: number = -1;
  sentReady: boolean = false;
  private frameNode?: FrameNode;

  constructor(events: MoUIPlatformViewEventSink) {
    super();
    this.events = events;
  }

  makeNode(uiContext: UIContext): FrameNode | null {
    const node = new FrameNode(uiContext);
    this.frameNode = node;
    const renderNode = node.getRenderNode();
    if (renderNode !== null) {
      renderNode.backgroundColor = 0xFF166534;
      renderNode.clipToFrame = true;
      renderNode.size = {
        width: Math.max(1, this.lastWidth),
        height: Math.max(1, this.lastHeight)
      };
    }
    return node;
  }

  updateSize(width: number, height: number): void {
    this.lastWidth = width;
    this.lastHeight = height;
    const renderNode = this.frameNode?.getRenderNode();
    if (renderNode !== undefined && renderNode !== null) {
      renderNode.size = {
        width: Math.max(1, width),
        height: Math.max(1, height)
      };
    }
  }
}

class ProbePlatformViewFactory implements MoUIPlatformViewFactory {
  create(_id: string, events: MoUIPlatformViewEventSink): NodeController {
    ProbeState.shared.increment('platformViewCreate');
    return new ProbeNodeController(events);
  }

  update(controller: NodeController, placement: MoUIPlatformViewPlacement): void {
    const probe = controller as ProbeNodeController;
    if (probe.lastWidth !== placement.frame.size.width || probe.lastHeight !== placement.frame.size.height) {
      ProbeState.shared.increment('platformViewResize');
      probe.updateSize(placement.frame.size.width, placement.frame.size.height);
    }
    if (placement.clip !== undefined) {
      ProbeState.shared.increment('platformViewClip');
    }
    if (!probe.sentReady) {
      probe.sentReady = true;
      if (probe.events.send('ready', placement.id, ProbeState.shared.snapshot(), true)) {
        ProbeState.shared.increment('platformViewEvent');
      }
    }
  }

  dispose(controller: NodeController): void {
    const probe = controller as ProbeNodeController;
    ProbeState.shared.increment('platformViewDispose');
    probe.events.send('disposed', '', ProbeState.shared.snapshot(), false);
  }
}

class ProbePendingTask implements MoUIHostServiceTask {
  private readonly completion: MoUIHostServiceCompletion;
  private readonly operation: string;
  private cancelled: boolean = false;

  constructor(completion: MoUIHostServiceCompletion, operation: string) {
    this.completion = completion;
    this.operation = operation;
  }

  cancel(): void {
    if (this.cancelled) {
      return;
    }
    this.cancelled = true;
    if (this.operation === 'cancel') {
      ProbeState.shared.increment('hostChannelCancel');
    } else if (!this.completion.ok('late-after-dispose')) {
      ProbeState.shared.increment('hostChannelLateAfterDispose');
    }
  }
}

class ProbeHostServiceHandler implements MoUIHostServiceHandler {
  handle(request: MoUIHostServiceRequest, completion: MoUIHostServiceCompletion): MoUIHostServiceTask | undefined {
    switch (request.operation) {
      case 'success':
      case 'echo':
        if (completion.ok(request.payload)) {
          ProbeState.shared.increment('hostChannelSuccess');
        }
        return undefined;
      case 'snapshot':
        completion.ok(ProbeState.shared.snapshot());
        return undefined;
      case 'error':
        if (completion.error(request.payload.length === 0 ? 'test-probe error' : request.payload)) {
          ProbeState.shared.increment('hostChannelError');
        }
        return undefined;
      case 'exactly-once': {
        const firstAccepted = completion.ok('first');
        const duplicateAccepted = completion.error('duplicate');
        if (firstAccepted && !duplicateAccepted) {
          ProbeState.shared.increment('hostChannelExactlyOnce');
        }
        return undefined;
      }
      case 'cancel':
      case 'late-after-dispose':
        return new ProbePendingTask(completion, request.operation);
      default:
        completion.unavailable(`unknown test-probe operation: ${request.operation}`);
        return undefined;
    }
  }
}

export class MoUIShellTestProbePlugin implements MoUIPlugin {
  readonly id: string = PLUGIN_ID;

  install(registry: MoUIPluginRegistry): void {
    registry.registerPlatformView(PLATFORM_VIEW_KIND, new ProbePlatformViewFactory());
    registry.registerHostService(HOST_CHANNEL, new ProbeHostServiceHandler());
    new ProbeServiceSmoke(registry).install();
  }
}
