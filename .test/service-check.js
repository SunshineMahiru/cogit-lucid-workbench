'use strict';

const assert = require('assert');
const Module = require('module');

class FakePredicates {
  constructor(table) {
    this.table = table;
    this.filters = [];
    this.orderField = null;
    this.orderDirection = 'desc';
    this.limit = -1;
    this.offset = 0;
  }

  equalTo(field, value) {
    this.filters.push({ field: field, value: value, op: 'eq' });
    return this;
  }

  notEqualTo(field, value) {
    this.filters.push({ field: field, value: value, op: 'ne' });
    return this;
  }

  and() {
    return this;
  }

  greaterThanOrEqualTo(field, value) {
    this.filters.push({ field: field, value: value, op: 'gte' });
    return this;
  }

  lessThanOrEqualTo(field, value) {
    this.filters.push({ field: field, value: value, op: 'lte' });
    return this;
  }

  orderByDesc(field) {
    this.orderField = field;
    this.orderDirection = 'desc';
    return this;
  }

  orderByAsc(field) {
    this.orderField = field;
    this.orderDirection = 'asc';
    return this;
  }

  limitAs(value) {
    this.limit = value;
    return this;
  }

  offsetAs(value) {
    this.offset = value;
    return this;
  }
}

class FakeResultSet {
  constructor(rows) {
    this.rows = rows;
    this.index = -1;
    this.columns = rows.length > 0 ? Object.keys(rows[0]) : [];
  }

  goToNextRow() {
    this.index += 1;
    return this.index < this.rows.length;
  }

  goToFirstRow() {
    this.index = 0;
    return this.rows.length > 0;
  }

  getColumnIndex(name) {
    // The real result set returns -1 for unknown columns; callers guard on it.
    return this.columns.indexOf(name);
  }

  getString(index) {
    const value = this.rows[this.index][this.columns[index]];
    return value === null || value === undefined ? '' : String(value);
  }

  getLong(index) {
    return Number(this.rows[this.index][this.columns[index]]);
  }

  getDouble(index) {
    return Number(this.rows[this.index][this.columns[index]]);
  }

  isColumnNull(index) {
    const value = this.rows[this.index][this.columns[index]];
    return value === null || value === undefined;
  }

  close() {
    this.rows = [];
  }
}

class FakeStore {
  constructor() {
    this.tables = new Map();
    this.snapshot = null;
    this.failTable = null;
    this.failUpdateTable = null;
    this.insertCount = 0;
  }

  rows(table) {
    if (!this.tables.has(table)) {
      this.tables.set(table, []);
    }
    return this.tables.get(table);
  }

  async insert(table, values) {
    if (this.failTable === table) {
      throw new Error(`insert failed: ${table}`);
    }
    this.rows(table).push(Object.assign({}, values));
    this.insertCount += 1;
    return this.insertCount;
  }

  async query(predicates) {
    let rows = this.rows(predicates.table).slice();
    for (const filter of predicates.filters) {
      if (filter.op === 'gte') {
        rows = rows.filter((row) => Number(row[filter.field]) >= Number(filter.value));
      } else if (filter.op === 'lte') {
        rows = rows.filter((row) => Number(row[filter.field]) <= Number(filter.value));
      } else if (filter.op === 'ne') {
        rows = rows.filter((row) => row[filter.field] !== filter.value);
      } else {
        rows = rows.filter((row) => row[filter.field] === filter.value);
      }
    }
    if (predicates.orderField !== null) {
      const field = predicates.orderField;
      const direction = predicates.orderDirection === 'asc' ? 1 : -1;
      rows.sort((left, right) => (Number(left[field]) - Number(right[field])) * direction);
    }
    if (predicates.offset > 0) {
      rows = rows.slice(predicates.offset);
    }
    if (predicates.limit >= 0) {
      rows = rows.slice(0, predicates.limit);
    }
    return new FakeResultSet(rows);
  }

  async update(values, predicates) {
    if (this.failUpdateTable === predicates.table) {
      throw new Error(`update failed: ${predicates.table}`);
    }
    let changed = 0;
    for (const row of this.rows(predicates.table)) {
      let match = true;
      for (const filter of predicates.filters) {
        if (row[filter.field] !== filter.value) {
          match = false;
        }
      }
      if (match) {
        Object.assign(row, values);
        changed += 1;
      }
    }
    return changed;
  }

  async executeSql(sql, args) {
    const insert = /INSERT OR IGNORE INTO\s+([a-z_]+)\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)/i.exec(sql);
    if (insert === null) {
      return;
    }
    const table = insert[1];
    const columns = insert[2].split(',').map((column) => column.trim());
    const row = {};
    for (let index = 0; index < columns.length; index += 1) {
      row[columns[index]] = args[index];
    }
    const exists = this.rows(table).some((existing) => existing.review_id === row.review_id &&
      existing.material_id === row.material_id);
    if (!exists) {
      this.rows(table).push(row);
    }
  }

  async delete(predicates) {
    const kept = [];
    let removed = 0;
    for (const row of this.rows(predicates.table)) {
      let match = true;
      for (const filter of predicates.filters) {
        if (row[filter.field] !== filter.value) {
          match = false;
        }
      }
      if (match) {
        removed += 1;
      } else {
        kept.push(row);
      }
    }
    this.tables.set(predicates.table, kept);
    return removed;
  }

  async querySql(sql, args) {
    if (/COUNT\(\*\)/i.test(sql) && /FROM\s+decision_record/i.test(sql) &&
      /JOIN\s+review_result/i.test(sql)) {
      const today = args !== undefined && args.length > 0 ? String(args[0]) : '';
      const reviews = this.rows('review_result');
      const pending = this.rows('decision_record').filter((row) => {
        const reviewAt = row.review_at === null || row.review_at === undefined ? '' : String(row.review_at);
        if (reviewAt.length === 0 || reviewAt > today || row.level === 'sealed') {
          return false;
        }
        const review = reviews.find((item) => item.id === row.review_id);
        return review !== undefined && review.level !== 'sealed';
      });
      return new FakeResultSet([{ total: pending.length }]);
    }
    const from = /FROM\s+([a-z_]+)/i.exec(sql);
    const table = from === null ? '' : from[1];
    if (/COUNT\(\*\)/i.test(sql) && table.length > 0) {
      return new FakeResultSet([{ total: this.rows(table).length }]);
    }
    return new FakeResultSet([]);
  }

  beginTransaction() {
    this.snapshot = new Map();
    for (const [table, rows] of this.tables) {
      this.snapshot.set(table, rows.map((row) => Object.assign({}, row)));
    }
  }

  commit() {
    this.snapshot = null;
  }

  rollBack() {
    if (this.snapshot !== null) {
      this.tables = this.snapshot;
      this.snapshot = null;
    }
  }
}

const store = new FakeStore();
const preferenceValues = new Map();
const fakePreferences = {
  getPreferences: async (context, options) => {
    const name = options && options.name ? options.name : 'default';
    return {
      get: async (key, fallback) => preferenceValues.has(`${name}:${key}`) ? preferenceValues.get(`${name}:${key}`) : fallback,
      put: async (key, value) => {
        preferenceValues.set(`${name}:${key}`, value);
      },
      flush: async () => {
      }
    };
  }
};
const fakeArkData = {
  relationalStore: {
    RdbPredicates: FakePredicates,
    SecurityLevel: { S1: 1 },
    getRdbStore: async () => store
  },
  preferences: fakePreferences
};

const originalLoad = Module._load;
const fakeCoreFileKit = {
  fileIo: {
    OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2 },
    accessSync: () => true,
    openSync: () => 0,
    open: async () => ({ fd: 0 }),
    close: async () => {
    },
    copyFile: async () => {
    },
    closeSync: () => {
    }
  }
};
const fakePerformanceKit = {
  hilog: {
    debug: () => {
    },
    info: () => {
    },
    warn: () => {
    },
    error: () => {
    }
  }
};
Module._load = function (request, parent, isMain) {
  if (request === '@kit.ArkData') {
    return fakeArkData;
  }
  if (request === '@kit.CoreFileKit') {
    return fakeCoreFileKit;
  }
  if (request === '@kit.PerformanceAnalysisKit') {
    return fakePerformanceKit;
  }
  return originalLoad.call(this, request, parent, isMain);
};

const { QuickNoteService, FREE_NOTE_TYPE } = require('./out2/note/QuickNoteService');
const { DELETED_NOTE_TITLE } = require('./out2/note/NoteListMapper');
const { createNoteDraft, createFreeformNoteDraft } = require('./out2/note/NoteDraftFactory');
const { NoteFieldKey } = require('./out2/note/NoteFieldKey');
const { NoteTemplateId } = require('./out2/note/NoteTemplateId');
const { NoteDepth } = require('./out2/note/NoteDraft');
const { AnchorService } = require('./out2/anchor/AnchorService');
const { RelationService } = require('./out2/relation/RelationService');
const { toReviewHistoryItem } = require('./out2/review/ReviewHistory');
const { StatusService } = require('./out2/status/StatusService');
const { HomeDataService } = require('./out2/data/HomeDataService');
const { ExperienceMaterialDao } = require('./out2/db/dao/ExperienceMaterialDao');
const { EvidenceItemDao } = require('./out2/db/dao/EvidenceItemDao');
const { DecisionRecordDao } = require('./out2/db/dao/DecisionRecordDao');
const { CostNoteDao } = require('./out2/db/dao/CostNoteDao');
const { toCostDimension } = require('./out2/model/CostNote');
const { parseReviewPayload } = require('./out2/db/SafeJson');
const { parseInteractionLog } = require('./out2/db/SafeJson');
const { PlanDao } = require('./out2/db/dao/PlanDao');
const { createPlan } = require('./out2/plan/PlanFactory');
const { AnchorDao } = require('./out2/db/dao/AnchorDao');
const { ReviewResultDao } = require('./out2/db/dao/ReviewResultDao');
const { ReviewMaterialDao } = require('./out2/db/dao/ReviewMaterialDao');
const { RequestAuditDao } = require('./out2/db/dao/RequestAuditDao');
const { buildNodeProgress, carryRatePercent, carrySeries } = require('./out2/plan/PlanInsights');
const { DB_TABLES, DB_TABLES_CHILD_FIRST, LEVELED_TABLES } = require('./out2/db/DbConstants');
const { TABLE_CREATE_SQLS } = require('./out2/db/schemas');
const { EventDao } = require('./out2/db/dao/EventDao');
const { DecisionDao } = require('./out2/db/dao/DecisionDao');
const { prepareExportBundle, allExportOptions } = require('./out2/export/ExportFilter');
const { renderExportDocument } = require('./out2/export/render');
const { ExportService } = require('./out2/export/ExportService');
const { PredictionService } = require('./out2/prediction/PredictionService');
const { validatePredictionDraft } = require('./out2/prediction/PredictionValidation');
const { ReviewService, decisionLevelFor } = require('./out2/review/ReviewService');
const { rangeFor } = require('./out2/review/ReviewRange');
const { PlanService } = require('./out2/plan/PlanService');
const { buildAnalysisInput } = require('./out2/security/RequestBuilder');
const { SecurityLevel } = require('./out2/model/SecurityLevel');

let passed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    passed += 1;
  } catch (error) {
    failures.push(`${name}: ${error.message}`);
  }
}

function fill(draft, key, value) {
  for (const entry of draft.entries) {
    if (entry.key === key) {
      entry.value = value;
    }
  }
}

function count(table) {
  return store.rows(table).length;
}

function lastRow(table) {
  const rows = store.rows(table);
  return rows[rows.length - 1];
}

function reset() {
  store.tables = new Map();
  store.snapshot = null;
  store.failTable = null;
  store.failUpdateTable = null;
  store.insertCount = 0;
  preferenceValues.clear();
}

async function main() {
  const service = await QuickNoteService.open({});

  await test('决策速记同时写入事件与决策并互相关联', async () => {
    reset();
    const draft = createNoteDraft(NoteTemplateId.DECISION);
    fill(draft, NoteFieldKey.BACKGROUND, '连续几天精力不足\n想做调整');
    fill(draft, NoteFieldKey.OPTIONS, '早起、减少晚间安排');
    fill(draft, NoteFieldKey.CHOICE, '减少晚间安排');
    fill(draft, NoteFieldKey.EXPECTED_OUTCOME, '睡眠回升');
    draft.tags.push('决策', '  ');
    const saved = await service.save(draft);

    assert.strictEqual(count('event'), 1);
    assert.strictEqual(count('decision'), 1);
    const eventRow = lastRow('event');
    const decisionRow = lastRow('decision');
    assert.strictEqual(eventRow.id, saved.eventId);
    assert.strictEqual(decisionRow.id, saved.decisionId);
    assert.strictEqual(eventRow.type, '决策');
    assert.strictEqual(eventRow.title, '连续几天精力不足');
    assert.strictEqual(eventRow.content, '背景：连续几天精力不足\n想做调整\n选项：早起、减少晚间安排\n选择：减少晚间安排\n预期：睡眠回升');
    assert.deepStrictEqual(JSON.parse(eventRow.tags), ['决策']);
    assert.deepStrictEqual(JSON.parse(eventRow.related_decision_ids), [saved.decisionId]);
    assert.deepStrictEqual(JSON.parse(decisionRow.related_event_ids), [saved.eventId]);
    assert.strictEqual(decisionRow.background, '连续几天精力不足\n想做调整');
    assert.deepStrictEqual(JSON.parse(decisionRow.options), ['早起', '减少晚间安排']);
    assert.strictEqual(decisionRow.reviewed, 0);
    assert.strictEqual(decisionRow.level, 'local_only');
  });

  await test('自由速记只写入事件', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '随手记一条';
    const saved = await service.save(draft);
    assert.strictEqual(count('event'), 1);
    assert.strictEqual(count('decision'), 0);
    assert.strictEqual(saved.decisionId, null);
    assert.strictEqual(lastRow('event').type, FREE_NOTE_TYPE);
    assert.strictEqual(lastRow('event').title, '随手记一条');
  });

  await test('校验失败的草稿不落库', async () => {
    reset();
    let message = '';
    try {
      await service.save(createNoteDraft(NoteTemplateId.EMOTION));
    } catch (error) {
      message = error.message;
    }
    assert.strictEqual(message, '触发不能为空');
    assert.strictEqual(count('event'), 0);
    assert.strictEqual(count('decision'), 0);
  });

  await test('决策写入失败时回滚已写入的事件', async () => {
    reset();
    const draft = createNoteDraft(NoteTemplateId.DECISION);
    fill(draft, NoteFieldKey.BACKGROUND, '背景');
    store.failTable = 'decision';
    let failed = false;
    try {
      await service.save(draft);
    } catch (error) {
      failed = true;
    }
    assert.strictEqual(failed, true);
    assert.strictEqual(count('event'), 0);
    assert.strictEqual(count('decision'), 0);
  });

  await test('时间戳为 0 时用当前时间补上', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '补时间戳';
    draft.timestamp = 0;
    const before = Date.now();
    await service.save(draft);
    const savedAt = lastRow('event').timestamp;
    assert.ok(savedAt >= before && savedAt <= Date.now());
  });

  await test('列表按时间倒序并遵守条数上限', async () => {
    reset();
    for (let index = 0; index < 3; index += 1) {
      const draft = createFreeformNoteDraft();
      draft.content = `第 ${index} 条`;
      draft.timestamp = 1000 + index;
      await service.save(draft);
    }
    const items = await service.listRecent(2);
    assert.strictEqual(items.length, 2);
    assert.deepStrictEqual(items.map((item) => item.timestamp), [1002, 1001]);
    assert.strictEqual((await service.listRecent(0)).length, 3);
    assert.strictEqual((await service.listRecent(-5)).length, 3);
  });

  await test('按类型筛选列表，空类型退化为全部', async () => {
    reset();
    const emotion = createNoteDraft(NoteTemplateId.EMOTION);
    fill(emotion, NoteFieldKey.TRIGGER, '临时改期');
    await service.save(emotion);

    const body = createNoteDraft(NoteTemplateId.BODY);
    fill(body, NoteFieldKey.BODY_SIGNAL, '早起头沉');
    await service.save(body);

    const emotions = await service.listByType('情绪');
    assert.strictEqual(emotions.length, 1);
    assert.strictEqual(emotions[0].type, '情绪');
    assert.strictEqual((await service.listByType('  ')).length, 2);
    assert.strictEqual((await service.listByType('人际')).length, 0);
  });

  await test('列表行带摘要与时间标签', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '第一行\n第二行';
    await service.save(draft);
    const items = await service.listRecent();
    assert.strictEqual(items[0].title, '第一行');
    assert.strictEqual(items[0].summary, '第一行 第二行');
    assert.ok(/^\d{2}:\d{2}$/.test(items[0].timeLabel));
  });

  await test('按 id 查询详情，缺失返回 null', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '详情内容';
    const saved = await service.save(draft);
    const detail = await service.findNote(saved.eventId);
    assert.ok(detail !== null);
    assert.strictEqual(detail.id, saved.eventId);
    assert.strictEqual(detail.content, '详情内容');
    assert.strictEqual(detail.type, FREE_NOTE_TYPE);
    assert.strictEqual(detail.level, 'local_only');
    assert.ok(detail.timeLabel.length > 0);
    assert.strictEqual(await service.findNote('missing'), null);
  });

  await test('修订写入新版本，列表只显示最新版', async () => {
    reset();
    const first = createFreeformNoteDraft();
    first.content = '原始正文';
    first.timestamp = 1000;
    const saved = await service.save(first);
    const originalRow = lastRow('event');
    assert.strictEqual(originalRow.version, 1);
    assert.strictEqual(originalRow.revision_of, '');

    const draft = createFreeformNoteDraft();
    draft.content = '修订正文';
    draft.timestamp = 2000;
    const revision = await service.saveRevision(saved.eventId, draft);
    assert.strictEqual(revision.version, 2);
    assert.notStrictEqual(revision.eventId, saved.eventId);

    const rows = store.rows('event');
    assert.strictEqual(rows.length, 2);
    const revisionRow = rows.find((row) => row.id === revision.eventId);
    assert.strictEqual(revisionRow.revision_of, saved.eventId);
    assert.strictEqual(revisionRow.version, 2);
    assert.strictEqual(revisionRow.content, '修订正文');
    const keptRow = rows.find((row) => row.id === saved.eventId);
    assert.strictEqual(keptRow.content, '原始正文');
    assert.strictEqual(keptRow.version, 1);
    assert.strictEqual(keptRow.revision_of, '');

    const items = await service.listRecent();
    assert.strictEqual(items.length, 1);
    assert.strictEqual(items[0].id, revision.eventId);
    assert.strictEqual(items[0].version, 2);

    const second = createFreeformNoteDraft();
    second.content = '再次修订';
    second.timestamp = 3000;
    const third = await service.saveRevision(revision.eventId, second);
    assert.strictEqual(third.version, 3);
    assert.strictEqual(store.rows('event').find((row) => row.id === third.eventId).revision_of, saved.eventId);
    const latest = await service.listRecent();
    assert.strictEqual(latest.length, 1);
    assert.strictEqual(latest[0].id, third.eventId);
  });

  await test('按类型筛选与首页近期都只显示最新版', async () => {
    reset();
    const first = createFreeformNoteDraft();
    first.content = '初稿';
    first.timestamp = 1000;
    const saved = await service.save(first);

    const draft = createFreeformNoteDraft();
    draft.content = '改稿';
    draft.timestamp = 2000;
    const revision = await service.saveRevision(saved.eventId, draft);

    const typed = await service.listByTypePage(FREE_NOTE_TYPE, 10, 0);
    assert.strictEqual(typed.length, 1);
    assert.strictEqual(typed[0].id, revision.eventId);

    const home = await HomeDataService.open({});
    const recent = await home.loadRecentNotes(5);
    assert.strictEqual(recent.length, 1);
    assert.strictEqual(recent[0].id, revision.eventId);
  });

  await test('分页按去重后的根切片，第二页不含重复根', async () => {
    reset();
    const expectedIds = [];
    for (let index = 0; index < 3; index += 1) {
      const draft = createFreeformNoteDraft();
      draft.content = `根 ${index}`;
      draft.timestamp = 1000 + index * 10;
      const saved = await service.save(draft);
      expectedIds.push(saved.eventId);
      if (index < 2) {
        const revision = createFreeformNoteDraft();
        revision.content = `根 ${index} 修订`;
        revision.timestamp = 1005 + index * 10;
        const savedRevision = await service.saveRevision(saved.eventId, revision);
        expectedIds[expectedIds.length - 1] = savedRevision.eventId;
      }
    }
    const pageOne = await service.listRecentPage(2, 0);
    const pageTwo = await service.listRecentPage(2, 2);
    assert.strictEqual(pageOne.length, 2);
    assert.strictEqual(pageTwo.length, 1);
    const ids = pageOne.concat(pageTwo).map((item) => item.id);
    assert.strictEqual(new Set(ids).size, 3);
    for (const id of ids) {
      assert.ok(expectedIds.includes(id));
    }
  });

  await test('删除最新版后整条链不再出现在列表', async () => {
    reset();
    const first = createFreeformNoteDraft();
    first.content = '待删初稿';
    first.timestamp = 1000;
    const saved = await service.save(first);

    const draft = createFreeformNoteDraft();
    draft.content = '待删改稿';
    draft.timestamp = 2000;
    const revision = await service.saveRevision(saved.eventId, draft);

    await service.delete(revision.eventId);

    assert.strictEqual((await service.listRecent()).length, 0);
    assert.strictEqual((await service.listByTypePage(FREE_NOTE_TYPE, 10, 0)).length, 0);
    const home = await HomeDataService.open({});
    assert.strictEqual((await home.loadRecentNotes(5)).length, 0);
    const rows = store.rows('event');
    assert.strictEqual(rows.length, 2);
    for (const row of rows) {
      assert.strictEqual(row.deleted, 1);
      assert.ok(row.content.length > 0);
      assert.notStrictEqual(row.title, DELETED_NOTE_TITLE);
    }
    await service.purgeNow(revision.eventId);
  });

  await test('连续两次修订版本号递增且不重复', async () => {
    reset();
    const first = createFreeformNoteDraft();
    first.content = 'v1';
    first.timestamp = 1000;
    const saved = await service.save(first);

    const second = createFreeformNoteDraft();
    second.content = 'v2';
    second.timestamp = 2000;
    const v2 = await service.saveRevision(saved.eventId, second);

    const third = createFreeformNoteDraft();
    third.content = 'v3';
    third.timestamp = 3000;
    const v3 = await service.saveRevision(v2.eventId, third);

    assert.strictEqual(v2.version, 2);
    assert.strictEqual(v3.version, 3);
    const versions = store.rows('event').map((row) => row.version).sort((left, right) => left - right);
    assert.deepStrictEqual(versions, [1, 2, 3]);
    const items = await service.listRecent();
    assert.strictEqual(items.length, 1);
    assert.strictEqual(items[0].version, 3);
  });

  await test('历史版本按序号升序返回，导出只带最新版', async () => {
    reset();
    const first = createFreeformNoteDraft();
    first.content = 'MARKER_V1';
    first.timestamp = 1000;
    first.level = SecurityLevel.ANALYZABLE;
    const saved = await service.save(first);

    const draft = createFreeformNoteDraft();
    draft.content = 'MARKER_V2';
    draft.timestamp = 2000;
    draft.level = SecurityLevel.ANALYZABLE;
    const revision = await service.saveRevision(saved.eventId, draft);

    const versions = await service.listRevisions(revision.eventId);
    assert.strictEqual(versions.length, 2);
    assert.deepStrictEqual(versions.map((item) => item.version), [1, 2]);
    assert.strictEqual(versions[0].id, saved.eventId);
    assert.strictEqual(versions[1].id, revision.eventId);

    const detail = await service.findNote(revision.eventId);
    assert.strictEqual(detail.version, 2);
    assert.strictEqual(detail.revisionOf, saved.eventId);

    const exportService = await ExportService.open({});
    const markdown = await exportService.buildMarkdown(3000, allExportOptions());
    assert.strictEqual(markdown.includes('MARKER_V2'), true);
    assert.strictEqual(markdown.includes('MARKER_V1'), false);
  });

  await test('锚点示例数据只载入一次', async () => {
    reset();
    const anchorService = await AnchorService.open({});
    assert.deepStrictEqual(await anchorService.list(), []);
    assert.strictEqual(await anchorService.seedDemoAnchors(), 2);
    const anchors = await anchorService.list();
    assert.strictEqual(anchors.length, 2);
    assert.strictEqual(anchors[0].order, 1);
    assert.strictEqual(anchors[1].order, 2);
    assert.strictEqual(await anchorService.seedDemoAnchors(), 0);
    assert.strictEqual((await anchorService.list()).length, 2);
  });

  await test('关系示例数据只载入一次并可查详情', async () => {
    reset();
    const relationService = await RelationService.open({});
    assert.deepStrictEqual(await relationService.list(null), []);
    assert.strictEqual(await relationService.seedDemoRelations(), 3);
    const items = await relationService.list(null);
    assert.strictEqual(items.length, 3);
    assert.strictEqual(items[0].trustLevel, 'transparent');
    assert.strictEqual(await relationService.seedDemoRelations(), 0);
    const detail = await relationService.find(items[0].id);
    assert.ok(detail !== null);
    assert.strictEqual(detail.interactionCount, 1);
  });

  await test('暂停让出主目标，恢复时收回', async () => {
    reset();
    const planService = await PlanService.open({});
    const first = await planService.createPlan('甲目标', '2026-11-02');
    const second = await planService.createPlan('乙目标', '2026-11-02');
    await planService.setPrimary(first.id);
    await planService.pausePlan(first.id, '这周先停');

    const paused = await planService.listPlans();
    const primaryAfterPause = paused.find((plan) => plan.isPrimary);
    assert.ok(primaryAfterPause !== undefined);
    assert.strictEqual(primaryAfterPause.id, second.id);

    await planService.resumePlan(first.id);
    const resumed = await planService.listPlans();
    assert.strictEqual(resumed.find((plan) => plan.isPrimary).id, first.id);
  });

  await test('锚点修订生成新版本并停用旧版', async () => {
    reset();
    const anchorService = await AnchorService.open({});
    await anchorService.seedDemoAnchors();
    const before = await anchorService.list();
    const first = before[0];

    const revised = await anchorService.revise(first.id, '改过的句子', '适用于工作', '换了说法');
    assert.strictEqual(revised.version, 2);

    const active = await anchorService.list();
    assert.ok(!active.some((anchor) => anchor.id === first.id));
    assert.ok(active.some((anchor) => anchor.id === revised.id));

    const versions = await anchorService.versions(revised.id);
    assert.strictEqual(versions.length, 2);
    assert.strictEqual(versions[0].status, 'retired');
    assert.strictEqual(versions[1].status, 'active');

    await assert.rejects(async () => {
      await anchorService.revise(revised.id, '再改一次', '', '');
    });
  });

  await test('目标与首周同事务创建，失败时不留下空目标', async () => {
    reset();
    const planService = await PlanService.open({});
    await planService.createPlan('本周计划', '2026-11-02');
    assert.strictEqual(store.rows('plan').length, 1);
    assert.strictEqual(store.rows('plan_node').length, 1);

    store.failTable = 'plan_node';
    let failed = false;
    try {
      await planService.createPlan('第二个目标', '2026-11-09');
    } catch (error) {
      failed = true;
    }
    store.failTable = null;
    assert.strictEqual(failed, true);
    assert.strictEqual(store.rows('plan').length, 1);
  });

  await test('反向关联保存按记录整体替换，重复保存不产生重复行', async () => {
    reset();
    const planService = await PlanService.open({});
    const plan = await planService.createPlan('本周计划', '2026-11-02');
    const node = (await planService.listNodes(plan.id))[0];
    await planService.replaceLinksByTarget('note', 'ev_1', [{
      id: 'lk_a', planId: plan.id, nodeId: node.id, module: 'note',
      targetId: 'ev_1', label: '一条速记', createdAt: 1
    }]);
    assert.strictEqual(store.rows('plan_link').length, 1);
    await planService.replaceLinksByTarget('note', 'ev_1', [{
      id: 'lk_b', planId: plan.id, nodeId: node.id, module: 'note',
      targetId: 'ev_1', label: '一条速记', createdAt: 2
    }]);
    assert.strictEqual(store.rows('plan_link').length, 1);
    assert.strictEqual(store.rows('plan_link')[0].id, 'lk_b');
    const links = await planService.listLinksByTarget('note', 'ev_1');
    assert.strictEqual(links.length, 1);
  });

  await test('按时间范围取速记时间戳，封存记录不计入', async () => {
    reset();
    const early = createFreeformNoteDraft();
    early.content = '早一条';
    early.timestamp = 1000;
    await service.save(early);
    const late = createFreeformNoteDraft();
    late.content = '晚一条';
    late.timestamp = 2000;
    await service.save(late);

    assert.deepStrictEqual(await service.timestampsBetween(1500, 2500), [2000]);
    store.rows('event')[1].level = 'sealed';
    assert.deepStrictEqual(await service.timestampsBetween(1500, 2500), []);
  });

  await test('损坏的 JSON 字段只影响该字段，不阻断列表', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '正常速记';
    await service.save(draft);
    const relationService = await RelationService.open({});
    await relationService.seedDemoRelations();

    const eventRow = lastRow('event');
    eventRow.tags = '{not json';
    eventRow.related_decision_ids = '{"a":1}';
    const relationRow = lastRow('relation');
    relationRow.interaction_log = '[{"timestamp":"x","content":1}]';

    const notes = await service.listRecent();
    assert.strictEqual(notes.length, 1);
    assert.deepStrictEqual(notes[0].tags, []);
    const relations = await relationService.list(null);
    assert.strictEqual(relations.length, 3);
    const damaged = relations.find((item) => item.id === relationRow.id);
    assert.strictEqual(damaged.interactionCount, 0);
  });

  await test('状态示例读数载入一次并汇总最近窗口', async () => {
    reset();
    const statusService = await StatusService.open({});
    assert.strictEqual((await statusService.overview()).latest, null);
    assert.strictEqual(await statusService.seedDemoRecords(), 7);
    const overview = await statusService.overview();
    assert.ok(overview.latest !== null);
    assert.strictEqual(overview.latest.date, '2026-10-27');
    assert.strictEqual(overview.summary.days, 7);
    assert.strictEqual(overview.summary.averageSleep, 6.7);
    assert.strictEqual(await statusService.seedDemoRecords(), 0);
    assert.strictEqual((await statusService.history()).length, 7);
  });

  await test('快速档不生成决策记录且类型为速记', async () => {
    reset();
    const draft = createNoteDraft(NoteTemplateId.DECISION);
    draft.depth = NoteDepth.QUICK;
    draft.content = '一句现场';
    const saved = await service.save(draft);
    assert.strictEqual(saved.decisionId, null);
    const row = store.rows('event').find((item) => item.id === saved.eventId);
    assert.strictEqual(row.type, '速记');
    assert.strictEqual(count('decision'), 0);
  });

  await test('首页最近速记跳过封存记录', async () => {
    reset();
    store.rows('event').push(
      {
        id: 'ev_local', title: '本机速记', content: '正文', type: '自由', timestamp: 2000,
        tags: '[]', level: 'local_only', related_decision_ids: '[]', related_relation_ids: '[]',
        revision_of: '', version: 1, deleted: 0
      },
      {
        id: 'ev_sealed', title: '封存速记', content: '不该出现', type: '自由', timestamp: 3000,
        tags: '[]', level: 'sealed', related_decision_ids: '[]', related_relation_ids: '[]',
        revision_of: '', version: 1, deleted: 0
      }
    );
    const home = await HomeDataService.open({});
    const notes = await home.loadRecentNotes(5);
    assert.deepStrictEqual(notes.map((note) => note.id), ['ev_local']);
  });

  await test('首页待修订预测包含未成立与三类非二值', async () => {
    reset();
    const now = new Date(2026, 9, 27, 12, 0).getTime();
    const predictionService = await PredictionService.open({});
    const outcomes = ['hold', 'fail', 'partial', 'insufficient', 'undecidable'];
    for (let index = 0; index < outcomes.length; index += 1) {
      const created = await predictionService.create({
        target: `待修订 ${index}`,
        judgment: '达成',
        confidence: 60,
        reason: '',
        falsification: '若未达成',
        settlementDate: '2026-10-27'
      }, now);
      await predictionService.settle(created.id, '结果', outcomes[index], '', now);
    }
    const home = await HomeDataService.open({});
    const summary = await home.loadSummary();
    assert.strictEqual(summary.revisionPredictions, 4);
    assert.strictEqual(summary.settledPredictions, 5);
  });

  await test('整条改密级只收窄宽于记录的材料的级', async () => {
    reset();
    store.rows('experience_material').push(
      {
        id: 'mt_1', event_id: 'ev_1', kind: 'body', form: '', text: '胸闷', observed_at: 1,
        source: 'direct', source_stance: '', level: 'analyzable', revision_of: '', deleted: 0, created_at: 1
      },
      {
        id: 'mt_2', event_id: 'ev_1', kind: 'scene', form: '', text: '现场', observed_at: 2,
        source: 'direct', source_stance: '', level: 'sealed', revision_of: '', deleted: 0, created_at: 1
      },
      {
        id: 'mt_3', event_id: 'ev_1', kind: 'feeling', form: '', text: '紧张', observed_at: 3,
        source: 'direct', source_stance: '', level: 'local_only', revision_of: '', deleted: 0, created_at: 1
      }
    );
    const dao = new ExperienceMaterialDao(store);
    await dao.clampLevelsByEvent('ev_1', 'local_only');
    assert.deepStrictEqual(store.rows('experience_material').map((row) => row.level),
      ['local_only', 'sealed', 'local_only']);
    await dao.clampLevelsByEvent('ev_1', 'sealed');
    assert.deepStrictEqual(store.rows('experience_material').map((row) => row.level),
      ['sealed', 'sealed', 'sealed']);
  });

  await test('同日更正保留原读数并记住观察规则', async () => {    reset();
    const statusService = await StatusService.open({});
    await statusService.save({
      date: '2026-10-28',
      sleepHours: 5,
      exerciseCount: 0,
      alertCount: 1,
      unknownReadings: '',
      note: '原记录',
      bodySignals: '头痛',
      functionState: '能读十分钟',
      emotion: '',
      environment: '',
      capacity: 'limited',
      functionGain: '',
      costPaid: ''
    }, 1000);
    const first = await statusService.find('2026-10-28');
    assert.strictEqual(first.revisions.length, 0);
    assert.strictEqual(first.bodySignals, '头痛');
    assert.strictEqual(first.capacity, 'limited');

    await statusService.save({
      date: '2026-10-28',
      sleepHours: 7,
      exerciseCount: 1,
      alertCount: 0,
      unknownReadings: '',
      note: '改过',
      bodySignals: '头痛',
      functionState: '能读十分钟',
      emotion: '',
      environment: '',
      capacity: 'bearable',
      functionGain: '',
      costPaid: ''
    }, 2000);
    const second = await statusService.find('2026-10-28');
    assert.strictEqual(second.correctedAt, 2000);
    assert.strictEqual(second.revisions.length, 1);
    assert.strictEqual(second.revisions[0].sleepHours, 5);
    assert.strictEqual(second.revisions[0].capacity, 'limited');
    assert.strictEqual(second.sleepHours, 7);

    await statusService.saveObservationRule({ sleepMinHours: 8, alertWarnCount: 3, hintsEnabled: false });
    const reopened = await StatusService.open({});
    assert.strictEqual(reopened.observationRule().sleepMinHours, 8);
    assert.strictEqual(reopened.observationRule().hintsEnabled, false);
    assert.strictEqual((await reopened.find('2026-10-28')).flags.length, 0);
  });

  await test('预测示例数据载入一次并生成统计', async () => {
    reset();
    const predictionService = await PredictionService.open({});
    assert.strictEqual((await predictionService.stats()).settled, 0);
    assert.strictEqual(await predictionService.seedDemoPredictions(), 10);
    const stats = await predictionService.stats();
    assert.strictEqual(stats.settled, 8);
    assert.strictEqual(stats.hits, 5);
    assert.strictEqual(stats.misses, 3);
    assert.strictEqual(stats.hitRate, 63);
    assert.strictEqual(stats.months.length, 3);
    assert.strictEqual(stats.months[0].month, '2026-08');
    assert.strictEqual(await predictionService.seedDemoPredictions(), 0);
  });

  await test('预测创建后落盘且只能结算一次', async () => {
    reset();
    const predictionService = await PredictionService.open({});
    const now = new Date(2026, 9, 27, 12, 0).getTime();
    const created = await predictionService.create({
      target: '本周作息',
      judgment: '本周日均睡眠达到 7 小时',
      confidence: 70,
      reason: '已调整晚间安排',
      falsification: '若日均睡眠低于 6 小时',
      settlementDate: '2026-10-27'
    }, now);
    assert.strictEqual(created.status, 'pending');
    assert.strictEqual(created.hit, null);
    assert.strictEqual(created.version, 1);

    const future = await predictionService.create({
      target: '下月作息',
      judgment: '下月日均睡眠达到 7 小时',
      confidence: 60,
      reason: '',
      falsification: '若日均睡眠低于 6 小时',
      settlementDate: '2026-11-03'
    }, now);
    await assert.rejects(async () => {
      await predictionService.settle(future.id, '提前结算', 'hold', '', now);
    });

    await assert.rejects(async () => {
      await predictionService.create({
        target: ' ',
        judgment: '',
        confidence: 0,
        reason: '',
        falsification: '',
        settlementDate: '2026-10-01'
      }, now);
    });

    await assert.rejects(async () => {
      await predictionService.create({
        target: '没有失效条件',
        judgment: '下周达成',
        confidence: 50,
        reason: '',
        settlementDate: '2026-11-03'
      }, now);
    });

    const settled = await predictionService.settle(created.id, '达成六天', 'hold');
    assert.ok(settled !== null);
    assert.strictEqual(settled.status, 'settled');
    assert.strictEqual(settled.hit, true);

    const stats = await predictionService.stats();
    assert.strictEqual(stats.settled, 1);
    assert.strictEqual(stats.hitRate, 100);
    assert.strictEqual(stats.excluded, 0);

    await assert.rejects(async () => {
      await predictionService.settle(created.id, '再次结算', 'fail');
    });
  });

  await test('统计分母只收二值结算，非二值单列', async () => {
    reset();
    const now = new Date(2026, 9, 27, 12, 0).getTime();
    const predictionService = await PredictionService.open({});
    const outcomes = ['hold', 'fail', 'partial', 'insufficient', 'undecidable'];
    for (let index = 0; index < outcomes.length; index += 1) {
      const created = await predictionService.create({
        target: `结算分母 ${index}`,
        judgment: '达成',
        confidence: 60,
        reason: '',
        falsification: '若未达成',
        settlementDate: '2026-10-27'
      }, now);
      await predictionService.settle(created.id, '结果', outcomes[index], '', now);
    }
    const stats = await predictionService.stats();
    assert.strictEqual(stats.settled, 5);
    assert.strictEqual(stats.hits, 1);
    assert.strictEqual(stats.misses, 1);
    assert.strictEqual(stats.hitRate, 50);
    assert.strictEqual(stats.outcomes.partial, 1);
    assert.strictEqual(stats.excluded, 0);
  });

  await test('复盘保存后可查历史与锚点对照', async () => {
    reset();
    const anchorService = await AnchorService.open({});
    await anchorService.seedDemoAnchors();
    const anchors = await anchorService.list();

    const reviewService = await ReviewService.open({});
    const id = await reviewService.save('week', {
      facts: '本周有三天晚睡',
      interpretation: '最近状态差',
      contradiction: '解释没有引用具体日期',
      action: '十点后不安排任务',
      anchorIds: [anchors[1].id]
    }, '10-21 ~ 10-27');

    const history = await reviewService.history();
    assert.strictEqual(history.length, 1);
    assert.strictEqual(history[0].id, id);
    assert.strictEqual(history[0].anchorCount, 1);
    assert.strictEqual(history[0].periodLabel, '周复盘');

    const detail = await reviewService.find(id);
    assert.ok(detail !== null);
    assert.strictEqual(detail.anchors.length, 1);
    assert.strictEqual(detail.anchors[0].id, anchors[1].id);
    assert.strictEqual(await reviewService.find('missing'), null);
  });

  await test('复盘保存时按引用材料写下快照', async () => {
    reset();
    const noteDraft = createFreeformNoteDraft();
    noteDraft.content = 'MARKER_SNAPSHOT_TEXT';
    noteDraft.materials = [
      { kind: 'scene', text: 'MARKER_SNAPSHOT_TEXT', source: 'reading', form: 'dialogue' }
    ];
    await service.save(noteDraft);
    const materialId = store.rows('experience_material')[0].id;

    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '本周有三天晚睡',
      interpretation: '',
      contradiction: '',
      action: '',
      materialIds: [materialId],
      anchorIds: []
    }, '11-09 ~ 11-15');

    const rows = store.rows('review_material');
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].review_id, reviewId);
    assert.strictEqual(rows[0].material_id, materialId);
    assert.strictEqual(rows[0].text_snapshot, 'MARKER_SNAPSHOT_TEXT');
    assert.strictEqual(rows[0].source_snapshot, 'reading');
    assert.strictEqual(rows[0].snapshot_missing, 0);

    const snapshots = await reviewService.materials(reviewId);
    assert.strictEqual(snapshots.length, 1);
    assert.strictEqual(snapshots[0].textSnapshot, 'MARKER_SNAPSHOT_TEXT');
    assert.strictEqual(snapshots[0].sourceSnapshot, 'reading');
  });

  await test('复盘保存时按证据草稿写入证据行', async () => {
    reset();
    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '',
      interpretation: '',
      contradiction: '',
      action: '',
      payload: {
        scene: '只写了现场',
        model: '',
        relation: '',
        evidence: '',
        cost: '',
        revision: '',
        evidenceDrafts: [
          { sourceType: 'practice', note: 'MARKER_EVIDENCE_ONE', effect: 'supports' },
          { sourceType: 'book', note: 'MARKER_EVIDENCE_TWO', effect: 'challenges' }
        ]
      },
      anchorIds: []
    }, '11-09 ~ 11-15');

    const stored = store.rows('evidence_item');
    assert.strictEqual(stored.length, 2);
    assert.strictEqual(stored[0].target_type, 'review');
    assert.strictEqual(stored[0].target_id, reviewId);
    assert.strictEqual(stored[0].zone, 4);
    assert.strictEqual(stored[0].level, SecurityLevel.LOCAL_ONLY);

    const dao = new EvidenceItemDao(store);
    const items = await dao.queryByTarget('review', reviewId);
    assert.strictEqual(items.length, 2);
    assert.deepStrictEqual(items.map((item) => item.note),
      ['MARKER_EVIDENCE_ONE', 'MARKER_EVIDENCE_TWO']);
    assert.deepStrictEqual(items.map((item) => item.zone), [4, 4]);
  });

  await test('复盘保存时按成本草稿写入成本行', async () => {
    reset();
    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '',
      interpretation: '',
      contradiction: '',
      action: '',
      payload: {
        scene: '只写了现场',
        model: '',
        relation: '',
        evidence: '',
        cost: '',
        revision: '',
        costDrafts: [
          { dimension: 'time', text: 'MARKER_COST_TIME', bearable: true },
          { dimension: 'body', text: 'MARKER_COST_BODY', bearable: false }
        ]
      },
      anchorIds: []
    }, '11-09 ~ 11-15');

    const stored = store.rows('cost_note');
    assert.strictEqual(stored.length, 2);
    assert.strictEqual(stored[0].review_id, reviewId);
    assert.strictEqual(stored[0].bearable, 1);
    assert.strictEqual(stored[1].bearable, 0);

    const notes = await reviewService.costs(reviewId);
    assert.deepStrictEqual(notes.map((note) => note.dimension), ['time', 'body']);
    assert.deepStrictEqual(notes.map((note) => note.text), ['MARKER_COST_TIME', 'MARKER_COST_BODY']);
    assert.deepStrictEqual(notes.map((note) => note.bearable), [true, false]);
  });

  await test('复盘保存时按决定引用写入关联行且重复 id 只写一条', async () => {
    reset();
    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '',
      interpretation: '',
      contradiction: '',
      action: '',
      payload: {
        scene: '只写了现场',
        model: '',
        relation: '',
        evidence: '',
        cost: '',
        revision: '',
        decisionIds: ['dc_1', 'dc_2', 'dc_1']
      },
      anchorIds: []
    }, '11-09 ~ 11-15');

    const stored = store.rows('review_decision');
    assert.strictEqual(stored.length, 2);
    assert.strictEqual(stored[0].review_id, reviewId);
    assert.deepStrictEqual(stored.map((row) => row.decision_id), ['dc_1', 'dc_2']);

    const ids = await reviewService.decisions(reviewId);
    assert.deepStrictEqual(ids, ['dc_1', 'dc_2']);
  });

  await test('复盘保存把引用编号写进关联表并从 payload 清空', async () => {
    reset();
    const noteDraft = createFreeformNoteDraft();
    noteDraft.content = 'MARKER_LINK_ONE';
    noteDraft.materials = [
      { kind: 'scene', text: 'MARKER_LINK_ONE', source: 'reading' },
      { kind: 'scene', text: 'MARKER_LINK_TWO', source: 'practice' }
    ];
    await service.save(noteDraft);
    const materialIds = store.rows('experience_material').map((row) => row.id);
    assert.strictEqual(materialIds.length, 2);

    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '',
      interpretation: '',
      contradiction: '',
      action: '',
      materialIds: materialIds,
      payload: {
        scene: '只写了现场',
        model: '',
        relation: '',
        evidence: '',
        cost: '',
        revision: '',
        decisionIds: ['dc_1', 'dc_2']
      },
      anchorIds: []
    }, '11-09 ~ 11-15');

    const stored = JSON.parse(store.rows('review_result')[0].payload);
    assert.deepStrictEqual(stored.materialIds, []);
    assert.deepStrictEqual(stored.decisionIds, []);
    assert.strictEqual(store.rows('review_material').length, 2);
    assert.strictEqual(store.rows('review_decision').length, 2);

    const snapshots = await reviewService.materials(reviewId);
    assert.deepStrictEqual(snapshots.map((row) => row.materialId).sort(), materialIds.slice().sort());
    assert.deepStrictEqual(await reviewService.decisions(reviewId), ['dc_1', 'dc_2']);
  });

  await test('旧复盘只有 payload 决定引用时 decisions 回退读取', async () => {
    reset();
    store.rows('review_result').push({
      id: 'rv_legacy_decision',
      payload: JSON.stringify({ decisionIds: ['dc_legacy_1', 'dc_legacy_2'] })
    });

    const reviewService = await ReviewService.open({});
    const ids = await reviewService.decisions('rv_legacy_decision');
    assert.deepStrictEqual(ids, ['dc_legacy_1', 'dc_legacy_2']);
  });

  await test('最近决定按时间倒序并截断', async () => {
    reset();
    store.rows('decision').push(
      { id: 'dc_old', title: '旧决定', choice: '旧选择', timestamp: 1000, level: 'local_only' },
      { id: 'dc_new', title: '新决定', choice: '新选择', timestamp: 3000, level: 'local_only' },
      { id: 'dc_mid', title: '中决定', choice: '中选择', timestamp: 2000, level: 'local_only' }
    );
    const reviewService = await ReviewService.open({});
    const recent = await reviewService.recentDecisions(2);
    assert.deepStrictEqual(recent.map((item) => item.id), ['dc_new', 'dc_mid']);
    assert.deepStrictEqual(recent.map((item) => item.title), ['新决定', '中决定']);
    assert.deepStrictEqual(recent.map((item) => item.choice), ['新选择', '中选择']);
  });

  await test('按决定筛选只返回引用过它的复盘', async () => {
    reset();
    const reviewService = await ReviewService.open({});
    const cited = (decisionIds, rangeLabel) => reviewService.save('week', {
      facts: '',
      interpretation: '',
      contradiction: '',
      action: '',
      payload: {
        scene: '现场',
        model: '',
        relation: '',
        evidence: '',
        cost: '',
        revision: '',
        decisionIds: decisionIds
      },
      anchorIds: []
    }, rangeLabel);

    const firstId = await cited(['dc_1'], '11-02 ~ 11-08');
    const secondId = await cited(['dc_1'], '11-09 ~ 11-15');
    const otherId = await cited(['dc_2'], '11-16 ~ 11-22');
    for (const row of store.rows('review_result')) {
      if (row.id === firstId) {
        row.created_at = 1000;
      }
      if (row.id === secondId) {
        row.created_at = 2000;
      }
      if (row.id === otherId) {
        row.created_at = 3000;
      }
    }

    const matched = await reviewService.historyByDecision('dc_1');
    assert.deepStrictEqual(matched.map((item) => item.id), [secondId, firstId]);
    assert.strictEqual(matched.some((item) => item.id === otherId), false);
    assert.deepStrictEqual((await reviewService.historyByDecision('dc_2')).map((item) => item.id), [otherId]);
    assert.deepStrictEqual(await reviewService.historyByDecision(''), []);
    assert.deepStrictEqual(await reviewService.historyByDecision('dc_missing'), []);
  });

  await test('删除被引用的速记后快照清空正文并标记缺失', async () => {
    reset();
    const noteDraft = createFreeformNoteDraft();
    noteDraft.content = 'MARKER_SNAPSHOT_GONE';
    const saved = await service.save(noteDraft);
    const materialId = store.rows('experience_material')[0].id;

    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '本周有三天晚睡',
      interpretation: '',
      contradiction: '',
      action: '',
      materialIds: [materialId],
      anchorIds: []
    }, '11-09 ~ 11-15');
    assert.strictEqual(store.rows('review_material')[0].text_snapshot, 'MARKER_SNAPSHOT_GONE');

    await service.delete(saved.eventId);
    await service.purgeNow(saved.eventId);

    const row = store.rows('review_material')[0];
    assert.strictEqual(row.text_snapshot, '');
    assert.strictEqual(row.source_snapshot, '');
    assert.strictEqual(row.snapshot_missing, 1);
    const snapshots = await reviewService.materials(reviewId);
    assert.strictEqual(snapshots.length, 1);
    assert.strictEqual(snapshots[0].textSnapshot, '');
    assert.strictEqual(snapshots[0].snapshotMissing, true);
  });

  await test('记录密级降为仅本地后快照跟着收窄', async () => {
    reset();
    const noteDraft = createFreeformNoteDraft();
    noteDraft.content = 'MARKER_SNAPSHOT_LEVEL';
    noteDraft.level = SecurityLevel.ANALYZABLE;
    noteDraft.materials = [
      { kind: 'scene', text: 'MARKER_SNAPSHOT_LEVEL', level: SecurityLevel.ANALYZABLE }
    ];
    const saved = await service.save(noteDraft);
    const materialId = store.rows('experience_material')[0].id;

    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '本周有三天晚睡',
      interpretation: '',
      contradiction: '',
      action: '',
      materialIds: [materialId],
      anchorIds: []
    }, '11-09 ~ 11-15');
    assert.strictEqual(store.rows('review_material')[0].level_snapshot, SecurityLevel.ANALYZABLE);

    const lowered = createFreeformNoteDraft();
    lowered.content = 'MARKER_SNAPSHOT_LEVEL';
    lowered.level = SecurityLevel.LOCAL_ONLY;
    lowered.materials = [{ kind: 'scene', text: 'MARKER_SNAPSHOT_LEVEL' }];
    await service.updateNote(saved.eventId, lowered);

    const row = store.rows('review_material')[0];
    assert.strictEqual(row.level_snapshot, SecurityLevel.LOCAL_ONLY);
    assert.strictEqual(row.text_snapshot, 'MARKER_SNAPSHOT_LEVEL');
    const snapshots = await reviewService.materials(reviewId);
    assert.strictEqual(snapshots[0].levelSnapshot, SecurityLevel.LOCAL_ONLY);
  });

  await test('六区有内容时旧四列按六区回填，草稿里的旧行动不进入记录', async () => {
    reset();
    const reviewService = await ReviewService.open({});
    const id = await reviewService.save('week', {
      facts: '',
      interpretation: '',
      contradiction: '',
      action: '上次草稿留下的行动',
      payload: {
        scene: '只写了现场',
        model: '',
        relation: '',
        evidence: '',
        cost: '',
        revision: ''
      },
      anchorIds: []
    }, '11-09 ~ 11-15');

    const detail = await reviewService.find(id);
    assert.ok(detail !== null);
    assert.strictEqual(detail.facts, '只写了现场');
    assert.strictEqual(detail.action, '');
    const stored = JSON.parse(store.rows('review_result')[0].payload);
    assert.strictEqual(stored.scene, '只写了现场');
    assert.strictEqual(stored.revision, '');
  });

  await test('速记引用关系后可在关系详情反向看到', async () => {
    reset();
    const relationService = await RelationService.open({});
    await relationService.seedDemoRelations();
    const relations = await relationService.list(null);
    const relationId = relations[0].id;

    const noteService = await QuickNoteService.open({});
    const draft = createFreeformNoteDraft();
    draft.content = '和这位朋友聊了近期作息';
    draft.relatedRelationIds = [relationId];
    await noteService.save(draft);

    const detail = await relationService.find(relationId);
    assert.ok(detail !== null);
    assert.strictEqual(detail.linkedEvents.length, 1);
    assert.ok(detail.linkedEvents[0].includes('作息'));
  });

  await test('关系封存后引用快照降级并清正文', async () => {
    reset();
    const relationService = await RelationService.open({});
    await relationService.seedDemoRelations();
    const relation = (await relationService.list(null))[0];
    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '', interpretation: '', contradiction: '', action: '',
      payload: {
        scene: '引用了关系材料', model: '', relation: '', evidence: '', cost: '', revision: ''
      },
      materialIds: [`relation:${relation.id}`],
      anchorIds: []
    }, '11-16 ~ 11-22');
    const materialDao = new ReviewMaterialDao(store);
    let rows = await materialDao.queryByReview(reviewId);
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].levelSnapshot, 'local_only');
    assert.ok(rows[0].textSnapshot.length > 0);

    const detail = await relationService.find(relation.id);
    assert.ok(detail !== null);
    await relationService.save(relation.id, detail.name, detail.trustLevel, false,
      detail.forbidAnalysis, 'sealed', detail.notes, detail.correction);

    rows = await materialDao.queryByReview(reviewId);
    assert.strictEqual(rows[0].levelSnapshot, 'sealed');
    assert.strictEqual(rows[0].textSnapshot, '');
  });

  await test('周统计支持指定周锚点', async () => {
    reset();
    const reviewService = await ReviewService.open({});
    const now = new Date(2026, 9, 27, 12, 0).getTime();
    const stats = await reviewService.loadStatsFor('week', now);
    assert.strictEqual(stats.rangeLabel, rangeFor('week', now).label);
    assert.strictEqual(stats.noteCount, 0);
  });

  await test('自写锚点拒绝空串并按顺序追加', async () => {
    reset();
    const anchorService = await AnchorService.open({});
    await assert.rejects(async () => {
      await anchorService.create('   ');
    });
    const first = await anchorService.create('先做重要的事');
    const second = await anchorService.create('核对证据');
    assert.strictEqual(first.order, 0);
    assert.strictEqual(second.order, 1);
    assert.strictEqual(first.source, '自写');
  });

  await test('更新速记保留 id、类型与时间戳并覆盖可编辑字段', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '原始内容';
    draft.timestamp = 1000;
    const saved = await service.save(draft);

    const edited = createFreeformNoteDraft();
    edited.content = '更新后的内容';
    edited.timestamp = 9999;
    edited.tags = ['复盘', '  '];
    edited.relatedRelationIds = ['rl_1'];
    edited.level = 'analyzable';
    const detail = await service.updateNote(saved.eventId, edited);

    const row = lastRow('event');
    assert.strictEqual(row.id, saved.eventId);
    assert.strictEqual(row.type, FREE_NOTE_TYPE);
    assert.strictEqual(row.timestamp, 1000);
    assert.strictEqual(row.content, '更新后的内容');
    assert.strictEqual(row.title, '更新后的内容');
    assert.deepStrictEqual(JSON.parse(row.tags), ['复盘']);
    assert.deepStrictEqual(JSON.parse(row.related_relation_ids), ['rl_1']);
    assert.strictEqual(row.level, 'analyzable');
    assert.strictEqual(detail.id, saved.eventId);
  });

  await test('改密级后材料跟着改，并决定请求是否放行', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = 'MARKER_BODY_4a1';
    draft.timestamp = 1000;
    const saved = await service.save(draft);
    assert.strictEqual(store.rows('experience_material').length, 1);
    assert.strictEqual(store.rows('experience_material')[0].level, SecurityLevel.LOCAL_ONLY);

    const loosened = createFreeformNoteDraft();
    loosened.content = 'MARKER_BODY_4a1';
    loosened.timestamp = 1000;
    loosened.level = SecurityLevel.ANALYZABLE;
    await service.updateNote(saved.eventId, loosened);
    assert.strictEqual(store.rows('experience_material')[0].level, SecurityLevel.ANALYZABLE);

    const allowed = buildAnalysisInput({
      facts: 'MARKER_BODY_4a1',
      interpretation: '',
      anchors: [],
      factsLevel: store.rows('experience_material')[0].level,
      interpretationLevel: SecurityLevel.LOCAL_ONLY,
      relationForbidsAnalysis: false
    }, 'model');
    assert.strictEqual(allowed.input.facts, 'MARKER_BODY_4a1');
    assert.deepStrictEqual(allowed.dropped.map((item) => item.kind), []);

    const sealedDraft = createFreeformNoteDraft();
    sealedDraft.content = 'MARKER_BODY_4a1';
    sealedDraft.timestamp = 1000;
    sealedDraft.level = SecurityLevel.SEALED;
    await service.updateNote(saved.eventId, sealedDraft);
    assert.strictEqual(store.rows('experience_material')[0].level, SecurityLevel.SEALED);

    const blocked = buildAnalysisInput({
      facts: 'MARKER_BODY_4a1',
      interpretation: '',
      anchors: [],
      factsLevel: store.rows('experience_material')[0].level,
      interpretationLevel: SecurityLevel.LOCAL_ONLY,
      relationForbidsAnalysis: false
    }, 'model');
    assert.strictEqual(blocked.input.facts, '');
    assert.deepStrictEqual(blocked.dropped.map((item) => item.kind), ['facts']);
    assert.ok(!JSON.stringify(blocked).includes('MARKER_BODY_4a1'), '拦下后仍带出了正文');
  });

  await test('编辑速记按草稿重写材料并回传材料', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '正文';
    draft.tags = ['原标签'];
    draft.relatedRelationIds = ['rl_1'];
    draft.materials = [
      { kind: 'scene', text: '原来的现场', source: 'direct', form: '' },
      { kind: 'feeling', text: '紧张', source: 'direct', form: '' }
    ];
    const saved = await service.save(draft);

    const edited = createFreeformNoteDraft();
    edited.content = '正文';
    edited.tags = ['原标签'];
    edited.relatedRelationIds = ['rl_1'];
    edited.materials = [
      { kind: 'scene', text: '改过的现场', source: 'reading', form: 'dialogue' },
      { kind: 'body', text: '胸口发紧', source: 'direct', form: '' }
    ];
    const detail = await service.updateNote(saved.eventId, edited);

    const rows = store.rows('experience_material');
    assert.deepStrictEqual(rows.map((row) => row.kind), ['scene', 'body']);
    assert.strictEqual(rows[0].text, '改过的现场');
    assert.strictEqual(rows[0].source, 'reading');
    assert.strictEqual(rows[0].form, 'dialogue');
    assert.strictEqual(rows[1].text, '胸口发紧');
    assert.deepStrictEqual(detail.materials.map((material) => material.kind), ['scene', 'body']);
    assert.deepStrictEqual(JSON.parse(lastRow('event').tags), ['原标签']);
    assert.deepStrictEqual(JSON.parse(lastRow('event').related_relation_ids), ['rl_1']);
  });

  await test('材料密级保存时不宽于记录级', async () => {
    reset();
    const local = createFreeformNoteDraft();
    local.content = '仅本地正文';
    local.level = SecurityLevel.LOCAL_ONLY;
    local.materials = [
      { kind: 'scene', text: '想标成可分析', level: SecurityLevel.ANALYZABLE },
      { kind: 'body', text: '保持封存', level: SecurityLevel.SEALED }
    ];
    await service.save(local);
    assert.deepStrictEqual(store.rows('experience_material').map((row) => row.level),
      [SecurityLevel.LOCAL_ONLY, SecurityLevel.SEALED]);

    const sealed = createFreeformNoteDraft();
    sealed.content = '封存正文';
    sealed.level = SecurityLevel.SEALED;
    sealed.materials = [
      { kind: 'scene', text: '另一条想标成可分析', level: SecurityLevel.ANALYZABLE },
      { kind: 'body', text: '另一条仅本地', level: SecurityLevel.LOCAL_ONLY }
    ];
    await service.save(sealed);
    assert.deepStrictEqual(store.rows('experience_material').slice(-2).map((row) => row.level),
      [SecurityLevel.SEALED, SecurityLevel.SEALED]);

    const analyzable = createFreeformNoteDraft();
    analyzable.content = '可分析正文';
    analyzable.level = SecurityLevel.ANALYZABLE;
    analyzable.materials = [{ kind: 'scene', text: '自己选封存', level: SecurityLevel.SEALED }];
    await service.save(analyzable);
    assert.strictEqual(store.rows('experience_material')[store.rows('experience_material').length - 1].level,
      SecurityLevel.SEALED);
  });

  await test('改密级时材料写失败，记录密级一并回滚', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = '回滚正文';
    const saved = await service.save(draft);

    const edited = createFreeformNoteDraft();
    edited.content = '回滚正文';
    edited.level = SecurityLevel.SEALED;
    store.failTable = 'experience_material';
    let failed = false;
    try {
      await service.updateNote(saved.eventId, edited);
    } catch (error) {
      failed = true;
    }
    store.failTable = null;
    assert.strictEqual(failed, true);
    assert.strictEqual(store.rows('event')[0].level, SecurityLevel.LOCAL_ONLY);
    assert.strictEqual(store.rows('experience_material')[0].level, SecurityLevel.LOCAL_ONLY);
  });

  await test('删除清空正文、材料与关联文本，导出不再带出', async () => {
    reset();
    const draft = createNoteDraft(NoteTemplateId.DECISION);
    fill(draft, NoteFieldKey.BACKGROUND, 'MARKER_DECISION_BG');
    fill(draft, NoteFieldKey.OPTIONS, '甲、乙');
    fill(draft, NoteFieldKey.CHOICE, 'MARKER_CHOICE');
    fill(draft, NoteFieldKey.EXPECTED_OUTCOME, 'MARKER_EXPECT');
    draft.timestamp = 1000;
    draft.level = SecurityLevel.ANALYZABLE;
    draft.materials = [{ kind: 'scene', text: 'MARKER_MATERIAL_9f2' }];
    const saved = await service.save(draft);
    store.rows('plan_link').push({
      id: 'lk_1', plan_id: 'pl_1', node_id: 'pn_1', module: 'note',
      target_id: saved.eventId, label: 'MARKER_LINK_LABEL', created_at: 1000
    });

    await service.delete(saved.eventId);
    await service.purgeNow(saved.eventId);

    const eventRow = store.rows('event')[0];
    assert.strictEqual(eventRow.deleted, 1);
    assert.strictEqual(eventRow.content, '');
    assert.strictEqual(eventRow.title, DELETED_NOTE_TITLE);
    assert.strictEqual(eventRow.id, saved.eventId);
    assert.strictEqual(eventRow.timestamp, 1000);
    assert.strictEqual(eventRow.level, SecurityLevel.ANALYZABLE);

    const decisionRow = store.rows('decision')[0];
    assert.strictEqual(decisionRow.title, '');
    assert.strictEqual(decisionRow.background, '');
    assert.strictEqual(decisionRow.options, '[]');
    assert.strictEqual(decisionRow.choice, '');
    assert.strictEqual(decisionRow.expected_outcome, '');
    assert.strictEqual(decisionRow.id, saved.decisionId);

    const materialRow = store.rows('experience_material')[0];
    assert.strictEqual(materialRow.deleted, 1);
    assert.strictEqual(materialRow.text, '');

    assert.strictEqual(store.rows('plan_link')[0].label, DELETED_NOTE_TITLE);

    const eventDao = new EventDao(store);
    const decisionDao = new DecisionDao(store);
    const markdown = renderExportDocument(prepareExportBundle({
      events: await eventDao.queryAll(),
      decisions: await decisionDao.queryAll(),
      relations: [],
      predictions: [],
      anchors: [],
      statusRecords: [],
      reviews: [],
      plans: [],
      exportedAt: 1000
    }));
    assert.strictEqual(markdown.includes('MARKER_DECISION_BG'), false, '导出仍带出被删正文');
    assert.strictEqual(markdown.includes('MARKER_CHOICE'), false, '导出仍带出被删决策');
    assert.strictEqual(markdown.includes('MARKER_MATERIAL_9f2'), false, '导出仍带出被删材料');
  });

  await test('删除只标记，正文与材料留到撤销窗口结束', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = 'MARKER_DELETE_KEEP';
    draft.materials = [{ kind: 'scene', text: 'MARKER_DELETE_MATERIAL' }];
    const saved = await service.save(draft);

    await service.delete(saved.eventId);

    const row = store.rows('event')[0];
    assert.strictEqual(row.deleted, 1);
    assert.strictEqual(row.content, 'MARKER_DELETE_KEEP');
    assert.strictEqual(store.rows('experience_material')[0].text, 'MARKER_DELETE_MATERIAL');
    assert.strictEqual((await service.listRecent()).length, 0);

    await service.purgeNow(saved.eventId);
  });

  await test('撤销删除后恢复可见且正文不变', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = 'MARKER_UNDO_BODY';
    const saved = await service.save(draft);

    await service.delete(saved.eventId);
    assert.strictEqual(await service.undoDelete(saved.eventId), true);

    const row = store.rows('event')[0];
    assert.strictEqual(row.deleted, 0);
    assert.strictEqual(row.content, 'MARKER_UNDO_BODY');
    const items = await service.listRecent();
    assert.strictEqual(items.length, 1);
    assert.strictEqual(items[0].id, saved.eventId);
    assert.strictEqual(await service.undoDelete(saved.eventId), false);
  });

  await test('立即清理清空正文与材料', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = 'MARKER_PURGE_BODY';
    draft.materials = [{ kind: 'scene', text: 'MARKER_PURGE_MATERIAL' }];
    const saved = await service.save(draft);

    await service.delete(saved.eventId);
    await service.purgeNow(saved.eventId);

    const row = store.rows('event')[0];
    assert.strictEqual(row.deleted, 1);
    assert.strictEqual(row.content, '');
    assert.strictEqual(row.title, DELETED_NOTE_TITLE);
    const materials = store.rows('experience_material');
    assert.strictEqual(materials.length, 1);
    assert.strictEqual(materials[0].text, '');
    assert.strictEqual(materials[0].deleted, 1);
  });

  await test('启动清理扫掉遗留的已删正文', async () => {
    reset();
    const draft = createFreeformNoteDraft();
    draft.content = 'MARKER_LEFTOVER';
    const saved = await service.save(draft);
    store.rows('event')[0].deleted = 1;

    assert.strictEqual(await service.purgeLeftovers(), 1);

    const row = store.rows('event')[0];
    assert.strictEqual(row.deleted, 1);
    assert.strictEqual(row.content, '');
    assert.strictEqual(row.title, DELETED_NOTE_TITLE);
    assert.strictEqual(await service.purgeLeftovers(), 0);
    assert.strictEqual(row.id, saved.eventId);
  });

  await test('修订预测递增版本并继承 rootId', async () => {
    reset();
    const predictionService = await PredictionService.open({});
    const now = new Date(2026, 9, 27, 12, 0).getTime();
    const created = await predictionService.create({
      target: '本周作息',
      judgment: '本周日均睡眠达到 7 小时',
      confidence: 70,
      reason: '初版',
      falsification: '若日均睡眠低于 6 小时',
      settlementDate: '2026-11-03'
    }, now);

    const revised = await predictionService.revise(created.id, {
      target: '本周作息',
      judgment: '本周日均睡眠达到 7 小时',
      confidence: 80,
      reason: '补充理由',
      falsification: '若日均睡眠低于 6 小时',
      settlementDate: '2026-11-03',
      revisionReason: '初版把原因归到睡眠',
      invalidated: '睡眠决定状态',
      preserved: '临时改期确实影响节奏',
      repositioned: '放到关系条件里看'
    }, now + 1000);
    assert.strictEqual(revised.version, 2);
    assert.strictEqual(lastRow('prediction').root_id, created.id);
    assert.strictEqual(revised.confidence, 80);
    assert.strictEqual(revised.reason, '补充理由');
    assert.strictEqual(revised.revisionReason, '初版把原因归到睡眠');
    assert.strictEqual(revised.preserved, '临时改期确实影响节奏');

    const again = await predictionService.revise(revised.id, {
      target: '本周作息',
      judgment: '本周日均睡眠达到 7 小时',
      confidence: 90,
      reason: '',
      falsification: '若日均睡眠低于 6 小时',
      settlementDate: '2026-11-03',
      revisionReason: '置信度再抬高'
    }, now + 2000);
    assert.strictEqual(again.version, 3);
    assert.strictEqual(lastRow('prediction').root_id, created.id);

    const versions = await predictionService.versions(created.id);
    assert.strictEqual(versions.length, 3);
    assert.strictEqual(versions[0].version, 1);
    assert.strictEqual(versions[2].version, 3);

    await assert.rejects(async () => {
      await predictionService.revise(created.id, {
        target: '本周作息',
        judgment: '本周日均睡眠达到 7 小时',
        confidence: 90,
        reason: '',
        settlementDate: '2026-11-03'
      }, now + 3000);
    });
  });

  await test('复盘窗口统计非空样本的计数与命中率', async () => {
    reset();
    const now = new Date(2026, 9, 27, 12, 0).getTime();
    const inWindow = new Date(2026, 9, 26, 9, 0).getTime();

    const free = createFreeformNoteDraft();
    free.content = '窗口内速记';
    free.timestamp = inWindow;
    await service.save(free);

    const decisionDraft = createNoteDraft(NoteTemplateId.DECISION);
    fill(decisionDraft, NoteFieldKey.BACKGROUND, '窗口内决策');
    decisionDraft.timestamp = inWindow + 1000;
    await service.save(decisionDraft);

    const predictionService = await PredictionService.open({});
    const hit = await predictionService.create({
      target: '作息 A',
      judgment: '达成',
      confidence: 70,
      reason: '',
      falsification: '若未达成',
      settlementDate: '2026-10-27'
    }, now);
    await predictionService.settle(hit.id, '达成', 'hold', '', now);
    const miss = await predictionService.create({
      target: '作息 B',
      judgment: '达成',
      confidence: 60,
      reason: '',
      falsification: '若未达成',
      settlementDate: '2026-10-27'
    }, now);
    await predictionService.settle(miss.id, '未达成', 'fail', '', now);
    await predictionService.create({
      target: '下月作息',
      judgment: '达成',
      confidence: 60,
      reason: '',
      falsification: '若未达成',
      settlementDate: '2026-11-10'
    }, now);

    const reviewService = await ReviewService.open({});
    const stats = await reviewService.loadStatsFor('week', now);
    assert.strictEqual(stats.noteCount, 2);
    assert.strictEqual(stats.decisionCount, 1);
    assert.strictEqual(stats.pendingPredictions, 1);
    assert.strictEqual(stats.settledPredictions, 2);
    assert.strictEqual(stats.hitRate, 50);
    assert.strictEqual(stats.anchorCount, 0);

    // A partial result counts as settled but stays out of the binary hit rate.
    const partial = await predictionService.create({
      target: '作息 C',
      judgment: '达成',
      confidence: 50,
      reason: '',
      falsification: '若未达成',
      settlementDate: '2026-10-27'
    }, now);
    await predictionService.settle(partial.id, '部分达成', 'partial', '', now);
    const afterPartial = await reviewService.loadStatsFor('week', now);
    assert.strictEqual(afterPartial.settledPredictions, 3);
    assert.strictEqual(afterPartial.hitRate, 50);
  });

  await test('决定记录写入全部字段', async () => {
    reset();
    const dao = new DecisionRecordDao(store);
    const rowId = await dao.insert({
      id: 'dr_1',
      reviewId: 'rv_1',
      type: 'joint',
      reason: '一起调整作息',
      action: '每周同步一次',
      commitment: '不临时改约定',
      relationId: 'rl_1',
      planItemId: 'pi_1',
      outcome: '第一周按约完成',
      reviewAt: '2026-11-20',
      level: SecurityLevel.LOCAL_ONLY,
      createdAt: 1000
    });
    assert.strictEqual(rowId, 1);
    const stored = store.rows('decision_record')[0];
    assert.strictEqual(stored.review_id, 'rv_1');
    assert.strictEqual(stored.type, 'joint');
    assert.strictEqual(stored.reason, '一起调整作息');
    assert.strictEqual(stored.action, '每周同步一次');
    assert.strictEqual(stored.commitment, '不临时改约定');
    assert.strictEqual(stored.relation_id, 'rl_1');
    assert.strictEqual(stored.plan_item_id, 'pi_1');
    assert.strictEqual(stored.outcome, '第一周按约完成');
    assert.strictEqual(stored.review_at, '2026-11-20');
    assert.strictEqual(stored.level, 'local_only');
    assert.strictEqual(stored.created_at, 1000);
  });

  await test('决定记录按复盘读取并可按复盘清理', async () => {
    reset();
    const dao = new DecisionRecordDao(store);
    await dao.insert({
      id: 'dr_1', reviewId: 'rv_1', type: 'continue', reason: '继续',
      level: SecurityLevel.LOCAL_ONLY, createdAt: 2000
    });
    await dao.insert({
      id: 'dr_2', reviewId: 'rv_2', type: 'pause', reason: '先停', action: '',
      level: SecurityLevel.LOCAL_ONLY, createdAt: 1000
    });
    await dao.insert({
      id: 'dr_3', reviewId: 'rv_1', type: 'exit', reason: '退出', action: '收回时间',
      level: SecurityLevel.LOCAL_ONLY, createdAt: 3000
    });

    const rows = await dao.queryByReview('rv_1');
    assert.deepStrictEqual(rows.map((row) => row.id), ['dr_1', 'dr_3']);
    assert.strictEqual(rows[0].action, '');
    assert.strictEqual(rows[1].action, '收回时间');
    assert.strictEqual(rows[1].level, 'local_only');

    assert.strictEqual(await dao.deleteByReview('rv_1'), 2);
    assert.deepStrictEqual((await dao.queryByReview('rv_1')).map((row) => row.id), []);
    assert.deepStrictEqual((await dao.queryByReview('rv_2')).map((row) => row.id), ['dr_2']);
  });

  await test('待回看决定排除未到期、无日期与封存记录', async () => {
    reset();
    store.rows('review_result').push(
      { id: 'rv_open', level: 'local_only' },
      { id: 'rv_sealed', level: 'sealed' }
    );
    const dao = new DecisionRecordDao(store);
    const base = {
      reason: '原因',
      action: '',
      level: SecurityLevel.LOCAL_ONLY
    };
    await dao.insert(Object.assign({}, base, {
      id: 'dr_due', reviewId: 'rv_open', type: 'continue', reviewAt: '2026-11-15', createdAt: 1
    }));
    await dao.insert(Object.assign({}, base, {
      id: 'dr_today', reviewId: 'rv_open', type: 'switch', reviewAt: '2026-11-16', createdAt: 2
    }));
    await dao.insert(Object.assign({}, base, {
      id: 'dr_future', reviewId: 'rv_open', type: 'pause', reviewAt: '2026-11-17', createdAt: 3
    }));
    await dao.insert(Object.assign({}, base, {
      id: 'dr_none', reviewId: 'rv_open', type: 'discard', reviewAt: '', createdAt: 4
    }));
    await dao.insert(Object.assign({}, base, {
      id: 'dr_sealed', reviewId: 'rv_open', type: 'exit', reviewAt: '2026-11-10',
      level: SecurityLevel.SEALED, createdAt: 5
    }));
    await dao.insert(Object.assign({}, base, {
      id: 'dr_sealed_review', reviewId: 'rv_sealed', type: 'joint', relationId: 'rl_1',
      reviewAt: '2026-11-10', createdAt: 6
    }));
    await dao.insert(Object.assign({}, base, {
      id: 'dr_no_review', reviewId: 'rv_missing', type: 'continue', reviewAt: '2026-11-10', createdAt: 7
    }));

    assert.strictEqual(await dao.countPending('2026-11-16'), 2);
  });

  await test('决定表在表清单与建表语句中齐全', async () => {
    assert.strictEqual(DB_TABLES.DECISION_RECORD, 'decision_record');
    assert.ok(DB_TABLES_CHILD_FIRST.indexOf(DB_TABLES.DECISION_RECORD) >= 0);
    assert.ok(DB_TABLES_CHILD_FIRST.indexOf(DB_TABLES.DECISION_RECORD) <
      DB_TABLES_CHILD_FIRST.indexOf(DB_TABLES.REVIEW_RESULT));
    assert.ok(LEVELED_TABLES.indexOf(DB_TABLES.DECISION_RECORD) >= 0);
    const marker = `CREATE TABLE IF NOT EXISTS ${DB_TABLES.DECISION_RECORD} (`;
    const createSql = TABLE_CREATE_SQLS.find((sql) => sql.indexOf(marker) >= 0);
    assert.ok(createSql !== undefined);
    assert.ok(createSql.indexOf('review_id') >= 0);
    assert.ok(createSql.indexOf('review_at') >= 0);
  });

  await test('复盘保存时同事务写入主决定', async () => {
    reset();
    const reviewService = await ReviewService.open({});
    const reviewId = await reviewService.save('week', {
      facts: '',
      interpretation: '',
      contradiction: '',
      action: '',
      payload: {
        scene: '只写了现场',
        model: '',
        relation: '',
        evidence: '',
        cost: '',
        revision: '',
        depth: 'deep',
        timeBudget: 30,
        decisionDraft: {
          type: 'switch',
          reason: '换一种做法',
          action: '先试一周',
          commitment: '每天记录',
          relationId: '',
          planItemId: '',
          outcome: '',
          reviewAt: '2026-11-20'
        }
      },
      anchorIds: []
    }, '11-16 ~ 11-22');

    const rows = store.rows('decision_record');
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].review_id, reviewId);
    assert.strictEqual(rows[0].id, `${reviewId}_decision`);
    assert.strictEqual(rows[0].type, 'switch');
    assert.strictEqual(rows[0].reason, '换一种做法');
    assert.strictEqual(rows[0].action, '先试一周');
    assert.strictEqual(rows[0].commitment, '每天记录');
    assert.strictEqual(rows[0].review_at, '2026-11-20');
    assert.strictEqual(rows[0].level, 'local_only');
    assert.strictEqual(rows[0].depth, 'deep');
    assert.strictEqual(rows[0].time_budget, 30);

    const read = await reviewService.reviewDecision(reviewId);
    assert.ok(read !== null);
    assert.strictEqual(read.type, 'switch');
    assert.strictEqual(read.planItemId, '');
    assert.strictEqual(read.depth, 'deep');
    assert.strictEqual(read.timeBudget, 30);
  });

  await test('决定写入后成本失败时整笔复盘回滚', async () => {
    reset();
    store.failTable = 'cost_note';
    const reviewService = await ReviewService.open({});
    let failed = false;
    try {
      await reviewService.save('week', {
        facts: '',
        interpretation: '',
        contradiction: '',
        action: '',
        payload: {
          scene: '只写了现场',
          model: '',
          relation: '',
          evidence: '',
          cost: '',
          revision: '',
          decisionDraft: {
            type: 'continue',
            reason: '继续观察',
            action: '',
            commitment: '',
            relationId: '',
            planItemId: '',
            outcome: '',
            reviewAt: ''
          },
          costDrafts: [
            { dimension: 'time', text: '代价', bearable: true }
          ]
        },
        anchorIds: []
      }, '11-16 ~ 11-22');
    } catch (error) {
      failed = true;
    }
    assert.strictEqual(failed, true);
    assert.strictEqual(store.rows('decision_record').length, 0);
    assert.strictEqual(store.rows('review_result').length, 0);
    assert.strictEqual(store.rows('review_decision').length, 0);
    assert.strictEqual(store.rows('cost_note').length, 0);
  });

  await test('决定密级跟随复盘且不宽于仅本地', async () => {
    assert.strictEqual(decisionLevelFor(SecurityLevel.SEALED), SecurityLevel.SEALED);
    assert.strictEqual(decisionLevelFor(SecurityLevel.ANALYZABLE), SecurityLevel.LOCAL_ONLY);
    assert.strictEqual(decisionLevelFor(SecurityLevel.LOCAL_ONLY), SecurityLevel.LOCAL_ONLY);
    assert.strictEqual(decisionLevelFor(undefined), SecurityLevel.LOCAL_ONLY);
  });

  await test('候选决定排除封存记录', async () => {
    reset();
    store.rows('decision').push(
      { id: 'dc_open', title: '开放', choice: '继续', timestamp: 3000, level: 'local_only' },
      { id: 'dc_sealed', title: '封存', choice: '隐藏', timestamp: 4000, level: 'sealed' },
      { id: 'dc_old', title: '旧', choice: '停下', timestamp: 1000, level: 'analyzable' }
    );
    const reviewService = await ReviewService.open({});
    const items = await reviewService.recentDecisions(20);
    assert.deepStrictEqual(items.map((item) => item.id), ['dc_open', 'dc_old']);
    const capped = await reviewService.recentDecisions(1);
    assert.deepStrictEqual(capped.map((item) => item.id), ['dc_open']);
  });

  await test('成本维度保留六个新值', () => {
    for (const value of ['meaning', 'body', 'relationship', 'time', 'public', 'other']) {
      assert.strictEqual(toCostDimension(value), value);
    }
  });

  await test('旧成本维度归一为其他', () => {
    for (const value of ['attention', 'money', 'unknown', '']) {
      assert.strictEqual(toCostDimension(value), 'other');
    }
  });

  await test('成本 DAO 读取旧维度时归一为其他', async () => {
    reset();
    store.rows('cost_note').push({
      id: 'cn_old', review_id: 'rv_cost', dimension: 'attention', text: '旧维度',
      bearable: 1, created_at: 1
    });
    const dao = new CostNoteDao(store);
    const rows = await dao.queryByReview('rv_cost');
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].dimension, 'other');
  });

  await test('载荷解析把旧成本维度归一为其他', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      costDrafts: [{ dimension: 'money', text: '花费', bearable: true }]
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.costDrafts.length, 1);
    assert.strictEqual(payload.costDrafts[0].dimension, 'other');
  });

  await test('载荷解析读取动机', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      motivation: 'external'
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.motivation, 'external');
  });

  await test('未知动机读作未填写', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      motivation: 'other'
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.motivation, undefined);
  });

  await test('载荷解析读取深度与预算', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      depth: 'deep', timeBudget: 45
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.depth, 'deep');
    assert.strictEqual(payload.timeBudget, 45);
  });

  await test('非法深度与预算读作未记录', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      depth: 'slow', timeBudget: -5
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.depth, undefined);
    assert.strictEqual(payload.timeBudget, undefined);
  });

  await test('载荷解析读取一等结果与锚点三问', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      standing: 'cannot_judge',
      anchorCitations: [{
        anchorId: 'an_1', reason: '旧理由', supports: '支持判断',
        limits: '限制范围', notApplicable: '不适用于工作'
      }]
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.standing, 'cannot_judge');
    assert.strictEqual(payload.anchorCitations[0].reason, '旧理由');
    assert.strictEqual(payload.anchorCitations[0].supports, '支持判断');
    assert.strictEqual(payload.anchorCitations[0].limits, '限制范围');
    assert.strictEqual(payload.anchorCitations[0].notApplicable, '不适用于工作');
  });

  await test('未知结果状态读作未记录', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      standing: 'done'
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.standing, undefined);
  });

  await test('计划保存与读取深度预算', async () => {
    reset();
    const dao = new PlanDao(store);
    const plan = createPlan('测试计划', '2026-11-16', '', 'deep', 45);
    plan.goal = '目标';
    await dao.insertPlan(plan);
    const found = await dao.findPlan(plan.id);
    assert.ok(found !== null);
    assert.strictEqual(found.depth, 'deep');
    assert.strictEqual(found.timeBudget, 45);
  });

  await test('旧计划行读回普通与零预算', async () => {
    reset();
    store.rows('plan').push({
      id: 'pl_old', title: '旧计划', goal: '', project_id: '', start_date: '2026-11-16',
      target_date: '', status: 'active', is_primary: 0, level: 'local_only',
      pause_reason: '', resume_at: '', depth: '', time_budget: 0, created_at: 1
    });
    const dao = new PlanDao(store);
    const old = await dao.findPlan('pl_old');
    assert.ok(old !== null);
    assert.strictEqual(old.depth, 'normal');
    assert.strictEqual(old.timeBudget, 0);
  });

  await test('计划建表包含深度与预算列', () => {
    const sql = TABLE_CREATE_SQLS.find((item) => item.indexOf('CREATE TABLE IF NOT EXISTS plan (') >= 0);
    assert.ok(sql !== undefined);
    assert.ok(sql.indexOf('depth') >= 0);
    assert.ok(sql.indexOf('time_budget') >= 0);
    assert.ok(sql.indexOf('done_standard') >= 0);
    assert.ok(sql.indexOf('impact') >= 0);
  });

  await test('计划保存与读取完成标准与影响对象', async () => {
    reset();
    const dao = new PlanDao(store);
    const plan = createPlan('目标', '2026-11-16');
    plan.goal = '推进计划模块';
    plan.doneStandard = '首页出现四项';
    plan.impact = '自己与同伴';
    await dao.insertPlan(plan);
    const found = await dao.findPlan(plan.id);
    assert.ok(found !== null);
    assert.strictEqual(found.doneStandard, '首页出现四项');
    assert.strictEqual(found.impact, '自己与同伴');
  });

  await test('旧计划缺少完成标准时读作空', async () => {
    reset();
    store.rows('plan').push({
      id: 'pl_old_goal', title: '旧目标', goal: '', project_id: '', start_date: '2026-11-16',
      target_date: '', status: 'active', is_primary: 0, level: 'local_only',
      pause_reason: '', resume_at: '', depth: 'normal', time_budget: 0,
      done_standard: '', impact: '', created_at: 1
    });
    const dao = new PlanDao(store);
    const old = await dao.findPlan('pl_old_goal');
    assert.ok(old !== null);
    assert.strictEqual(old.doneStandard, '');
    assert.strictEqual(old.impact, '');
  });

  await test('计划更新保留完成标准与影响对象', async () => {
    reset();
    const dao = new PlanDao(store);
    const plan = createPlan('目标', '2026-11-16');
    plan.doneStandard = '第一版标准';
    plan.impact = '第一版对象';
    await dao.insertPlan(plan);
    plan.doneStandard = '第二版标准';
    await dao.updatePlan(plan);
    const found = await dao.findPlan(plan.id);
    assert.ok(found !== null);
    assert.strictEqual(found.doneStandard, '第二版标准');
    assert.strictEqual(found.impact, '第一版对象');
  });

  await test('预测期限可以留空', () => {
    const errors = validatePredictionDraft({
      target: '对象', judgment: '会成立', confidence: 60, reason: '',
      settlementDate: '', falsification: '出现反例就不成立'
    }, Date.now());
    assert.strictEqual(errors.settlementDate, '');
  });

  await test('无期限预测可结算并记录当天', async () => {
    reset();
    const service = await PredictionService.open({});
    const created = await service.create({
      target: '无期限预测', judgment: '会成立', confidence: 60, reason: '',
      settlementDate: '', falsification: '出现反例就不成立'
    });
    const settled = await service.settle(created.id, '实际发生', 'hold');
    assert.ok(settled !== null);
    assert.strictEqual(settled.settlementDate.length, 10);
  });

  await test('复盘材料包含状态与关系候选', async () => {
    reset();
    store.rows('status_record').push({
      id: 'st_1', date: '2026-11-15', sleep_hours: 7, exercise_count: 1, alert_count: 0,
      note: '状态备注', body_signals: '肩颈紧', function_state: '能写两行', emotion: '',
      environment: '', capacity: '', function_gain: '', cost_paid: '晚上疲惫',
      unknown_readings: '', corrected_at: 0, revisions: '', level: 'local_only', deleted: 0
    });
    store.rows('relation').push({
      id: 'rl_1', name: '同事', trust_level: 'friendly',
      interaction_log: JSON.stringify([
        { timestamp: 1000, content: '他说下周三有空', source: 'stated', citation: 'hidden', allowContext: false }
      ]),
      raw_material_test: 0, forbid_analysis: 0, correction: '', correction_at: 0,
      level: 'local_only', deleted: 0, notes: ''
    });
    const service = await ReviewService.open({});
    const items = await service.recentMaterials(20);
    const status = items.find((item) => item.id === 'status:st_1');
    const relation = items.find((item) => item.id === 'relation:rl_1');
    assert.ok(status !== undefined);
    assert.strictEqual(status.source, 'direct');
    assert.ok(status.text.includes('能写两行'));
    assert.ok(relation !== undefined);
    assert.strictEqual(relation.source, 'interaction');
    assert.strictEqual(relation.interactionSource, 'stated');
    assert.strictEqual(relation.text, '他说下周三有空');
  });

  await test('封存关系不进入材料候选', async () => {
    reset();
    store.rows('relation').push({
      id: 'rl_sealed', name: '封存关系', trust_level: 'friendly', interaction_log: '[]',
      raw_material_test: 0, forbid_analysis: 0, correction: '', correction_at: 0,
      level: 'sealed', deleted: 0, notes: ''
    });
    const service = await ReviewService.open({});
    const items = await service.recentMaterials(20);
    assert.strictEqual(items.some((item) => item.id === 'relation:rl_sealed'), false);
  });

  await test('引用状态与关系后写入快照', async () => {
    reset();
    store.rows('status_record').push({
      id: 'st_snap', date: '2026-11-15', sleep_hours: 7, exercise_count: 1, alert_count: 0,
      note: '状态快照', body_signals: '', function_state: '', emotion: '', environment: '',
      capacity: '', function_gain: '', cost_paid: '', unknown_readings: '', corrected_at: 0,
      revisions: '', level: 'local_only', deleted: 0
    });
    store.rows('relation').push({
      id: 'rl_snap', name: '同事', trust_level: 'friendly',
      interaction_log: JSON.stringify([{ timestamp: 1000, content: '一起吃了午饭', source: 'joint' }]),
      raw_material_test: 0, forbid_analysis: 0, correction: '', correction_at: 0,
      level: 'local_only', deleted: 0, notes: ''
    });
    const service = await ReviewService.open({});
    const reviewId = await service.save('week', {
      facts: '', interpretation: '', contradiction: '', action: '',
      payload: {
        scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
        materialIds: ['status:st_snap', 'relation:rl_snap']
      },
      materialIds: ['status:st_snap', 'relation:rl_snap'],
      anchorIds: []
    }, '11-16 ~ 11-22');
    const snapshots = await service.materials(reviewId);
    assert.strictEqual(snapshots.length, 2);
    assert.strictEqual(snapshots.every((row) => row.textSnapshot.length > 0), true);
    assert.strictEqual(snapshots.every((row) => row.snapshotMissing === false), true);
  });

  await test('引用已删除状态时快照标记缺失', async () => {
    reset();
    store.rows('status_record').push({
      id: 'st_gone', date: '2026-11-14', sleep_hours: 6, exercise_count: 0, alert_count: 1,
      note: '', body_signals: '', function_state: '', emotion: '', environment: '',
      capacity: '', function_gain: '', cost_paid: '', unknown_readings: '', corrected_at: 0,
      revisions: '', level: 'local_only', deleted: 1
    });
    const service = await ReviewService.open({});
    const reviewId = await service.save('week', {
      facts: '', interpretation: '', contradiction: '', action: '',
      payload: {
        scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
        materialIds: ['status:st_gone']
      },
      materialIds: ['status:st_gone'],
      anchorIds: []
    }, '11-16 ~ 11-22');
    const snapshots = await service.materials(reviewId);
    assert.strictEqual(snapshots.length, 1);
    assert.strictEqual(snapshots[0].snapshotMissing, true);
    assert.strictEqual(snapshots[0].textSnapshot, '');
  });

  await test('载荷解析锚点理由并去重', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
      anchorCitations: [
        { anchorId: 'a1', reason: '对应睡眠记录' },
        { anchorId: 'a1', reason: '重复' },
        { anchorId: '', reason: '坏项' }
      ]
    }));
    assert.ok(payload !== undefined);
    assert.strictEqual(payload.anchorCitations.length, 1);
    assert.strictEqual(payload.anchorCitations[0].anchorId, 'a1');
    assert.strictEqual(payload.anchorCitations[0].reason, '对应睡眠记录');
  });

  await test('旧载荷没有锚点理由时读作空数组', () => {
    const payload = parseReviewPayload(JSON.stringify({
      scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: ''
    }));
    assert.ok(payload !== undefined);
    assert.deepStrictEqual(payload.anchorCitations, []);
  });

  await test('锚点创建时间写入与读取', async () => {
    reset();
    const dao = new AnchorDao(store);
    await dao.insert({
      id: 'an_time', text: '先记录再解释', source: '自定', order: 1,
      level: 'local_only', rootId: 'an_time', version: 1, status: 'active',
      context: '', revisionReason: '', synthetic: false, createdAt: 1000
    });
    const rows = await dao.queryAll();
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].createdAt, 1000);
  });

  await test('复盘保存锚点选择理由', async () => {
    reset();
    const service = await ReviewService.open({});
    const reviewId = await service.save('week', {
      facts: '', interpretation: '', contradiction: '', action: '',
      payload: {
        scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
        anchorCitations: [{ anchorId: 'an_1', reason: '这条锚点对应本周的睡眠记录' }]
      },
      anchorIds: ['an_1']
    }, '11-16 ~ 11-22');
    const row = await new ReviewResultDao(store).queryById(reviewId);
    assert.ok(row !== null);
    assert.ok(row.payload !== undefined);
    assert.strictEqual(row.payload.anchorCitations.length, 1);
    assert.strictEqual(row.payload.anchorCitations[0].reason, '这条锚点对应本周的睡眠记录');
  });

  await test('清单处理四类计数可核对', () => {
    const node = {
      id: 'pn_1', planId: 'pl_1', weekIndex: 1,
      startDate: '2026-11-02', endDate: '2026-11-08', status: 'closed'
    };
    const items = [
      { id: 'pi_1', nodeId: 'pn_1', text: '完成项', done: true, sortOrder: 0 },
      { id: 'pi_2', nodeId: 'pn_1', text: '延续项', done: false, carriedFrom: 'pi_old', sortOrder: 1 },
      { id: 'pi_3', nodeId: 'pn_1', text: '暂停项', done: false, disposition: 'paused', sortOrder: 2 },
      { id: 'pi_4', nodeId: 'pn_1', text: '舍弃项', done: false, disposition: 'discarded', sortOrder: 3 },
      { id: 'pi_5', nodeId: 'pn_1', text: '新开项', done: false, sortOrder: 4 }
    ];
    const rows = buildNodeProgress([node], items);
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].done, 1);
    assert.strictEqual(rows[0].openCarried, 1);
    assert.strictEqual(rows[0].paused, 1);
    assert.strictEqual(rows[0].discarded, 1);
    assert.strictEqual(rows[0].total, 5);
  });

  await test('延续率排除暂停与舍弃项', () => {
    const row = {
      nodeId: 'pn_1', weekIndex: 1, startDate: '', endDate: '', status: 'closed',
      done: 0, openCarried: 1, openNew: 1, paused: 1, discarded: 1, total: 4
    };
    assert.strictEqual(carryRatePercent(row), 50);
  });

  await test('清单走势跳过没有清单的周', () => {
    const rows = [
      {
        nodeId: 'pn_1', weekIndex: 1, startDate: '', endDate: '', status: 'closed',
        done: 1, openCarried: 0, openNew: 0, paused: 0, discarded: 0, total: 1
      },
      {
        nodeId: 'pn_2', weekIndex: 2, startDate: '', endDate: '', status: 'closed',
        done: 0, openCarried: 0, openNew: 0, paused: 0, discarded: 0, total: 0
      }
    ];
    const points = carrySeries(rows);
    assert.strictEqual(points.length, 1);
    assert.strictEqual(points[0].label, '第1周');
  });

  await test('审计只保存编号密级与剔除数，不保存正文', async () => {
    reset();
    const dao = new RequestAuditDao(store);
    await dao.insert({
      id: 'aud_1', provider: 'mock', host: 'http://127.0.0.1:8787',
      materialIds: ['relation:rl_1', 'facts'], levels: ['local_only', 'analyzable'],
      chars: 128, confirmed: true, fellBack: false, removedCount: 2, createdAt: 1000
    });
    const rows = await dao.queryRecent(1);
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].removedCount, 2);
    assert.deepStrictEqual(rows[0].materialIds, ['relation:rl_1', 'facts']);
    assert.deepStrictEqual(rows[0].levels, ['local_only', 'analyzable']);
    assert.strictEqual(JSON.stringify(rows[0]).includes('正文内容'), false);
  });

  await test('旧审计行缺少剔除数时读作零', async () => {
    reset();
    store.rows('request_audit').push({
      id: 'aud_old', provider: 'mock', host: 'http://127.0.0.1:8787',
      material_ids: '[]', levels: '[]', chars: 10, confirmed: 1, fell_back: 0, created_at: 1
    });
    const rows = await new RequestAuditDao(store).queryRecent(1);
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].removedCount, 0);
  });

  await test('互动条目密级缺省时保持未标注', () => {
    const logs = parseInteractionLog(JSON.stringify([
      { timestamp: 1, content: '已封存互动', level: 'sealed' },
      { timestamp: 2, content: '旧条目没有密级' },
      { timestamp: 3, content: '非法密级', level: 'unknown' }
    ]));
    assert.strictEqual(logs.length, 3);
    assert.strictEqual(logs[0].level, 'sealed');
    assert.strictEqual(logs[1].level, undefined);
    assert.strictEqual(logs[2].level, undefined);
  });

  await test('历史条目统计引用材料与证据数', () => {
    const item = toReviewHistoryItem({
      id: 'rv_hist', period: 'week', rangeLabel: '11-16 ~ 11-22',
      action: '', createdAt: 1000, anchorIds: [],
      payload: {
        scene: '现场', model: '', relation: '', evidence: '', cost: '', revision: '',
        materialIds: ['m1', 'm2'],
        evidenceDrafts: [
          { source: 'practice', effect: 'support', text: '证据' }
        ]
      }
    });
    assert.strictEqual(item.materialCount, 2);
    assert.strictEqual(item.evidenceCount, 1);
  });

  if (failures.length > 0) {
    console.error(`FAILED ${failures.length} / ${passed + failures.length}`);
    for (const failure of failures) {
      console.error(`  - ${failure}`);
    }
    process.exit(1);
  }
  console.log(`PASSED ${passed} / ${passed}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
