import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import componentGallery from 'libcomponent_gallery_harmonyos.so';

const DOMAIN = 0x4D4F;
const TAG = 'MoUIHarmony';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'window stage create');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'content loaded');
    });
  }

  onDestroy(): void {
    const destroyed = componentGallery.destroyApplication();
    hilog.info(DOMAIN, TAG, 'ability destroyed runtime=%{public}d', destroyed ? 1 : 0);
  }
}
