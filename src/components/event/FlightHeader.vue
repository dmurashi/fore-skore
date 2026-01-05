<script setup>
const props = defineProps({
  flight: { type: String, required: true },
  scoreModeLabel: { type: String, required: true }, // "Gross" | "Net"
  scoreMode: { type: String, required: true },      // "gross" | "net"
  prizeView: { type: Boolean, required: true },
})

const emit = defineEmits(['set-gross', 'set-net', 'toggle-prizes'])
</script>

<template>
  <div class="flight-header">
    <h2 class="flight-title">
      Scorecards – Flight {{ flight }}
      <span class="mode-paren">(</span>
      <span class="mode-label" :style="{ color: scoreModeLabel === 'Net' ? 'red' : 'green' }">
        {{ scoreModeLabel }}
      </span>
      <span class="mode-paren">)</span>
    </h2>

    <div class="mode-toggle">
      <button
        class="pill-btn"
        :class="{ 'is-active': scoreMode === 'gross' }"
        @click="emit('set-gross')"
      >
        Gross
      </button>

      <button
        class="pill-btn"
        :class="{ 'is-active': scoreMode === 'net' }"
        @click="emit('set-net')"
      >
        Net
      </button>

      <button
        type="button"
        class="pill-btn"
        :class="{ 'is-active': prizeView }"
        @click="emit('toggle-prizes')"
      >
        Prizes
      </button>
    </div>
  </div>
</template>

<style scoped>
/* =========================================================
   Layout
========================================================= */
.flight-header {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  padding: 10px 12px;
  border-radius: 5px;
  background-color: #f0f1f3;
}

.flight-title {
  white-space: nowrap;
  flex-shrink: 0;
  font-size: 18px;
  color: #111827; /* light mode */
}

.mode-toggle {
  display: inline-flex;
  gap: 7px;
  margin-left: auto;
  flex-shrink: 0;
}

</style>
