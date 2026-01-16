console.log("VITE_DATA_BASE_URL =", import.meta.env.VITE_DATA_BASE_URL);

const raw = import.meta.env.VITE_DATA_BASE_URL || "/data";
export const BASE = raw.replace(/\/+$/, "");

export const familyIndexUrl = (f) => `${BASE}/${f}/family-index.json`;

export const monthIndexUrl = (f, y, m) =>
  `${BASE}/${f}/events/${y}/${m}/index.json`;

export const eventUrl = ({ f, y, m, id }) =>
  `${BASE}/${f}/events/${y}/${m}/${id}.json`;

export const courseUrl = ({ f, y, m, id }) =>
  `${BASE}/${f}/courses/${y}/${m}/${id}.json`;

// CTP now lives at: {family}/ctp/{eventId}-ctp.json
export const ctpUrl = ({ f, id }) => `${BASE}/${f}/ctp/ctp.json`;
