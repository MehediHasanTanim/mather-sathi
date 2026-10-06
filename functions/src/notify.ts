import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

/** One push to everyone subscribed to a district topic. */
export interface PushMessage {
  topic: string;
  title: string;
  body: string;
  channelId: "alerts" | "weather";
  /** In-app route opened on tap. The app only honours an allow-list of routes. */
  route: string;
}

export interface PushSender {
  send(m: PushMessage): Promise<void>;
}

/** FCM topic for a district slug. The app subscribes to the same name (lib/features/notifications). */
export const districtTopic = (slug: string): string => `d_${slug}`;

export class FcmSender implements PushSender {
  async send(m: PushMessage): Promise<void> {
    await getMessaging().send({
      topic: m.topic,
      notification: { title: m.title, body: m.body },
      data: { route: m.route },
      android: { notification: { channelId: m.channelId } },
    });
  }
}

/**
 * Emulator only: nothing can be sent without real credentials, so the would-be push is recorded in `_emulator_outbox`.
 * The end-to-end script (task 7.7) counts these to prove one push per alert.
 */
export class EmulatorOutboxSender implements PushSender {
  async send(m: PushMessage): Promise<void> {
    await getFirestore().collection("_emulator_outbox").add({ ...m, at: new Date() });
  }
}

export function defaultSender(): PushSender {
  return process.env.FUNCTIONS_EMULATOR === "true" ? new EmulatorOutboxSender() : new FcmSender();
}
