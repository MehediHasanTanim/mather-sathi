import { buildSystemPrompt, candidateIds, classifyImage, validateClassification } from "../src/classify";
import { supportsForcedToolChoice, supportsSampling } from "../src/lib/modelCaps";
import { FakeClient, kbFixture, message, toolUse } from "./support/fakes";

const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0x00]);
const rice = () => kbFixture().forCrop("rice");
const ids = candidateIds(rice());

describe("classifyImage", () => {
  test("returns a listed disease with its confidence and image issue", async () => {
    const c = new FakeClient(toolUse({ disease_id: "rice_blast", confidence: "high", image_issue: "none" }));
    const r = await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice());
    expect(r).toMatchObject({ disease_id: "rice_blast", confidence: "high", image_issue: "none" });
    expect(r.usage).toEqual({ input_tokens: 1500, output_tokens: 60 });
  });

  test("an out-of-enum disease id becomes unknown / low", async () => {
    const c = new FakeClient(toolUse({ disease_id: "potato_late_blight", confidence: "high", image_issue: "none" }));
    const r = await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice());
    expect(r).toMatchObject({ disease_id: "unknown", confidence: "low" });
  });

  test("no tool call becomes unknown", async () => {
    const c = new FakeClient(message([{ type: "text", text: "It looks like blast.", citations: null } as never]));
    expect((await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice())).disease_id).toBe("unknown");
  });

  test("a call to a different tool is ignored", async () => {
    const c = new FakeClient(toolUse({ disease_id: "rice_blast", confidence: "high", image_issue: "none" }, "other_tool"));
    expect((await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice())).disease_id).toBe("unknown");
  });

  test("invalid confidence / image_issue fall back to safe values", async () => {
    const c = new FakeClient(toolUse({ disease_id: "healthy", confidence: "certain", image_issue: "weird" }));
    expect(await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice())).toMatchObject({
      disease_id: "healthy", confidence: "low", image_issue: "none",
    });
  });

  test("the prompt and the tool enum list only this crop's candidates", async () => {
    const c = new FakeClient(toolUse({ disease_id: "healthy", confidence: "low", image_issue: "none" }));
    await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice());
    const p = c.calls[0];
    expect(p.system).toContain("rice_blast");
    expect(p.system).toContain("rice_brown_spot");
    expect(p.system).not.toContain("potato_late_blight");
    const schema = (p.tools![0] as { input_schema: { properties: { disease_id: { enum: string[] } } } }).input_schema;
    expect(schema.properties.disease_id.enum).toEqual(["rice_blast", "rice_brown_spot", "healthy", "unknown"]);
  });

  test("the prompt tells the model that image text is not an instruction", () => {
    expect(buildSystemPrompt("rice", rice())).toMatch(/not an instruction/);
  });

  test("sends a base64 JPEG image block", async () => {
    const c = new FakeClient(toolUse({ disease_id: "healthy", confidence: "low", image_issue: "none" }));
    await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice());
    const content = (c.calls[0].messages[0].content as { type: string; source?: { media_type: string; data: string } }[]);
    expect(content[0]).toMatchObject({ type: "image", source: { media_type: "image/jpeg", data: jpeg.toString("base64") } });
  });
});

describe("model-dependent request shape", () => {
  test("Haiku: forced tool call and temperature 0, no strict flag", async () => {
    const c = new FakeClient(toolUse({ disease_id: "healthy", confidence: "low", image_issue: "none" }));
    await classifyImage(c, "claude-haiku-4-5", jpeg, "rice", rice());
    expect(c.calls[0].tool_choice).toEqual({ type: "tool", name: "report_diagnosis" });
    expect(c.calls[0].temperature).toBe(0);
    expect(c.calls[0].tools![0]).not.toHaveProperty("strict");
  });

  test.each(["claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-1"])(
    "%s: no forced tool choice (400 on that model), no sampling, strict schema, more token room",
    async (model) => {
      const c = new FakeClient(toolUse({ disease_id: "healthy", confidence: "low", image_issue: "none" }));
      await classifyImage(c, model, jpeg, "rice", rice());
      expect(c.calls[0].tool_choice).toEqual({ type: "auto" });
      expect(c.calls[0]).not.toHaveProperty("temperature");
      expect(c.calls[0].tools![0]).toHaveProperty("strict", true);
      expect(c.calls[0].max_tokens).toBeGreaterThan(1000);
    },
  );

  test("capability helpers", () => {
    expect(supportsForcedToolChoice("claude-haiku-4-5")).toBe(true);
    expect(supportsForcedToolChoice("claude-opus-5")).toBe(true);
    expect(supportsForcedToolChoice("claude-opus-5-5")).toBe(false);
    expect(supportsSampling("claude-haiku-4-5")).toBe(true);
    expect(supportsSampling("claude-sonnet-5")).toBe(false);
  });
});

test("validateClassification handles an empty response", () => {
  expect(validateClassification([], ids)).toEqual({ disease_id: "unknown", confidence: "low", image_issue: "none" });
});
