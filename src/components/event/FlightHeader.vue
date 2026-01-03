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
/* Layout */
.flight-header {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;

  /* ✅ dark-mode friendly header backing */
  padding: 10px 12px;
  border-radius: 5px;
}

.flight-title {
  white-space: nowrap;
  flex-shrink: 0;
  font-size: 18px;
  color: #111827; /* default */
}

.mode-toggle {
  display: inline-flex;
  gap: 6px;
  margin-bottom: 10px;
  margin-left: auto;
  flex-shrink: 0;
}

/* Buttons (light default) */
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

/* Responsive */
@media (max-width: 900px) {
  .mode-toggle {
    width: 100%;
    margin-left: 0;
    justify-content: flex-start;
  }
}

/* ✅ Dark mode styling */
@media (prefers-color-scheme: dark) {
  .flight-header {
    background: #e4e5e6;   /* slate-700-ish */
    border-color: #465365;
  }

  .flight-title {
    color: #0e0e0f;
  }

  .mode-paren {
    color: #0e0e0f;
  }

  .mode-btn {
    background: #374151;      /* inactive */
    border-color: #4b5563;
    color: #e5e7eb;
  }

  .mode-btn:hover {
    background: #4b5563;
  }

  .mode-btn.active {
    background: #ffffff;      /* high-contrast active */
    color: #111827;
    border-color: #60a5fa;
  }
}
</style>
