import mouiRuntime from 'libmoui_mobile_harmonyos.so';
import displaySync from '@ohos.graphics.displaySync';
import pasteboard from '@ohos.pasteboard';
import hilog from '@ohos.hilog';

import { installGeneratedPlugins } from './MoUIGeneratedPlugins';
import {
  MoUIHostServices,
  MoUIHostedPlatformView,
  MoUIPlatformViewController,
  MoUIPlatformViewSnapshotPayload,
  MoUIPluginRegistry,
  MoUIRect,
  MoUIRuntimeInputBindings,
  MoUISemanticsNodeSnapshot,
  PlatformChannelPayload
} from './MoUIPlugins';

const DOMAIN: number = 0x4D4F;
const TAG: string = 'MoUIHarmony';
const HOST_WIRE_SCHEMA_VERSION: number = 1;

interface TextRangePayload {
  start: number;
  end: number;
}

interface ImePayload {
  revision: number;
  enabled: boolean;
  text: string;
  caret: number;
  selection?: TextRangePayload;
  composition?: string;
  frame: MoUIRect;
  candidate_anchor: MoUIRect;
}

interface SemanticsStatePayload {
  disabled: boolean;
  selected: boolean;
  checked: boolean;
}

interface SemanticsNodePayload {
  element_id: number;
  role: string;
  label: string;
  value: string;
  description: string;
  state: SemanticsStatePayload;
  actions: string[];
  frame: MoUIRect;
}

interface SemanticsPayload {
  revision: number;
  nodes: SemanticsNodePayload[];
}

interface ClipboardPayload {
  operation: string;
  text?: string;
  mime?: string;
  bytes?: number[];
}

interface HostUpdate {
  kind: string;
  id?: number;
  payload: ImePayload | SemanticsPayload | ClipboardPayload |
    MoUIPlatformViewSnapshotPayload | PlatformChannelPayload | string;
}

interface HostUpdateEnvelope {
  schemaVersion: number;
  sessionGeneration: number;
  updates: HostUpdate[];
}

class MoUIRootRuntimeInputBindings implements MoUIRuntimeInputBindings {
  dispatchAccessibility(elementId: number, action: number, value: string): boolean {
    return mouiRuntime.dispatchAccessibility(elementId, action, value);
  }

  dispatchTextInput(kind: number, text: string, start: number, end: number): boolean {
    return mouiRuntime.dispatchTextInput(kind, text, start, end);
  }

  dispatchCommand(kind: number): boolean {
    return mouiRuntime.dispatchCommand(kind);
  }
}

@Component
export struct MoUIRoot {
  private readonly xcomponentId: string = 'moui_mobile_harmonyos_surface';
  private readonly frameSync: displaySync.DisplaySync = displaySync.create();
  private readonly platformViews: MoUIPlatformViewController = new MoUIPlatformViewController(
    (encoded: string): boolean => mouiRuntime.dispatchHostResponseEnvelope(encoded)
  );
  private readonly hostServices: MoUIHostServices = new MoUIHostServices(
    (encoded: string): boolean => mouiRuntime.dispatchHostResponseEnvelope(encoded)
  );
  private readonly pluginRuntimeInput: MoUIRuntimeInputBindings = new MoUIRootRuntimeInputBindings();
  private applyingIme: boolean = false;
  private imeComposing: boolean = false;
  private imePreviousText: string = '';
  private imeRevision: number = -1;
  private semanticsRevision: number = -1;
  private sessionGeneration: number = 0;
  @State private imeEnabled: boolean = false;
  @State private imeText: string = '';
  @State private imeX: number = 0;
  @State private imeY: number = 0;
  @State private imeWidth: number = 1;
  @State private imeHeight: number = 1;
  @State private semanticsNodes: SemanticsNodePayload[] = [];
  @State private hostedPlatformViews: MoUIHostedPlatformView[] = [];

  private readonly frameCallback = (info: displaySync.IntervalInfo): void => {
    mouiRuntime.frameTick(info.timestamp / 1000000.0);
    this.processHostUpdates();
  };

  aboutToAppear(): void {
    installGeneratedPlugins();
    this.frameSync.on('frame', this.frameCallback);
    this.frameSync.start();
  }

  aboutToDisappear(): void {
    this.frameSync.stop();
    this.frameSync.off('frame', this.frameCallback);
    this.clearHostState();
  }

  build() {
    Stack() {
      XComponent({
        id: this.xcomponentId,
        type: XComponentType.SURFACE,
        libraryname: 'moui_mobile_harmonyos'
      })
        .width('100%')
        .height('100%')

      ForEach(this.hostedPlatformViews, (hosted: MoUIHostedPlatformView) => {
        Stack() {
          NodeContainer(hosted.controller)
            .position({ x: hosted.childX, y: hosted.childY })
            .width(hosted.childWidth)
            .height(hosted.childHeight)
        }
        .position({ x: hosted.x, y: hosted.y })
        .width(hosted.width)
        .height(hosted.height)
        .clip(true)
        .zIndex(hosted.zIndex)
      }, (hosted: MoUIHostedPlatformView) => hosted.key)

      TextInput({ text: this.imeText })
        .id('moui-ime-proxy')
        .position({ x: this.imeX, y: this.imeY })
        .width(this.imeWidth)
        .height(this.imeHeight)
        .opacity(0.01)
        .focusable(this.imeEnabled)
        .enablePreviewText(true)
        .selectionMenuHidden(false)
        .onChange((value: string, preview?: PreviewText) => {
          if (this.applyingIme) {
            return;
          }
          if (preview !== undefined && preview.value.length > 0) {
            if (!this.imeComposing) {
              mouiRuntime.dispatchTextInput(3, '', 0, 0);
              this.imeComposing = true;
            }
            mouiRuntime.dispatchTextInput(4, preview.value, preview.value.length, preview.value.length);
          } else {
            mouiRuntime.dispatchTextInput(1, value, 0, this.imePreviousText.length);
            this.imePreviousText = value;
            if (this.imeComposing) {
              mouiRuntime.dispatchTextInput(5, '', 0, 0);
              this.imeComposing = false;
            }
          }
        })
        .onTextSelectionChange((start: number, end: number) => {
          if (!this.applyingIme) {
            mouiRuntime.dispatchTextInput(2, '', start, end);
          }
        })
        .onSubmit(() => {
          mouiRuntime.dispatchCommand(3);
        })
        .onCopy((_value: string) => {
          mouiRuntime.dispatchCommand(0);
        })
        .onCut((_value: string) => {
          mouiRuntime.dispatchCommand(1);
        })
        .onPaste((_value: string, event: PasteEvent) => {
          if (event.preventDefault !== undefined) {
            event.preventDefault();
          }
          mouiRuntime.dispatchCommand(2);
        })

      ForEach(this.semanticsNodes, (node: SemanticsNodePayload) => {
        Blank()
          .position({ x: node.frame.origin.x, y: node.frame.origin.y })
          .width(Math.max(1, node.frame.size.width))
          .height(Math.max(1, node.frame.size.height))
          .opacity(0.01)
          .hitTestBehavior(HitTestMode.None)
          .accessibilityLevel('yes')
          .accessibilityText(node.label.length > 0 ? node.label : node.value)
          .accessibilityDescription(node.description)
          .accessibilityRole(this.toAccessibilityRole(node.role))
          .accessibilityChecked(node.state.checked)
          .accessibilitySelected(node.state.selected)
          .enabled(!node.state.disabled)
          .onAccessibilityFocus((focused: boolean) => {
            if (focused) {
              hilog.info(DOMAIN, TAG, 'moui-mobile service accessibility focus id=%{public}d', node.element_id);
              mouiRuntime.dispatchAccessibility(node.element_id, 1, '');
            }
          })
          .onAccessibilityActionIntercept((action: AccessibilityAction) => {
            if (action === AccessibilityAction.ACCESSIBILITY_CLICK) {
              hilog.info(DOMAIN, TAG, 'moui-mobile service accessibility action=activate id=%{public}d', node.element_id);
              mouiRuntime.dispatchAccessibility(node.element_id, 0, '');
              return AccessibilityActionInterceptResult.ACTION_INTERCEPT;
            }
            return AccessibilityActionInterceptResult.ACTION_CONTINUE;
          })
      }, (node: SemanticsNodePayload) => `${node.element_id}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }

  private processHostUpdates(): void {
    const encoded = mouiRuntime.takeHostUpdates();
    if (encoded.length === 0) {
      return;
    }
    try {
      const envelope = JSON.parse(encoded) as HostUpdateEnvelope;
      if (envelope.schemaVersion !== HOST_WIRE_SCHEMA_VERSION || envelope.sessionGeneration <= 0) {
        hilog.error(DOMAIN, TAG, 'invalid Host Wire envelope schema=%{public}d generation=%{public}d',
          envelope.schemaVersion, envelope.sessionGeneration);
        return;
      }
      if (this.sessionGeneration !== 0 && this.sessionGeneration !== envelope.sessionGeneration) {
        this.clearHostState();
      }
      this.sessionGeneration = envelope.sessionGeneration;
      MoUIPluginRegistry.shared.activateSession(envelope.sessionGeneration, this.pluginRuntimeInput);
      envelope.updates.forEach((update: HostUpdate) => this.applyHostUpdate(update, envelope.sessionGeneration));
    } catch (error) {
      const message = error instanceof Error ? error.message : 'invalid Host Wire envelope';
      hilog.error(DOMAIN, TAG, 'Host Wire parse failed: %{public}s', message);
    }
  }

  private applyHostUpdate(update: HostUpdate, generation: number): void {
    if (update.kind === 'ime') {
      this.applyIme(update.payload as ImePayload);
    } else if (update.kind === 'semantics') {
      this.applySemantics(update.payload as SemanticsPayload, generation);
    } else if (update.kind === 'clipboard' && update.id !== undefined) {
      this.applyClipboard(generation, update.id, update.payload as ClipboardPayload);
    } else if (update.kind === 'platform-views') {
      this.hostedPlatformViews = this.platformViews.sync(
        update.payload as MoUIPlatformViewSnapshotPayload,
        generation
      );
    } else if (update.kind === 'platform-channel' && update.id !== undefined) {
      const payload = update.payload as PlatformChannelPayload;
      this.hostServices.dispatch({ id: update.id, payload: payload }, generation);
    } else if (update.kind === 'diagnostic') {
      hilog.info(DOMAIN, TAG, '%{public}s', update.payload as string);
    }
  }

  private applyIme(payload: ImePayload): void {
    if (payload.revision <= this.imeRevision) {
      return;
    }
    this.imeRevision = payload.revision;
    this.applyingIme = true;
    this.imeEnabled = payload.enabled;
    this.imeText = payload.text;
    this.imePreviousText = payload.text;
    this.imeX = payload.frame.origin.x;
    this.imeY = payload.frame.origin.y;
    this.imeWidth = Math.max(1, payload.frame.size.width);
    this.imeHeight = Math.max(1, payload.frame.size.height);
    this.applyingIme = false;
    hilog.info(DOMAIN, TAG, 'moui-mobile service ime state enabled=%{public}d', payload.enabled ? 1 : 0);
    try {
      if (payload.enabled) {
        this.getUIContext().getFocusController().requestFocus('moui-ime-proxy');
      } else {
        this.imeComposing = false;
        this.getUIContext().getFocusController().clearFocus();
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'focus update failed';
      hilog.warn(DOMAIN, TAG, 'IME focus update failed: %{public}s', message);
    }
  }

  private applySemantics(payload: SemanticsPayload, generation: number): void {
    if (payload.revision <= this.semanticsRevision) {
      return;
    }
    this.semanticsRevision = payload.revision;
    this.semanticsNodes = payload.nodes;
    const snapshotNodes = payload.nodes.map((node: SemanticsNodePayload): MoUISemanticsNodeSnapshot => {
      return { elementId: node.element_id, role: node.role, label: node.label };
    });
    MoUIPluginRegistry.shared.publishSemantics(generation, payload.revision, snapshotNodes);
    hilog.info(DOMAIN, TAG, 'moui-mobile service accessibility tree nodes=%{public}d', payload.nodes.length);
  }

  private applyClipboard(generation: number, id: number, payload: ClipboardPayload): void {
    const board = pasteboard.getSystemPasteboard();
    try {
      if (payload.operation === 'read-text') {
        this.completeClipboard(
          generation, id, payload.operation, 1, board.getDataSync().getPrimaryText(), new ArrayBuffer(0));
      } else if (payload.operation === 'write-text') {
        board.setDataSync(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, payload.text ?? ''));
        this.completeClipboard(generation, id, payload.operation, 3, '', new ArrayBuffer(0));
      } else if (payload.operation === 'write-image') {
        const bytes = new Uint8Array(payload.bytes ?? []).buffer;
        board.setDataSync(pasteboard.createData(payload.mime ?? 'image/png', bytes));
        this.completeClipboard(generation, id, payload.operation, 3, '', new ArrayBuffer(0));
      } else if (payload.operation === 'read-image') {
        const data = board.getDataSync();
        const mime = data.getPrimaryMimeType();
        data.getRecord(0).getData(mime).then((value: pasteboard.ValueType) => {
          if (value instanceof ArrayBuffer) {
            this.completeClipboard(generation, id, payload.operation, 2, '', value);
          } else {
            this.completeClipboard(
              generation, id, payload.operation, 0, 'clipboard image is unavailable', new ArrayBuffer(0));
          }
        }).catch((error: Error) => {
          this.completeClipboard(generation, id, payload.operation, 0, error.message, new ArrayBuffer(0));
        });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'clipboard operation failed';
      this.completeClipboard(generation, id, payload.operation, 0, message, new ArrayBuffer(0));
    }
  }

  private completeClipboard(
    generation: number,
    id: number,
    operation: string,
    kind: number,
    text: string,
    bytes: ArrayBuffer
  ): void {
    const accepted = mouiRuntime.completeClipboard(generation, id, kind, text, bytes);
    hilog.info(DOMAIN, TAG,
      'moui-mobile service clipboard complete operation=%{public}s generation=%{public}d id=%{public}d kind=%{public}d accepted=%{public}d',
      operation, generation, id, kind, accepted ? 1 : 0);
  }

  private clearHostState(): void {
    MoUIPluginRegistry.shared.resetSession();
    this.hostServices.reset();
    this.platformViews.clear();
    this.hostedPlatformViews = [];
    this.sessionGeneration = 0;
    this.imeRevision = -1;
    this.semanticsRevision = -1;
    this.imeEnabled = false;
    this.imeComposing = false;
    this.imeText = '';
    this.semanticsNodes = [];
  }

  private toAccessibilityRole(role: string): AccessibilityRoleType {
    if (role === 'Button') return AccessibilityRoleType.BUTTON;
    if (role === 'TextField') return AccessibilityRoleType.TEXT_INPUT;
    if (role === 'Checkbox') return AccessibilityRoleType.CHECKBOX;
    if (role === 'Switch') return AccessibilityRoleType.SWITCH;
    if (role === 'Radio') return AccessibilityRoleType.RADIO;
    if (role === 'List') return AccessibilityRoleType.LIST;
    if (role === 'ListItem') return AccessibilityRoleType.LIST_ITEM;
    if (role === 'ScrollView') return AccessibilityRoleType.SCROLL;
    return AccessibilityRoleType.BLANK;
  }
}
