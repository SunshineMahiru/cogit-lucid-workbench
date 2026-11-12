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
      const secondMonth = await driver.findComponent(ON.id('analytics_month_second'));
      expect(secondMonth !== null).assertTrue();
      await secondMonth.click();
      await driver.waitForComponent(ON.text('当前月份 2026-10'), 3000);
      await driver.waitForComponent(ON.text('数据看板'), 3000);
    });

    it('returnsHome', 0, async () => {
      const driver = Driver.create();
      await driver.pressBack();
      await driver.waitForComponent(ON.id('home_dashboard_entry'), 3000);
    });
  });

  describe('SettingsFlow', () => {
    it('opensSettings', 0, async () => {
      const driver = Driver.create();
      await driver.waitForComponent(ON.id('home_settings_entry'), 3000);
      const entry = await driver.findComponent(ON.id('home_settings_entry'));
      expect(entry !== null).assertTrue();
      await entry.click();
      await driver.delayMs(1200);
      const chip = await driver.findComponent(ON.id('settings_provider_model'));
      expect(chip !== null).assertTrue();
    });

    it('showsModelFieldsAfterSwitching', 0, async () => {
      const driver = Driver.create();
      const chip = await driver.findComponent(ON.id('settings_provider_model'));
      expect(chip !== null).assertTrue();
      await chip.click();
      await driver.delayMs(600);
      const modelField = await driver.findComponent(ON.text('GLM-4.7-Flash'));
      expect(modelField !== null).assertTrue();
    });

    it('restoresTemplateAndReturns', 0, async () => {
      const driver = Driver.create();
      const template = await driver.findComponent(ON.id('settings_provider_template'));
      expect(template !== null).assertTrue();
      await template.click();
      await driver.delayMs(600);
      const modelField = await driver.findComponent(ON.text('GLM-4.7-Flash'));
      expect(modelField === null).assertTrue();
      await driver.pressBack();
      await driver.delayMs(800);
      const home = await driver.findComponent(ON.id('home_dashboard_entry'));
      expect(home !== null).assertTrue();
    });
  });
}
