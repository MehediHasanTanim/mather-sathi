import { HttpsError } from "firebase-functions/v2/https";
import { dhakaDayKey } from "./util/dhakaDay";

/** Structural slice of Firestore used here; the real `Firestore` satisfies it, tests use an in-memory fake. */
export interface TxLike {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  get(ref: any): Promise<{ get(field: string): unknown }>;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  set(ref: any, data: Record<string, unknown>, options?: { merge?: boolean }): unknown;
}
export interface DbLike {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  doc(path: string): any;
  runTransaction<T>(fn: (tx: TxLike) => Promise<T>): Promise<T>;
}

const TWO_DAYS_MS = 2 * 864e5;

/**
 * Counts one cloud diagnosis against the install's daily cap (Dhaka-time day), atomically.
 * `expireAt` carries a Firestore TTL policy so old quota docs clean themselves up.
 * Throws `resource-exhausted` when the cap is already reached.
 */
export async function consumeQuota(db: DbLike, uid: string, cap: number, nowMs = Date.now()): Promise<void> {
  const ref = db.doc(`quotas/${uid}_${dhakaDayKey(nowMs)}`);
  await db.runTransaction(async (tx) => {
    const used = Number((await tx.get(ref)).get("count") ?? 0);
    if (used >= cap) throw new HttpsError("resource-exhausted", "daily cap");
    tx.set(ref, { count: used + 1, uid, expireAt: new Date(nowMs + TWO_DAYS_MS) });
  });
}
