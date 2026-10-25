import { relationalStore } from '@kit.ArkData';

/** Store configuration for the relational database. */
export const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'cogit_lucid.db',
  securityLevel: relationalStore.SecurityLevel.S1
};
