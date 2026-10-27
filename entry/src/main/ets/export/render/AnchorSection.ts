import { Anchor } from '../../model/Anchor';
import { inlineText } from '../MarkdownText';

/** Renders the read-only anchor list; returns an empty string when there is nothing to export. */
export function renderAnchorSection(anchors: Anchor[]): string {
  if (anchors.length === 0) {
    return '';
  }
  const lines: string[] = ['## 价值锚点', ''];
  let index = 0;
  for (const anchor of anchors) {
    index += 1;
    const text = inlineText(anchor.text);
    const source = anchor.source.trim();
    lines.push(source.length > 0 ? `${index}. ${text} —— ${source}` : `${index}. ${text}`);
  }
  return lines.join('\n');
}
