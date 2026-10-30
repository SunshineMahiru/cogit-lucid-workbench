import { deviceInfo } from '@kit.BasicServicesKit';

/** True on the HarmonyOS emulator, where localhost + hdc rport is the intended mock path. */
export function isEmulatorDevice(): boolean {
  try {
    const model = `${deviceInfo.productModel} ${deviceInfo.hardwareProfile} ${deviceInfo.marketName}`.toLowerCase();
    return model.includes('emulator');
  } catch (error) {
    return false;
  }
}
