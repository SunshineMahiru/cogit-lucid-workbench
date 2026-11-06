import { relationalStore } from '@kit.ArkData';

/** Runs a COUNT-style query and always closes the result set. */
export async function queryCount(store: relationalStore.RdbStore, sql: string): Promise<number> {
  const resultSet = await store.querySql(sql);
  try {
    return resultSet.goToFirstRow() ? resultSet.getLong(0) : 0;
  } finally {
    resultSet.close();
  }
}
