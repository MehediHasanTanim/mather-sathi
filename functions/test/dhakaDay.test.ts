import { dhakaDayKey } from "../src/util/dhakaDay";

test("rolls the day at 18:00 UTC (midnight in Dhaka)", () => {
  expect(dhakaDayKey(Date.UTC(2026, 9, 6, 17, 59))).toBe("2026-10-06");
  expect(dhakaDayKey(Date.UTC(2026, 9, 6, 18, 0))).toBe("2026-10-07");
});
