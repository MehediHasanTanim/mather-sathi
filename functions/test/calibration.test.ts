import { buildReport, type EvalRecord } from "../src/evalMetrics";
import {
  calibrate, checkBuckets, chooseCutoff, chooseModel, cropVerdicts, recommendConfThresholds, renderReport, DRAFT_BAR,
  type ScoredSample,
} from "../src/calibration";

const META = (model: string) => ({ model, kbSeq: 1, kbVersion: "t", generatedAt: "2026-01-01" });
let k = 0;
const rec = (crop: string, ok: boolean, confidence: "high" | "medium" | "low", latencyMs = 1000): EvalRecord => ({
  file: `f${k++}`, crop, expected: "a", predicted: ok ? "a" : "b", confidence, latencyMs, usage: { input_tokens: 1000, output_tokens: 50 },
});
const many = (n: number, crop: string, ok: boolean, c: "high" | "medium" | "low") => Array.from({ length: n }, () => rec(crop, ok, c));

describe("cropVerdicts", () => {
  const report = buildReport([
    ...many(90, "rice", true, "high"), ...many(10, "rice", false, "high"),       // 90%
    ...many(72, "potato", true, "high"), ...many(28, "potato", false, "high"),    // 72%: beta
    ...many(50, "jute", true, "high"), ...many(50, "jute", false, "high"),        // 50%: drop
    ...many(10, "tomato", true, "high"),                                          // 10 photos
  ], META("m"));

  it("launch / beta / drop / insufficient data", () => {
    const v = Object.fromEntries(cropVerdicts(report).map((c) => [c.crop, c.verdict]));
    expect(v).toEqual({ rice: "launch", potato: "beta", jute: "drop", tomato: "insufficient_data" });
  });
  it("the bar itself passes, just below does not", () => {
    const at = buildReport([...many(80, "rice", true, "high"), ...many(20, "rice", false, "high")], META("m"));
    expect(cropVerdicts(at)[0].verdict).toBe("launch");
    const below = buildReport([...many(79, "rice", true, "high"), ...many(21, "rice", false, "high")], META("m"));
    expect(cropVerdicts(below)[0].verdict).toBe("beta");
  });
});

describe("checkBuckets", () => {
  it("passes when high is good and clearly better than medium", () => {
    const r = buildReport([...many(95, "rice", true, "high"), ...many(5, "rice", false, "high"), ...many(45, "rice", true, "medium"), ...many(15, "rice", false, "medium")], META("m"));
    expect(checkBuckets(r).ok).toBe(true);
  });
  it("fails when the high bucket is not good enough", () => {
    const r = buildReport([...many(80, "rice", true, "high"), ...many(20, "rice", false, "high")], META("m"));
    expect(checkBuckets(r).problems.join()).toContain("high bucket accuracy 80.0% is below 90.0%");
  });
  it("fails when high is no better than medium, and when a bucket has too few photos", () => {
    const same = buildReport([...many(92, "rice", true, "high"), ...many(8, "rice", false, "high"), ...many(94, "rice", true, "medium"), ...many(6, "rice", false, "medium")], META("m"));
    expect(checkBuckets(same).problems.join()).toContain("not noticeably better");
    const thin = buildReport(many(5, "rice", true, "high"), META("m"));
    expect(checkBuckets(thin).problems.join()).toContain("only 5 photos");
  });
});

describe("chooseModel", () => {
  const rep = (model: string, ok: number, bad: number, tokens: number) =>
    buildReport([...Array.from({ length: ok }, () => ({ ...rec("rice", true, "high"), usage: { input_tokens: tokens, output_tokens: 50 } })), ...Array.from({ length: bad }, () => ({ ...rec("rice", false, "high"), usage: { input_tokens: tokens, output_tokens: 50 } }))], META(model));

  it("no model meeting the bar means no choice", () => {
    expect(chooseModel([rep("claude-haiku-4-5", 60, 40, 1000)]).chosen).toBeNull();
  });
  it("picks the best accuracy that meets the bar", () => {
    const c = chooseModel([rep("claude-haiku-4-5", 85, 15, 1000), rep("claude-sonnet-5-5", 95, 5, 1000)]);
    expect(c.chosen).toBe("claude-sonnet-5-5");
  });
  it("a cheaper model within one point of the best wins", () => {
    const c = chooseModel([rep("claude-haiku-4-5", 94, 6, 1000), rep("claude-sonnet-5-5", 95, 5, 1000)]);
    expect(c.chosen).toBe("claude-haiku-4-5");
  });
});

describe("recommendConfThresholds", () => {
  // shares 0.50..0.99: accuracy rises with the share
  const mk = (share: number, n: number, accuracyRate: number): ScoredSample[] =>
    Array.from({ length: n }, (_, i) => ({ crop: "rice", expected: "a", predicted: i < n * accuracyRate ? "a" : "b", share }));
  const samples = [...mk(0.95, 60, 0.97), ...mk(0.85, 60, 0.92), ...mk(0.7, 60, 0.75), ...mk(0.55, 60, 0.4)];

  it("finds the lowest cut-off whose bucket reaches the high bar, then a medium cut-off below it", () => {
    const t = recommendConfThresholds(samples);
    expect(t.confHigh).toBe(0.85);
    expect(t.confMedium).toBe(0.7);
  });
  it("returns null when no cut-off is accurate enough, and says so", () => {
    const poor = [...mk(0.95, 60, 0.7), ...mk(0.6, 60, 0.5)];
    const t = recommendConfThresholds(poor);
    expect(t.confHigh).toBeNull();
    expect(t.notes[0]).toContain("no cut-off");
  });
  it("too little data is never trusted", () => {
    expect(recommendConfThresholds(mk(0.95, 10, 1)).confHigh).toBeNull();
  });
});

describe("chooseCutoff (reject when value < threshold)", () => {
  const good = Array.from({ length: 100 }, (_, i) => 100 + i);     // 100..199
  const bad = Array.from({ length: 100 }, (_, i) => i * 1.2);       // 0..118.8

  it("maximises catches within the false-reject budget", () => {
    const c = chooseCutoff(good, bad, 0.05)!;
    expect(c.falseRejectRate).toBeLessThanOrEqual(0.05);
    expect(c.threshold).toBe(105); // 5 of the good photos (100..104) are rejected
    expect(c.catchRate).toBeGreaterThan(0.85);
  });
  it("a zero budget never rejects a good photo", () => {
    const c = chooseCutoff(good, bad, 0)!;
    expect(c.falseRejectRate).toBe(0);
    expect(c.threshold).toBe(100);
  });
  it("empty inputs give null", () => {
    expect(chooseCutoff([], bad)).toBeNull();
    expect(chooseCutoff(good, [])).toBeNull();
  });
});

describe("calibrate + renderReport", () => {
  const rep = buildReport([...many(95, "rice", true, "high"), ...many(5, "rice", false, "high"), ...many(40, "rice", true, "medium"), ...many(20, "rice", false, "medium"), ...many(40, "jute", true, "high"), ...many(60, "jute", false, "high")], META("claude-haiku-4-5"));

  it("only measured values end up in the Remote Config output", () => {
    const r = calibrate({ reports: [rep], quality: { blur: { good: [100, 120, 150], bad: [10, 20, 30] } } });
    expect(Object.keys(r.remoteConfig)).toEqual(["blur_threshold"]);
  });
  it("the report says what was not measured", () => {
    const text = renderReport(calibrate({ reports: [rep] }));
    expect(text).toContain("Not measured (no on-device samples given)");
    expect(text).toContain("dark: not measured, default stays");
    expect(text).toContain("| jute | 100 | 40.0% | drop |");
  });
  it("no reports at all is a clear failure, not a crash", () => {
    const r = calibrate({ reports: [] });
    expect(r.buckets.ok).toBe(false);
    expect(r.chosenModel.chosen).toBeNull();
    expect(DRAFT_BAR.top1).toBe(0.8);
  });
});
