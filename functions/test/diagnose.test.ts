import Anthropic from "@anthropic-ai/sdk";
import { HttpsError } from "firebase-functions/v2/https";
import { decodeJpeg, handleDiagnose, mapProviderError, parseCrop, type DiagnoseDeps } from "../src/diagnose";
import { FakeClient, FakeDb, jpegBase64, kbFixture, toolUse } from "./support/fakes";

const AUTH = { uid: "user-1" };
const ok = () => toolUse({ disease_id: "rice_blast", confidence: "medium", image_issue: "none" });

function deps(over: Partial<DiagnoseDeps> = {}): DiagnoseDeps & { db: FakeDb; client: FakeClient } {
  return {
    db: new FakeDb(), kb: kbFixture(), client: new FakeClient(ok()), model: "claude-haiku-4-5",
    dailyCap: 30, now: () => Date.UTC(2026, 9, 6, 12), ...over,
  } as DiagnoseDeps & { db: FakeDb; client: FakeClient };
}
const req = (crop = "rice", image = jpegBase64()) => ({ image, crop });
const code = async (p: Promise<unknown>) => p.then(() => "ok", (e: HttpsError) => e.code);

describe("handleDiagnose", () => {
  test("classified response for a launch crop, without usage, with kb_seq", async () => {
    const r = await handleDiagnose(req(), AUTH, deps());
    expect(r).toEqual({ mode: "classified", disease_id: "rice_blast", confidence: "medium", image_issue: "none", kb_seq: 7 });
  });

  test("other crop returns general advice", async () => {
    const d = deps({ client: new FakeClient(toolUse({ summary_bn: "পাতায় দাগ আছে।", prevention_bn: [], image_issue: "none" }, "report_general_advice")) });
    const r = await handleDiagnose(req("other:ধনেপাতা"), AUTH, d);
    expect(r).toMatchObject({ mode: "general", see_expert: true });
    expect(r).not.toHaveProperty("usage");
  });

  test("no auth → unauthenticated, and nothing is spent", async () => {
    const d = deps();
    expect(await code(handleDiagnose(req(), undefined, d))).toBe("unauthenticated");
    expect(d.client.calls).toHaveLength(0);
    expect(d.db.docs.size).toBe(0);
  });

  test("kill switch → unavailable, before validation and quota", async () => {
    const d = deps();
    d.db.docs.set("config/runtime", { cloudEnabled: false });
    expect(await code(handleDiagnose({}, AUTH, d))).toBe("unavailable");
    expect(d.client.calls).toHaveLength(0);
  });

  test("missing runtime config means enabled", async () => {
    expect(await code(handleDiagnose(req(), AUTH, deps()))).toBe("ok");
  });

  test("the 31st call of the day → resource-exhausted; the next day resets", async () => {
    const d = deps();
    for (let i = 0; i < 30; i++) await handleDiagnose(req(), AUTH, d);
    expect(await code(handleDiagnose(req(), AUTH, d))).toBe("resource-exhausted");
    expect(d.client.calls).toHaveLength(30);
    expect(await code(handleDiagnose(req(), { uid: "user-2" }, d))).toBe("ok");
    const nextDay = { ...d, now: () => Date.UTC(2026, 9, 7, 12) };
    expect(await code(handleDiagnose(req(), AUTH, nextDay))).toBe("ok");
  });

  test("quota doc has a TTL timestamp", async () => {
    const d = deps();
    await handleDiagnose(req(), AUTH, d);
    const q = d.db.docs.get("quotas/user-1_2026-10-06")!;
    expect(q.count).toBe(1);
    expect((q.expireAt as Date).getTime()).toBeGreaterThan(Date.UTC(2026, 9, 7));
  });

  test("invalid input never consumes quota", async () => {
    const d = deps();
    for (const bad of [undefined, {}, { image: jpegBase64(), crop: "wheat" }, { image: "AAAA", crop: "rice" }]) {
      expect(await code(handleDiagnose(bad, AUTH, d))).toBe("invalid-argument");
    }
    expect(d.db.docs.size).toBe(0);
  });

  test("oversize or non-JPEG image → invalid-argument", async () => {
    const d = deps();
    expect(await code(handleDiagnose(req("rice", jpegBase64(700 * 1024)), AUTH, d))).toBe("invalid-argument");
    expect(await code(handleDiagnose(req("rice", Buffer.from("GIF89a....").toString("base64")), AUTH, d))).toBe("invalid-argument");
    expect(await code(handleDiagnose(req("rice", "x".repeat(2_000_000)), AUTH, d))).toBe("invalid-argument");
  });

  test("model failures map to codes the app can fall back on", () => {
    expect(mapProviderError(new Anthropic.APIConnectionTimeoutError()).code).toBe("deadline-exceeded");
    expect(mapProviderError(new Anthropic.RateLimitError(429, {}, "slow", new Headers())).code).toBe("unavailable");
    expect(mapProviderError(new Error("boom")).code).toBe("internal");
    expect(mapProviderError(new HttpsError("resource-exhausted", "x")).code).toBe("resource-exhausted");
  });

  test("a provider timeout surfaces as deadline-exceeded", async () => {
    const d = deps({ client: new FakeClient(async () => { throw new Anthropic.APIConnectionTimeoutError(); }) });
    expect(await code(handleDiagnose(req(), AUTH, d))).toBe("deadline-exceeded");
  });
});

describe("input parsing", () => {
  test("decodeJpeg accepts a JPEG at the size limit and rejects just above it", () => {
    expect(decodeJpeg(jpegBase64(600 * 1024 - 4))).toHaveLength(600 * 1024);
    expect(() => decodeJpeg(jpegBase64(600 * 1024 - 3))).toThrow(HttpsError);
  });

  test("parseCrop accepts launch crops and bounded 'other:' labels only", () => {
    const kb = kbFixture();
    expect(parseCrop("rice", kb)).toEqual({ kind: "launch", crop: "rice" });
    expect(parseCrop("other: ধনেপাতা ", kb)).toEqual({ kind: "other", label: "ধনেপাতা" });
    expect(parseCrop(`other:${"ক".repeat(40)}`, kb)).toMatchObject({ kind: "other" });
    for (const bad of ["other:", "other:   ", `other:${"ক".repeat(41)}`, "other:a\nb", "jute", 5, null]) {
      expect(() => parseCrop(bad, kb)).toThrow(HttpsError);
    }
  });
});

describe("diagnoseLogLine", () => {
  const { diagnoseLogLine } = jest.requireActual("../src/diagnose") as typeof import("../src/diagnose");
  it("logs counts and codes only: no image, no uid, no free text", () => {
    const line = diagnoseLogLine({ image: "AAAA", crop: "other:ধনেপাতা" }, { ok: true, mode: "general" }, 1234.6);
    expect(line).toEqual({ event: "diagnose", ok: true, mode: "general", crop: "other", latency_ms: 1235 });
    expect(JSON.stringify(line)).not.toContain("AAAA");
    expect(JSON.stringify(line)).not.toContain("ধনে");
  });
  it("failures carry the code", () => {
    expect(diagnoseLogLine({ crop: "rice" }, { ok: false, code: "unavailable" }, 90)).toEqual({ event: "diagnose", ok: false, code: "unavailable", crop: "rice", latency_ms: 90 });
  });
  it("tolerates garbage input", () => {
    expect(diagnoseLogLine(null, { ok: false, code: "invalid-argument" }, 1).crop).toBeUndefined();
  });
});
