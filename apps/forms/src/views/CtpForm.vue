<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";

const route = useRoute();

const family = computed(() => String(route.query.family ?? "").trim());
const eventId = computed(() => String(route.query.event ?? "").trim());
const hole = computed(() => String(route.query.hole ?? "").trim());
const flight = computed(() =>
  String(route.query.flight ?? "")
    .trim()
    .toUpperCase()
);

const valid = computed(() => {
  if (!family.value) return false;
  if (!/^\d+$/.test(eventId.value)) return false;
  if (!/^\d+$/.test(hole.value)) return false;
  if (!/^[A-Z]$/.test(flight.value)) return false;
  const h = Number(hole.value);
  return h >= 1 && h <= 18;
});

const title = computed(() =>
  valid.value
    ? `CTP Entry — Flight ${flight.value} • Hole ${hole.value}`
    : "CTP Entry"
);
</script>

<template>
  <div class="page">
    <div class="card">
      <h1 class="title">{{ title }}</h1>

      <div v-if="!valid" class="bad">
        Missing/invalid parameters.<br />
        Expected:
        <code>?event=52&hole=2&flight=A&family=madmen</code>
      </div>

      <div v-else class="meta">
        <div><b>Family:</b> {{ family }}</div>
        <div><b>Event:</b> {{ eventId }}</div>
        <div><b>Flight:</b> {{ flight }}</div>
        <div><b>Hole:</b> {{ hole }}</div>
      </div>

      <label class="label">Player name</label>
      <input class="input" placeholder="Phase 1 (not wired yet)" disabled />

      <button class="btn" disabled>Submit (Phase 2)</button>
    </div>
  </div>
</template>

<style scoped>
.page {
  min-height: 100vh;
  display: grid;
  place-items: start center;
  padding: 32px 16px;
  background: #f6f7fb;
}
.card {
  width: 100%;
  max-width: 560px;
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  padding: 20px;
  box-shadow: 0 10px 20px rgba(0, 0, 0, 0.06);
}
.title {
  margin: 0 0 12px;
  font-size: 22px;
  font-weight: 800;
  color: #111827;
}
.bad {
  background: #fff1f2;
  border: 1px solid #fecdd3;
  color: #9f1239;
  padding: 12px;
  border-radius: 12px;
}
.meta {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  padding: 12px;
  border-radius: 12px;
  margin-bottom: 14px;
  color: #374151;
}
.label {
  display: block;
  margin: 14px 0 6px;
  font-weight: 700;
  color: #111827;
}
.input {
  width: 100%;
  padding: 12px;
  border-radius: 12px;
  border: 1px solid #e5e7eb;
  font-size: 16px;
}
.btn {
  margin-top: 14px;
  width: 100%;
  padding: 12px;
  border-radius: 12px;
  border: 0;
  background: #111827;
  color: #fff;
  font-weight: 800;
  opacity: 0.5;
}
code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
</style>
