import { Anchor } from '../../model/Anchor';
import { AnchorMatch, AnchorMatcher } from './AnchorMatcher';

/** Scores anchors by shared two-character grams; good enough for short Chinese anchors. */
export class KeywordAnchorMatcher implements AnchorMatcher {
  match(text: string, anchors: Anchor[], limit: number): AnchorMatch[] {
    const normalized = normalize(text);
    if (normalized.length < 2) {
      return [];
    }
    const textGrams = grams(normalized);
    const matches: AnchorMatch[] = [];
    for (const anchor of anchors) {
      const anchorGrams = grams(normalize(anchor.text));
      if (anchorGrams.size === 0) {
        continue;
      }
      let overlap = 0;
      for (const gram of anchorGrams) {
        if (textGrams.has(gram)) {
          overlap += 1;
        }
      }
      const score = overlap / anchorGrams.size;
      if (score > 0) {
        matches.push({
          anchorId: anchor.id,
          score: Math.round(score * 100) / 100,
          reason: `关键词重合 ${overlap} 处`
        });
      }
    }
    matches.sort((left: AnchorMatch, right: AnchorMatch) => right.score - left.score);
    return matches.slice(0, limit);
  }
}

function normalize(text: string): string {
  return text.replace(/[\s，。！？、；：""''（）()【】\[\]《》<>·—\-]/g, '').toLowerCase();
}

function grams(text: string): Set<string> {
  const result: Set<string> = new Set<string>();
  for (let index = 0; index + 1 < text.length; index += 1) {
    result.add(text.slice(index, index + 2));
  }
  return result;
}
