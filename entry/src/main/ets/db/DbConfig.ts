import { relationalStore } from '@kit.ArkData';

/** Schema version applied to the store after it is opened. */
export const DB_VERSION = 4;

/** Store configuration for the relational database. */
export const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'cogit_lucid.db',
  securityLevel: relationalStore.SecurityLevel.S1,
  encrypt: true
};

/** Plaintext configuration used only to open and rekey databases created before encryption. */
export const PLAIN_DB_CONFIG: relationalStore.StoreConfig = {
  name: 'cogit_lucid.db',
  securityLevel: relationalStore.SecurityLevel.S1,
  encrypt: false
};
