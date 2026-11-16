import { LlmClient, LlmMessage } from '../llm/LlmClient';
import { AnalysisContext } from '../types';
import {
  CandidateUncertainty,
  ContradictionAnalyzer,
  ContradictionCandidate,
  ContradictionInput
} from './ContradictionAnalyzer';

interface CandidatePayload {
  candidates?: ContradictionCandidate[];
}

export const CONTRADICTION_SYSTEM_PROMPT = '你是元认知复盘助手。只输出 JSON，格式为 ' +
  '{"candidates":[{"anchorId":"","gap":"矛盾点","prompt":"追问","basis":"依据","unknowns":"未知项","uncertainty":"low|medium|high"}]}，最多三条。' +
  '依据只能来自给定的事实、解释与价值锚点；不推断动机、人格、关系结局或他人意图；' +
  '没有依据的内容写进 unknowns；不确定度取 low、medium 或 high；没有把握就返回空数组。';

/** Turns facts, interpretation and anchors into one chat request and parses candidates back. */
export class LlmContradictionAnalyzer implements ContradictionAnalyzer {
  private client: LlmClient;
  private model: string;

  constructor(client: LlmClient, model: string) {
    this.client = client;
    this.model = model;
  }

  async analyze(input: ContradictionInput, context: AnalysisContext): Promise<ContradictionCandidate[]> {
    const messages: LlmMessage[] = [
      { role: 'system', content: CONTRADICTION_SYSTEM_PROMPT },
      { role: 'user', content: buildContradictionUserPrompt(input) }
    ];
    const response = await this.client.complete({
      model: this.model,
      messages: messages,
      temperature: 0.3
    });
    return parseContradictionCandidates(response.content);
  }
}

/** Builds the user turn; the constraints repeat in the user text so a model cannot miss them. */
export function buildContradictionUserPrompt(input: ContradictionInput): string {
  const lines: string[] = [];
  lines.push(`事实：${input.facts.trim()}`);
  lines.push(`解释：${input.interpretation.trim()}`);
  if (input.anchors.length > 0) {
    lines.push('价值锚点：');
    for (const anchor of input.anchors) {
      lines.push(`- [${anchor.id}] ${anchor.text}`);
    }
  }
  lines.push('请找出解释与事实之间的差距，并给出可执行的追问。');
  lines.push('不要推断动机、人格或关系结局；依据不足的内容写进未知项。');
  return lines.join('\n');
}

/** Parses fenced or plain JSON and validates every candidate. */
export function parseContradictionCandidates(content: string): ContradictionCandidate[] {
  const cleaned = content.trim().replace(/^```json/i, '').replace(/^```/, '').replace(/```$/, '').trim();
  const payload = JSON.parse(cleaned) as CandidatePayload;
  if (!Array.isArray(payload.candidates)) {
    throw new Error('invalid candidate payload');
  }
  const candidates: ContradictionCandidate[] = [];
  for (const item of payload.candidates) {
    if (typeof item.anchorId !== 'string' || typeof item.gap !== 'string' ||
      typeof item.prompt !== 'string' || item.gap.trim().length === 0 || item.prompt.trim().length === 0) {
      continue;
    }
    candidates.push({
      anchorId: item.anchorId,
      gap: item.gap.trim(),
      prompt: item.prompt.trim(),
      basis: typeof item.basis === 'string' ? item.basis.trim() : '',
      unknowns: typeof item.unknowns === 'string' ? item.unknowns.trim() : '',
      uncertainty: readUncertainty(item.uncertainty)
    });
  }
  return candidates.slice(0, 3);
}

function readUncertainty(value: CandidateUncertainty | undefined): CandidateUncertainty {
  if (value === 'low' || value === 'medium' || value === 'high') {
    return value;
  }
  return '';
}
