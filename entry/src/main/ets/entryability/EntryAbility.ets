import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyboardAvoidMode, window } from '@kit.ArkUI';
import { DbHelper } from '../db/DbHelper';
import { appHealth } from '../app/AppHealth';
import { applyTheme } from '../theme/AppTheme';
import { notifyPageBackgroundChanged } from '../settings/PageBackgroundBus';
import { DebugFaults } from '../app/DebugFaults';
import BuildProfile from 'BuildProfile';

const DOMAIN = 0x0000;
const TAG = 'CogitLucid';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    DebugFaults.setDebug(BuildProfile.DEBUG);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    DbHelper.init(this.context).then(() => {
      appHealth.markReady();
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'DbHelper.init failed: %{private}s', error.message);
      appHealth.markFailed(error.message);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const dark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    applyTheme(dark);
    this.applySystemBar(dark);
    notifyPageBackgroundChanged();
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onConfigurationUpdate');
  }

  /** Keeps the status bar clear so the page colour owns the top edge; icons follow the palette. */
  private applySystemBar(dark: boolean): void {
    if (this.mainWindow === null) {
      return;
    }
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: dark ? '#FFFFFF' : '#000000'
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'setWindowSystemBarProperties failed: %{private}s', error.message);
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{private}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      this.mainWindow = mainWindow;
      // The page scrim owns the surface colour, so the window itself stays clear and
      // a translucent page can show what sits behind the application window.
      mainWindow.setWindowBackgroundColor('#00000000');
      // Shrink the page instead of shifting it, so fixed bottom actions stay above the keyboard.
      mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
      this.applySystemBar(this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'setWindowBackgroundColor failed: %{private}s', error.message);
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
