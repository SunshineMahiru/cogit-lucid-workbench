import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DbHelper } from '../db/DbHelper';
import { applyTheme } from '../theme/AppTheme';
import { notifyPageBackgroundChanged } from '../settings/PageBackgroundBus';

const DOMAIN = 0x0000;
const TAG = 'CogitLucid';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    DbHelper.init(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'DbHelper.init failed: %{public}s', error.message);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    applyTheme(newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    notifyPageBackgroundChanged();
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onConfigurationUpdate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      // The page scrim owns the surface colour, so the window itself stays clear and
      // a translucent page can show what sits behind the application window.
      mainWindow.setWindowBackgroundColor('#00000000');
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'setWindowBackgroundColor failed: %{public}s', error.message);
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
