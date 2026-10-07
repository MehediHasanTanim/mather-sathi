/**
 * What the configured vision model accepts. The model is a deploy parameter (VISION_MODEL), so request
 * shape must not assume one model. Cheap Haiku-class is the default (Design §7.2).
 */
export const DEFAULT_VISION_MODEL = "claude-haiku-4-5";

/** Forced tool_choice (`any`/`tool`) returns a 400 on these models; use auto + strict + prompt instead. */
export function supportsForcedToolChoice(model: string): boolean {
  return !/(fable-5-1|mythos-5-1|opus-5-5|sonnet-5-5)/.test(model);
}

/** Sampling parameters (temperature, top_p, top_k) are rejected on the newest models. */
export function supportsSampling(model: string): boolean {
  return !/(fable|mythos|opus-5|opus-4-[78]|sonnet-5)/.test(model);
}

/** Thinking-always-on models need room beyond the tool call itself. */
export function maxTokensFor(model: string): number {
  return supportsSampling(model) ? 400 : 4000;
}

/** USD per million tokens [input, output], for the eval's cost estimate. Check current pricing before relying on it. */
const PRICES: [RegExp, [number, number]][] = [
  [/haiku-4-5/, [1, 5]],
  [/sonnet-5/, [2, 10]],
  [/opus-5-5/, [4, 20]],
  [/opus-5|opus-4-[678]/, [5, 25]],
  [/fable|mythos/, [10, 50]],
];

export function priceFor(model: string): [number, number] | undefined {
  return PRICES.find(([re]) => re.test(model))?.[1];
}
