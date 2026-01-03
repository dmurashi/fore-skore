<!--  FlightPrizeSummaryMobile.vue -->
<script setup>
import { computed } from 'vue'
import { formatCurrency } from '@/utils/money.js'

const props = defineProps({
  flightName: { type: String, required: true },
  playerCount: { type: Number, required: true },
  summary: { type: Object, required: true },
})

const hasPlayers = computed(() =>
  Array.isArray(props.summary.players) && props.summary.players.length > 0
)

const safePlayerCount = computed(() => Number(props.playerCount ?? 0))
</script>


<template>
  <div class="mobile-summary">
    <div class="mobile-header">
      <div class="mh-left">
        <div class="mh-title">FLIGHT {{ flightName }}</div>
        <div class="mh-sub">Players: {{ safePlayerCount }}</div>
      </div>

      <div class="mh-right">
        <div class="mh-pot">{{ formatCurrency(summary.totalPot) }}</div>
        <div class="mh-metrics">
          <span>Skins: {{ summary.totalWins }}</span>
          <span>Per: {{ formatCurrency(summary.per) }}</span>
        </div>
      </div>
    </div>

    <div v-if="!hasPlayers" class="mobile-empty">
      No prize results
    </div>

    <div v-else class="mobile-list">
      <div v-for="player in summary.players" :key="player.player_id ?? player.name" class="mobile-row">
        <div class="mr-top">
            <div class="mr-name">
                <span class="mr-name-text">{{ player.name }}</span>
                <span class="mr-count">({{ player.winCount }})</span>
            </div>

            <div class="mr-amount">
                {{ formatCurrency(player.total) }}
            </div>
            </div>

        <div class="mr-wins">
          {{ player.wins }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.mobile-summary {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 16px 0 24px;
}

.mobile-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;           /* ✅ allow right side to drop if needed */

  border: 1px solid #d1d5db;
  background-color: #eaecee !important;
  border-radius: 14px;

  padding: 12px 16px 12px 12px; /* reduce right padding; 28px is huge on mobile */
}

.mh-left,
.mh-right {
  min-width: 0;              /* ✅ critical in flex layouts */
}

.mh-right {
  text-align: right;
  display: flex;
  flex-direction: column;
  justify-content: center;

  padding-right: 0;          /* ✅ remove the extra inward shove */
  flex: 1 1 auto;            /* ✅ allow shrink/grow */
}

.mh-title {
  font-size: 16px;
  font-weight: 900;
  color: #111827;
}

.mh-sub {
  margin-top: 4px;
  font-size: 12px;
  font-weight: 700;
  color: #6b7280;
}

.mh-pot {
  font-size: 16px;
  font-weight: 900;
  color: #111827;
  white-space: nowrap;
}

.mh-metrics {
  margin-top: 4px;
  display: flex;
  gap: 10px;
  justify-content: flex-end;

  font-size: 12px;
  font-weight: 800;
  color: #374151;

  white-space: normal;       /* ✅ allow wrapping */
  flex-wrap: wrap;           /* ✅ */
}


.mobile-empty {
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 12px;
  color: #6b7280;
  font-style: italic;
  text-align: center;
  background: #fff;
}

.mobile-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.mobile-row {
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 12px;
  background: #ffffff;
  color: #111827;
}

.mr-top {
  display: flex;
  align-items: center;
  gap: 10px;
}

.mr-name {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  flex: 1 1 auto;      /* ✅ name takes remaining space */
  font-weight: 900;
  color: #111827;
}

.mr-name-text {
  min-width: 0;        /* ✅ ellipsis reliability */
  flex: 1 1 auto;      /* ✅ */
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.mr-count {
  flex-shrink: 0;
  font-weight: 700;
  color: #6b7280;
}

.mr-amount {
  margin-left: 8px;
  flex: 0 0 auto;      /* ✅ amount stays readable */
  white-space: nowrap; /* ✅ prevents weird wraps */
  font-weight: 900;
  color: #111827; 
}


.mr-wins {
  margin-top: 8px;

  /* 🔑 fixes alignment */
  text-align: left;
  align-self: flex-start;

  font-size: 12px;
  line-height: 1.35;
  color: #374151;
}

@media (max-width: 420px) {
  .mobile-header {
    align-items: flex-start;
    background: #e5e7eb;
  }
  .mh-right {
    width: 100%;
    text-align: left;
  }
  .mh-metrics {
    justify-content: flex-start;
  }
}
</style>
