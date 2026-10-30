import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';

const API_KEY_ALIAS = 'cogit-llm-api-key';

/** Stores the model key in the system asset service instead of Preferences. */
export class SecretStore {
  /** Saves or replaces the key; returns false when the asset service is unavailable. */
  static async save(apiKey: string): Promise<boolean> {
    if (apiKey.trim().length === 0) {
      await SecretStore.clear();
      return true;
    }
    try {
      await SecretStore.clear();
      const attributes: asset.AssetMap = new Map();
      attributes.set(asset.Tag.ALIAS, encode(API_KEY_ALIAS));
      attributes.set(asset.Tag.SECRET, encode(apiKey));
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      await asset.add(attributes);
      return true;
    } catch (error) {
      return false;
    }
  }

  /** Reads the key; returns an empty string when no key is stored. */
  static async load(): Promise<string> {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, encode(API_KEY_ALIAS));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const rows = await asset.query(query);
      if (rows.length === 0) {
        return '';
      }
      const secret = rows[0].get(asset.Tag.SECRET);
      if (secret instanceof Uint8Array) {
        return decode(secret);
      }
      return '';
    } catch (error) {
      return '';
    }
  }

  /** Removes the stored key. */
  static async clear(): Promise<void> {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, encode(API_KEY_ALIAS));
      await asset.remove(query);
    } catch (error) {
    }
  }
}

function encode(value: string): Uint8Array {
  return new util.TextEncoder().encodeInto(value);
}

function decode(value: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(value);
}
