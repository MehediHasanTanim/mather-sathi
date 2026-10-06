import type { Forecast } from "./weather";

/** Source of a 3-day forecast. The provider is swappable: check its terms against commercial use first (plan task O6). */
export interface WeatherProvider {
  fetch(lat: number, lon: number): Promise<Forecast>;
}

interface OpenMeteoResponse {
  hourly?: { relative_humidity_2m?: (number | null)[] };
  daily?: {
    precipitation_probability_max?: (number | null)[];
    precipitation_sum?: (number | null)[];
    temperature_2m_min?: (number | null)[];
    temperature_2m_max?: (number | null)[];
  };
}

const nums = (a?: (number | null)[]): number[] => (a ?? []).filter((v): v is number => typeof v === "number");

/** Maps the Open-Meteo `/v1/forecast` JSON (hourly humidity, daily rain/temperature) to a [Forecast]. */
export function parseOpenMeteo(json: unknown): Forecast {
  const j = json as OpenMeteoResponse;
  return {
    humidity: nums(j.hourly?.relative_humidity_2m),
    rainProb: nums(j.daily?.precipitation_probability_max),
    rainMm: nums(j.daily?.precipitation_sum),
    tMin: nums(j.daily?.temperature_2m_min),
    tMax: nums(j.daily?.temperature_2m_max),
  };
}

export class OpenMeteoProvider implements WeatherProvider {
  constructor(private readonly fetchImpl: typeof fetch = fetch, private readonly baseUrl = "https://api.open-meteo.com/v1/forecast") {}

  async fetch(lat: number, lon: number): Promise<Forecast> {
    const url =
      `${this.baseUrl}?latitude=${lat}&longitude=${lon}&forecast_days=3&timezone=Asia%2FDhaka` +
      `&hourly=relative_humidity_2m` +
      `&daily=precipitation_probability_max,precipitation_sum,temperature_2m_min,temperature_2m_max`;
    const res = await this.fetchImpl(url, { signal: AbortSignal.timeout(15_000) });
    if (!res.ok) throw new Error(`weather provider HTTP ${res.status}`);
    return parseOpenMeteo(await res.json());
  }
}
