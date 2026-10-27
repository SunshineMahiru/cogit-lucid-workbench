import { Anchor } from '../../model/Anchor';
import { AnalysisContext } from '../types';
import { KeywordAnchorMatcher } from '../anchors/KeywordAnchorMatcher';
import {
  ContradictionAnalyzer,
  ContradictionCandidate,
  ContradictionInput
} from './ContradictionAnalyzer';

const ABSOLUTE_WORDS: string[] = ['总是', '从不', '永远', '一定', '必须', '应该', '所有人', '没人', '根本'];

/** Deterministic offline hints used when no model is configured. */
export class TemplateContradictionAnalyzer implements ContradictionAnalyzer {
  private matcher: KeywordAnchorMatcher = new KeywordAnchorMatcher();

  async analyze(input: ContradictionInput, context: AnalysisContext): Promise<ContradictionCandidate[]> {
    const facts = input.facts.trim();
    const interpretation = input.interpretation.trim();
    const candidates: ContradictionCandidate[] = [];

    for (const word of ABSOLUTE_WORDS) {
      if (interpretation.includes(word)) {
        candidates.push({
          anchorId: '',
          gap: `解释里出现「${word}」，事实部分未必支持这种绝对化表述`,
          prompt: '把这句话改成可核对的程度描述，还剩下多少成立？'
        });
        break;
      }
    }

    if (/\d/.test(facts) && !/\d/.test(interpretation)) {
      candidates.push({
        anchorId: '',
        gap: '事实里有具体数字，解释却没有引用任何数字或时间',
        prompt: '解释能否对应到某一个具体日期、次数或时长？'
      });
    }

    const matched = this.matcher.match(`${facts} ${interpretation}`, input.anchors, 1);
    if (matched.length > 0) {
      const anchor = findAnchor(input.anchors, matched[0].anchorId);
      if (anchor !== null) {
        candidates.push({
          anchorId: anchor.id,
          gap: `解释与锚点「${anchor.text}」的侧重点可能不一致`,
          prompt: '这条锚点要求你先做什么？现在的解释跳过了哪一步？'
        });
      }
    }

    if (candidates.length === 0) {
      candidates.push({
        anchorId: '',
        gap: '解释暂时没有引用具体事件或数字',
        prompt: '这条解释最依赖哪一个事实？那个事实能否被他人核对？'
      });
      candidates.push({
        anchorId: '',
        gap: '目前只有一种解释，没有反证视角',
        prompt: '如果这条解释是错的，最可能错在哪一步？'
      });
    }

    return candidates.slice(0, 3);
  }
}

function findAnchor(anchors: Anchor[], id: string): Anchor | null {
  for (const anchor of anchors) {
    if (anchor.id === id) {
      return anchor;
    }
  }
  return null;
}
