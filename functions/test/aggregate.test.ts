import { alertId, alertMessage, handleReport, isValidReport, type AggregateDeps, type Report } from "../src/aggregateReports";
import { listDistricts } from "../src/districts";
import { FakeDb, FakeSender, kbFixture } from "./support/fakes";

const dhaka = listDistricts().find((d) => d.slug === "dhaka")!;
const upazila = `${dhaka.upazilas[0].id}`;
const report = (uid: string, over: Partial<Report> = {}): Report => ({
  uid, district: "dhaka", upazila, crop: "rice", diseaseId: "rice_blast", week: "2026-W41", ...over,
});
const ID = alertId({ district: "dhaka", upazila, crop: "rice", diseaseId: "rice_blast", week: "2026-W41" });

function env(over: Partial<AggregateDeps> = {}) {
  const db = new FakeDb();
  const sender = new FakeSender();
  const deps: AggregateDeps = { db, kb: kbFixture(), sender, threshold: 3, now: () => Date.UTC(2026, 9, 6, 10), ...over };
  return { db, sender, deps };
}

describe("aggregateReports (task 7.1)", () => {
  test("an alert becomes visible only at the third distinct install, with exactly one push", async () => {
    const { db, sender, deps } = env();
    expect(await handleReport(report("a"), deps)).toBe("counted");
    expect(await handleReport(report("b"), deps)).toBe("counted");
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 2, visible: false });
    expect(sender.sent).toHaveLength(0);

    expect(await handleReport(report("c"), deps)).toBe("became_visible");
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 3, visible: true, district: "dhaka", crop: "rice", week: "2026-W41" });
    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0]).toMatchObject({ topic: "d_dhaka", channelId: "alerts", route: "/alerts" });

    expect(await handleReport(report("d"), deps)).toBe("counted");
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 4, visible: true });
    expect(sender.sent).toHaveLength(1); // a fourth report does not push again
  });

  test("a re-delivered trigger does not double count", async () => {
    const { db, deps } = env();
    expect(await handleReport(report("a"), deps)).toBe("counted");
    expect(await handleReport(report("a"), deps)).toBe("duplicate");
    expect(await handleReport(report("a"), deps)).toBe("duplicate");
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 1 });
  });

  test("one install cannot reach the threshold alone, however many ids it uses", async () => {
    const { db, sender, deps } = env();
    for (let i = 0; i < 5; i++) await handleReport(report("same"), deps);
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 1, visible: false });
    expect(sender.sent).toHaveLength(0);
  });

  test("garbage reports are ignored: unknown district, upazila of another district, bad crop or disease, bad week", async () => {
    const { db, deps } = env();
    const other = listDistricts().find((d) => d.slug !== "dhaka")!;
    for (const bad of [
      report("a", { district: "atlantis" }),
      report("a", { upazila: `${other.upazilas[0].id}` }),
      report("a", { crop: "wheat" }),
      report("a", { diseaseId: "potato_late_blight" }), // valid disease, wrong crop
      report("a", { diseaseId: "healthy" }),
      report("a", { week: "last-week" }),
      report("a", { uid: "" }),
      report("a", { crop: 5 }),
    ]) {
      expect(await handleReport(bad, deps)).toBe("ignored");
    }
    expect(db.docs.size).toBe(0);
  });

  test("a suppressed alert stays hidden and sends nothing, however many report", async () => {
    const { db, sender, deps } = env();
    db.docs.set(`alerts/${ID}`, { suppressed: true, count: 0 });
    for (const u of ["a", "b", "c", "d"]) await handleReport(report(u), deps);
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 4, visible: false, suppressed: true });
    expect(sender.sent).toHaveLength(0);
  });

  test("the threshold is a parameter: raising it delays visibility", async () => {
    const { db, deps } = env({ threshold: 5 });
    for (const u of ["a", "b", "c", "d"]) await handleReport(report(u), deps);
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 4, visible: false });
    expect(await handleReport(report("e"), deps)).toBe("became_visible");
  });

  test("reporter and alert docs carry TTLs (30 and 60 days)", async () => {
    const { db, deps } = env();
    await handleReport(report("a"), deps);
    const now = Date.UTC(2026, 9, 6, 10);
    expect((db.docs.get(`alerts/${ID}/reporters/a`)!.expireAt as Date).getTime()).toBe(now + 30 * 864e5);
    expect((db.docs.get(`alerts/${ID}`)!.expireAt as Date).getTime()).toBe(now + 60 * 864e5);
    expect((db.docs.get(`alerts/${ID}`)!.lastReportAt as Date).getTime()).toBe(now);
  });

  test("different upazilas, crops, diseases and weeks are separate alerts", async () => {
    const { db, deps } = env();
    const second = `${dhaka.upazilas[1].id}`;
    await handleReport(report("a"), deps);
    await handleReport(report("a", { upazila: second }), deps);
    await handleReport(report("a", { week: "2026-W42" }), deps);
    await handleReport(report("a", { diseaseId: "rice_brown_spot" }), deps);
    expect([...db.docs.keys()].filter((k) => !k.includes("reporters"))).toHaveLength(4);
  });

  test("a failing push does not undo the count", async () => {
    const { db, sender, deps } = env();
    sender.fail = true;
    for (const u of ["a", "b"]) await handleReport(report(u), deps);
    expect(await handleReport(report("c"), deps)).toBe("became_visible");
    expect(db.docs.get(`alerts/${ID}`)).toMatchObject({ count: 3, visible: true });
  });

  test("push text is Bangla: upazila, crop, disease and count in Bangla digits", () => {
    const m = alertMessage({ district: "dhaka", upazila, crop: "rice", diseaseId: "rice_blast" }, 3, kbFixture());
    expect(m.body).toContain(dhaka.upazilas[0].name_bn);
    expect(m.body).toContain("ধান");
    expect(m.body).toContain("ধানের ব্লাস্ট রোগ");
    expect(m.body).toContain("৩ জন কৃষক");
  });

  test("isValidReport narrows valid reports", () => {
    expect(isValidReport(report("a"), kbFixture())).toBe(true);
    expect(isValidReport(report("a", { week: "2026-41" }), kbFixture())).toBe(false);
  });
});
