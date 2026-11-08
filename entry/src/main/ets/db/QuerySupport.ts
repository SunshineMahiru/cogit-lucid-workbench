import { relationalStore } from '@kit.ArkData';

/** Runs a COUNT-style query and always closes the result set. */
export async function queryCount(store: relationalStore.RdbStore, sql: string,
  args?: Array<relationalStore.ValueType>): Promise<number> {
  const resultSet = args === undefined ? await store.querySql(sql) : await store.querySql(sql, args);
  try {
    return resultSet.goToFirstRow() ? resultSet.getLong(0) : 0;
  } finally {
    resultSet.close();
  }
}

/** Runs a predicate query, maps every row and always closes the result set. */
export async function queryRows<T>(store: relationalStore.RdbStore, predicates: relationalStore.RdbPredicates,
  mapper: (resultSet: relationalStore.ResultSet) => T): Promise<T[]> {
  const resultSet = await store.query(predicates);
  try {
    const rows: T[] = [];
    while (resultSet.goToNextRow()) {
      rows.push(mapper(resultSet));
    }
    return rows;
  } finally {
    resultSet.close();
  }
}
