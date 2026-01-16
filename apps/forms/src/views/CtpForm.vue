<!-- SCRIPT -->
<script setup>
import { computed, ref } from "vue";
import { useRoute } from "vue-router";

import eventLogo from "@/assets/logos/madmen-mvcc.png";

const route = useRoute();

const family = computed(() => String(route.query.family ?? "").trim());
const hole = computed(() => String(route.query.hole ?? "").trim());
const flight = computed(() =>
  String(route.query.flight ?? "")
    .trim()
    .toUpperCase()
);

const familyLabel = computed(() =>
  family.value
    ? family.value.charAt(0).toUpperCase() + family.value.slice(1)
    : ""
);

const playerName = ref("");
const isSubmitting = ref(false);
const err = ref("");
const ok = ref(false);

/**
 * ✅ VALIDATION — event-agnostic
 */
const isValid = computed(() => {
  const hNum = Number(hole.value);
  const hOk = Number.isInteger(hNum) && hNum >= 1 && hNum <= 18;
  const fOk = /^[A-Z]$/.test(flight.value);
  const famOk = family.value.length > 0;
  return hOk && fOk && famOk;
});

const canSubmit = computed(
  () => isValid.value && playerName.value.length > 0 && !isSubmitting.value
);

async function submit() {
  err.value = "";

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
    const res = await fetch("https://api.fore-skore.com/api/ctp", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        family: family.value,
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

    // 🔁 Redirect to generic CTP leaders
    setTimeout(() => {
      window.location.href = "https://fore-skore.com/events/ctp";
    }, 300);
  } catch (e) {
    err.value = String(e?.message ?? e);
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<!-- TEMPLATE -->
<template>
  <div class="page">
    <div class="card">
      <img
        v-if="eventLogo"
        :src="eventLogo"
        alt="Event logo"
        class="site-logo"
      />
      <h1 class="title">{{ familyLabel }} CTP</h1>
      <h2 class="title2">Hole {{ hole }} - Flight {{ flight }}</h2>

      <label class="label">Enter name</label>
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

<!-- STYLE -->
<style scoped>
.page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  background: #f3f4f6; /* same light gray as event pages */
  padding: 24px;
  font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI",
    sans-serif;
  color: #111827;
}

/* Card matches scorecard containers */
.card {
  width: 100%;
  background: #ffffff;
  border-radius: 12px;
  padding: 10px;
  max-width: 720px;
  border: 1px solid #e5e7eb;
  box-shadow: none; /* kill marketing shadow */
}

.site-logo {
  display: block;
  max-width: 140px;
  max-height: 140px;
  width: auto;
  height: auto;
  margin: 0 auto 12px;
  object-fit: contain;
}

/* Titles */
.title {
  margin: 0 0 4px 0;
  font-size: 28px;
  font-weight: 700;
  text-align: center;
  letter-spacing: -0.01em;
}

.title2 {
  margin: 14px 0 14px 0;
  font-size: 24px;
  font-weight: 700;
  text-align: center;
  color: #0f55b8;
}

/* Meta summary block */
.meta {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 12px 14px;
  margin-bottom: 16px;
  font-size: 14px;
  line-height: 1.4;
}

.meta b {
  font-weight: 600;
}

/* Label */
.label {
  display: block;
  font-weight: 600;
  font-size: 14px;
  margin: 12px 0 6px;
}

/* Input — same energy as leaderboard cells */
.input {
  width: 100%;
  box-sizing: border-box;

  font-size: clamp(14px, 1.2vw, 16px);
  padding: clamp(8px, 1.1vw, 12px) clamp(10px, 1.4vw, 14px);

  line-height: 1.4;
  border-radius: 8px;
  border: 1px solid #d1d5db;
}

.input:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.15);
}

/* Submit button — matches Flight / Gross toggle */
.btn {
  width: 100%;
  margin-top: 16px;
  margin-bottom: 16px;

  height: clamp(40px, 4.5vw, 46px);
  font-size: clamp(14px, 1.2vw, 16px);

  border-radius: 10px;
  border: none;
  font-weight: 700;
  background: #111827;
  color: #ffffff;
  cursor: pointer;
}

.btn:disabled {
  background: #9ca3af;
  cursor: not-allowed;
}

/* Messages */
.msg {
  margin: 12px 0 0;
  font-weight: 600;
  text-align: center;
  font-size: 14px;
}

.err {
  color: #b91c1c;
}

.ok {
  color: #047857;
}
</style>
