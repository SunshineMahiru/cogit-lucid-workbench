import { CitationScope, InteractionLog, InteractionSource } from '../model/Relation';

/** Options in display order; observation stays first because it is the default. */
export const SOURCE_OPTIONS: InteractionSource[] = ['observation', 'stated', 'joint', 'inference'];

/** Options for how far an entry may travel. */
export const CITATION_OPTIONS: CitationScope[] = ['hidden', 'paraphrase', 'quote'];

/** Label of one source. */
export function sourceText(source: InteractionSource): string {
  if (source === 'stated') {
    return '对方明确陈述';
  }
  if (source === 'joint') {
    return '共同实践';
  }
  if (source === 'inference') {
    return '我的推测';
  }
  return '我的观察';
}

/** Normalizes a stored source; anything unknown reads as the author's observation. */
export function toInteractionSource(value: string): InteractionSource {
  if (value === 'stated' || value === 'joint' || value === 'inference') {
    return value;
  }
  return 'observation';
}

/** Label of one citation scope. */
export function citationText(scope: CitationScope): string {
  if (scope === 'quote') {
    return '可原文引用';
  }
  if (scope === 'paraphrase') {
    return '可转述';
  }
  return '仅本机';
}

/** Normalizes a stored citation scope; anything unknown reads as hidden. */
export function toCitationScope(value: string): CitationScope {
  if (value === 'quote' || value === 'paraphrase') {
    return value;
  }
  return 'hidden';
}

/** Restores the defaults of one entry: observation, hidden, kept out of model requests. */
export function normalizeInteractionLog(log: InteractionLog): InteractionLog {
  return {
    timestamp: log.timestamp,
    content: log.content,
    source: toInteractionSource(log.source ?? ''),
    citation: toCitationScope(log.citation ?? ''),
    allowContext: log.allowContext === true
  };
}

/** Reports whether the entry is something the other person said. */
export function isOtherStatement(log: InteractionLog): boolean {
  return toInteractionSource(log.source ?? '') === 'stated';
}

/** Statements stay out of export files until the author raises their citation scope. */
export function visibleInExport(log: InteractionLog): boolean {
  if (!isOtherStatement(log)) {
    return true;
  }
  return toCitationScope(log.citation ?? '') !== 'hidden';
}

/** Only entries explicitly allowed may enter a model request. */
export function allowedInContext(log: InteractionLog): boolean {
  return log.allowContext === true;
}
