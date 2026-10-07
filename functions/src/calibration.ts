// Pure calibration logic for task 9.1 (used by tools/eval/calibrate.ts; not imported by the deployed functions).
// Turns eval results into Remote Config values and a per-crop launch verdict. It only recommends: the agronomist and the
// team agree the bar, and a crop that misses it is dropped or labelled beta, never given a lower bar.
import type { Report } from "./evalMetrics";

export interface Bar {
  /** Overall and per-crop top-1 needed to launch a crop. Draft agreed in the plan: 0.80. */
  top1: number;
  /** Accuracy the "high" bucket must reach. */
  highBucket: number;
  /** Accuracy the "medium" bucket must reach. */
  mediumBucket: number;
  /** Fewest labelled photos per crop (and per bucket) before a number is trusted. */
  minSupport: number;
}
export const DRAFT_BAR: Bar = { top1: 0.8, highBucket: 0.9, mediumBucket: 0.7, minSupport: 30 };

// ---------- launch verdict per crop ----------

export type Verdict = "launch" | "beta" | "drop" | "insufficient_data";
export interface CropVerdict { crop: string; n: number; top1: number; verdict: Verdict; reason: string }

/** beta = within 10 points of the bar. Anything lower is dropped from the launch list rather than shipped with a lower bar. */
export function cropVerdicts(report: Report, bar: Bar = DRAFT_BAR): CropVerdict[] {
  return Object.entries(report.perCrop)
    .map(([crop, g]): CropVerdict => {
      if (g.n < bar.minSupport) return { crop, n: g.n, top1: g.top1, verdict: "insufficient_data", reason: `only ${g.n} photos (need ${bar.minSupport})` };
      if (g.top1 >= bar.top1) return { crop, n: g.n, top1: g.top1, verdict: "launch", reason: "meets the bar" };
      if (g.top1 >= bar.top1 - 0.1) return { crop, n: g.n, top1: g.top1, verdict: "beta", reason: "within 10 points of the bar: label as beta" };
      return { crop, n: g.n, top1: g.top1, verdict: "drop", reason: "well below the bar: remove from the launch list" };
    })
    .sort((a, b) => a.crop.localeCompare(b.crop));
}

export interface BucketCheck { ok: boolean; problems: string[] }

/** The "high" label has to mean something: reaches its bar, and is clearly better than "medium". "low" always shows the expert CTA (UI rule), so it is not judged here. */
export function checkBuckets(report: Report, bar: Bar = DRAFT_BAR): BucketCheck {
  const problems: string[] = [];
  const { high, medium } = report.calibration;
  if (high.n < bar.minSupport) problems.push(`high bucket has only ${high.n} photos (need ${bar.minSupport})`);
  else if ((high.accuracy ?? 0) < bar.highBucket) problems.push(`high bucket accuracy ${pct(high.accuracy)} is below ${pct(bar.highBucket)}`);
  if (medium.n >= bar.minSupport && (medium.accuracy ?? 0) < bar.mediumBucket) problems.push(`medium bucket accuracy ${pct(medium.accuracy)} is below ${pct(bar.mediumBucket)}`);
  if (high.accuracy !== null && medium.accuracy !== null && high.n >= bar.minSupport && medium.n >= bar.minSupport && high.accuracy < medium.accuracy + 0.05) {
    problems.push("high is not noticeably better than medium (needs at least 5 points)");
  }
  return { ok: problems.length === 0, problems };
}

// ---------- choosing the cloud model ----------

export interface ModelChoice { ranking: { model: string; top1: number; meetsBar: boolean; p95Ms: number; perCallUsd: number | null }[]; chosen: string | null; why: string }

/** Among models that meet the bar overall: best top-1, but a model within 1 point of the best that costs less wins; no model meeting the bar means no choice. */
export function chooseModel(reports: Report[], bar: Bar = DRAFT_BAR): ModelChoice {
  const rows = reports.map((r) => ({ model: r.meta.model, top1: r.overall.top1, meetsBar: r.overall.n >= bar.minSupport && r.overall.top1 >= bar.top1, p95Ms: r.latencyMs.p95, perCallUsd: r.cost.perCallUsd }));
  const ranking = [...rows].sort((a, b) => b.top1 - a.top1);
  const ok = ranking.filter((r) => r.meetsBar);
  if (ok.length === 0) return { ranking, chosen: null, why: "no model meets the bar; see the contingency: improve ai_hint_en, narrow candidates, or drop crops" };
  const best = ok[0];
  const near = ok.filter((r) => best.top1 - r.top1 <= 0.01 + 1e-9);
  near.sort((a, b) => (a.perCallUsd ?? Infinity) - (b.perCallUsd ?? Infinity) || a.p95Ms - b.p95Ms);
  return { ranking, chosen: near[0].model, why: near[0].model === best.model ? "best accuracy among models meeting the bar" : "within 1 point of the best accuracy and cheaper" };
}

// ---------- on-device thresholds ----------

export interface ScoredSample {
  crop: string;
  expected: string;
  predicted: string;
  /** Winning class's share of the chosen crop's probability mass (what `conf_high`/`conf_medium` are compared with). */
  share: number;
}

export interface ConfThresholds { confHigh: number | null; confMedium: number | null; notes: string[] }

const accuracy = (xs: ScoredSample[]) => (xs.length === 0 ? null : xs.filter((s) => s.predicted === s.expected).length / xs.length);

/**
 * conf_high: the lowest share whose bucket (share >= it) still reaches the high bar with enough photos.
 * conf_medium: the lowest share, below conf_high, whose bucket (between the two) reaches the medium bar.
 * null = no threshold meets the bar: keep the defaults and treat the on-device model as not launch-ready.
 */
export function recommendConfThresholds(samples: ScoredSample[], bar: Bar = DRAFT_BAR): ConfThresholds {
  const notes: string[] = [];
  const cuts = [...new Set(samples.map((s) => s.share))].sort((a, b) => a - b);

  let confHigh: number | null = null;
  for (const t of cuts) {
    const bucket = samples.filter((s) => s.share >= t);
    if (bucket.length < bar.minSupport) break; // higher cuts only get smaller
    if ((accuracy(bucket) ?? 0) >= bar.highBucket) { confHigh = t; break; }
  }
  if (confHigh === null) notes.push(`no cut-off gives a high bucket with accuracy >= ${pct(bar.highBucket)} on >= ${bar.minSupport} photos`);

  let confMedium: number | null = null;
  if (confHigh !== null) {
    for (const t of cuts.filter((c) => c < confHigh!)) {
      const bucket = samples.filter((s) => s.share >= t && s.share < confHigh!);
      if (bucket.length < bar.minSupport) continue;
      if ((accuracy(bucket) ?? 0) >= bar.mediumBucket) { confMedium = t; break; }
    }
    if (confMedium === null) notes.push("no medium bucket reaches its bar; everything below conf_high should be treated as low");
  }
  return { confHigh, confMedium, notes };
}

// ---------- reject-below cut-offs (blur, dark, min_crop_mass) ----------

export interface Cutoff { threshold: number; falseRejectRate: number; catchRate: number }

/**
 * For gates that reject a photo when `value < threshold`: pick the threshold that catches the most bad photos while
 * rejecting at most [maxFalseReject] of the good ones. Close-up leaf photos are naturally textured, so this must be
 * measured on real field photos, never desktop ones. Null when either list is empty.
 */
export function chooseCutoff(good: number[], bad: number[], maxFalseReject = 0.05): Cutoff | null {
  if (good.length === 0 || bad.length === 0) return null;
  const candidates = [...new Set([...good, ...bad])].sort((a, b) => a - b);
  let best: Cutoff = { threshold: Math.min(...good), falseRejectRate: 0, catchRate: bad.filter((v) => v < Math.min(...good)).length / bad.length };
  for (const t of candidates) {
    const falseReject = good.filter((v) => v < t).length / good.length;
    if (falseReject > maxFalseReject) break; // rates only grow with t
    const catchRate = bad.filter((v) => v < t).length / bad.length;
    if (catchRate > best.catchRate) best = { threshold: t, falseRejectRate: falseReject, catchRate };
  }
  return best;
}

// ---------- output ----------

export interface CalibrationInput {
  reports: Report[];
  samples?: ScoredSample[];
  quality?: { blur?: { good: number[]; bad: number[] }; dark?: { good: number[]; bad: number[] }; cropMass?: { good: number[]; bad: number[] } };
  bar?: Bar;
}

export interface CalibrationResult {
  chosenModel: ModelChoice;
  perCrop: CropVerdict[];
  buckets: BucketCheck;
  confThresholds: ConfThresholds | null;
  cutoffs: { blur: Cutoff | null; dark: Cutoff | null; cropMass: Cutoff | null };
  /** Only values that were actually measured; keys are Remote Config names. */
  remoteConfig: Record<string, number>;
  launchCrops: string[];
  betaCrops: string[];
  droppedCrops: string[];
}

export function calibrate(input: CalibrationInput): CalibrationResult {
  const bar = input.bar ?? DRAFT_BAR;
  const chosenModel = chooseModel(input.reports, bar);
  const best = input.reports.find((r) => r.meta.model === chosenModel.chosen) ?? [...input.reports].sort((a, b) => b.overall.top1 - a.overall.top1)[0];
  const perCrop = best ? cropVerdicts(best, bar) : [];
  const buckets = best ? checkBuckets(best, bar) : { ok: false, problems: ["no reports given"] };
  const confThresholds = input.samples ? recommendConfThresholds(input.samples, bar) : null;
  const q = input.quality ?? {};
  const cutoffs = {
    blur: q.blur ? chooseCutoff(q.blur.good, q.blur.bad) : null,
    dark: q.dark ? chooseCutoff(q.dark.good, q.dark.bad) : null,
    cropMass: q.cropMass ? chooseCutoff(q.cropMass.good, q.cropMass.bad) : null,
  };
  const remoteConfig: Record<string, number> = {};
  if (confThresholds?.confHigh != null) remoteConfig.conf_high = round(confThresholds.confHigh);
  if (confThresholds?.confMedium != null) remoteConfig.conf_medium = round(confThresholds.confMedium);
  if (cutoffs.blur) remoteConfig.blur_threshold = round(cutoffs.blur.threshold);
  if (cutoffs.dark) remoteConfig.dark_threshold = round(cutoffs.dark.threshold);
  if (cutoffs.cropMass) remoteConfig.min_crop_mass = round(cutoffs.cropMass.threshold);
  return {
    chosenModel, perCrop, buckets, confThresholds, cutoffs, remoteConfig,
    launchCrops: perCrop.filter((c) => c.verdict === "launch").map((c) => c.crop),
    betaCrops: perCrop.filter((c) => c.verdict === "beta").map((c) => c.crop),
    droppedCrops: perCrop.filter((c) => c.verdict === "drop" || c.verdict === "insufficient_data").map((c) => c.crop),
  };
}

const round = (n: number) => Math.round(n * 1000) / 1000;
function pct(n: number | null) { return n === null ? "n/a" : `${(n * 100).toFixed(1)}%`; }

/** Markdown for the agronomist review. States what is missing instead of hiding it. */
export function renderReport(r: CalibrationResult, bar: Bar = DRAFT_BAR): string {
  const L: string[] = ["# Calibration report (task 9.1)", "", `Bar: top-1 >= ${pct(bar.top1)} per crop, high bucket >= ${pct(bar.highBucket)}, medium bucket >= ${pct(bar.mediumBucket)}, at least ${bar.minSupport} photos per number.`, ""];
  L.push("## Cloud model", "", r.chosenModel.chosen ? `Chosen: **${r.chosenModel.chosen}** (${r.chosenModel.why}).` : `**No model chosen**: ${r.chosenModel.why}.`, "", "| Model | Top-1 | Meets bar | p95 ms | USD/call |", "|---|---|---|---|---|");
  for (const m of r.chosenModel.ranking) L.push(`| ${m.model} | ${pct(m.top1)} | ${m.meetsBar ? "yes" : "no"} | ${Math.round(m.p95Ms)} | ${m.perCallUsd === null ? "n/a" : m.perCallUsd.toFixed(4)} |`);
  L.push("", "## Per crop", "", "| Crop | Photos | Top-1 | Verdict | Why |", "|---|---|---|---|---|");
  for (const c of r.perCrop) L.push(`| ${c.crop} | ${c.n} | ${pct(c.top1)} | ${c.verdict} | ${c.reason} |`);
  L.push("", "## Confidence buckets (cloud)", "", r.buckets.ok ? "The buckets meet the bar." : r.buckets.problems.map((p) => `- ${p}`).join("\n"));
  L.push("", "## On-device thresholds", "");
  if (!r.confThresholds) L.push("Not measured (no on-device samples given). Defaults stay; the on-device model is not calibrated.");
  else L.push(`conf_high = ${r.confThresholds.confHigh ?? "none found"}, conf_medium = ${r.confThresholds.confMedium ?? "none found"}`, ...r.confThresholds.notes.map((n) => `- ${n}`));
  L.push("", "## Photo-quality gates", "");
  for (const [k, c] of Object.entries(r.cutoffs)) L.push(c ? `- ${k}: threshold ${round(c.threshold)} (catches ${pct(c.catchRate)} of bad photos, rejects ${pct(c.falseRejectRate)} of good ones)` : `- ${k}: not measured, default stays`);
  L.push("", "## Remote Config values to set", "", "```json", JSON.stringify(r.remoteConfig, null, 2), "```", "");
  L.push("## Launch list", "", `- launch: ${r.launchCrops.join(", ") || "none"}`, `- beta: ${r.betaCrops.join(", ") || "none"}`, `- drop / insufficient data: ${r.droppedCrops.join(", ") || "none"}`, "");
  return L.join("\n");
}
