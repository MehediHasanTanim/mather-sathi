// Cloud eval harness v0 (Phase 3.9).
//   cd tools/eval && npm install
//   ANTHROPIC_API_KEY=... npx ts-node cloud_eval.ts --data ./testset --crops rice,potato --out reports/cloud_v0.json
// Dataset layout: testset/{crop}/{disease_id}/*.jpg  (disease_id may be "healthy"; use prepared <= 300 KB JPEGs).
// Options: --model ID (default: VISION_MODEL or claude-haiku-4-5)  --concurrency N  --limit N (per class)
//          --kb PATH (default functions/src/kb_index.json)  --dry-run (no API calls; checks the dataset and wiring)
import fs from "node:fs";
import path from "node:path";
import Anthropic from "@anthropic-ai/sdk";
import { runEval } from "../../functions/src/evalRunner";
import { KbIndex } from "../../functions/src/kbIndex";
import { DEFAULT_VISION_MODEL } from "../../functions/src/lib/modelCaps";
import type { MessagesClient } from "../../functions/src/lib/types";

const args = process.argv.slice(2);
const opt = (n: string, d?: string) => {
  const i = args.indexOf(`--${n}`);
  return i >= 0 ? args[i + 1] : d;
};

async function main() {
  const dataDir = opt("data");
  if (!dataDir) throw new Error("--data <dir> is required");
  const out = opt("out", "reports/cloud_v0.json")!;
  const model = opt("model", process.env.VISION_MODEL ?? DEFAULT_VISION_MODEL)!;
  const kbPath = path.resolve(opt("kb", path.join(__dirname, "../../functions/src/kb_index.json"))!);
  const kb = new KbIndex(JSON.parse(fs.readFileSync(kbPath, "utf8")));

  // Same client settings as production (diagnose.ts): no SDK retries, 6 s timeout.
  const client: MessagesClient = args.includes("--dry-run")
    ? { messages: { create: async () => { throw new Error("dry run: no API call made"); } } }
    : (new Anthropic({ maxRetries: 0, timeout: 6000 }) as unknown as MessagesClient);

  const report = await runEval({
    dataDir, kb, client, model,
    crops: opt("crops")?.split(","),
    concurrency: Number(opt("concurrency", "4")),
    limitPerClass: opt("limit") ? Number(opt("limit")) : undefined,
    onProgress: (d, t) => process.stderr.write(`\r${d}/${t}`),
  });
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, `${JSON.stringify(report, null, 2)}\n`);
  process.stderr.write("\n");
  console.log(`model=${model} kb_seq=${kb.seq} images=${report.meta.images} errors=${report.meta.errors}`);
  console.log(`top-1 overall=${(report.overall.top1 * 100).toFixed(1)}%  p95=${report.latencyMs.p95}ms  cost/call=${report.cost.perCallUsd?.toFixed(5) ?? "n/a"} USD`);
  for (const [c, v] of Object.entries(report.perCrop)) console.log(`  ${c}: ${(v.top1 * 100).toFixed(1)}% (${v.correct}/${v.n})`);
  console.log("calibration:", JSON.stringify(report.calibration));
  console.log(`report written to ${out}`);
}

main().catch((e) => { console.error(e instanceof Error ? e.message : e); process.exit(1); });
