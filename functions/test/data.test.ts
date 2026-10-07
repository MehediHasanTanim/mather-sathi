import fs from "node:fs";
import path from "node:path";
import { listDistricts, isValidLocation } from "../src/districts";
import { loadKbIndex } from "../src/kbIndex";

const repo = path.join(__dirname, "../..");

test("the Functions copy of districts.json matches the app asset", () => {
  expect(fs.readFileSync(path.join(repo, "functions/src/districts.json"), "utf8"))
    .toBe(fs.readFileSync(path.join(repo, "assets/data/districts.json"), "utf8"));
});

test("district and upazila validation", () => {
  const d = listDistricts().find((x) => x.slug === "dhaka")!;
  expect(listDistricts()).toHaveLength(64);
  expect(isValidLocation("dhaka", `${d.upazilas[0].id}`)).toBe(true);
  expect(isValidLocation("dhaka", "999999")).toBe(false);
  expect(isValidLocation("atlantis", "1")).toBe(false);
  expect(isValidLocation(1, "1")).toBe(false);
});

test("the generated KB index loads and groups by crop", () => {
  const kb = loadKbIndex();
  expect(kb.hasCrop("rice")).toBe(true);
  expect(kb.hasCrop("wheat")).toBe(false);
  expect(kb.forCrop("potato").every((e) => e.id.startsWith("potato_"))).toBe(true);
  expect(kb.isValid("rice", kb.forCrop("rice")[0].id)).toBe(true);
  expect(kb.isValid("potato", kb.forCrop("rice")[0].id)).toBe(false);
  expect(kb.seq).toBeGreaterThan(0);
});
