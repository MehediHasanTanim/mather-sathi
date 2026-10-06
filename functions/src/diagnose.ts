import Anthropic from "@anthropic-ai/sdk";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret, defineString } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { classifyImage, type Classification } from "./classify";
import { generalAdvice, type GeneralAdvice } from "./general";
import { KbIndex, loadKbIndex } from "./kbIndex";
import { DEFAULT_VISION_MODEL } from "./lib/modelCaps";
import type { MessagesClient } from "./lib/types";
import { consumeQuota, type DbLike } from "./quota";

export const MAX_JPEG_BYTES = 600 * 1024;
export const MAX_OTHER_LABEL = 40;

export interface DiagnoseDeps {
  db: DbLike;
  kb: KbIndex;
  client: MessagesClient;
  model: string;
  dailyCap: number;
  now?: () => number;
}

export type DiagnoseResponse =
  | (Omit<Classification, "usage"> & { mode: "classified"; kb_seq: number })
  | (Omit<GeneralAdvice, "usage"> & { mode: "general" });

type ParsedCrop = { kind: "launch"; crop: string } | { kind: "other"; label: string };

/** base64 string → JPEG bytes, or invalid-argument. Checks size and magic bytes before anything is spent. */
export function decodeJpeg(image: unknown): Buffer {
  if (typeof image !== "string" || image.length === 0) throw new HttpsError("invalid-argument", "image required");
  if (image.length > Math.ceil((MAX_JPEG_BYTES * 4) / 3) + 8) throw new HttpsError("invalid-argument", "image too large");
  const buf = Buffer.from(image, "base64");
  if (buf.length > MAX_JPEG_BYTES) throw new HttpsError("invalid-argument", "image too large");
  if (buf.length < 3 || buf[0] !== 0xff || buf[1] !== 0xd8 || buf[2] !== 0xff) {
    throw new HttpsError("invalid-argument", "not a JPEG");
  }
  return buf;
}

export function parseCrop(crop: unknown, kb: KbIndex): ParsedCrop {
  if (typeof crop === "string") {
    if (kb.hasCrop(crop)) return { kind: "launch", crop };
    if (crop.startsWith("other:")) {
      const label = crop.slice(6).trim();
      const len = Array.from(label).length;
      if (len >= 1 && len <= MAX_OTHER_LABEL && !/\p{C}/u.test(label)) return { kind: "other", label };
    }
  }
  throw new HttpsError("invalid-argument", "bad crop");
}

/** Provider failures become codes the app maps to its fallback path (Design §6.5). */
export function mapProviderError(e: unknown): HttpsError {
  if (e instanceof HttpsError) return e;
  if (e instanceof Anthropic.APIConnectionTimeoutError) return new HttpsError("deadline-exceeded", "model timeout");
  if (e instanceof Anthropic.APIError) return new HttpsError("unavailable", `model error ${e.status ?? ""}`.trim());
  return new HttpsError("internal", "diagnosis failed");
}

export async function handleDiagnose(
  data: unknown,
  auth: { uid: string } | undefined,
  deps: DiagnoseDeps,
): Promise<DiagnoseResponse> {
  if (!auth) throw new HttpsError("unauthenticated", "sign-in required");

  // Server-side kill switch: stops spend within a minute (drill in task 9.4).
  const runtime = (await deps.db.doc("config/runtime").get()).data();
  if (runtime?.cloudEnabled === false) throw new HttpsError("unavailable", "disabled");

  const body = (data ?? {}) as { image?: unknown; crop?: unknown };
  const jpeg = decodeJpeg(body.image);
  const crop = parseCrop(body.crop, deps.kb);

  await consumeQuota(deps.db, auth.uid, deps.dailyCap, deps.now?.());

  try {
    if (crop.kind === "launch") {
      const { usage: _u, ...result } = await classifyImage(
        deps.client, deps.model, jpeg, crop.crop, deps.kb.forCrop(crop.crop),
      );
      return { mode: "classified", ...result, kb_seq: deps.kb.seq };
    }
    const { usage: _u, ...advice } = await generalAdvice(deps.client, deps.model, jpeg, crop.label);
    return { mode: "general", ...advice };
  } catch (e) {
    throw mapProviderError(e);
  }
}

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const DAILY_CAP = defineString("DAILY_CAP", { default: "30" });
const VISION_MODEL = defineString("VISION_MODEL", { default: DEFAULT_VISION_MODEL });

export const diagnose = onCall(
  {
    region: "asia-south1",
    // Roll out in monitor mode (ENFORCE_APP_CHECK unset), then enforce (task 9.4).
    enforceAppCheck: process.env.ENFORCE_APP_CHECK === "true",
    secrets: [ANTHROPIC_API_KEY],
    memory: "512MiB",
    timeoutSeconds: 30,
    maxInstances: 20,
    minInstances: 1, // avoids a 1-3 s cold start eating the client's 8 s budget
  },
  (req) =>
    handleDiagnose(req.data, req.auth, {
      db: getFirestore() as unknown as DbLike,
      kb: loadKbIndex(),
      client: new Anthropic({ apiKey: ANTHROPIC_API_KEY.value(), timeout: 6000, maxRetries: 0 }),
      model: VISION_MODEL.value(),
      dailyCap: parseInt(DAILY_CAP.value(), 10),
    }),
);
