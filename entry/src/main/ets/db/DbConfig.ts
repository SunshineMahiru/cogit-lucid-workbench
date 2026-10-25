import { relationalStore } from '@kit.ArkData';

/** Current schema version of the relational database. */
export const DB_VERSION = 1;

/** Store configuration for the relational database. */
export const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'cogit_lucid.db',
  securityLevel: relationalStore.SecurityLevel.S1,
  version: DB_VERSION
};
