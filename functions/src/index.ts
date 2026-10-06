import { initializeApp } from "firebase-admin/app";

initializeApp();

export { diagnose } from "./diagnose";
export { aggregateReports } from "./aggregateReports";
export { refreshWeather } from "./weather/refreshWeather";
