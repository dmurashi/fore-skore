<template>
  <div class="page">
    <div class="card">
      <h1 class="title">CTP Entry — Flight {{ flight }} • Hole {{ hole }}</h1>

      <div class="meta">
        <div><b>Family:</b> {{ family }}</div>
        <div><b>Event:</b> {{ eventId }}</div>
        <div><b>Flight:</b> {{ flight }}</div>
        <div><b>Hole:</b> {{ hole }}</div>
      </div>

      <label class="label">Player name</label>
      <input
        class="input"
        v-model.trim="playerName"
        type="text"
        autocomplete="name"
        placeholder="Enter your name"
        :disabled="isSubmitting"
      />

      <button class="btn" :disabled="!canSubmit" @click="submit">
        {{ isSubmitting ? "Submitting..." : "Submit" }}
      </button>

      <p v-if="err" class="msg err">{{ err }}</p>
      <p v-if="ok" class="msg ok">Submitted ✅</p>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from "vue";
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

const playerName = ref("");
const isSubmitting = ref(false);
const err = ref("");
const ok = ref(false);

const isValid = computed(() => {
  const eOk = /^\d+$/.test(eventId.value);
  const hNum = Number(hole.value);
  const hOk = Number.isInteger(hNum) && hNum >= 1 && hNum <= 18;
  const fOk = /^[A-Z]$/.test(flight.value);
  const famOk = family.value.length > 0;
  return eOk && hOk && fOk && famOk;
});

const canSubmit = computed(
  () => isValid.value && playerName.value.length > 0 && !isSubmitting.value
);

async function submit() {
  err.value = "";
  ok.value = false;

  if (!isValid.value) {
    err.value = "Bad link (missing/invalid querystring).";
    return;
  }
  if (!playerName.value) {
    err.value = "Player name required.";
    return;
  }

  isSubmitting.value = true;
  try {
    const res = await fetch("https://forms.fore-skore.com/api/ctp", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        family: family.value,
        event: Number(eventId.value),
        hole: Number(hole.value),
        flight: flight.value,
        name: playerName.value,
      }),
    });

    const data = await res.json().catch(() => ({}));

    if (!res.ok || data?.ok !== true) {
      err.value = data?.error || `Submit failed (${res.status})`;
      return;
    }

    ok.value = true;
    playerName.value = "";
  } catch (e) {
    err.value = String(e?.message ?? e);
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<style scoped>
.page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  background: #f4f6fb;
  padding: 24px;
}
.card {
  width: min(760px, 92vw);
  background: white;
  border-radius: 18px;
  padding: 28px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
  border: 1px solid rgba(0, 0, 0, 0.06);
}
.title {
  margin: 0 0 16px 0;
  font-size: 34px;
  font-weight: 800;
  text-align: center;
}
.meta {
  border: 1px solid rgba(0, 0, 0, 0.12);
  background: #fbfbfd;
  border-radius: 14px;
  padding: 14px 16px;
  margin-bottom: 18px;
  font-size: 18px;
  line-height: 1.35;
}
.label {
  display: block;
  font-weight: 800;
  font-size: 20px;
  margin: 14px 0 8px;
}
.input {
  width: 100%;
  padding: 16px 18px;
  border-radius: 14px;
  border: 1px solid rgba(0, 0, 0, 0.12);
  font-size: 20px;
}
.btn {
  width: 100%;
  margin-top: 18px;
  padding: 16px 18px;
  border-radius: 14px;
  border: 0;
  font-weight: 800;
  font-size: 20px;
  background: #101827;
  color: white;
  cursor: pointer;
}
.btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}
.msg {
  margin: 14px 0 0;
  font-weight: 700;
  text-align: center;
}
.err {
  color: #b91c1c;
}
.ok {
  color: #047857;
}
</style>
