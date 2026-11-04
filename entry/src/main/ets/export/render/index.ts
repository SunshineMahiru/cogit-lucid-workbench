import { ExportBundle } from '../ExportBundle';
import { renderDocumentHeader } from './DocumentHeader';
import { renderEventSection } from './EventSection';
import { renderDecisionSection } from './DecisionSection';
import { renderRelationSection } from './RelationSection';
import { renderPredictionSection } from './PredictionSection';
import { renderAnchorSection } from './AnchorSection';
import { renderStatusSection } from './StatusSection';
import { renderReviewSection } from './ReviewSection';
import { renderPlanSection } from './PlanSection';

export {
  renderDocumentHeader,
  renderEventSection,
  renderDecisionSection,
  renderRelationSection,
  renderPredictionSection,
  renderAnchorSection,
  renderStatusSection,
  renderReviewSection
};

/** Renders the whole Markdown document from a prepared bundle; empty sections are skipped. */
export function renderExportDocument(bundle: ExportBundle): string {
  const sections: string[] = [
    renderDocumentHeader(bundle),
    renderEventSection(bundle.events),
    renderDecisionSection(bundle.decisions),
    renderRelationSection(bundle.relations),
    renderPredictionSection(bundle.predictions),
    renderAnchorSection(bundle.anchors),
    renderStatusSection(bundle.statusRecords),
    renderReviewSection(bundle.reviews, bundle.anchors),
    renderPlanSection(bundle.plans ?? [])
  ];
  const blocks: string[] = [];
  for (const section of sections) {
    const text = section.trim();
    if (text.length > 0) {
      blocks.push(text);
    }
  }
  return `${blocks.join('\n\n')}\n`;
}
