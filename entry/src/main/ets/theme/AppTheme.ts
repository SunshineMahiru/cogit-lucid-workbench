/** Design tokens shared by new pages; existing pages migrate later. */
export const AppTheme = {
  color: {
    page: '#F5F6F8',
    surface: '#FFFFFF',
    primary: '#4A6FA5',
    primaryDeep: '#185FA5',
    text: '#1F2329',
    textStrong: '#444441',
    textSecondary: '#8A8F99',
    textSecondaryStrong: '#5F5E5A',
    textMuted: '#B0B4BE',
    border: '#E0E0E0',
    borderStrong: '#D3D1C7',
    borderSelected: '#B7CDE8',
    tint: '#E8EFF7',
    surfaceAlt: '#F7F6F2',
    surfaceTint: '#F7F9FC',
    surfaceWarm: '#FFFDF5',
    selectedSurface: '#F3F7FC',
    chip: '#F1EFE8',
    track: '#EEF0F3',
    primaryDisabled: '#8FA6C4',
    accentPurple: '#6B5B95',
    accentGold: '#E8A93C',
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
