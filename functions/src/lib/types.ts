import type Anthropic from "@anthropic-ai/sdk";

/** The slice of the Anthropic client we use; lets tests inject a fake. */
export interface MessagesClient {
  messages: {
    create(params: Anthropic.MessageCreateParamsNonStreaming): Promise<Anthropic.Message>;
  };
}

export type Confidence = "high" | "medium" | "low";
export type ImageIssue = "none" | "blurry" | "not_a_plant" | "wrong_crop" | "too_dark";

export const CONFIDENCES: Confidence[] = ["high", "medium", "low"];
export const IMAGE_ISSUES: ImageIssue[] = ["none", "blurry", "not_a_plant", "wrong_crop", "too_dark"];

export interface Usage {
  input_tokens: number;
  output_tokens: number;
}
