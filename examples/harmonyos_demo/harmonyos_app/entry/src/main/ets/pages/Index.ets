import mouiDemo from 'libmoui_harmonyos_demo.so';
import displaySync from '@ohos.graphics.displaySync';
import pasteboard from '@ohos.pasteboard';
import hilog from '@ohos.hilog';

interface PointPayload { x: number; y: number; }
interface SizePayload { width: number; height: number; }
interface RectPayload { origin: PointPayload; size: SizePayload; }
interface TextRangePayload { start: number; end: number; }
interface ImePayload {
  enabled: boolean;
  text: string;
  caret: number;
  selection?: TextRangePayload;
  composition?: string;
  candidate_anchor: RectPayload;
}
interface SemanticsStatePayload { disabled: boolean; selected: boolean; checked: boolean; }
interface SemanticsNodePayload {
  element_id: number;
  role: string;
  label: string;
  value: string;
  description: string;
  state: SemanticsStatePayload;
  actions: string[];
  frame: RectPayload;
}
interface SemanticsPayload { nodes: SemanticsNodePayload[]; }
interface ClipboardPayload { operation: string; text?: string; mime?: string; bytes?: number[]; }
interface HostUpdate {
  kind: string;
  id?: number;
  payload: ImePayload | SemanticsPayload | ClipboardPayload;
}

@Entry
@Component
struct Index {
  private xcomponentId: string = 'moui_harmonyos_demo_surface';
  private frameSync: displaySync.DisplaySync = displaySync.create();
  private applyingIme: boolean = false;
  private imeComposing: boolean = false;
  private imePreviousText: string = '';
  @State private imeEnabled: boolean = false;
  @State private imeText: string = '';
  @State private imeX: number = 0;
  @State private imeY: number = 0;
  @State private imeWidth: number = 1;
  @State private imeHeight: number = 1;
  @State private semanticsNodes: SemanticsNodePayload[] = [];

  private frameCallback = (info: displaySync.IntervalInfo): void => {
    mouiDemo.frameTick(info.timestamp / 1000000.0);
    this.processHostUpdates();
  };

  aboutToAppear(): void {
    this.frameSync.on('frame', this.frameCallback);
    this.frameSync.start();
  }

  aboutToDisappear(): void {
    this.frameSync.stop();
    this.frameSync.off('frame', this.frameCallback);
  }

  build() {
    Stack() {
      XComponent({
        id: this.xcomponentId,
        type: XComponentType.SURFACE,
        libraryname: 'moui_harmonyos_demo'
      })
        .width('100%')
        .height('100%')

      TextInput({ text: this.imeText })
        .id('moui-ime-proxy')
        .position({ x: this.imeX, y: this.imeY })
        .width(this.imeWidth)
        .height(this.imeHeight)
        .opacity(0.01)
        .focusable(this.imeEnabled)
        .enablePreviewText(true)
        .selectionMenuHidden(true)
        .onChange((value: string, preview?: PreviewText) => {
          if (this.applyingIme) return;
          if (preview !== undefined && preview.value.length > 0) {
            if (!this.imeComposing) {
              mouiDemo.dispatchTextInput(3, '', 0, 0);
              this.imeComposing = true;
            }
            mouiDemo.dispatchTextInput(4, preview.value, preview.value.length, preview.value.length);
          } else {
            mouiDemo.dispatchTextInput(1, value, 0, this.imePreviousText.length);
            this.imePreviousText = value;
            if (this.imeComposing) {
              mouiDemo.dispatchTextInput(5, '', 0, 0);
              this.imeComposing = false;
            }
          }
        })
        .onTextSelectionChange((start: number, end: number) => {
          if (!this.applyingIme) mouiDemo.dispatchTextInput(2, '', start, end);
        })
        .onSubmit(() => {
          mouiDemo.dispatchCommand(3);
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
          .accessibilityRole(this.accessibilityRole(node.role))
          .accessibilityChecked(node.state.checked)
          .accessibilitySelected(node.state.selected)
          .enabled(!node.state.disabled)
          .onAccessibilityFocus((focused: boolean) => {
            if (focused) mouiDemo.dispatchAccessibility(node.element_id, 1, '');
          })
          .onAccessibilityActionIntercept((action: AccessibilityAction) => {
            if (action === AccessibilityAction.ACCESSIBILITY_CLICK) {
              mouiDemo.dispatchAccessibility(node.element_id, 0, '');
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
    const encoded = mouiDemo.takeHostUpdates();
    if (encoded.length === 0 || encoded === '[]') return;
    const updates = JSON.parse(encoded) as HostUpdate[];
    updates.forEach((update: HostUpdate) => {
      if (update.kind === 'ime') {
        this.applyIme(update.payload as ImePayload);
      } else if (update.kind === 'semantics') {
        this.semanticsNodes = (update.payload as SemanticsPayload).nodes;
        hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service accessibility tree nodes=%{public}d', this.semanticsNodes.length);
      } else if (update.kind === 'clipboard' && update.id !== undefined) {
        this.applyClipboard(update.id, update.payload as ClipboardPayload);
      }
    });
  }

  private applyIme(payload: ImePayload): void {
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service ime state enabled=%{public}d', payload.enabled ? 1 : 0);
    this.applyingIme = true;
    this.imeEnabled = payload.enabled;
    this.imeText = payload.text;
    this.imePreviousText = payload.text;
    this.imeX = payload.candidate_anchor.origin.x;
    this.imeY = payload.candidate_anchor.origin.y;
    this.imeWidth = Math.max(1, payload.candidate_anchor.size.width);
    this.imeHeight = Math.max(1, payload.candidate_anchor.size.height);
    this.applyingIme = false;
    if (payload.enabled) {
      this.getUIContext().getFocusController().requestFocus('moui-ime-proxy');
    } else {
      this.imeComposing = false;
      this.getUIContext().getFocusController().clearFocus();
    }
  }

  private applyClipboard(id: number, payload: ClipboardPayload): void {
    const board = pasteboard.getSystemPasteboard();
    try {
      if (payload.operation === 'read-text') {
        mouiDemo.completeClipboard(id, 1, board.getDataSync().getPrimaryText(), new ArrayBuffer(0));
      } else if (payload.operation === 'write-text') {
        board.setDataSync(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, payload.text ?? ''));
        mouiDemo.completeClipboard(id, 3, '', new ArrayBuffer(0));
      } else if (payload.operation === 'write-image') {
        const bytes = new Uint8Array(payload.bytes ?? []).buffer;
        board.setDataSync(pasteboard.createData(payload.mime ?? 'image/png', bytes));
        mouiDemo.completeClipboard(id, 3, '', new ArrayBuffer(0));
      } else if (payload.operation === 'read-image') {
        const data = board.getDataSync();
        const mime = data.getPrimaryMimeType();
        data.getRecord(0).getData(mime).then((value: pasteboard.ValueType) => {
          if (value instanceof ArrayBuffer) {
            mouiDemo.completeClipboard(id, 2, '', value);
          } else {
            mouiDemo.completeClipboard(id, 0, 'clipboard image is unavailable', new ArrayBuffer(0));
          }
        }).catch((error: Error) => {
          mouiDemo.completeClipboard(id, 0, error.message, new ArrayBuffer(0));
        });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'clipboard operation failed';
      mouiDemo.completeClipboard(id, 0, message, new ArrayBuffer(0));
    }
  }

  private accessibilityRole(role: string): AccessibilityRoleType {
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
