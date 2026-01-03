<!-- FlightPrizeSummaryMobile.vue -->
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
    <!-- ===== Header ===== -->
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

    <!-- ===== Empty ===== -->
    <div v-if="!hasPlayers" class="mobile-empty">
      No prize results
    </div>

    <!-- ===== Player List ===== -->
    <div v-else class="mobile-list">
      <div
        v-for="player in summary.players"
        :key="player.player_id ?? player.name"
        class="mobile-row"
      >
        <!-- TOP ROW -->
        <div class="mr-top">
          <div class="mr-left">
            <div class="mr-name">
              <span class="mr-name-text">{{ player.name }}</span>
              <span class="mr-count">({{ player.winCount }})</span>
            </div>
          </div>

          <div class="mr-amount">
            {{ formatCurrency(player.total) }}
          </div>
        </div>

        <!-- DETAILS -->
        <div class="mr-wins">
          {{ player.wins }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ===== Layout ===== */

.mobile-summary {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 16px 0 24px;
}

/* ===== Header ===== */

.mobile-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;

  border: 1px solid #d1d5db;
  background: #f3f4f6;
  border-radius: 14px;
  padding: 12px 16px;
}

.mh-left,
.mh-right {
  min-width: 0;
}

.mh-right {
  text-align: right;
  display: flex;
  flex-direction: column;
  flex: 1 1 auto;
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
  flex-wrap: wrap;
}

/* ===== Empty ===== */

.mobile-empty {
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 12px;
  color: #6b7280;
  font-style: italic;
  text-align: center;
  background: #fff;
}

/* ===== List ===== */

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
}

/* ===== Player Row ===== */

.mr-top {
  display: flex;
  align-items: center;
  gap: 10px;
}

/* LEFT side must be shrinkable (Safari fix) */
.mr-left {
  flex: 1 1 auto;
  min-width: 0; /* 🔑 critical for iOS Safari */
}

.mr-name {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  font-weight: 900;
  color: #111827;
}

.mr-name-text {
  min-width: 0; /* 🔑 */
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.mr-count {
  flex-shrink: 0;
  font-weight: 700;
  color: #6b7280;
}

/* RIGHT side must NEVER shrink */
.mr-amount {
  flex: 0 0 auto; /* 🔑 */
  white-space: nowrap;
  font-weight: 900;
  color: #111827;
}

/* ===== Details ===== */

.mr-wins {
  margin-top: 8px;
  font-size: 12px;
  line-height: 1.35;
  color: #374151;
  text-align: left;
}

/* ===== Small screens ===== */

@media (max-width: 420px) {
  .mobile-header {
    align-items: flex-start;
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
