import { Prediction } from '../../model/Prediction';
import { outcomeFromLegacy } from '../../model/PredictionOutcome';
import {
  EMPTY_FIELD,
  formatConfidence,
  formatExportTime,
  hitLabel,
  inlineText,
  predictionStatusLabel
} from '../MarkdownText';

/** Renders the prediction section; returns an empty string when there is nothing to export. */
export function renderPredictionSection(predictions: Prediction[]): string {
  if (predictions.length === 0) {
    return '';
  }
  const lines: string[] = ['## 预测', ''];
  for (const prediction of predictions) {
    const stored = prediction.outcome ?? '';
    const outcome = stored.length > 0 ? stored : outcomeFromLegacy(prediction.hit);
    lines.push(`### ${inlineText(prediction.target)}`);
    lines.push('');
    lines.push(`- 判断：${inlineText(prediction.judgment)}`);
    lines.push(`- 置信度：${formatConfidence(prediction.confidence)}`);
    lines.push(`- 结算日：${inlineText(prediction.settlementDate)}`);
    lines.push(`- 状态：${predictionStatusLabel(prediction.status)}`);
    lines.push(`- 结算结果：${hitLabel(outcome)}`);
    lines.push(`- 实际结果：${inlineText(prediction.actualResult)}`);
    lines.push(`- 理由：${inlineText(prediction.reason)}`);
    lines.push(`- 创建时间：${formatExportTime(prediction.createdAt)}`);
    lines.push(`- 版本：v${prediction.version}`);
    if ((prediction.scope ?? '').length > 0) {
      lines.push(`- 适用范围：${inlineText(prediction.scope ?? '')}`);
    }
    if ((prediction.falsification ?? '').length > 0) {
      lines.push(`- 失效条件：${inlineText(prediction.falsification ?? '')}`);
    }
    if ((prediction.unknowns ?? '').length > 0) {
      lines.push(`- 未知项：${inlineText(prediction.unknowns ?? '')}`);
    }
    if ((prediction.evidenceLevel ?? '').length > 0) {
      lines.push(`- 证据来源：${inlineText(prediction.evidenceLevel ?? '')}`);
    }
    if ((prediction.revisionReason ?? '').length > 0) {
      lines.push(`- 修订原因：${inlineText(prediction.revisionReason ?? '')}`);
    }
    if ((prediction.invalidated ?? '').length > 0) {
      lines.push(`- 取消：${inlineText(prediction.invalidated ?? '')}`);
    }
    if ((prediction.preserved ?? '').length > 0) {
      lines.push(`- 保存：${inlineText(prediction.preserved ?? '')}`);
    }
    if ((prediction.repositioned ?? '').length > 0) {
      lines.push(`- 重新定位：${inlineText(prediction.repositioned ?? '')}`);
    }
    if ((prediction.missing ?? '').length > 0) {
      lines.push(`- 失效来源：${inlineText(prediction.missing ?? '')}`);
    }
    if ((prediction.explanatoryGain ?? '').length > 0) {
      lines.push(`- 新增解释力：${inlineText(prediction.explanatoryGain ?? '')}`);
    }
    lines.push('');
  }
  return lines.join('\n').trim();
}
