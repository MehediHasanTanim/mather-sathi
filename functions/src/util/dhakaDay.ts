/** Day key (YYYY-MM-DD) in Asia/Dhaka (UTC+6, no DST), used for per-install daily quotas. */
export function dhakaDayKey(nowMs: number = Date.now()): string {
  return new Date(nowMs + 6 * 3600_000).toISOString().slice(0, 10);
}
