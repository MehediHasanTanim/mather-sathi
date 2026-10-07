// Calibration (task 9.1): eval reports (+ optional on-device samples and photo-quality stats) -> Remote Config values,
// per-crop launch verdicts and a markdown report for the agronomist review.
//   npx ts-node calibrate.ts --reports reports/haiku.json reports/sonnet.json \
//        [--samples reports/ondevice_samples.json] [--quality reports/quality.json] [--out reports/calibration]
// --samples: [{ "crop", "expected", "predicted", "share" }] from the on-device model on the SAME held-out field set
//            (share = winner's share of the chosen crop's probability mass; see lib/features/offline/crop_scoring.dart)
// --quality: { "blur": {"good":[...],"bad":[...]}, "dark": {...}, "cropMass": {...} } (see test/tools/quality_stats_test.dart)
import fs from "node:fs";
import path from "node:path";
import { calibrate, renderReport, DRAFT_BAR } from "../../functions/src/calibration";
import type { Report } from "../../functions/src/evalMetrics";

const args = process.argv.slice(2);
const opt = (n: string) => {
  const i = args.indexOf(`--${n}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const list = (n: string) => {
  const i = args.indexOf(`--${n}`);
  if (i < 0) return [];
  const out: string[] = [];
  for (let j = i + 1; j < args.length && !args[j].startsWith("--"); j++) out.push(args[j]);
  return out;
};
const read = <T>(p: string): T => JSON.parse(fs.readFileSync(p, "utf8")) as T;

const reportPaths = list("reports");
if (reportPaths.length === 0) {
  console.error("usage: calibrate.ts --reports a.json [b.json ...] [--samples s.json] [--quality q.json] [--out dir]");
  process.exit(2);
}
const result = calibrate({
  reports: reportPaths.map((p) => read<Report>(p)),
  samples: opt("samples") ? read(opt("samples")!) : undefined,
  quality: opt("quality") ? read(opt("quality")!) : undefined,
  bar: DRAFT_BAR,
});
const out = opt("out") ?? "reports/calibration";
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(`${out}.json`, JSON.stringify(result, null, 2));
fs.writeFileSync(`${out}.md`, renderReport(result));
console.log(renderReport(result));
console.log(`\nwritten: ${out}.json, ${out}.md`);
