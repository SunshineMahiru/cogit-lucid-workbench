'use strict';

const assert = require('assert');
const {
  addPlanDays,
  createPlan,
  createPlanItem,
  createPlanNode,
  mondayOf,
  parsePlanDate
} = require('./out2/plan/PlanFactory');
const { PlanNodeStatus, PlanStatus } = require('./out2/model/PlanStatus');

const plan = createPlan('测试目标', '2026-11-05');
assert.strictEqual(plan.startDate, '2026-11-02');
assert.strictEqual(plan.status, PlanStatus.ACTIVE);
assert.strictEqual(plan.isPrimary, false);

const node = createPlanNode(plan.id, 2, '2026-11-09');
assert.strictEqual(node.startDate, '2026-11-09');
assert.strictEqual(node.endDate, '2026-11-15');
assert.strictEqual(node.status, PlanNodeStatus.OPEN);

const later = addPlanDays('2026-11-08', 1);
assert.ok(Number.isNaN(parsePlanDate('2026-99-99').getTime()));
assert.ok(Number.isNaN(parsePlanDate('2026-02-30').getTime()));
assert.strictEqual(later, '2026-11-09');
assert.strictEqual(mondayOf('2026-11-08'), '2026-11-02');

const item = createPlanItem(node.id, ' 写完复盘 ', 0);
assert.strictEqual(item.text, '写完复盘');
assert.strictEqual(item.done, false);

const { markLinkSuggestions } = require('./out2/plan/PlanLinkCandidate');
const { PlanLinkModule } = require('./out2/model/PlanLinkModule');
const candidates = [
  { module: PlanLinkModule.NOTE, targetId: 'old', title: '旧记录', subtitle: '', timestamp: 0,
    tags: [], relationIds: [], suggested: false, score: 0 },
  { module: PlanLinkModule.NOTE, targetId: 'week', title: '本周记录', subtitle: '',
    timestamp: new Date('2026-11-10T09:00:00').getTime(), tags: [], relationIds: [], suggested: false, score: 0 },
  { module: PlanLinkModule.RELATION, targetId: 'rl_1', title: '关系 A', subtitle: '',
    timestamp: 0, tags: [], relationIds: ['rl_1'], suggested: false, score: 0 }
];
const sorted = markLinkSuggestions(candidates, '2026-11-09', '2026-11-15', ['rl_1'], []);
assert.strictEqual(sorted[0].targetId, 'week');
assert.strictEqual(sorted[1].targetId, 'rl_1');
assert.strictEqual(sorted[2].targetId, 'old');

const { renderPlanSection } = require('./out2/export/render/PlanSection');
const section = renderPlanSection([{
  plan: { id: 'pl_1', title: '测试目标', goal: '把计划做完', startDate: '2026-11-02',
    status: 'active', isPrimary: true, createdAt: 1 },
  nodes: [{ id: 'pn_1', planId: 'pl_1', weekIndex: 1, startDate: '2026-11-02',
    endDate: '2026-11-08', status: 'closed' }],
  items: [
    { id: 'pi_1', nodeId: 'pn_1', text: '已完成', done: true, sortOrder: 0 },
    { id: 'pi_2', nodeId: 'pn_1', text: '未完成', done: false, sortOrder: 1 }
  ],
  links: [{ id: 'lk_1', planId: 'pl_1', nodeId: 'pn_1', module: 'note', targetId: 'n1',
    label: '一条速记', createdAt: 1 }]
}]);
assert.ok(section.includes('- [x] 已完成'));
assert.ok(section.includes('- [ ] 未完成'));
assert.ok(section.includes('速记 · 一条速记'));

const datedSection = renderPlanSection([{
  plan: { id: 'pl_2', title: '带结束日', goal: '', startDate: '2026-11-02',
    targetDate: '2026-12-31', status: 'active', isPrimary: false, createdAt: 1 },
  nodes: [], items: [], links: []
}]);
assert.ok(datedSection.includes('- 结束：2026-12-31'));

const openSection = renderPlanSection([{
  plan: { id: 'pl_3', title: '无结束日', goal: '', startDate: '2026-11-02',
    status: 'active', isPrimary: false, createdAt: 1 },
  nodes: [], items: [], links: []
}]);
assert.strictEqual(openSection.includes('- 结束：'), false);

const { mergePlanLinks, planLinkKey } = require('./out2/plan/PlanLinkSelection');
const existingLink = {
  id: 'lk_old', planId: 'pl_1', nodeId: 'pn_1', module: 'note',
  targetId: 'note_not_in_candidates', label: '很早的一条速记', createdAt: 1
};
const candidateForNew = {
  module: PlanLinkModule.NOTE, targetId: 'n_new', title: '新记录', subtitle: '',
  timestamp: 0, tags: [], relationIds: [], suggested: false, score: 0
};
const merged = mergePlanLinks('pl_1', 'pn_1', [existingLink], [candidateForNew],
  [planLinkKey('note', 'note_not_in_candidates'), planLinkKey('note', 'n_new')]);
assert.strictEqual(merged.length, 2);
assert.strictEqual(merged[0].id, 'lk_old');
assert.strictEqual(merged[0].label, '很早的一条速记');
assert.strictEqual(merged[1].targetId, 'n_new');
assert.strictEqual(merged[1].label, '新记录');

const removed = mergePlanLinks('pl_1', 'pn_1', [existingLink], [candidateForNew],
  [planLinkKey('note', 'n_new')]);
assert.deepStrictEqual(removed.map((link) => link.targetId), ['n_new']);

const deduped = mergePlanLinks('pl_1', 'pn_1', [existingLink], [candidateForNew],
  [planLinkKey('note', 'n_new'), planLinkKey('note', 'n_new')]);
assert.strictEqual(deduped.length, 1);

const keepLabel = mergePlanLinks('pl_1', 'pn_1', [existingLink],
  [Object.assign({}, candidateForNew, { targetId: 'note_not_in_candidates', title: '改名后的速记' })],
  [planLinkKey('note', 'note_not_in_candidates')]);
assert.strictEqual(keepLabel[0].label, '很早的一条速记');

const {
  buildDayActivity,
  buildNodeProgress,
  carryRatePercent,
  carrySeries,
  deadlineProgress,
  linkCounts,
  nodeDays,
  weekDates
} = require('./out2/plan/PlanInsights');

const insightNodes = [
  { id: 'pn_1', planId: 'pl_1', weekIndex: 1, startDate: '2026-11-02', endDate: '2026-11-08', status: 'closed' },
  { id: 'pn_2', planId: 'pl_1', weekIndex: 2, startDate: '2026-11-09', endDate: '2026-11-15', status: 'open' },
  { id: 'pn_3', planId: 'pl_1', weekIndex: 3, startDate: '2026-11-16', endDate: '2026-11-22', status: 'open' }
];
const insightItems = [
  { id: 'i1', nodeId: 'pn_1', text: '完成项', done: true, sortOrder: 0 },
  { id: 'i2', nodeId: 'pn_1', text: '延续项', done: false, sortOrder: 1, carriedFrom: 'i0' },
  { id: 'i3', nodeId: 'pn_1', text: '新加项', done: false, sortOrder: 2 },
  { id: 'i4', nodeId: 'pn_2', text: '第二周完成', done: true, sortOrder: 0 },
  { id: 'i5', nodeId: 'pn_2', text: '第二周延续', done: false, sortOrder: 1, carriedFrom: 'i3' }
];
const progress = buildNodeProgress(insightNodes, insightItems);
assert.strictEqual(progress.length, 3);
assert.deepStrictEqual(
  { done: progress[0].done, carried: progress[0].openCarried, added: progress[0].openNew, total: progress[0].total },
  { done: 1, carried: 1, added: 1, total: 3 });
assert.strictEqual(progress[2].total, 0);
assert.strictEqual(carryRatePercent(progress[0]), 33);
assert.strictEqual(carryRatePercent(progress[2]), 0);
const carryPoints = carrySeries(progress);
assert.strictEqual(carryPoints.length, 2);
assert.deepStrictEqual(carryPoints.map((point) => point.label), ['第1周', '第2周']);

const counts = linkCounts([
  { id: 'l1', planId: 'pl_1', nodeId: 'pn_1', module: 'note', targetId: 'e1', label: 'a', createdAt: 1 },
  { id: 'l2', planId: 'pl_1', nodeId: 'pn_1', module: 'note', targetId: 'e2', label: 'b', createdAt: 2 },
  { id: 'l3', planId: 'pl_1', nodeId: 'pn_1', module: 'relation', targetId: 'r1', label: 'c', createdAt: 3 }
]);
assert.deepStrictEqual(counts.map((row) => row.count), [2, 0, 0, 0, 1, 0]);

const noTarget = deadlineProgress('2026-11-02', '', '2026-11-05');
assert.strictEqual(noTarget.hasTarget, false);
const halfway = deadlineProgress('2026-11-02', '2026-11-12', '2026-11-07');
assert.strictEqual(halfway.hasTarget, true);
assert.strictEqual(halfway.totalDays, 10);
assert.strictEqual(halfway.percent, 50);
assert.strictEqual(halfway.remainingDays, 5);
assert.strictEqual(halfway.overdue, false);
const overdue = deadlineProgress('2026-11-02', '2026-11-04', '2026-11-07');
assert.strictEqual(overdue.percent, 100);
assert.strictEqual(overdue.overdue, true);

const days = nodeDays('2026-11-09', '2026-11-15', '2026-11-12');
assert.deepStrictEqual(days, { left: 4, total: 7, percent: 57 });

const dates = weekDates('2026-11-09');
assert.strictEqual(dates.length, 7);
assert.strictEqual(dates[0], '2026-11-09');
assert.strictEqual(dates[6], '2026-11-15');
const activity = buildDayActivity(dates, [new Date('2026-11-10T09:00:00').getTime()],
  [{ date: '2026-11-11', sleepHours: 7.5, exerciseCount: 1 }]);
assert.strictEqual(activity[1].noteCount, 1);
assert.strictEqual(activity[1].hasReading, false);
assert.strictEqual(activity[2].hasReading, true);
assert.strictEqual(activity[2].sleepHours, 7.5);
assert.strictEqual(activity[0].weekday, '一');

const { validatePlanDraft } = require('./out2/plan/PlanValidation');

assert.strictEqual(validatePlanDraft('  ', '2026-11-05', '').message, '请填写目标名称');
assert.strictEqual(validatePlanDraft('目标', '2026-2-3', '').message, '起始日期格式应为 YYYY-MM-DD');
assert.strictEqual(validatePlanDraft('目标', '2026-11-05', '2026-13-01').message,
  '结束日期格式应为 YYYY-MM-DD，或留空');
assert.strictEqual(validatePlanDraft('目标', '2026-11-05', '2026-11-01').message,
  '结束日期需晚于起始日期');
assert.strictEqual(validatePlanDraft('目标', '2026-11-05', '2026-11-02').message,
  '结束日期需晚于起始日期');
assert.strictEqual(validatePlanDraft('目标', '2026-11-05', '').ok, true);
assert.strictEqual(validatePlanDraft('目标', '2026-11-05', '2026-11-03').ok, true);
assert.strictEqual(validatePlanDraft('目标', '2026-11-08', '2026-11-03').ok, true);

console.log('PASSED plan factories');

