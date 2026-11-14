import { TrustLevel } from '../model/TrustLevel';

/** What a relation permits the author to share; never what the author may infer. */
export interface DisclosureBoundary {
  /** One line describing the tier */
  tierText: string;
  /** What the author may record and mention */
  shareable: string;
  /** The rule that always applies */
  rule: string;
}

/** Builds the boundary text for one relation. */
export function disclosureBoundaryOf(trustLevel: TrustLevel, forbidAnalysis: boolean): DisclosureBoundary {
  const rule = forbidAnalysis ?
    '该关系已禁止任何动机、人格与结局推断；相关材料只做事实描述。' :
    '本应用不推断对方动机、人格或关系结局；对方的话与自己的推测分开记录。';
  if (trustLevel === TrustLevel.TRANSPARENT) {
    return {
      tierText: '透明',
      shareable: '可以记录对方看过的材料与共同承担的事；引用范围仍按每条记录单独确认。',
      rule: rule
    };
  }
  if (trustLevel === TrustLevel.SINCERE) {
    return {
      tierText: '真诚',
      shareable: '可以记录真实想法与对方的明确表态；对方的话默认只留在本机。',
      rule: rule
    };
  }
  return {
    tierText: '友好',
    shareable: '只记录日常往来；对方的话默认只留在本机，导出前逐条确认。',
    rule: rule
  };
}
