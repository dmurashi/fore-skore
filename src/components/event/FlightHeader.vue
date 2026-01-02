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
        class="mode-btn"
        :class="{ active: scoreMode === 'gross' }"
        @click="emit('set-gross')"
      >
        Gross
      </button>

      <button
        class="mode-btn"
        :class="{ active: scoreMode === 'net' }"
        @click="emit('set-net')"
      >
        Net
      </button>

      <button
        type="button"
        class="mode-btn"
        :class="{ active: prizeView }"
        @click="emit('toggle-prizes')"
      >
        Prizes
      </button>
    </div>
  </div>
</template>



<style scoped>
/* Toggle */

.mode-toggle {
  display: inline-flex;
  gap: 6px;
  margin-bottom: 10px;
  margin-left: auto;
}

.flight-header {
  display: flex;
  align-items: center;
  flex-wrap: wrap;   /* allow wrapping */
  gap: 12px;
}

.flight-title {
  white-space: nowrap;
  flex-shrink: 0;
  font-size: 18px;
}

.mode-toggle {
  margin-left: auto; /* push toggles right on wide screens */
  flex-shrink: 0;
}

.flight-title { white-space: nowrap; }

.mode-btn {
  padding: 6px 14px;
  border: 1px solid #e5e7eb;
  background: #f9fafb;
  border-radius: 10px;
  font-weight: 600;
  font-size: 13px;
  color: #6b7280;
  cursor: pointer;
  transition:
    border-color 120ms ease,
    color 120ms ease,
    background-color 120ms ease;
}

.mode-btn:hover {
  background: #f3f4f6;
}

.mode-btn.active {
  background: #ffffff;
  color: #111827;
  border-color: #2563eb;
}

@media (max-width: 900px) {
  .mode-toggle {
    width: 100%;
    margin-left: 0;
    justify-content: flex-start;
  }
}

</style>