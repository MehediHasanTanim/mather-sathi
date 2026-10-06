import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type Anthropic from "@anthropic-ai/sdk";
import { buildReport, percentile, type EvalRecord } from "../src/evalMetrics";
import { listSamples, runEval } from "../src/evalRunner";
import type { MessagesClient } from "../src/lib/types";
import { kbFixture, toolUse } from "./support/fakes";

const rec = (o: Partial<EvalRecord>): EvalRecord => ({ file: "f", crop: "rice", expected: "rice_blast", latencyMs: 100, ...o });
const meta = { model: "claude-haiku-4-5", kbSeq: 7, kbVersion: "t", generatedAt: "2026-01-01T00:00:00Z" };

describe("buildReport", () => {
  const records = [
    rec({ predicted: "rice_blast", confidence: "high", latencyMs: 100, usage: { input_tokens: 2000, output_tokens: 50 } }),
    rec({ predicted: "rice_blast", confidence: "high", latencyMs: 200, usage: { input_tokens: 2000, output_tokens: 50 } }),
    rec({ predicted: "rice_brown_spot", confidence: "high", latencyMs: 300, usage: { input_tokens: 2000, output_tokens: 50 } }),
    rec({ expected: "rice_brown_spot", predicted: "rice_brown_spot", confidence: "medium", latencyMs: 400, usage: { input_tokens: 2000, output_tokens: 50 } }),
    rec({ expected: "healthy", predicted: "unknown", confidence: "low", latencyMs: 500, usage: { input_tokens: 2000, output_tokens: 50 } }),
    rec({ crop: "potato", expected: "potato_late_blight", predicted: "potato_late_blight", confidence: "high", latencyMs: 600 }),
    rec({ error: "timeout" }),
  ];
  const r = buildReport(records, meta);

  test("per-crop and overall top-1; errors are counted but excluded", () => {
    expect(r.perCrop.rice).toEqual({ n: 5, correct: 3, top1: 0.6 });
    expect(r.perCrop.potato.top1).toBe(1);
    expect(r.overall).toMatchObject({ n: 6, correct: 4 });
    expect(r.meta).toMatchObject({ images: 7, errors: 1 });
    expect(r.perDisease["rice/rice_blast"]).toEqual({ n: 3, correct: 2, top1: 2 / 3 });
  });

  test("confusion matrix", () => {
    expect(r.confusion.rice.rice_blast).toEqual({ rice_blast: 2, rice_brown_spot: 1 });
    expect(r.confusion.rice.healthy).toEqual({ unknown: 1 });
  });

  test("calibration table: observed accuracy per confidence bucket", () => {
    expect(r.calibration.high).toEqual({ n: 4, correct: 3, accuracy: 0.75 });
    expect(r.calibration.medium).toEqual({ n: 1, correct: 1, accuracy: 1 });
    expect(r.calibration.low).toEqual({ n: 1, correct: 0, accuracy: 0 });
  });

  test("unknown rate, latency percentiles and cost", () => {
    expect(r.rates.unknown).toBeCloseTo(1 / 6);
    expect(r.latencyMs.p50).toBe(300);
    expect(r.latencyMs.p95).toBe(600);
    expect(r.cost.inputTokens).toBe(10000);
    // 10000 * $1/M + 250 * $5/M = $0.01125 over 6 calls
    expect(r.cost.totalUsd).toBeCloseTo(0.01125, 6);
    expect(r.cost.perCallUsd).toBeCloseTo(0.01125 / 6, 6);
  });

  test("unknown model has no cost estimate; empty bucket has null accuracy", () => {
    const x = buildReport([rec({ predicted: "rice_blast", confidence: "high" })], { ...meta, model: "mystery" });
    expect(x.cost.totalUsd).toBeNull();
    expect(x.calibration.low.accuracy).toBeNull();
  });

  test("percentile nearest-rank", () => {
    expect(percentile([], 95)).toBe(0);
    expect(percentile([5], 95)).toBe(5);
    expect(percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 95)).toBe(10);
    expect(percentile([1, 2, 3, 4], 50)).toBe(2);
  });
});

describe("runEval over a folder dataset", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "eval-"));
  const put = (crop: string, cls: string, name: string, bytes: number[]) => {
    fs.mkdirSync(path.join(dir, crop, cls), { recursive: true });
    fs.writeFileSync(path.join(dir, crop, cls, name), Buffer.from([0xff, 0xd8, 0xff, ...bytes]));
  };
  put("rice", "rice_blast", "a.jpg", [1]);
  put("rice", "rice_blast", "b.jpg", [2]);
  put("rice", "healthy", "c.jpg", [3]);
  put("potato", "potato_late_blight", "d.jpg", [4]);
  put("wheat", "wheat_rust", "e.jpg", [5]); // not a KB crop
  fs.writeFileSync(path.join(dir, "rice", "readme.txt"), "ignored");

  // The fake "model" answers from the image bytes: 1 -> correct, 2 -> wrong, 3 -> correct, 4 -> correct.
  const answers: Record<number, string> = { 1: "rice_blast", 2: "rice_brown_spot", 3: "healthy", 4: "potato_late_blight" };
  const client: MessagesClient = {
    messages: {
      create: async (p: Anthropic.MessageCreateParamsNonStreaming) => {
        const img = (p.messages[0].content as { source?: { data: string } }[])[0].source!.data;
        const id = answers[Buffer.from(img, "base64")[3]];
        return toolUse({ disease_id: id, confidence: "high", image_issue: "none" });
      },
    },
  };

  test("lists samples by crop/disease folder, honouring --crops and the per-class limit", () => {
    expect(listSamples(dir, ["rice"]).map((s) => path.basename(s.file))).toEqual(["c.jpg", "a.jpg", "b.jpg"]);
    expect(listSamples(dir, ["rice"], 1)).toHaveLength(2);
  });

  test("scores the dataset and reports an unknown crop as an error", async () => {
    const progress: number[] = [];
    const r = await runEval({
      dataDir: dir, kb: kbFixture(), client, model: "claude-haiku-4-5", concurrency: 2,
      onProgress: (d) => progress.push(d),
    });
    expect(r.overall).toMatchObject({ n: 4, correct: 3 });
    expect(r.meta).toMatchObject({ images: 5, errors: 1, kbSeq: 7 });
    expect(r.perCrop.potato.top1).toBe(1);
    expect(progress).toHaveLength(5);
  });

  test("an oversize file is reported, not uploaded", async () => {
    const big = fs.mkdtempSync(path.join(os.tmpdir(), "eval-big-"));
    fs.mkdirSync(path.join(big, "rice", "rice_blast"), { recursive: true });
    fs.writeFileSync(path.join(big, "rice", "rice_blast", "x.jpg"), Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(700 * 1024)]));
    const r = await runEval({ dataDir: big, kb: kbFixture(), client, model: "claude-haiku-4-5" });
    expect(r.meta.errors).toBe(1);
  });
});
