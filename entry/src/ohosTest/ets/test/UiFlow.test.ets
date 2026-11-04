import { describe, it, expect, beforeAll } from '@ohos/hypium';
import { Driver, ON } from '@ohos.UiTest';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

const BUNDLE_NAME = 'com.sunshinemahiru.cogitlucid';

/** Covers the home entry, the remote dashboard and the range switch on a real device. */
export default function analyticsFlowTest() {
  describe('AnalyticsFlow', () => {
    beforeAll(async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: BUNDLE_NAME, abilityName: 'EntryAbility' });
      await Driver.create().delayMs(2000);
    });

    it('opensDashboard', 0, async () => {
      const driver = Driver.create();
      await driver.waitForComponent(ON.id('home_dashboard_entry'), 3000);
      const entry = await driver.findComponent(ON.id('home_dashboard_entry'));
      expect(entry !== null).assertTrue();
      await entry.click();
      await driver.waitForComponent(ON.id('analytics_range_12m'), 3000);
    });

    it('switchesMonth', 0, async () => {
      const driver = Driver.create();
      const firstMonth = await driver.findComponent(ON.id('analytics_month_first'));
      expect(firstMonth !== null).assertTrue();
      await firstMonth.click();
      await driver.waitForComponent(ON.text('数据看板'), 3000);
    });

    it('returnsHome', 0, async () => {
      const driver = Driver.create();
      await driver.pressBack();
      await driver.waitForComponent(ON.id('home_dashboard_entry'), 3000);
    });
  });
}
