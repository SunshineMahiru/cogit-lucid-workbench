/** Semantic design tokens shared by pages and components. */
export interface ThemePalette {
  page: string;
  surface: string;
  primary: string;
  primaryDeep: string;
  text: string;
  textStrong: string;
  textSecondary: string;
  textSecondaryStrong: string;
  textMuted: string;
  border: string;
  borderStrong: string;
  borderSelected: string;
  tint: string;
  surfaceAlt: string;
  surfaceTint: string;
  surfaceWarm: string;
  selectedSurface: string;
  chip: string;
  track: string;
  primaryDisabled: string;
  accentPurple: string;
  accentGold: string;
  warning: string;
  warningSurface: string;
  success: string;
  successSurface: string;
  danger: string;
  dangerSurface: string;
}

const LIGHT: ThemePalette = {
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
};

const DARK: ThemePalette = {
  page: '#121417',
  surface: '#1B1F24',
  primary: '#8FB4E3',
  primaryDeep: '#B8D3F0',
  text: '#E8EAED',
  textStrong: '#D5D8DC',
  textSecondary: '#A8AFB8',
  textSecondaryStrong: '#C3C8CF',
  textMuted: '#7D858F',
  border: '#343A42',
  borderStrong: '#4A525C',
  borderSelected: '#4F6F91',
  tint: '#25384D',
  surfaceAlt: '#23272D',
  surfaceTint: '#1F242A',
  surfaceWarm: '#2A2418',
  selectedSurface: '#1E2B3A',
  chip: '#2C3036',
  track: '#30363D',
  primaryDisabled: '#586574',
  accentPurple: '#A99BD2',
  accentGold: '#D8B25E',
  warning: '#E0A85C',
  warningSurface: '#3A2C18',
  success: '#78C98A',
  successSurface: '#1E3424',
  danger: '#F08A8A',
  dangerSurface: '#3E2020'
};

export const AppTheme = {
  color: { ...LIGHT } as ThemePalette,
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
};

let darkMode: boolean = false;

/** True when the dark palette is active; pages use it for image strength and scrims. */
export function isDarkMode(): boolean {
  return darkMode;
}

/** Builds #AARRGGBB from a #RRGGBB token so a page surface can be made translucent. */
export function withAlpha(hex: string, alpha: number): string {
  const clamped = Math.min(1, Math.max(0, alpha));
  const channel = Math.round(clamped * 255).toString(16).toUpperCase();
  const prefix = channel.length === 1 ? `0${channel}` : channel;
  const body = hex.startsWith('#') ? hex.substring(1) : hex;
  return `#${prefix}${body}`;
}

/** Switches semantic colors before the page tree renders. */
export function applyTheme(dark: boolean): void {
  darkMode = dark;
  const source = dark ? DARK : LIGHT;
  const target = AppTheme.color;
  target.page = source.page;
  target.surface = source.surface;
  target.primary = source.primary;
  target.primaryDeep = source.primaryDeep;
  target.text = source.text;
  target.textStrong = source.textStrong;
  target.textSecondary = source.textSecondary;
  target.textSecondaryStrong = source.textSecondaryStrong;
  target.textMuted = source.textMuted;
  target.border = source.border;
  target.borderStrong = source.borderStrong;
  target.borderSelected = source.borderSelected;
  target.tint = source.tint;
  target.surfaceAlt = source.surfaceAlt;
  target.surfaceTint = source.surfaceTint;
  target.surfaceWarm = source.surfaceWarm;
  target.selectedSurface = source.selectedSurface;
  target.chip = source.chip;
  target.track = source.track;
  target.primaryDisabled = source.primaryDisabled;
  target.accentPurple = source.accentPurple;
  target.accentGold = source.accentGold;
  target.warning = source.warning;
  target.warningSurface = source.warningSurface;
  target.success = source.success;
  target.successSurface = source.successSurface;
  target.danger = source.danger;
  target.dangerSurface = source.dangerSurface;
}
