/** Semantic colour set shared by pages and components. */
export interface ThemePalette {
  page: string;
  surface: ResourceColor;
  primary: string;
  primaryDeep: string;
  text: ResourceColor;
  textStrong: string;
  textSecondary: ResourceColor;
  textSecondaryStrong: string;
  textMuted: ResourceColor;
  border: ResourceColor;
  borderStrong: string;
  borderSelected: string;
  tint: string;
  surfaceAlt: ResourceColor;
  surfaceTint: string;
  surfaceWarm: string;
  selectedSurface: string;
  chip: ResourceColor;
  track: ResourceColor;
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

/** Colour fields that stay on the app palette and follow applyTheme. */
interface RetainedPalette {
  page: string;
  primary: string;
  primaryDeep: string;
  textStrong: string;
  textSecondaryStrong: string;
  borderStrong: string;
  borderSelected: string;
  tint: string;
  surfaceTint: string;
  surfaceWarm: string;
  selectedSurface: string;
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

/** Corner radius tokens, in vp. */
export interface RadiusTokens {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
  xxl: number;
}

/** Spacing tokens, in vp. */
export interface SpacingTokens {
  page: number;
  card: number;
  section: number;
  gap: number;
}

/** Type scale, in fp. */
export interface FontTokens {
  caption: number;
  body: number;
  bodyStrong: number;
  subtitle: number;
  title: number;
  headline: number;
  display: number;
}

/** Token bundle shared by pages and components. */
export interface AppTokens {
  color: ThemePalette;
  radius: RadiusTokens;
  spacing: SpacingTokens;
  font: FontTokens;
}

const LIGHT: RetainedPalette = {
  page: '#F5F6F8',
  primary: '#4A6FA5',
  primaryDeep: '#185FA5',
  textStrong: '#444441',
  textSecondaryStrong: '#5F5E5A',
  borderStrong: '#D3D1C7',
  borderSelected: '#B7CDE8',
  tint: '#E8EFF7',
  surfaceTint: '#F7F9FC',
  surfaceWarm: '#FFFDF5',
  selectedSurface: '#F3F7FC',
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

const DARK: RetainedPalette = {
  page: '#121417',
  primary: '#8FB4E3',
  primaryDeep: '#B8D3F0',
  textStrong: '#D5D8DC',
  textSecondaryStrong: '#C3C8CF',
  borderStrong: '#4A525C',
  borderSelected: '#4F6F91',
  tint: '#25384D',
  surfaceTint: '#1F242A',
  surfaceWarm: '#2A2418',
  selectedSurface: '#1E2B3A',
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

const RADIUS: RadiusTokens = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 28
};

const SPACING: SpacingTokens = {
  page: 16,
  card: 14,
  section: 12,
  gap: 8
};

const FONT: FontTokens = {
  caption: 10,
  body: 11,
  bodyStrong: 12,
  subtitle: 14,
  title: 16,
  headline: 20,
  display: 28
};

/** Builds the palette once; mapped fields resolve through system resources. */
function createColor(): ThemePalette {
  return {
    page: LIGHT.page,
    surface: $r('sys.color.ohos_id_color_card_bg'),
    primary: LIGHT.primary,
    primaryDeep: LIGHT.primaryDeep,
    text: $r('sys.color.ohos_id_color_text_primary'),
    textStrong: LIGHT.textStrong,
    textSecondary: $r('sys.color.ohos_id_color_text_secondary'),
    textSecondaryStrong: LIGHT.textSecondaryStrong,
    textMuted: $r('sys.color.ohos_id_color_text_tertiary'),
    border: $r('sys.color.ohos_id_color_list_separator'),
    borderStrong: LIGHT.borderStrong,
    borderSelected: LIGHT.borderSelected,
    tint: LIGHT.tint,
    surfaceAlt: $r('sys.color.ohos_id_color_sub_background'),
    surfaceTint: LIGHT.surfaceTint,
    surfaceWarm: LIGHT.surfaceWarm,
    selectedSurface: LIGHT.selectedSurface,
    chip: $r('sys.color.ohos_id_color_button_normal'),
    track: $r('sys.color.ohos_id_color_button_normal'),
    primaryDisabled: LIGHT.primaryDisabled,
    accentPurple: LIGHT.accentPurple,
    accentGold: LIGHT.accentGold,
    warning: LIGHT.warning,
    warningSurface: LIGHT.warningSurface,
    success: LIGHT.success,
    successSurface: LIGHT.successSurface,
    danger: LIGHT.danger,
    dangerSurface: LIGHT.dangerSurface
  };
}

export const AppTheme: AppTokens = {
  color: createColor(),
  radius: RADIUS,
  spacing: SPACING,
  font: FONT
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
  const prefix: string = channel.length === 1 ? `0${channel}` : channel;
  const body: string = hex.startsWith('#') ? hex.substring(1) : hex;
  return `#${prefix}${body}`;
}

/** Glyph size for the initial inside an avatar of the given diameter. */
export function avatarGlyphSize(size: number): number {
  return Math.round(size / 2.6);
}

/** Switches the retained colours before the page tree renders. */
export function applyTheme(dark: boolean): void {
  darkMode = dark;
  const source: RetainedPalette = dark ? DARK : LIGHT;
  const target: ThemePalette = AppTheme.color;
  target.page = source.page;
  target.primary = source.primary;
  target.primaryDeep = source.primaryDeep;
  target.textStrong = source.textStrong;
  target.textSecondaryStrong = source.textSecondaryStrong;
  target.borderStrong = source.borderStrong;
  target.borderSelected = source.borderSelected;
  target.tint = source.tint;
  target.surfaceTint = source.surfaceTint;
  target.surfaceWarm = source.surfaceWarm;
  target.selectedSurface = source.selectedSurface;
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