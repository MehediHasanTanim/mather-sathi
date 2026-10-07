// Eval harness core (Phase 3.9). Runs a labelled folder dataset through classifyImage(), the same code the
// diagnose() Function runs in production, and returns a Report. The CLI lives in tools/eval/cloud_eval.ts.
import fs from "node:fs";
import path from "node:path";
import { classifyImage } from "./classify";
import { buildReport, type EvalRecord, type Report } from "./evalMetrics";
import type { KbIndex } from "./kbIndex";
import type { MessagesClient } from "./lib/types";

export interface EvalOptions {
  /** Layout: {dataDir}/{crop}/{disease_id}/*.jpg, where disease_id may be "healthy". */
  dataDir: string;
  crops?: string[];
  kb: KbIndex;
  client: MessagesClient;
  model: string;
  concurrency?: number;
  /** Cap per disease folder, for cheap smoke runs. */
  limitPerClass?: number;
  onProgress?: (done: number, total: number) => void;
}

const MAX_UPLOAD = 600 * 1024;

export interface Sample {
  file: string;
  crop: string;
  expected: string;
}

export function listSamples(dataDir: string, crops?: string[], limitPerClass?: number): Sample[] {
  const out: Sample[] = [];
  const dirs = (p: string) => fs.readdirSync(p, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name).sort();
  for (const crop of dirs(dataDir)) {
    if (crops && !crops.includes(crop)) continue;
    for (const expected of dirs(path.join(dataDir, crop))) {
      const files = fs.readdirSync(path.join(dataDir, crop, expected)).filter((f) => /\.jpe?g$/i.test(f)).sort();
      for (const f of limitPerClass ? files.slice(0, limitPerClass) : files) {
        out.push({ file: path.join(dataDir, crop, expected, f), crop, expected });
      }
    }
  }
  return out;
}

export async function runEval(o: EvalOptions): Promise<Report> {
  const samples = listSamples(o.dataDir, o.crops, o.limitPerClass);
  const records: EvalRecord[] = new Array(samples.length);
  let next = 0;
  let done = 0;

  async function worker() {
    for (;;) {
      const i = next++;
      if (i >= samples.length) return;
      const s = samples[i];
      const base = { file: s.file, crop: s.crop, expected: s.expected, latencyMs: 0 };
      try {
        const jpeg = fs.readFileSync(s.file);
        // The app uploads <= 300 KB prepared JPEGs; larger files here would not reflect production.
        if (jpeg.length > MAX_UPLOAD) throw new Error(`file is ${jpeg.length} bytes (> ${MAX_UPLOAD}); resize like the app does`);
        if (!o.kb.hasCrop(s.crop)) throw new Error(`crop "${s.crop}" is not in the KB index`);
        const t0 = Date.now();
        const r = await classifyImage(o.client, o.model, jpeg, s.crop, o.kb.forCrop(s.crop));
        records[i] = { ...base, latencyMs: Date.now() - t0, predicted: r.disease_id, confidence: r.confidence, usage: r.usage };
      } catch (e) {
        records[i] = { ...base, error: e instanceof Error ? e.message : String(e) };
      }
      o.onProgress?.(++done, samples.length);
    }
  }

  await Promise.all(Array.from({ length: Math.max(1, o.concurrency ?? 4) }, worker));
  return buildReport(records, { model: o.model, kbSeq: o.kb.seq, kbVersion: o.kb.version });
}
