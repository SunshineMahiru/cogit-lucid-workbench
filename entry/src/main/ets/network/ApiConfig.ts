/**
 * Base URL for the local mock server.
 * Emulator and Previewer use localhost with hdc rport; a real device falls back to the host LAN address.
 */
export const API_BASE_URL = 'http://localhost:4523';

/** Host-LAN fallback used when the device is not the emulator. */
export const API_FALLBACK_BASE_URL = 'http://10.111.10.55:4523';

/** Request timeout in milliseconds. */
export const API_TIMEOUT_MS = 5000;

/** Builds the review prompt endpoint for one base URL. */
export function reviewPromptsUrlForBase(baseUrl: string, period: string): string {
  const base = baseUrl.endsWith('/') ? baseUrl.slice(0, baseUrl.length - 1) : baseUrl;
  return `${base}/review-prompts?period=${encodeURIComponent(period)}`;
}

/** Builds the review prompt endpoint for the default local mock server. */
export function reviewPromptsUrl(period: string): string {
  return reviewPromptsUrlForBase(API_BASE_URL, period);
}

/** Candidate endpoints, in priority order; the repository tries each one. */
export function reviewPromptsUrls(period: string): string[] {
  return [
    reviewPromptsUrlForBase(API_BASE_URL, period),
    reviewPromptsUrlForBase(API_FALLBACK_BASE_URL, period)
  ];
}
