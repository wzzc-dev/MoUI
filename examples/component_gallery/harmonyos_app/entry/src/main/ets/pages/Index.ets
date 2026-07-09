import mouiDemo from 'libcomponent_gallery_harmonyos.so';
import hilog from '@ohos.hilog';

const DOMAIN = 0x4D4F;
const TAG = 'MoUIHarmony';

@Entry
@Component
struct Index {
  private xcomponentId: string = 'component_gallery_harmonyos_surface';

  build() {
    Column() {
      XComponent({
        id: this.xcomponentId,
        type: XComponentType.SURFACE,
        libraryname: 'component_gallery_harmonyos'
      })
        .width('100%')
        .height('100%')
        .onLoad(() => {
          const rendered = mouiDemo.renderFrame();
          hilog.info(DOMAIN, TAG, 'xcomponent onLoad renderFrame=%{public}s', `${rendered}`);
        })
        .onDestroy(() => {
          hilog.info(DOMAIN, TAG, 'xcomponent onDestroy detachSurface');
          mouiDemo.detachSurface();
        })
        .onTouch((event: TouchEvent) => {
          if (event.touches.length <= 0) {
            hilog.warn(DOMAIN, TAG, 'touch event without touches type=%{public}d', event.type);
            return;
          }
          const touch = event.touches[0];
          const phase = this.pointerPhase(event.type);
          const dispatched = mouiDemo.dispatchPointer(
            phase,
            touch.x,
            touch.y,
            Date.now()
          );
          const rendered = mouiDemo.renderFrame();
          hilog.info(
            DOMAIN,
            TAG,
            'touch phase=%{public}d x=%{public}f y=%{public}f dispatch=%{public}s renderFrame=%{public}s',
            phase,
            touch.x,
            touch.y,
            `${dispatched}`,
            `${rendered}`
          );
        })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          hilog.info(
            DOMAIN,
            TAG,
            'xcomponent area old=%{public}s new=%{public}s',
            JSON.stringify(oldArea),
            JSON.stringify(newArea)
          );
          mouiDemo.resize(
            Number(newArea.width),
            Number(newArea.height),
            1.0
          );
          mouiDemo.renderFrame();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }

  private pointerPhase(type: TouchType): number {
    if (type === TouchType.Down) {
      return 0;
    }
    if (type === TouchType.Move) {
      return 1;
    }
    if (type === TouchType.Up) {
      return 2;
    }
    if (type === TouchType.Cancel) {
      return 3;
    }
    return 1;
  }
}
