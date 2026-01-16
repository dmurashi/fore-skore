<!-- src/views/CTPLeadersView.vue -->
<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from "vue";
import { useRoute } from "vue-router";
import { ctpUrl } from "@/config/datasources";

const route = useRoute();

// ✅ event id (param-first, query fallback)
const eventId = computed(() =>
  String(route.params.eventId ?? route.query.event_id ?? "")
);

// TEMP: hardcode while UI settles (next step = derive from event JSON)
const family = "madmen";
const year = "2026";
const month = "01";

const data = ref(null);
const loading = ref(false);
const error = ref("");

const flightFilter = ref("ALL");
const holeFilter = ref("ALL");
const search = ref("");

const POLL_MS = 15000;
let timer = null;

function norm(s) {
  return String(s ?? "").trim();
}

function matchesSearch(name) {
  const q = norm(search.value).toLowerCase();
  if (!q) return true;
  return norm(name).toLowerCase().includes(q);
}

async function load() {
  if (!eventId.value) return;

  loading.value = true;
  error.value = "";

  try {
    const url = ctpUrl({
      f: family,
      y: year,
      m: month,
      id: eventId.value,
    });

    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data.value = await res.json();
  } catch (e) {
    error.value = e?.message ?? "Failed to load CTP feed";
  } finally {
    loading.value = false;
  }
}

const holesList = computed(() => {
  const holes = data.value?.holes ?? {};
  return Object.keys(holes).sort((a, b) => Number(a) - Number(b));
});

const visibleModel = computed(() => {
  const holes = data.value?.holes ?? {};
  const out = [];

  for (const hole of Object.keys(holes)) {
    if (holeFilter.value !== "ALL" && String(holeFilter.value) !== String(hole))
      continue;

    const flightsObj = holes[hole] ?? {};
    const flights = Object.keys(flightsObj).sort();

    const flightCards = [];

    for (const flight of flights) {
      if (flightFilter.value !== "ALL" && flightFilter.value !== flight)
        continue;

      const block = flightsObj[flight];
      const entries = Array.isArray(block?.entries) ? block.entries : [];
      const filteredEntries = entries
        .slice(1)
        .filter((e) => matchesSearch(e?.player));

      if (search.value.trim() && filteredEntries.length === 0) continue;

      flightCards.push({
        flight,
        holder: block?.holder ?? entries[0] ?? null,
        entries: filteredEntries,
        totalEntries: entries.length,
      });
    }

    if (flightCards.length) out.push({ hole, flightCards });
  }

  return out;
});

onMounted(async () => {
  await load();
  timer = setInterval(load, POLL_MS);
});

onBeforeUnmount(() => {
  if (timer) clearInterval(timer);
});
</script>

<template>
  <div class="ctp-page">
    <div class="ctp-header">
      <div class="ctp-title">
        <h1>CTP Leaders</h1>
        <div class="ctp-sub">
          Event {{ eventId }}
          <span v-if="data?.updated_at">• Updated {{ data.updated_at }}</span>
        </div>
      </div>

      <div class="ctp-controls">
        <select v-model="flightFilter" class="ctl">
          <option value="ALL">All Flights</option>
          <option value="A">Flight A</option>
          <option value="B">Flight B</option>
          <option value="C">Flight C</option>
        </select>

        <select v-model="holeFilter" class="ctl">
          <option value="ALL">All Holes</option>
          <option v-for="h in holesList" :key="h" :value="h">
            Hole {{ h }}
          </option>
        </select>

        <input v-model="search" class="ctl" placeholder="Search player name…" />

        <button class="btn" @click="load" :disabled="loading">
          {{ loading ? "Refreshing…" : "Refresh" }}
        </button>
      </div>
    </div>

    <div v-if="error" class="error">⚠️ {{ error }}</div>

    <div v-if="!error && visibleModel.length === 0" class="empty">
      No CTP entries yet.
    </div>

    <div
      v-for="section in visibleModel"
      :key="section.hole"
      class="hole-section"
    >
      <div class="hole-title">
        <span>Hole {{ section.hole }}</span>
      </div>

      <div class="flight-grid">
        <div
          v-for="card in section.flightCards"
          :key="card.flight"
          class="flight-card"
        >
          <div class="flight-card-header">
            <div class="flight-name">Flight {{ card.flight }}</div>
            <div class="flight-meta">{{ card.totalEntries }} entries</div>
          </div>

          <div class="holder" v-if="card.holder">
            <div class="holder-label">Current holder</div>
            <div class="holder-name">{{ card.holder.player }}</div>
            <div class="holder-time">{{ card.holder.created_at }}</div>
          </div>

          <div class="entries">
            <div class="entries-title">Previous</div>
            <div v-for="(e, idx) in card.entries" :key="idx" class="entry-row">
              <div class="entry-name">{{ e.player }}</div>
              <div class="entry-time">{{ e.created_at }}</div>
            </div>

            <div v-if="card.entries.length === 0" class="entries-empty">
              No matching entries.
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ctp-page {
  padding: 16px;
  max-width: 1100px;
  margin: 0 auto;
}
.ctp-header {
  display: flex;
  gap: 12px;
  align-items: flex-end;
  justify-content: space-between;
  flex-wrap: wrap;
}
.ctp-title h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 800;
}
.ctp-sub {
  margin-top: 4px;
  color: #6b7280;
  font-size: 13px;
}
.ctp-controls {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-wrap: wrap;
}
.ctl {
  padding: 8px 10px;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  background: #fff;
  font-size: 13px;
}
.btn {
  padding: 8px 12px;
  border: 1px solid #111827;
  border-radius: 10px;
  background: #111827;
  color: #fff;
  font-weight: 700;
  font-size: 13px;
  cursor: pointer;
}
.btn:disabled {
  opacity: 0.6;
  cursor: default;
}

.error {
  margin-top: 12px;
  padding: 10px 12px;
  border: 1px solid #fecaca;
  background: #fff1f2;
  color: #991b1b;
  border-radius: 12px;
}
.empty {
  margin-top: 12px;
  color: #6b7280;
}

.hole-section {
  margin-top: 18px;
}

.hole-title {
  margin: 48px 0 22px;
  text-align: center;
  position: relative;
  padding: 14px 0;
}

.hole-title::before {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  top: 50%;
  height: 6px;
  transform: translateY(-50%);
  background: linear-gradient(
    to right,
    transparent,
    rgba(17, 24, 39, 0.1),
    transparent
  );
  border-radius: 999px;
}

.hole-title span {
  position: relative;
  display: inline-block;
  padding: 10px 22px;
  border-radius: 999px;
  background: #111827;
  color: #ffffff;
  font-weight: 900;
  font-size: 18px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.18);
}

.flight-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 12px;
}
.flight-card {
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  padding: 12px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.04);
}

.flight-card-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 8px;
}
.flight-name {
  font-weight: 900;
}
.flight-meta {
  color: #6b7280;
  font-size: 12px;
}

.holder {
  border: 1px solid #d1fae5;
  background: #ecfdf5;
  border-radius: 14px;
  padding: 10px;
  margin-bottom: 10px;
}
.holder-label {
  font-size: 12px;
  color: #065f46;
  font-weight: 800;
}
.holder-name {
  font-size: 16px;
  font-weight: 900;
  margin-top: 2px;
  color: #064e3b;
}
.holder-time {
  font-size: 12px;
  color: #047857;
  margin-top: 2px;
}

.entries-title {
  font-size: 12px;
  color: #6b7280;
  font-weight: 800;
  margin-bottom: 6px;
}
.entry-row {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  padding: 6px 0;
  border-bottom: 1px dashed #e5e7eb;
}
.entry-row:last-child {
  border-bottom: 0;
}
.entry-name {
  font-weight: 500;
  color: #111827;
}
.entry-time {
  font-size: 12px;
  color: #6b7280;
  white-space: nowrap;
}
.entries-empty {
  color: #9ca3af;
  font-size: 13px;
  padding: 6px 0;
}

@media (max-width: 480px) {
  .hole-title span {
    font-size: 16px;
    padding: 8px 18px;
  }
}
</style>
