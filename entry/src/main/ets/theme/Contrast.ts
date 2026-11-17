/** Contrast helpers for text drawn over a page that may carry a background image. */

/** Minimum ratio for body text under WCAG AA. */
export const MIN_BODY_CONTRAST = 4.5;

/** Body text ratio the platform dark theme targets. */
export const DARK_BODY_CONTRAST = 5.0;

/** Parses #RRGGBB or #AARRGGBB into red, green, blue and alpha channels. */
function channels(hex: string): number[] {
  const body = hex.startsWith('#') ? hex.substring(1) : hex;
  const rgb = body.length === 8 ? body.substring(2) : body;
  const alphaHex = body.length === 8 ? body.substring(0, 2) : 'FF';
  if (rgb.length < 6) {
    return [0, 0, 0, 255];
  }
  const red = parseInt(rgb.substring(0, 2), 16);
  const green = parseInt(rgb.substring(2, 4), 16);
  const blue = parseInt(rgb.substring(4, 6), 16);
  if (Number.isNaN(red) || Number.isNaN(green) || Number.isNaN(blue)) {
    return [0, 0, 0, 255];
  }
  const alpha = parseInt(alphaHex, 16);
  return [red, green, blue, Number.isNaN(alpha) ? 255 : alpha];
}

/** Formats three channels as a six-digit #RRGGBB string. */
function toHex(red: number, green: number, blue: number): string {
  const parts: string[] = [];
  for (const value of [red, green, blue]) {
    const text = value.toString(16).toUpperCase();
    parts.push(text.length === 1 ? `0${text}` : text);
  }
  return `#${parts[0]}${parts[1]}${parts[2]}`;
}

/** Relative luminance of one colour, per WCAG 2.1; alpha is ignored. */
export function relativeLuminance(hex: string): number {
  const rgb = channels(hex);
  const linear: number[] = [];
  for (let index = 0; index < 3; index += 1) {
    const channel = rgb[index] / 255;
    linear.push(channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4));
  }
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

/** Contrast ratio between two opaque colours. */
export function contrastRatio(foreground: string, background: string): number {
  const first = relativeLuminance(foreground);
  const second = relativeLuminance(background);
  const lighter = Math.max(first, second);
  const darker = Math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

/** Blends the page colour over a solid image colour at the given alpha. */
export function compositeOver(pageHex: string, imageHex: string, alpha: number): string {
  const clamped = Math.min(1, Math.max(0, alpha));
  const page = channels(pageHex);
  const image = channels(imageHex);
  const parts: string[] = [];
  for (let index = 0; index < 3; index += 1) {
    const value = Math.round(page[index] * clamped + image[index] * (1 - clamped));
    const text = value.toString(16).toUpperCase();
    parts.push(text.length === 1 ? `0${text}` : text);
  }
  return `#${parts[0]}${parts[1]}${parts[2]}`;
}

/** Flattens a translucent text colour onto an opaque background before measuring it. */
export function compositeText(textHex: string, backgroundHex: string): string {
  const text = channels(textHex);
  const alpha = text[3] / 255;
  if (alpha >= 1) {
    return toHex(text[0], text[1], text[2]);
  }
  return compositeOver(textHex, backgroundHex, alpha);
}

/** Worst-case ratio over a pure black and a pure white image; pageWeight is 1 minus image strength. */
export function worstCaseContrastRatio(textHex: string, pageHex: string, pageWeight: number): number {
  const onBlackBackground = compositeOver(pageHex, '#000000', pageWeight);
  const onWhiteBackground = compositeOver(pageHex, '#FFFFFF', pageWeight);
  const onBlack = contrastRatio(compositeText(textHex, onBlackBackground), onBlackBackground);
  const onWhite = contrastRatio(compositeText(textHex, onWhiteBackground), onWhiteBackground);
  return Math.round(Math.min(onBlack, onWhite) * 10) / 10;
}

/** One line the page can show next to the opacity slider. */
export function contrastHint(
  textHex: string,
  pageHex: string,
  pageWeight: number,
  threshold: number = MIN_BODY_CONTRAST
): string {
  const ratio = worstCaseContrastRatio(textHex, pageHex, pageWeight);
  if (ratio >= threshold) {
    return `正文对比度最低 ${ratio}:1，满足 ${threshold}:1，任意图片下都可读`;
  }
  return `正文对比度最低 ${ratio}:1，低于 ${threshold}:1，建议调淡图片或换纯色底`;
}