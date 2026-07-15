import mouiDemo from 'libmoui_mobile_harmonyos.so';
import display from '@ohos.display';
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
  frame: RectPayload;
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
  payload: ImePayload | SemanticsPayload | ClipboardPayload | string;
}

// Process-level once-fire guards for deterministic matching-host smoke.
let a11ySmokeFired: boolean = false;
let serviceSmokeFired: boolean = false;

@Entry
@Component
struct Index {
  private xcomponentId: string = 'moui_mobile_harmonyos_surface';
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

  private displayDensity(): number {
    try {
      const d = display.getDefaultDisplaySync();
      return d.densityPixels > 0 ? d.densityPixels : 1;
    } catch (_err) {
      return 1;
    }
  }

  // Area is in vp; native XComponent size is physical px. Report logical area so
  // attach/resize can compute scale = physical/logical (~2 on MateBook Pro HVD).
  private syncSurfaceMetrics(areaWidth: number, areaHeight: number): void {
    if (areaWidth <= 0 || areaHeight <= 0) {
      return;
    }
    const density = this.displayDensity();
    hilog.info(
      0x4D4F,
      'MoUIHarmony',
      'surface metrics logical=%{public}fx%{public}f density=%{public}f',
      areaWidth,
      areaHeight,
      density
    );
    mouiDemo.resize(areaWidth, areaHeight, density);
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
        libraryname: 'moui_mobile_harmonyos'
      })
        .width('100%')
        .height('100%')
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.syncSurfaceMetrics(newValue.width, newValue.height);
        })

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
          if (this.applyingIme) return;
          if (preview !== undefined && preview.value.length > 0) {
            if (!this.imeComposing) {
              mouiDemo.dispatchTextInput(3, '', 0, 0);
              this.imeComposing = true;
            }
            hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service ime edit kind=composition');
            mouiDemo.dispatchTextInput(4, preview.value, preview.value.length, preview.value.length);
          } else {
            hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service ime edit kind=commit');
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
        .onCopy((_value: string) => {
          mouiDemo.dispatchCommand(0);
        })
        .onCut((_value: string) => {
          mouiDemo.dispatchCommand(1);
        })
        .onPaste((_value: string, event: PasteEvent) => {
          if (event !== undefined && event.preventDefault !== undefined) {
            event.preventDefault();
          }
          mouiDemo.dispatchCommand(2);
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
              hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service accessibility focus id=%{public}d', node.element_id);
              mouiDemo.dispatchAccessibility(node.element_id, 1, '');
            }
          })
          .onAccessibilityActionIntercept((action: AccessibilityAction) => {
            if (action === AccessibilityAction.ACCESSIBILITY_CLICK) {
              hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service accessibility action=activate id=%{public}d', node.element_id);
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
        this.logServiceProbePlan();
        this.maybeFireAccessibilitySmoke();
        this.maybeFireServiceSmoke();
      } else if (update.kind === 'clipboard' && update.id !== undefined) {
        this.applyClipboard(update.id, update.payload as ClipboardPayload);
      } else if (update.kind === 'diagnostic') {
        hilog.info(0x4D4F, 'MoUIHarmony', '%{public}s', update.payload as string);
      }
    });
  }

  // Emit Service Probe coordinates from MoUI semantics so the recorder can
  // drive taps when uitest cannot see XComponent virtual overlays.
  private logServiceProbePlan(): void {
    const textField = this.findSemanticsLabel('Service probe text', 'TextField');
    const action = this.findSemanticsLabel('Activate service probe', 'Button');
    if (textField === undefined || action === undefined) return;
    const density = this.displayDensity();
    const textX = Math.round((textField.frame.origin.x + textField.frame.size.width / 2) * density);
    const textY = Math.round((textField.frame.origin.y + textField.frame.size.height / 2) * density);
    const actionX = Math.round((action.frame.origin.x + action.frame.size.width / 2) * density);
    const actionY = Math.round((action.frame.origin.y + action.frame.size.height / 2) * density);
    hilog.info(
      0x4D4F,
      'MoUIHarmony',
      'moui-mobile service probe plan textField=%{public}d,%{public}d action=%{public}d,%{public}d textFieldId=%{public}d actionId=%{public}d density=%{public}f',
      textX,
      textY,
      actionX,
      actionY,
      textField.element_id,
      action.element_id,
      density
    );
  }

  private findSemanticsLabel(label: string, preferredRole: string): SemanticsNodePayload | undefined {
    let preferred: SemanticsNodePayload | undefined = undefined;
    let any: SemanticsNodePayload | undefined = undefined;
    for (let i = 0; i < this.semanticsNodes.length; i++) {
      const node = this.semanticsNodes[i];
      if (node.label !== label && node.label.indexOf(label) < 0) continue;
      any = node;
      if (node.role === preferredRole) {
        preferred = node;
        break;
      }
    }
    return preferred !== undefined ? preferred : any;
  }

  // Emulator smoke can request a deterministic focus/activate pair without a
  // live screen-reader gesture stream. Runs once per process when the host
  // sets MOUI_MOBILE_A11Y_SMOKE=1, mirroring the iOS once-fire path.
  private maybeFireAccessibilitySmoke(): void {
    if (a11ySmokeFired || this.semanticsNodes.length === 0) return;
    if (!mouiDemo.a11ySmokeEnabled()) return;
    let target = this.findSemanticsLabel('Activate service probe', 'Button');
    if (target === undefined) {
      for (let i = 0; i < this.semanticsNodes.length; i++) {
        const node = this.semanticsNodes[i];
        if (node.role === 'Button') {
          target = node;
          break;
        }
      }
    }
    if (target === undefined) return;
    a11ySmokeFired = true;
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service accessibility focus id=%{public}d', target.element_id);
    mouiDemo.dispatchAccessibility(target.element_id, 1, '');
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service accessibility action=activate id=%{public}d', target.element_id);
    mouiDemo.dispatchAccessibility(target.element_id, 0, '');
  }

  // Matching-host service smoke: drive IME + clipboard through the host channel
  // once semantics expose the Service Probe controls (uitest-independent).
  private maybeFireServiceSmoke(): void {
    if (serviceSmokeFired || this.semanticsNodes.length === 0) return;
    if (!mouiDemo.a11ySmokeEnabled()) return;
    const textField = this.findSemanticsLabel('Service probe text', 'TextField');
    const action = this.findSemanticsLabel('Activate service probe', 'Button');
    if (textField === undefined || action === undefined) return;
    serviceSmokeFired = true;
    hilog.info(
      0x4D4F,
      'MoUIHarmony',
      'moui-mobile service smoke begin textFieldId=%{public}d actionId=%{public}d',
      textField.element_id,
      action.element_id
    );
    mouiDemo.dispatchAccessibility(textField.element_id, 1, '');
    mouiDemo.dispatchAccessibility(textField.element_id, 2, 'ime-mobile-probe');
    mouiDemo.dispatchTextInput(1, 'ime-mobile-probe', 0, 0);
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service ime edit kind=commit smoke=1');
    mouiDemo.dispatchTextInput(2, '', 0, 'ime-mobile-probe'.length);
    mouiDemo.dispatchCommand(0);
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service smoke copy');
    try {
      const board = pasteboard.getSystemPasteboard();
      board.setDataSync(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, 'clipboard-service-probe'));
    } catch (_err) {
      hilog.warn(0x4D4F, 'MoUIHarmony', 'moui-mobile service smoke seed clipboard failed');
    }
    mouiDemo.dispatchCommand(2);
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service smoke paste');
    mouiDemo.dispatchCommand(1);
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service smoke cut');
    mouiDemo.dispatchAccessibility(action.element_id, 1, '');
    mouiDemo.dispatchAccessibility(action.element_id, 0, '');
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service smoke end');
  }

  private applyIme(payload: ImePayload): void {
    hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service ime state enabled=%{public}d', payload.enabled ? 1 : 0);
    this.applyingIme = true;
    this.imeEnabled = payload.enabled;
    this.imeText = payload.text;
    this.imePreviousText = payload.text;
    this.imeX = payload.frame.origin.x;
    this.imeY = payload.frame.origin.y;
    this.imeWidth = Math.max(1, payload.frame.size.width);
    this.imeHeight = Math.max(1, payload.frame.size.height);
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
        hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service clipboard complete operation=read-text');
      } else if (payload.operation === 'write-text') {
        board.setDataSync(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, payload.text ?? ''));
        mouiDemo.completeClipboard(id, 3, '', new ArrayBuffer(0));
        hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service clipboard complete operation=write-text');
      } else if (payload.operation === 'write-image') {
        const bytes = new Uint8Array(payload.bytes ?? []).buffer;
        board.setDataSync(pasteboard.createData(payload.mime ?? 'image/png', bytes));
        mouiDemo.completeClipboard(id, 3, '', new ArrayBuffer(0));
        hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service clipboard complete operation=write-image');
      } else if (payload.operation === 'read-image') {
        const data = board.getDataSync();
        const mime = data.getPrimaryMimeType();
        data.getRecord(0).getData(mime).then((value: pasteboard.ValueType) => {
          if (value instanceof ArrayBuffer) {
            mouiDemo.completeClipboard(id, 2, '', value);
            hilog.info(0x4D4F, 'MoUIHarmony', 'moui-mobile service clipboard complete operation=read-image');
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
