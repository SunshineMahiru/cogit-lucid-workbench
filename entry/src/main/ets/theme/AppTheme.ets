import { common } from '@kit.AbilityKit';

/** Semantic colour set shared by pages and components. */
export interface ThemePalette {
  page: ResourceColor;
  surface: ResourceColor;
  primary: string;
  primaryDeep: string;
  text: ResourceColor;
  textStrong: ResourceColor;
  textSecondary: ResourceColor;
  textSecondaryStrong: ResourceColor;
  textMuted: ResourceColor;
  border: ResourceColor;
  borderStrong: ResourceColor;
  borderSelected: string;
  tint: ResourceColor;
  surfaceAlt: ResourceColor;
  surfaceTint: ResourceColor;
  surfaceWarm: string;
  selectedSurface: ResourceColor;
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
  heatEmpty: string;
  heatLow: string;
  heatMid: string;
  heatHigh: string;
  evPractice: string;
  evPracticeSurface: string;
  evOther: string;
  evOtherSurface: string;
  evBody: string;
  evBodySurface: string;
  evTime: string;
  evTimeSurface: string;
  evBook: string;
  evBookSurface: string;
  evPublic: string;
  evPublicSurface: string;
}

/** Colour fields that stay on the app palette and follow applyTheme. */
interface RetainedPalette {
  primary: string;
  primaryDeep: string;
  borderSelected: string;
  surfaceWarm: string;
  primaryDisabled: string;
  accentPurple: string;
  accentGold: string;
  warning: string;
  warningSurface: string;
  success: string;
  successSurface: string;
  danger: string;
  dangerSurface: string;
  heatEmpty: string;
  heatLow: string;
  heatMid: string;
  heatHigh: string;
  evPractice: string;
  evPracticeSurface: string;
  evOther: string;
  evOtherSurface: string;
  evBody: string;
  evBodySurface: string;
  evTime: string;
  evTimeSurface: string;
  evBook: string;
  evBookSurface: string;
  evPublic: string;
  evPublicSurface: string;
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

/** Spacing scale, in vp, plus semantic aliases onto the same steps. */
export interface SpacingTokens {
  s2: number;
  s4: number;
  s6: number;
  s8: number;
  s10: number;
  s12: number;
  s16: number;
  s20: number;
  s24: number;
  page: number;
  card: number;
  section: number;
  gap: number;
}

/** Type scale, resolved from system fp resources. */
export interface FontTokens {
  caption: Resource;
  body: Resource;
  bodyStrong: Resource;
  subtitle: Resource;
  title: Resource;
  headline: Resource;
  display: Resource;
}

/** Font weights paired one-to-one with the type scale. */
export interface FontWeightTokens {
  caption: FontWeight;
  body: FontWeight;
  bodyStrong: FontWeight;
  subtitle: FontWeight;
  title: FontWeight;
  headline: FontWeight;
  display: FontWeight;
}

/** Absolute line heights in vp, paired one-to-one with the type scale. */
export interface LineHeightTokens {
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
  primary: '#4A6FA5',
  primaryDeep: '#185FA5',
  borderSelected: '#B7CDE8',
  surfaceWarm: '#FFFDF5',
  primaryDisabled: '#8FA6C4',
  accentPurple: '#6B5B95',
  accentGold: '#E8A93C',
  warning: '#B0761E',
  warningSurface: '#FFF4E0',
  success: '#2E7D32',
  successSurface: '#E8F5E9',
  danger: '#A32D2D',
  dangerSurface: '#FCEBEB',
  heatEmpty: '#EDEBE4',
  heatLow: '#B7D3E8',
  heatMid: '#6FA8CC',
  heatHigh: '#2E6F9E',
  evPractice: '#2E6F9E',
  evPracticeSurface: '#E8F1F8',
  evOther: '#6B5B95',
  evOtherSurface: '#EFECF6',
  evBody: '#B0563B',
  evBodySurface: '#F8ECE7',
  evTime: '#4C7A3F',
  evTimeSurface: '#ECF3E9',
  evBook: '#8A6D3B',
  evBookSurface: '#F5EFE3',
  evPublic: '#5B7083',
  evPublicSurface: '#ECEFF2'
};

const DARK: RetainedPalette = {
  primary: '#8FB4E3',
  primaryDeep: '#B8D3F0',
  borderSelected: '#4F6F91',
  surfaceWarm: '#2A2418',
  primaryDisabled: '#586574',
  accentPurple: '#A99BD2',
  accentGold: '#D8B25E',
  warning: '#E0A85C',
  warningSurface: '#3A2C18',
  success: '#78C98A',
  successSurface: '#1E3424',
  danger: '#F08A8A',
  dangerSurface: '#3E2020',
  heatEmpty: '#23272C',
  heatLow: '#1F3A52',
  heatMid: '#2E6F9E',
  heatHigh: '#6FA8CC',
  evPractice: '#8FB4E3',
  evPracticeSurface: '#1F3A52',
  evOther: '#A99BD2',
  evOtherSurface: '#2A2438',
  evBody: '#E09A85',
  evBodySurface: '#3A241C',
  evTime: '#78C98A',
  evTimeSurface: '#1E3424',
  evBook: '#D8B25E',
  evBookSurface: '#3A2C18',
  evPublic: '#A9BAC9',
  evPublicSurface: '#23272C'
};

const RADIUS: RadiusTokens = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 28
};

const S2: number = 2;
const S4: number = 4;
const S6: number = 6;
const S8: number = 8;
const S10: number = 10;
const S12: number = 12;
const S16: number = 16;
const S20: number = 20;
const S24: number = 24;

const SPACING: SpacingTokens = {
  s2: S2,
  s4: S4,
  s6: S6,
  s8: S8,
  s10: S10,
  s12: S12,
  s16: S16,
  s20: S20,
  s24: S24,
  page: S16,
  card: S16,
  section: S12,
  gap: S8
};

const FONT: FontTokens = {
  caption: $r('sys.float.Caption_L'),
  body: $r('sys.float.Body_M'),
  bodyStrong: $r('sys.float.Body_L'),
  subtitle: $r('sys.float.Subtitle_L'),
  title: $r('sys.float.Title_S'),
  headline: $r('sys.float.Title_M'),
  display: $r('sys.float.Display_S')
};

export const FONT_WEIGHT: FontWeightTokens = {
  caption: FontWeight.Medium,
  body: FontWeight.Regular,
  bodyStrong: FontWeight.Medium,
  subtitle: FontWeight.Medium,
  title: FontWeight.Bold,
  headline: FontWeight.Bold,
  display: FontWeight.Lighter
};

/**
 * Absolute line heights in vp. Caption through title are the font size times 1.5 rounded up to
 * the next even number, headline times 1.42, display times 1.26. The platform only ships
 * incremental line-space tokens (ohos_id_text_line_space_s 1.1vp, _l 1.4vp), so these stay local.
 */
export const LINE_HEIGHT: LineHeightTokens = {
  caption: 18,
  body: 22,
  bodyStrong: 24,
  subtitle: 28,
  title: 30,
  headline: 34,
  display: 48
};

/** Formats a 32-bit ARGB value as a six-digit #RRGGBB string, dropping alpha. */
function argbToHex(value: number): string {
  let text = (value >>> 0).toString(16).toUpperCase();
  while (text.length < 8) {
    text = `0${text}`;
  }
  return `#${text.substring(2)}`;
}

/**
 * Resolves a palette colour to a six-digit #RRGGBB string for Canvas strokes and alpha blending.
 * Returns an empty string when the context is absent or the resource cannot be resolved; callers
 * own the fallback.
 */
export function resolveColorHex(color: ResourceColor, context: common.Context | undefined | null): string {
  if (typeof color === 'string') {
    const body = color.startsWith('#') ? color.substring(1) : color;
    const rgb = body.length === 8 ? body.substring(2) : body;
    return rgb.length === 6 ? `#${rgb.toUpperCase()}` : '';
  }
  if (typeof color === 'number') {
    return argbToHex(color);
  }
  if (context === undefined || context === null) {
    return '';
  }
  try {
    return argbToHex(context.resourceManager.getColorSync(color.id));
  } catch (error) {
    return '';
  }
}

/** Builds the palette once; system-backed fields stay fixed, retained fields follow applyTheme. */
function createColor(): ThemePalette {
  return {
    page: $r('sys.color.background_primary'),
    surface: $r('sys.color.comp_background_list_card'),
    primary: LIGHT.primary,
    primaryDeep: LIGHT.primaryDeep,
    text: $r('sys.color.font_primary'),
    textStrong: $r('sys.color.font_primary'),
    textSecondary: $r('sys.color.font_secondary'),
    textSecondaryStrong: $r('sys.color.font_secondary'),
    textMuted: $r('sys.color.font_tertiary'),
    border: $r('sys.color.comp_divider'),
    borderStrong: $r('sys.color.comp_outline_color'),
    borderSelected: LIGHT.borderSelected,
    tint: $r('sys.color.comp_background_secondary'),
    surfaceAlt: $r('sys.color.comp_background_gray'),
    surfaceTint: $r('sys.color.comp_background_tertiary'),
    surfaceWarm: LIGHT.surfaceWarm,
    selectedSurface: $r('sys.color.interactive_select'),
    chip: $r('sys.color.comp_background_secondary'),
    track: $r('sys.color.comp_background_gray'),
    primaryDisabled: LIGHT.primaryDisabled,
    accentPurple: LIGHT.accentPurple,
    accentGold: LIGHT.accentGold,
    warning: LIGHT.warning,
    warningSurface: LIGHT.warningSurface,
    success: LIGHT.success,
    successSurface: LIGHT.successSurface,
    danger: LIGHT.danger,
    heatEmpty: LIGHT.heatEmpty,
    heatLow: LIGHT.heatLow,
    heatMid: LIGHT.heatMid,
    heatHigh: LIGHT.heatHigh,
    evPractice: LIGHT.evPractice,
    evPracticeSurface: LIGHT.evPracticeSurface,
    evOther: LIGHT.evOther,
    evOtherSurface: LIGHT.evOtherSurface,
    evBody: LIGHT.evBody,
    evBodySurface: LIGHT.evBodySurface,
    evTime: LIGHT.evTime,
    evTimeSurface: LIGHT.evTimeSurface,
    evBook: LIGHT.evBook,
    evBookSurface: LIGHT.evBookSurface,
    evPublic: LIGHT.evPublic,
    evPublicSurface: LIGHT.evPublicSurface,
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
  target.primary = source.primary;
  target.primaryDeep = source.primaryDeep;
  target.borderSelected = source.borderSelected;
  target.surfaceWarm = source.surfaceWarm;
  target.primaryDisabled = source.primaryDisabled;
  target.accentPurple = source.accentPurple;
  target.accentGold = source.accentGold;
  target.warning = source.warning;
  target.warningSurface = source.warningSurface;
  target.success = source.success;
  target.successSurface = source.successSurface;
  target.danger = source.danger;
  target.dangerSurface = source.dangerSurface;
  target.heatEmpty = source.heatEmpty;
  target.heatLow = source.heatLow;
  target.heatMid = source.heatMid;
  target.heatHigh = source.heatHigh;
  target.evPractice = source.evPractice;
  target.evPracticeSurface = source.evPracticeSurface;
  target.evOther = source.evOther;
  target.evOtherSurface = source.evOtherSurface;
  target.evBody = source.evBody;
  target.evBodySurface = source.evBodySurface;
  target.evTime = source.evTime;
  target.evTimeSurface = source.evTimeSurface;
  target.evBook = source.evBook;
  target.evBookSurface = source.evBookSurface;
  target.evPublic = source.evPublic;
  target.evPublicSurface = source.evPublicSurface;
}