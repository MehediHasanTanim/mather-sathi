import { parseOpenMeteo, OpenMeteoProvider } from "../src/weather/openMeteo";
import { refreshAll, weatherMessage } from "../src/weather/refreshWeather";
import { evaluateRules, loadRules, riskLevelIncreased, summarize, validateRules, type Forecast, type Risk, type Rule, type WeatherSummary } from "../src/weather/weather";
import { FakeDb, FakeSender } from "./support/fakes";

const rule = (over: Partial<Rule> = {}): Rule => ({
  id: "r1", status: "published", crops: ["rice", "potato"], when: { humidity_gte: 85, rain_prob_gte: 60 }, level: "watch",
  message_bn: "ক্ষেত পর্যবেক্ষণে রাখুন।", ...over,
});
const wet: WeatherSummary = { humidity: 90, rainProb: 80, rainMm: 40, tMin: 22, tMax: 30 };
const dry: WeatherSummary = { humidity: 50, rainProb: 5, rainMm: 0, tMin: 20, tMax: 34 };

describe("evaluateRules (task 7.3)", () => {
  test("a rule fires only when every condition holds", () => {
    expect(evaluateRules([rule()], wet).map((r) => r.crop)).toEqual(["potato", "rice"]);
    expect(evaluateRules([rule()], dry)).toEqual([]);
    expect(evaluateRules([rule()], { ...wet, rainProb: 59 })).toEqual([]); // one condition short
  });

  test("conditions are inclusive and support gte and lte on every metric", () => {
    expect(evaluateRules([rule({ when: { humidity_gte: 90 } })], wet)).toHaveLength(2);
    expect(evaluateRules([rule({ when: { tmax_lte: 30 } })], wet)).toHaveLength(2);
    expect(evaluateRules([rule({ when: { tmin_lte: 21 } })], wet)).toEqual([]);
    expect(evaluateRules([rule({ when: { rain_mm_gte: 40 } })], wet)).toHaveLength(2);
  });

  test("draft rules (placeholder thresholds) are skipped unless explicitly allowed", () => {
    const draft = rule({ status: "draft" });
    expect(evaluateRules([draft], wet)).toEqual([]);
    expect(evaluateRules([draft], wet, { allowDraft: true })).toHaveLength(2);
  });

  test("the highest level wins per crop", () => {
    const risks = evaluateRules([rule({ level: "watch" }), rule({ id: "r2", level: "high", crops: ["rice"], message_bn: "অতি ঝুঁকি।" })], wet);
    expect(risks.find((r) => r.crop === "rice")).toMatchObject({ level: "high", ruleId: "r2" });
    expect(risks.find((r) => r.crop === "potato")).toMatchObject({ level: "watch" });
  });

  test("empty or unknown conditions fail closed instead of matching everything", () => {
    expect(evaluateRules([rule({ when: {} })], wet)).toEqual([]);
    expect(evaluateRules([rule({ when: { wind_gte: 1 } as never })], wet)).toEqual([]);
  });

  test("the shipped weather_rules.json is valid and ships only draft rules until reviewed", () => {
    const rules = loadRules();
    expect(validateRules(rules)).toEqual([]);
    expect(rules.every((r) => r.status === "draft")).toBe(true);
  });

  test("validateRules catches a bad edit", () => {
    expect(validateRules([rule({ id: "" })]).length).toBeGreaterThan(0);
    expect(validateRules([rule(), rule()]).some((e) => /duplicated/.test(e))).toBe(true);
    expect(validateRules([rule({ crops: ["wheat"] })]).length).toBeGreaterThan(0);
    expect(validateRules([rule({ when: { humidity: 5 } as never })]).length).toBeGreaterThan(0);
    expect(validateRules([rule({ message_bn: "english" })]).length).toBeGreaterThan(0);
    expect(validateRules([rule({ level: "red" as never })]).length).toBeGreaterThan(0);
  });
});

describe("riskLevelIncreased: pushes only on increase (task 7.6)", () => {
  const r = (crop: string, level: "watch" | "high"): Risk => ({ crop, level, ruleId: "x", message_bn: "ক" });
  test.each([
    [undefined, [r("rice", "watch")], true],
    [[], [r("rice", "watch")], true],
    [[r("rice", "watch")], [r("rice", "high")], true],
    [[r("rice", "watch")], [r("rice", "watch")], false],
    [[r("rice", "high")], [r("rice", "watch")], false],
    [[r("rice", "high")], [], false],
    [[r("rice", "watch")], [r("rice", "watch"), r("potato", "watch")], true],
    [undefined, [], false],
  ])("prev %j -> next %j = %s", (prev, next, want) => {
    expect(riskLevelIncreased(prev as Risk[] | undefined, next as Risk[])).toBe(want);
  });
});

describe("forecast parsing and summary", () => {
  const forecast: Forecast = { humidity: [80, 90, 100], rainProb: [10, 70, 40], rainMm: [0, 12.5, 3], tMin: [21, 19, 22], tMax: [31, 28, 33] };

  test("summarize: mean humidity, max rain probability, total rain, extreme temperatures", () => {
    expect(summarize(forecast)).toEqual({ humidity: 90, rainProb: 70, rainMm: 15.5, tMin: 19, tMax: 33 });
  });

  test("missing values are skipped; an empty forecast is an error", () => {
    expect(summarize({ ...forecast, rainProb: [], rainMm: [] })).toMatchObject({ rainProb: 0, rainMm: 0 });
    expect(() => summarize({ ...forecast, humidity: [] })).toThrow();
    expect(() => summarize({ ...forecast, tMax: [Number.NaN] })).toThrow();
  });

  test("parseOpenMeteo maps the documented response shape and tolerates nulls", () => {
    const f = parseOpenMeteo({
      hourly: { time: ["t1", "t2"], relative_humidity_2m: [80, null, 90] },
      daily: {
        precipitation_probability_max: [10, 60, null], precipitation_sum: [0, 4.2, 1],
        temperature_2m_min: [20, 21, 22], temperature_2m_max: [30, 31, 32],
      },
    });
    expect(f).toEqual({ humidity: [80, 90], rainProb: [10, 60], rainMm: [0, 4.2, 1], tMin: [20, 21, 22], tMax: [30, 31, 32] });
    expect(parseOpenMeteo({})).toEqual({ humidity: [], rainProb: [], rainMm: [], tMin: [], tMax: [] });
  });

  test("the provider builds a 3-day Dhaka-timezone request and fails on HTTP errors", async () => {
    let url = "";
    const ok = new OpenMeteoProvider((async (u: string) => { url = u; return { ok: true, json: async () => ({ hourly: { relative_humidity_2m: [70] }, daily: { temperature_2m_min: [20], temperature_2m_max: [30] } }) }; }) as never);
    await ok.fetch(23.8, 90.4);
    expect(url).toContain("latitude=23.8&longitude=90.4");
    expect(url).toContain("forecast_days=3");
    expect(url).toContain("timezone=Asia%2FDhaka");
    const bad = new OpenMeteoProvider((async () => ({ ok: false, status: 429 })) as never);
    await expect(bad.fetch(1, 2)).rejects.toThrow(/429/);
  });
});

describe("refreshAll", () => {
  const districts = [
    { id: 1, slug: "dhaka", lat: 23.8, lon: 90.4 },
    { id: 2, slug: "khulna", lat: 22.8, lon: 89.5 },
    { id: 3, slug: "sylhet", lat: 24.9, lon: 91.9 },
  ];
  const wetForecast: Forecast = { humidity: [95], rainProb: [90], rainMm: [30], tMin: [22], tMax: [29] };
  const dryForecast: Forecast = { humidity: [50], rainProb: [0], rainMm: [0], tMin: [20], tMax: [35] };
  const provider = (by: Record<string, Forecast | Error>) => ({
    fetch: async (lat: number) => {
      const slug = districts.find((d) => d.lat === lat)!.slug;
      const v = by[slug];
      if (v instanceof Error) throw v;
      return v;
    },
  });
  const run = (db: FakeDb, sender: FakeSender, by: Record<string, Forecast | Error>, at = Date.UTC(2026, 9, 6, 6)) =>
    refreshAll({ db, sender, provider: provider(by), rules: [rule()], allowDraftRules: false, districts, concurrency: 2, now: () => at });

  test("caches summary, risks and fetch time per district", async () => {
    const db = new FakeDb();
    const r = await run(db, new FakeSender(), { dhaka: wetForecast, khulna: dryForecast, sylhet: dryForecast });
    expect(r).toEqual({ updated: 3, pushed: 1, failed: [] });
    const d = db.docs.get("weather/dhaka")!;
    expect((d.risks as Risk[]).map((x) => x.crop)).toEqual(["potato", "rice"]);
    expect((d.fetchedAt as Date).getTime()).toBe(Date.UTC(2026, 9, 6, 6));
    expect(db.docs.get("weather/khulna")!.risks).toEqual([]);
  });

  test("pushes when risk appears, not again while unchanged, and not when it falls", async () => {
    const db = new FakeDb();
    const sender = new FakeSender();
    const all = (f: Forecast) => ({ dhaka: f, khulna: f, sylhet: f });
    await run(db, sender, all(dryForecast));
    expect(sender.sent).toHaveLength(0);
    await run(db, sender, all(wetForecast));
    expect(sender.sent.map((m) => m.topic).sort()).toEqual(["d_dhaka", "d_khulna", "d_sylhet"]);
    await run(db, sender, all(wetForecast));
    expect(sender.sent).toHaveLength(3); // unchanged: no repeat
    await run(db, sender, all(dryForecast));
    expect(sender.sent).toHaveLength(3); // falling: no push
    await run(db, sender, all(wetForecast));
    expect(sender.sent).toHaveLength(6); // back up: pushes again
  });

  test("one failing district does not block the others", async () => {
    const db = new FakeDb();
    const r = await run(db, new FakeSender(), { dhaka: new Error("provider down"), khulna: wetForecast, sylhet: dryForecast });
    expect(r).toMatchObject({ updated: 2, failed: ["dhaka"] });
    expect(db.docs.has("weather/dhaka")).toBe(false);
    expect(db.docs.has("weather/khulna")).toBe(true);
  });

  test("a failing push does not stop caching", async () => {
    const sender = new FakeSender();
    sender.fail = true;
    const db = new FakeDb();
    const r = await run(db, sender, { dhaka: wetForecast, khulna: wetForecast, sylhet: wetForecast });
    expect(r.updated).toBe(3);
    expect(db.docs.size).toBe(3);
  });

  test("draft rules are not evaluated in a normal run", async () => {
    const db = new FakeDb();
    const r = await refreshAll({
      db, sender: new FakeSender(), provider: provider({ dhaka: wetForecast, khulna: wetForecast, sylhet: wetForecast }),
      rules: [rule({ status: "draft" })], allowDraftRules: false, districts,
    });
    expect(r.pushed).toBe(0);
    expect(db.docs.get("weather/dhaka")!.risks).toEqual([]);
  });

  test("push text is Bangla, names the crops, and opens the alerts tab", () => {
    const m = weatherMessage("dhaka", [{ crop: "rice", level: "watch", ruleId: "r", message_bn: "ক্ষেত দেখুন।" }, { crop: "potato", level: "high", ruleId: "r", message_bn: "ঝুঁকি বেশি।" }]);
    expect(m).toMatchObject({ topic: "d_dhaka", channelId: "weather", route: "/alerts" });
    expect(m.body).toContain("ঝুঁকি বেশি।");
    expect(m.body).toContain("ধান");
    expect(m.body).toContain("আলু");
  });
});
