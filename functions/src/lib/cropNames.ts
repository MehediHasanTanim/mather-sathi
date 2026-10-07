/** Bangla crop names for push text (the app has its own copy in the ARB file). */
export const CROP_NAMES_BN: Record<string, string> = {
  rice: "ধান", jute: "পাট", potato: "আলু", tomato: "টমেটো",
  brinjal: "বেগুন", chili: "মরিচ", onion: "পেঁয়াজ", mustard: "সরিষা",
};

const BN_DIGITS = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"];
export const toBnDigits = (s: string | number): string => `${s}`.replace(/[0-9]/g, (d) => BN_DIGITS[Number(d)]);
