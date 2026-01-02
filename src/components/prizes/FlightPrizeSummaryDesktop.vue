<!--  FlightPrizeSummaryDesktop.vue -->
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
  <div class="flight-prize-summary">
    <table class="summary-table">
      <colgroup>
        <col class="col-player" />
        <col class="col-total" />
        <col class="col-metrics" />
      </colgroup>

      <thead>
        <tr class="summary-header">
          <th class="flight-header">
          <div class="flight-header-inner">
            <span class="flight-left">FLIGHT {{ flightName }}</span>
            <span class="flight-right">Players: {{ safePlayerCount }}</span>
          </div>
        </th>

          <th class="total-header">
            {{ formatCurrency(summary.totalPot) }}
          </th>

          <th class="metrics-header">
            <div class="metrics">
              <span>Skins: {{ summary.totalWins }}</span>
              <span>Per: {{ formatCurrency(summary.per) }}</span>
            </div>
          </th>
        </tr>
      </thead>

      <tbody>
        <tr v-if="!hasPlayers">
          <td colspan="3" class="empty-row">No prize results</td>
        </tr>

        <tr v-for="player in summary.players" :key="player.player_id ?? player.name">
          <td class="player-name">
          <div class="player-name-inner">
              <span class="player-name-text">{{ player.name }}</span>
              <span class="win-count">{{ player.winCount }}</span>
          </div>
          </td>

          <td class="player-total">{{ formatCurrency(player.total) }}</td>
          <td class="player-wins">{{ player.wins }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
/* paste your existing desktop styles here (table/cols/rows) */
.flight-prize-summary { margin: 16px 0 24px; }

.summary-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
  table-layout: fixed;
}

.col-player { width: 260px; }
.col-total  { width: 140px; }
.col-metrics { width: auto; }

.summary-table th,
.summary-table td {
  border: 1px solid #d1d5db;
  padding: 6px 10px;
}

.summary-table thead tr:first-child th {
  background-color: #f3f4f6;
  font-weight: 800;
  color: #1f2937;
}

/* Force only ONE line between thead and tbody */
.summary-table thead th { border-bottom: 0; }
.summary-table tbody tr:first-child td { border-top: 1px solid #d1d5db; }


.metrics { justify-content: flex-start; }


.metrics {
  display: flex;
  justify-content: left;
  gap: 32px;
  font-weight: 700;
}

.flight-header { white-space: nowrap; }

.flight-header-inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.flight-left {
  font-weight: 900;
  letter-spacing: 0.02em;
}

.flight-right {
  font-size: 13px;
  font-weight: 700;
  color: #040404;
}

.total-header {
  text-align: center;
  font-weight: 900;      /* optional, but matches visual weight */
  font-size: 16px;       /* optional: helps it stand out */
  white-space: nowrap;
}


.player-row:hover { background: #f8fafc; }

.player-name {
  white-space: nowrap; /* keep td as a real table-cell */
}

.player-name-inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}


.player-name-text {
  white-space: nowrap;
  min-width: 0;          /* important when inside flex */
  flex: 1 1 auto;        /* let it shrink */
  font-weight: 700;

}

.win-count {
  flex-shrink: 0;
  color: #6b7280;
  font-weight: 500;
}

.player-total {
  text-align: center;
  font-weight: 700;
  white-space: nowrap;
}

.player-wins {
  text-align: left;
  font-size: 14px;
  line-height: 1.4;
  color: #1f2937;
}

.empty-row {
  text-align: center;
  color: #6b7280;
  font-style: italic;
}
</style>
