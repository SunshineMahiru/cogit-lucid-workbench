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

  getColumnIndex(name) {
    const index = this.columns.indexOf(name);
    if (index < 0) {
      throw new Error(`missing column ${name}`);
    }
    return index;
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

  async executeSql() {
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
      this.snapshot.set(table, rows.slice());
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
const fakeArkData = {
  relationalStore: {
    RdbPredicates: FakePredicates,
    SecurityLevel: { S1: 1 },
    getRdbStore: async () => store
  }
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
const { createNoteDraft, createFreeformNoteDraft } = require('./out2/note/NoteDraftFactory');
const { NoteFieldKey } = require('./out2/note/NoteFieldKey');
const { NoteTemplateId } = require('./out2/note/NoteTemplateId');
const { AnchorService } = require('./out2/anchor/AnchorService');
const { RelationService } = require('./out2/relation/RelationService');
const { StatusService } = require('./out2/status/StatusService');
const { PredictionService } = require('./out2/prediction/PredictionService');
const { ReviewService } = require('./out2/review/ReviewService');
const { rangeFor } = require('./out2/review/ReviewRange');
const { PlanService } = require('./out2/plan/PlanService');

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
  store.insertCount = 0;
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
      await predictionService.settle(future.id, '提前结算', true, now);
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

    const settled = await predictionService.settle(created.id, '达成六天', true);
    assert.ok(settled !== null);
    assert.strictEqual(settled.status, 'settled');
    assert.strictEqual(settled.hit, true);

    const stats = await predictionService.stats();
    assert.strictEqual(stats.settled, 1);
    assert.strictEqual(stats.hitRate, 100);

    await assert.rejects(async () => {
      await predictionService.settle(created.id, '再次结算', false);
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
      settlementDate: '2026-11-03'
    }, now + 1000);
    assert.strictEqual(revised.version, 2);
    assert.strictEqual(lastRow('prediction').root_id, created.id);
    assert.strictEqual(revised.confidence, 80);
    assert.strictEqual(revised.reason, '补充理由');

    const again = await predictionService.revise(revised.id, {
      target: '本周作息',
      judgment: '本周日均睡眠达到 7 小时',
      confidence: 90,
      reason: '',
      settlementDate: '2026-11-03'
    }, now + 2000);
    assert.strictEqual(again.version, 3);
    assert.strictEqual(lastRow('prediction').root_id, created.id);
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
    await predictionService.settle(hit.id, '达成', true, now);
    const miss = await predictionService.create({
      target: '作息 B',
      judgment: '达成',
      confidence: 60,
      reason: '',
      settlementDate: '2026-10-27'
    }, now);
    await predictionService.settle(miss.id, '未达成', false, now);
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
