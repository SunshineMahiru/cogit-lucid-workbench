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

  async querySql(sql) {
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
const { StatusService } = require('./out2/status/StatusService');
const { HomeDataService } = require('./out2/data/HomeDataService');
const { ExperienceMaterialDao } = require('./out2/db/dao/ExperienceMaterialDao');
const { EvidenceItemDao } = require('./out2/db/dao/EvidenceItemDao');
const { EventDao } = require('./out2/db/dao/EventDao');
const { DecisionDao } = require('./out2/db/dao/DecisionDao');
const { prepareExportBundle, allExportOptions } = require('./out2/export/ExportFilter');
const { renderExportDocument } = require('./out2/export/render');
const { ExportService } = require('./out2/export/ExportService');
const { PredictionService } = require('./out2/prediction/PredictionService');
const { ReviewService } = require('./out2/review/ReviewService');
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
        settlementDate: '2026-10-01'
      }, now);
    });

    const settled = await predictionService.settle(created.id, '达成六天', 'hold');
    assert.ok(settled !== null);
    assert.strictEqual(settled.status, 'settled');
    assert.strictEqual(settled.hit, true);

    const stats = await predictionService.stats();
    assert.strictEqual(stats.settled, 1);
    assert.strictEqual(stats.hitRate, 100);

    await assert.rejects(async () => {
      await predictionService.settle(created.id, '再次结算', 'fail');
    });
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
      settlementDate: '2026-11-03'
    }, now);

    const revised = await predictionService.revise(created.id, {
      target: '本周作息',
      judgment: '本周日均睡眠达到 7 小时',
      confidence: 80,
      reason: '补充理由',
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
      settlementDate: '2026-10-27'
    }, now);
    await predictionService.settle(hit.id, '达成', 'hold', '', now);
    const miss = await predictionService.create({
      target: '作息 B',
      judgment: '达成',
      confidence: 60,
      reason: '',
      settlementDate: '2026-10-27'
    }, now);
    await predictionService.settle(miss.id, '未达成', 'fail', '', now);
    await predictionService.create({
      target: '下月作息',
      judgment: '达成',
      confidence: 60,
      reason: '',
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
      settlementDate: '2026-10-27'
    }, now);
    await predictionService.settle(partial.id, '部分达成', 'partial', '', now);
    const afterPartial = await reviewService.loadStatsFor('week', now);
    assert.strictEqual(afterPartial.settledPredictions, 3);
    assert.strictEqual(afterPartial.hitRate, 50);
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
