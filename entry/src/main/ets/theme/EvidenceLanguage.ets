import { AppTheme } from './AppTheme';
import { EvidenceSource, EvidenceEffect } from '../model/EvidenceItem';

export interface EvidenceStyle {
  label: string;
  color: string;
  surface: string;
}

export function evidenceStyle(source: EvidenceSource): EvidenceStyle {
  switch (source) {
    case 'practice':
      return { label: '现场与行动', color: AppTheme.color.evPractice, surface: AppTheme.color.evPracticeSurface };
    case 'other_person':
      return { label: '他者叙述', color: AppTheme.color.evOther, surface: AppTheme.color.evOtherSurface };
    case 'body':
      return { label: '身体反馈', color: AppTheme.color.evBody, surface: AppTheme.color.evBodySurface };
    case 'time':
      return { label: '长期结果', color: AppTheme.color.evTime, surface: AppTheme.color.evTimeSurface };
    case 'book':
      return { label: '书本理论', color: AppTheme.color.evBook, surface: AppTheme.color.evBookSurface };
    default:
      return { label: '公共资料', color: AppTheme.color.evPublic, surface: AppTheme.color.evPublicSurface };
  }
}

export function effectLabel(effect: EvidenceEffect): string {
  switch (effect) {
    case 'supports':
      return '支持';
    case 'challenges':
      return '挑战';
    default:
      return '未明';
  }
}