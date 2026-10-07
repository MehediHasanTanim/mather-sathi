import weatherRulesJson from "./weather_rules.json";

/** 3-day outlook for one district, reduced to what the rules need. */
export interface WeatherSummary {
  /** Mean relative humidity, %. */
  humidity: number;
  /** Highest daily chance of rain, %. */
  rainProb: number;
  /** Total expected rain, mm. */
  rainMm: number;
  tMin: number;
  tMax: number;
}

export type RiskLevel = "watch" | "high";
export interface Risk {
  crop: string;
  level: RiskLevel;
  ruleId: string;
  message_bn: string;
}

type Comparator = "gte" | "lte";
const METRICS = { humidity: "humidity", rain_prob: "rainProb", rain_mm: "rainMm", tmin: "tMin", tmax: "tMax" } as const;

export interface Rule {
  id: string;
  /** `draft` rules carry placeholder thresholds and are only evaluated when explicitly allowed (dev). */
  status: "draft" | "published";
  crops: string[];
  /** e.g. `{ "humidity_gte": 85, "rain_prob_gte": 60 }`: every condition must hold. */
  when: Record<string, number>;
  level: RiskLevel;
  message_bn: string;
}

export function loadRules(): Rule[] {
  return (weatherRulesJson as unknown as { rules: Rule[] }).rules;
}

const CROPS = ["rice", "jute", "potato", "tomato", "brinjal", "chili", "onion", "mustard"];

/** Problems in a rules file (empty means valid). Run in tests so a bad edit by the agronomist fails CI, not production. */
export function validateRules(rules: Rule[]): string[] {
  const errs: string[] = [];
  const ids = new Set<string>();
  for (const r of rules) {
    const at = `rule "${r.id}"`;
    if (!r.id || ids.has(r.id)) errs.push(`${at}: id missing or duplicated`);
    ids.add(r.id);
    if (r.status !== "draft" && r.status !== "published") errs.push(`${at}: status must be draft or published`);
    if (r.level !== "watch" && r.level !== "high") errs.push(`${at}: level must be watch or high`);
    if (!Array.isArray(r.crops) || r.crops.length === 0 || r.crops.some((c) => !CROPS.includes(c))) errs.push(`${at}: crops must be launch crops`);
    const conds = Object.entries(r.when ?? {});
    if (conds.length === 0) errs.push(`${at}: needs at least one condition`);
    for (const [k, v] of conds) {
      if (!/^(humidity|rain_prob|rain_mm|tmin|tmax)_(gte|lte)$/.test(k) || typeof v !== "number") errs.push(`${at}: bad condition ${k}`);
    }
    if (!/[\u0980-\u09FF]/.test(r.message_bn ?? "")) errs.push(`${at}: message_bn must be Bangla`);
  }
  return errs;
}

const LEVEL_RANK: Record<RiskLevel, number> = { watch: 1, high: 2 };

function matches(when: Record<string, number>, s: WeatherSummary): boolean {
  const entries = Object.entries(when);
  if (entries.length === 0) return false; // an empty condition would match everything: refuse
  return entries.every(([key, limit]) => {
    const m = /^(humidity|rain_prob|rain_mm|tmin|tmax)_(gte|lte)$/.exec(key);
    if (!m) return false; // unknown condition: fail closed
    const value = s[METRICS[m[1] as keyof typeof METRICS]];
    return (m[2] as Comparator) === "gte" ? value >= limit : value <= limit;
  });
}

/** One risk per crop: the highest level among the matching rules. Draft rules are skipped unless [allowDraft]. */
export function evaluateRules(rules: Rule[], s: WeatherSummary, opts: { allowDraft?: boolean } = {}): Risk[] {
  const best = new Map<string, Risk>();
  for (const rule of rules) {
    if (rule.status !== "published" && !opts.allowDraft) continue;
    if (!matches(rule.when, s)) continue;
    for (const crop of rule.crops) {
      const cur = best.get(crop);
      if (!cur || LEVEL_RANK[rule.level] > LEVEL_RANK[cur.level]) {
        best.set(crop, { crop, level: rule.level, ruleId: rule.id, message_bn: rule.message_bn });
      }
    }
  }
  return [...best.values()].sort((a, b) => a.crop.localeCompare(b.crop));
}

/** True when any crop's risk is new or higher than in [prev]. A falling or unchanged risk never pushes. */
export function riskLevelIncreased(prev: Risk[] | undefined, next: Risk[]): boolean {
  const before = new Map((prev ?? []).map((r) => [r.crop, LEVEL_RANK[r.level]]));
  return next.some((r) => LEVEL_RANK[r.level] > (before.get(r.crop) ?? 0));
}

export interface Forecast {
  /** Hourly relative humidity, %, over the window. */
  humidity: number[];
  /** Per day. */
  rainProb: number[];
  rainMm: number[];
  tMin: number[];
  tMax: number[];
}

export function summarize(f: Forecast): WeatherSummary {
  const nums = (a: number[]) => a.filter((v) => typeof v === "number" && Number.isFinite(v));
  const h = nums(f.humidity);
  const rp = nums(f.rainProb), rm = nums(f.rainMm), tn = nums(f.tMin), tx = nums(f.tMax);
  if (h.length === 0 || tn.length === 0 || tx.length === 0) throw new Error("forecast has no usable data");
  const round = (v: number) => Math.round(v * 10) / 10;
  return {
    humidity: round(h.reduce((a, b) => a + b, 0) / h.length),
    rainProb: rp.length ? Math.max(...rp) : 0,
    rainMm: round(rm.reduce((a, b) => a + b, 0)),
    tMin: Math.min(...tn),
    tMax: Math.max(...tx),
  };
}
