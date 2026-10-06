import type Anthropic from "@anthropic-ai/sdk";
import { KbIndex } from "../../src/kbIndex";
import type { MessagesClient } from "../../src/lib/types";
import type { DbLike, TxLike } from "../../src/quota";

/** In-memory stand-in for the slice of Firestore the functions use. */
export class FakeDb implements DbLike {
  docs = new Map<string, Record<string, unknown>>();

  doc(path: string) {
    return {
      path,
      set: async (data: Record<string, unknown>) => void this.docs.set(path, data),
      get: async () => ({ data: () => this.docs.get(path), get: (f: string) => this.docs.get(path)?.[f], exists: this.docs.has(path) }),
    };
  }

  async runTransaction<T>(fn: (tx: TxLike) => Promise<T>): Promise<T> {
    const writes: [string, Record<string, unknown>][] = [];
    const tx: TxLike = {
      get: async (ref: { path: string }) => ({ get: (f: string) => this.docs.get(ref.path)?.[f] }),
      set: (ref: { path: string }, data, options) =>
        void writes.push([ref.path, options?.merge ? { ...(this.docs.get(ref.path) ?? {}), ...data } : data]),
    };
    const out = await fn(tx);
    for (const [p, d] of writes) this.docs.set(p, d);
    return out;
  }
}

export const kbFixture = () =>
  new KbIndex({
    schema: 1,
    version: "test",
    seq: 7,
    entries: [
      { id: "rice_blast", crop: "rice", name_en: "Rice blast", name_bn: "ধানের ব্লাস্ট রোগ", ai_hint_en: "Eye-shaped lesions." },
      { id: "rice_brown_spot", crop: "rice", name_en: "Rice brown spot", name_bn: "ধানের বাদামি দাগ", ai_hint_en: "Small brown spots." },
      { id: "potato_late_blight", crop: "potato", name_en: "Potato late blight", name_bn: "আলুর লেট ব্লাইট", ai_hint_en: "Water-soaked patches." },
    ],
  });

export function toolUse(input: unknown, name = "report_diagnosis"): Anthropic.Message {
  return message([{ type: "tool_use", id: "toolu_1", name, input, caller: { type: "direct" } } as Anthropic.ToolUseBlock]);
}

export function message(content: Anthropic.ContentBlock[]): Anthropic.Message {
  return {
    id: "msg_1", type: "message", role: "assistant", model: "m", content, stop_reason: "tool_use",
    stop_sequence: null, usage: { input_tokens: 1500, output_tokens: 60 },
  } as unknown as Anthropic.Message;
}

export class FakeClient implements MessagesClient {
  calls: Anthropic.MessageCreateParamsNonStreaming[] = [];
  constructor(private reply: Anthropic.Message | (() => Promise<Anthropic.Message>)) {}
  messages = {
    create: async (p: Anthropic.MessageCreateParamsNonStreaming) => {
      this.calls.push(p);
      return typeof this.reply === "function" ? this.reply() : this.reply;
    },
  };
}

/** Smallest thing that passes the JPEG magic-byte check. */
export const jpegBase64 = (bytes = 2000) => Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(bytes)]).toString("base64");

import type { PushMessage, PushSender } from "../../src/notify";

export class FakeSender implements PushSender {
  sent: PushMessage[] = [];
  fail = false;
  async send(m: PushMessage): Promise<void> {
    if (this.fail) throw new Error("fcm down");
    this.sent.push(m);
  }
}
