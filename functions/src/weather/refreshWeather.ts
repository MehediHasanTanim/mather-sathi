import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore } from "firebase-admin/firestore";
import { listDistricts } from "../districts";
import { CROP_NAMES_BN } from "../lib/cropNames";
import { defaultSender, districtTopic, type PushSender } from "../notify";
import type { DbLike } from "../quota";
import { OpenMeteoProvider, type WeatherProvider } from "./openMeteo";
import { evaluateRules, loadRules, riskLevelIncreased, summarize, type Risk, type Rule } from "./weather";

export interface RefreshDeps {
  db: DbLike;
  provider: WeatherProvider;
  sender: PushSender;
  rules: Rule[];
  allowDraftRules: boolean;
  now?: () => number;
  concurrency?: number;
  districts?: { id: number; slug: string; lat: number; lon: number }[];
}

export interface RefreshResult {
  updated: number;
  pushed: number;
  failed: string[];
}

const chunk = <T>(a: T[], n: number): T[][] => Array.from({ length: Math.ceil(a.length / n) }, (_, i) => a.slice(i * n, i * n + n));

export function weatherMessage(slug: string, risks: Risk[]) {
  const top = [...risks].sort((a, b) => (a.level === b.level ? 0 : a.level === "high" ? -1 : 1))[0];
  const crops = risks.map((r) => CROP_NAMES_BN[r.crop] ?? r.crop).join("، ");
  return {
    topic: districtTopic(slug),
    title: "⛅ আবহাওয়া সতর্কতা",
    body: `${top.message_bn} (${crops})`,
    channelId: "weather" as const,
    route: "/alerts",
  };
}

/**
 * Fetches the forecast per district, evaluates the agronomist rules, caches the result in `weather/{slug}`, and pushes
 * only when a crop's risk went UP. 64 districts, a modest concurrency, one failing district never blocks the rest.
 */
export async function refreshAll(deps: RefreshDeps): Promise<RefreshResult> {
  const result: RefreshResult = { updated: 0, pushed: 0, failed: [] };
  const districts = deps.districts ?? listDistricts();
  const now = deps.now?.() ?? Date.now();

  for (const batch of chunk(districts, deps.concurrency ?? 8)) {
    await Promise.all(batch.map(async (d) => {
      try {
        const summary = summarize(await deps.provider.fetch(d.lat, d.lon));
        const risks = evaluateRules(deps.rules, summary, { allowDraft: deps.allowDraftRules });
        const ref = deps.db.doc(`weather/${d.slug}`);
        const prev = ((await ref.get()).data?.() as { risks?: Risk[] } | undefined)?.risks;
        await ref.set({ summary, risks, fetchedAt: new Date(now) });
        result.updated++;
        if (riskLevelIncreased(prev, risks)) {
          let sent = true;
          await deps.sender.send(weatherMessage(d.slug, risks)).catch((e) => {
            sent = false;
            console.error("weather push failed", d.slug, e);
          });
          if (sent) result.pushed++;
        }
      } catch (e) {
        console.error("weather refresh failed", d.slug, e);
        result.failed.push(d.slug);
      }
    }));
  }
  return result;
}

export const refreshWeather = onSchedule(
  { schedule: "0 6,14 * * *", timeZone: "Asia/Dhaka", region: "asia-south1", timeoutSeconds: 300 },
  async () => {
    const r = await refreshAll({
      db: getFirestore() as unknown as DbLike,
      provider: new OpenMeteoProvider(),
      sender: defaultSender(),
      rules: loadRules(),
      // Placeholder (draft) rules run only where explicitly allowed, e.g. a dev project's .env.
      allowDraftRules: process.env.ALLOW_DRAFT_WEATHER_RULES === "true",
    });
    console.log(`weather refresh: updated=${r.updated} pushed=${r.pushed} failed=${r.failed.length}`);
    if (r.failed.length > 8) throw new Error(`weather refresh failed for ${r.failed.length} districts`); // surfaces in error-rate alerts
  },
);
