import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineString } from "firebase-functions/params";
import { getFirestore } from "firebase-admin/firestore";
import { isValidLocation, listDistricts } from "./districts";
import { KbIndex, loadKbIndex } from "./kbIndex";
import { CROP_NAMES_BN, toBnDigits } from "./lib/cropNames";
import { defaultSender, districtTopic, type PushSender } from "./notify";
import type { DbLike } from "./quota";

export interface Report {
  uid: unknown;
  district: unknown;
  upazila: unknown;
  crop: unknown;
  diseaseId: unknown;
  week: unknown;
}

export interface AggregateDeps {
  db: DbLike;
  kb: KbIndex;
  sender: PushSender;
  /** Distinct installs needed before an alert becomes visible. A Function parameter, so it can be raised without a release. */
  threshold: number;
  now?: () => number;
}

const DAY = 864e5;
const str = (v: unknown): v is string => typeof v === "string" && v.length > 0 && v.length < 100;

/** The shape and content a report must have to count. Rules enforce the shape; this also checks meaning. */
export function isValidReport(r: Report, kb: KbIndex): r is { uid: string; district: string; upazila: string; crop: string; diseaseId: string; week: string } {
  return (
    str(r.uid) && str(r.week) && /^\d{4}-W\d{2}$/.test(r.week) &&
    str(r.crop) && str(r.diseaseId) && kb.isValid(r.crop, r.diseaseId) &&
    isValidLocation(r.district, r.upazila)
  );
}

export const alertId = (r: { district: string; upazila: string; crop: string; diseaseId: string; week: string }) =>
  `${r.district}_${r.upazila}_${r.crop}_${r.diseaseId}_${r.week}`;

/**
 * Counts one report toward its (upazila, crop, disease, week) alert. Idempotent: Firestore triggers can be delivered
 * more than once, so every reporting install is recorded under the alert and counted once.
 * Returns what happened, for tests and logs.
 */
export async function handleReport(report: Report, deps: AggregateDeps): Promise<"ignored" | "duplicate" | "counted" | "became_visible"> {
  if (!isValidReport(report, deps.kb)) return "ignored"; // garbage never reaches the feed
  const now = deps.now?.() ?? Date.now();
  const ref = deps.db.doc(`alerts/${alertId(report)}`);
  const reporter = deps.db.doc(`alerts/${alertId(report)}/reporters/${report.uid}`);

  let outcome = "counted" as "duplicate" | "counted" | "became_visible"; // assigned inside the transaction callback
  let count = 0;
  await deps.db.runTransaction(async (tx) => {
    const [alert, rep] = await Promise.all([tx.get(ref), tx.get(reporter)]); // all reads before any write
    if (rep.get("at")) {
      outcome = "duplicate";
      return;
    }
    count = Number(alert.get("count") ?? 0) + 1;
    const wasVisible = alert.get("visible") === true;
    const visible = count >= deps.threshold && alert.get("suppressed") !== true; // `suppressed` is the manual moderation switch
    tx.set(reporter, { at: new Date(now), expireAt: new Date(now + 30 * DAY) });
    tx.set(ref, {
      district: report.district, upazila: report.upazila, crop: report.crop, diseaseId: report.diseaseId, week: report.week,
      count, visible, lastReportAt: new Date(now), expireAt: new Date(now + 60 * DAY),
    }, { merge: true });
    if (visible && !wasVisible) outcome = "became_visible";
  });

  if (outcome === "became_visible") {
    // Best effort: a failed push must not undo or retry the count (a retry would see the reporter and stay silent).
    await deps.sender.send(alertMessage(report, count, deps.kb)).catch((e) => console.error("alert push failed", e));
  }
  return outcome;
}

export function alertMessage(r: { district: string; upazila: string; crop: string; diseaseId: string }, count: number, kb: KbIndex) {
  const district = listDistricts().find((d) => d.slug === r.district);
  const upazila = district?.upazilas.find((u) => `${u.id}` === r.upazila);
  return {
    topic: districtTopic(r.district),
    title: "🚨 আপনার এলাকায় রোগবালাই",
    body: `${upazila?.name_bn ?? ""} উপজেলায় ${CROP_NAMES_BN[r.crop] ?? r.crop} — ${kb.nameBn(r.diseaseId) ?? ""} (${toBnDigits(count)} জন কৃষক রিপোর্ট করেছেন)`,
    channelId: "alerts" as const,
    route: "/alerts",
  };
}

const ALERT_THRESHOLD = defineString("ALERT_THRESHOLD", { default: "3" });

export const aggregateReports = onDocumentCreated({ document: "reports/{id}", region: "asia-south1" }, async (event) => {
  const data = event.data?.data();
  if (!data) return;
  await handleReport(data as Report, {
    db: getFirestore() as unknown as DbLike,
    kb: loadKbIndex(),
    sender: defaultSender(),
    threshold: parseInt(ALERT_THRESHOLD.value(), 10) || 3,
  });
});
