import { Prediction } from '../../model/Prediction';
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
    lines.push(`### ${inlineText(prediction.target)}`);
    lines.push('');
    lines.push(`- 判断：${inlineText(prediction.judgment)}`);
    lines.push(`- 置信度：${formatConfidence(prediction.confidence)}`);
    lines.push(`- 结算日：${inlineText(prediction.settlementDate)}`);
    lines.push(`- 状态：${predictionStatusLabel(prediction.status)}`);
    lines.push(`- 命中：${hitLabel(prediction.hit)}`);
    lines.push(`- 实际结果：${inlineText(prediction.actualResult)}`);
    lines.push(`- 理由：${inlineText(prediction.reason)}`);
    lines.push(`- 创建时间：${formatExportTime(prediction.createdAt)}`);
    lines.push(`- 版本：v${prediction.version}`);
    lines.push('');
  }
  return lines.join('\n').trim();
}
