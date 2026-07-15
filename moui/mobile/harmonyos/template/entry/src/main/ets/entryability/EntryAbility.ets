import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import mouiRuntime from 'libmoui_mobile_harmonyos.so';

import { mouiGeneratedConfiguration } from '../moui/MoUIGeneratedConfig';

const DOMAIN: number = 0x4D4F;
const TAG: string = 'MoUIHarmony';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'window stage create');
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(error));
        return;
      }
      this.configureWindow(windowStage);
      hilog.info(DOMAIN, TAG, 'content loaded');
    });
  }

  onDestroy(): void {
    const destroyed = mouiRuntime.destroyApplication();
    hilog.info(DOMAIN, TAG, 'ability destroyed runtime=%{public}d', destroyed ? 1 : 0);
  }

  private configureWindow(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(mouiGeneratedConfiguration.fullscreen).catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'fullscreen configuration failed: %{public}s', error.message);
      });
      if (mouiGeneratedConfiguration.statusBar !== 'auto') {
        const enabledBars: Array<'status' | 'navigation'> =
          mouiGeneratedConfiguration.statusBar === 'hidden' ? ['navigation'] : ['status', 'navigation'];
        mainWindow.setWindowSystemBarEnable(enabledBars).catch((error: Error) => {
          hilog.warn(DOMAIN, TAG, 'system bar configuration failed: %{public}s', error.message);
        });
      }
      let orientation = window.Orientation.UNSPECIFIED;
      if (mouiGeneratedConfiguration.orientation === 'portrait') {
        orientation = window.Orientation.PORTRAIT;
      } else if (mouiGeneratedConfiguration.orientation === 'landscape') {
        orientation = window.Orientation.LANDSCAPE;
      }
      mainWindow.setPreferredOrientation(orientation).catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'orientation configuration failed: %{public}s', error.message);
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'window configuration failed';
      hilog.warn(DOMAIN, TAG, 'window configuration failed: %{public}s', message);
    }
  }
}
