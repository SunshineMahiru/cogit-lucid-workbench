/** Design tokens shared by new pages; existing pages migrate later. */
export const AppTheme = {
  color: {
    page: '#F5F6F8',
    surface: '#FFFFFF',
    primary: '#4A6FA5',
    primaryDeep: '#185FA5',
    text: '#1F2329',
    textSecondary: '#8A8F99',
    textMuted: '#B0B4BE',
    border: '#E0E0E0',
    tint: '#E8EFF7',
    warning: '#B0761E',
    warningSurface: '#FFF4E0',
    success: '#2E7D32',
    successSurface: '#E8F5E9',
    danger: '#A32D2D',
    dangerSurface: '#FCEBEB'
  },
  radius: {
    card: 12,
    tag: 8,
    button: 12
  },
  spacing: {
    page: 16,
    card: 14,
    section: 12,
    gap: 8
  }
} as const;
