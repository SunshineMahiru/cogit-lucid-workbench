'use strict';

const assert = require('assert');
const Module = require('module');

// ReviewAgent 间接依赖 HttpClient 与 LlmSpendStore，两者在模块加载期就要 @kit 模块。
// 这里统一给空壳：本文件的用例全部在构造真实客户端或读取偏好之前就走回退分支。
const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === '@kit.NetworkKit') {
    return {
      http: {
        createHttp: () => ({
          request: async () => {
            throw new Error('network disabled in tests');
          },
          destroy: () => {
          }
        })
      }
    };
  }
  if (request.indexOf('@kit.') === 0) {
    return {};
  }
  return originalLoad.call(this, request, parent, isMain);
};
const { KeywordAnchorMatcher } = require('./out2/analysis/anchors/KeywordAnchorMatcher');
const { TemplateContradictionAnalyzer } = require('./out2/analysis/contradiction/TemplateContradictionAnalyzer');
const { parseContradictionCandidates } = require('./out2/analysis/contradiction/LlmContradictionAnalyzer');
const { ReviewAgent } = require('./out2/review/ReviewAgent');
const { defaultAppSettings } = require('./out2/settings/AppSettings');

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

(async () => {
  await test('锚点匹配按关键词重合排序', () => {
    const matcher = new KeywordAnchorMatcher();
    const anchors = [
      { id: 'a1', text: '先记录睡眠，再解释', source: '', order: 1 },
      { id: 'a2', text: '先行动，再评价', source: '', order: 2 }
    ];
    const matches = matcher.match('这周睡眠记录很少', anchors, 3);
    assert.strictEqual(matches[0].anchorId, 'a1');
    assert.ok(matches[0].score > 0);
  });

  await test('模板分析捕捉绝对化表述与缺失数字', async () => {
    const analyzer = new TemplateContradictionAnalyzer();
    const candidates = await analyzer.analyze({
      facts: '这周有 3 天睡不到 7 小时，周三临时改期两次',
      interpretation: '我总是状态差',
      anchors: []
    }, { now: Date.now() });
    assert.ok(candidates.length >= 2);
    assert.ok(candidates.some((item) => item.gap.includes('总是')));
    assert.ok(candidates.some((item) => item.gap.includes('数字')));
  });

  await test('空文本仍返回通用追问', async () => {
    const analyzer = new TemplateContradictionAnalyzer();
    const candidates = await analyzer.analyze({ facts: '', interpretation: '', anchors: [] }, { now: Date.now() });
    assert.strictEqual(candidates.length, 2);
  });

  await test('模型候选解析支持代码围栏并过滤坏项', () => {
    const parsed = parseContradictionCandidates('```json\n{"candidates":[{"anchorId":"a1","gap":"差距","prompt":"追问"},{"anchorId":"","gap":"","prompt":"空"}]}\n```');
    assert.strictEqual(parsed.length, 1);
    assert.strictEqual(parsed[0].anchorId, 'a1');
    assert.throws(() => parseContradictionCandidates('not json'));
  });

  const agentInput = () => ({
    facts: '这周有 3 天睡不到 7 小时',
    interpretation: '我总是状态差',
    anchors: [{ id: 'a1', text: '先记录睡眠，再解释', source: '', order: 1 }]
  });

  const settingsWith = (patch) => Object.assign(defaultAppSettings(), patch);

  await test('模板模式下不进入预算与网络分支', async () => {
    const agent = new ReviewAgent(settingsWith({ llmProvider: 'template' }), null);
    const outcome = await agent.analyze(agentInput(), 1700000000000);
    assert.strictEqual(outcome.provider, 'template');
    assert.strictEqual(outcome.fellBack, false);
    assert.strictEqual(outcome.message, '离线模板');
    assert.ok(outcome.candidates.length >= 2);
  });

  await test('预算为零时回退模板并标记 fellBack', async () => {
    const agent = new ReviewAgent(settingsWith({ llmProvider: 'model', llmMonthlyBudget: 0 }), null);
    const outcome = await agent.analyze(agentInput(), 1700000000000);
    assert.strictEqual(outcome.provider, 'template');
    assert.strictEqual(outcome.fellBack, true);
    assert.ok(outcome.message.includes('回退'));
  });

  await test('模型模式缺少预算存储时回退模板', async () => {
    const agent = new ReviewAgent(settingsWith({ llmProvider: 'model', llmMonthlyBudget: 20 }), null);
    const outcome = await agent.analyze(agentInput(), 1700000000000);
    assert.strictEqual(outcome.provider, 'template');
    assert.strictEqual(outcome.fellBack, true);
    assert.ok(outcome.candidates.length >= 2);
  });

  await test('预算耗尽时回退模板', async () => {
    const store = {
      canAfford: async () => false,
      record: async () => {
      }
    };
    const agent = new ReviewAgent(settingsWith({ llmProvider: 'model', llmMonthlyBudget: 20 }), store);
    const outcome = await agent.analyze(agentInput(), 1700000000000);
    assert.strictEqual(outcome.provider, 'template');
    assert.strictEqual(outcome.fellBack, true);
  });

  if (failures.length > 0) {
    console.error(`FAILED ${failures.length} / ${passed + failures.length}`);
    for (const failure of failures) {
      console.error(`  - ${failure}`);
    }
    process.exit(1);
  }
  console.log(`PASSED ${passed} / ${passed}`);
})();
