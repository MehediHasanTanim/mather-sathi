// Pure metrics for the eval harness (tools/eval). Kept under functions/src so the harness and its tests
// share the exact types and price table the Function uses; nothing here is imported by the deployed functions.
import { priceFor } from "./lib/modelCaps";
import type { Confidence, Usage } from "./lib/types";

export interface EvalRecord {
  file: string;
  crop: string;
  expected: string;
  predicted?: string;
  confidence?: Confidence;
  latencyMs: number;
  usage?: Usage;
  error?: string;
}

export interface Report {
  meta: { model: string; kbSeq: number; kbVersion: string; generatedAt: string; images: number; errors: number };
  overall: { n: number; correct: number; top1: number };
  perCrop: Record<string, { n: number; correct: number; top1: number }>;
  perDisease: Record<string, { n: number; correct: number; top1: number }>;
  /** confusion[crop][expected][predicted] = count */
  confusion: Record<string, Record<string, Record<string, number>>>;
  /** Observed accuracy per reported confidence bucket: what the "high" label is actually worth. */
  calibration: Record<Confidence, { n: number; correct: number; accuracy: number | null }>;
  rates: { unknown: number; healthy: number };
  latencyMs: { mean: number; p50: number; p95: number };
  cost: { inputTokens: number; outputTokens: number; perCallUsd: number | null; totalUsd: number | null };
}

const ratio = (a: number, b: number) => (b === 0 ? 0 : a / b);

/** Nearest-rank percentile of an unsorted list. */
export function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1))];
}

export function buildReport(
  records: EvalRecord[],
  meta: { model: string; kbSeq: number; kbVersion: string; generatedAt?: string },
): Report {
  const ok = records.filter((r) => !r.error && r.predicted !== undefined);
  const hit = (r: EvalRecord) => r.predicted === r.expected;

  const group = (key: (r: EvalRecord) => string) => {
    const out: Record<string, { n: number; correct: number; top1: number }> = {};
    for (const r of ok) {
      const g = (out[key(r)] ??= { n: 0, correct: 0, top1: 0 });
      g.n++;
      if (hit(r)) g.correct++;
    }
    for (const g of Object.values(out)) g.top1 = ratio(g.correct, g.n);
    return out;
  };

  const confusion: Report["confusion"] = {};
  for (const r of ok) {
    const row = ((confusion[r.crop] ??= {})[r.expected] ??= {});
    row[r.predicted!] = (row[r.predicted!] ?? 0) + 1;
  }

  const calibration = {} as Report["calibration"];
  for (const b of ["high", "medium", "low"] as Confidence[]) {
    const inB = ok.filter((r) => r.confidence === b);
    const correct = inB.filter(hit).length;
    calibration[b] = { n: inB.length, correct, accuracy: inB.length ? correct / inB.length : null };
  }

  const lat = ok.map((r) => r.latencyMs);
  const inTok = ok.reduce((s, r) => s + (r.usage?.input_tokens ?? 0), 0);
  const outTok = ok.reduce((s, r) => s + (r.usage?.output_tokens ?? 0), 0);
  const price = priceFor(meta.model);
  const total = price ? (inTok * price[0] + outTok * price[1]) / 1e6 : null;
  const correct = ok.filter(hit).length;

  return {
    meta: {
      ...meta, generatedAt: meta.generatedAt ?? new Date().toISOString(),
      images: records.length, errors: records.length - ok.length,
    },
    overall: { n: ok.length, correct, top1: ratio(correct, ok.length) },
    perCrop: group((r) => r.crop),
    perDisease: group((r) => `${r.crop}/${r.expected}`),
    confusion,
    calibration,
    rates: {
      unknown: ratio(ok.filter((r) => r.predicted === "unknown").length, ok.length),
      healthy: ratio(ok.filter((r) => r.predicted === "healthy").length, ok.length),
    },
    latencyMs: { mean: lat.length ? lat.reduce((a, b) => a + b, 0) / lat.length : 0, p50: percentile(lat, 50), p95: percentile(lat, 95) },
    cost: { inputTokens: inTok, outputTokens: outTok, perCallUsd: total === null ? null : ratio(total, ok.length), totalUsd: total },
  };
}
