import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/** What "delete my data" removes (Design §10.5). Ports so the orchestration is testable without Firebase. */
export interface Eraser {
  /** `users/{uid}` and everything under it (the history docs). */
  history(uid: string): Promise<void>;
  /** The caller's `reports/` docs. Returns how many were removed. */
  reports(uid: string): Promise<number>;
  /** Storage objects under `backups/{uid}/`. */
  backups(uid: string): Promise<void>;
  /** Storage objects under `contrib/{uid}/`. */
  contrib(uid: string): Promise<void>;
}

/**
 * Runs every step even when one fails, so a partial outage deletes as much as possible, then fails loudly:
 * the app must not tell the farmer "deleted" unless everything was. Every step is idempotent, so retrying is safe.
 */
export async function eraseUser(uid: unknown, e: Eraser): Promise<{ reports: number }> {
  if (typeof uid !== "string" || uid.length === 0) throw new HttpsError("unauthenticated", "sign in required");
  let reports = 0;
  const steps: [string, () => Promise<unknown>][] = [
    ["history", () => e.history(uid)],
    ["reports", async () => void (reports = await e.reports(uid))],
    ["backups", () => e.backups(uid)],
    ["contrib", () => e.contrib(uid)],
  ];
  const failed: string[] = [];
  for (const [name, run] of steps) {
    try {
      await run();
    } catch (err) {
      console.error(`deleteMyData ${name} failed`, err);
      failed.push(name);
    }
  }
  if (failed.length > 0) throw new HttpsError("internal", `delete incomplete: ${failed.join(",")}`);
  return { reports };
}

const BATCH = 400;

export function firebaseEraser(): Eraser {
  const db = getFirestore();
  const bucket = () => getStorage().bucket();
  return {
    history: (uid) => db.recursiveDelete(db.doc(`users/${uid}`)),
    reports: async (uid) => {
      let n = 0;
      for (;;) {
        const snap = await db.collection("reports").where("uid", "==", uid).limit(BATCH).get();
        if (snap.empty) return n;
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        n += snap.size;
      }
    },
    backups: (uid) => bucket().deleteFiles({ prefix: `backups/${uid}/`, force: true }),
    contrib: (uid) => bucket().deleteFiles({ prefix: `contrib/${uid}/`, force: true }),
  };
}

/** Backs the "ইতিহাস মুছুন" button. The caller can only ever delete their own data: the uid comes from the auth token. */
export const deleteMyData = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: process.env.ENFORCE_APP_CHECK === "true",
    timeoutSeconds: 120,
    maxInstances: 5,
  },
  async (req) => {
    const out = await eraseUser(req.auth?.uid, firebaseEraser());
    return { ok: true, reports: out.reports };
  },
);
