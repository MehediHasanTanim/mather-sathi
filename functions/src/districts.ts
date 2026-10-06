import districtsJson from "./districts.json";

interface DistrictRow {
  id: number;
  slug: string;
  name_bn: string;
  name_en: string;
  lat: number;
  lon: number;
  upazilas: { id: number; name_bn: string; name_en: string }[];
}

const districts = districtsJson as DistrictRow[];

export function listDistricts(): DistrictRow[] {
  return districts;
}

/** A report/alert location is valid only for a known district slug and one of its upazila ids. */
export function isValidLocation(districtSlug: unknown, upazilaId: unknown): boolean {
  if (typeof districtSlug !== "string" || typeof upazilaId !== "string") return false;
  const d = districts.find((x) => x.slug === districtSlug);
  return !!d && d.upazilas.some((u) => `${u.id}` === upazilaId);
}
