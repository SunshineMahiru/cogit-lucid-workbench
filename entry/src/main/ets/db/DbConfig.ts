import { relationalStore } from '@kit.ArkData';

/** Schema version applied to the store after it is opened. */
export const DB_VERSION = 1;

/** Store configuration for the relational database. */
export const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'cogit_lucid.db',
  securityLevel: relationalStore.SecurityLevel.S1
};
