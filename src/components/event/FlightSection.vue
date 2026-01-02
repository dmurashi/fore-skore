<script setup>
import { computed } from 'vue'

import FlightHeader from './FlightHeader.vue'
import PrizeLegend from '@/components/prizes/PrizeLegend.vue'
import FlightPrizeSummary from '@/components/prizes/FlightPrizeSummary.vue'
import LeaderboardScroll from './LeaderboardScroll.vue'
import LeaderboardTable from './LeaderboardTable.vue'

/* ========================
  Props
======================== */
const props = defineProps({
  flight: { type: String, required: true },
  players: { type: Array, required: true },
  teeSet: { type: Object, required: true },
  courseManifest: { type: Object, required: true },
  prizeSummary: { type: Object, required: true },
  // These come in as plain values (templates unwrap refs)
  scoreMode: { type: String, required: true },      // "gross" | "net"
  scoreModeLabel: { type: String, required: true }, // "Gross" | "Net"
  prizeView: { type: Boolean, required: true },
})

const emit = defineEmits(['set-gross', 'set-net', 'toggle-prizes'])

/* ========================
  Derived
======================== */
const flightPlayers = computed(() =>
  props.players.filter(p => p.flight === props.flight)
)

const flightPlayerCount = computed(() => flightPlayers.value.length)
</script>

<template>
  <section class="flight-scorecard">
    <!-- Prize Summary -->
    <FlightPrizeSummary
      :flight-name="flight"
      :summary="prizeSummary"
      :player-count="flightPlayerCount"
    />

    <!-- Header (now extracted) -->
    <FlightHeader
      :flight="flight"
      :score-mode="scoreMode"
      :score-mode-label="scoreModeLabel"
      :prize-view="prizeView"
      @set-gross="emit('set-gross')"
      @set-net="emit('set-net')"
      @toggle-prizes="emit('toggle-prizes')"
    />

    <!-- Prize Legend -->
    <PrizeLegend v-if="prizeView" />

    <!-- Leaderboard -->
    <LeaderboardScroll>
      <LeaderboardTable
        :players="flightPlayers"
        :tee-set="teeSet"
        :course-manifest="courseManifest"
        :score-mode="scoreMode"
        :prize-view="prizeView"
      />
    </LeaderboardScroll>
    <div class="flight-separator"></div>

  </section>
</template>

<style scoped>

/*.flight-scorecard {
  max-width: 100%;
  overflow-x: hidden;
}*/
  

.flight-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.flight-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #111827;
}

.flight-separator {
  margin: 36px 0;
  height: 2px;
  background: linear-gradient(
    to right,
    transparent,
    #cbd5e1,
    #cbd5e1,
    transparent
  );
}


/* Toggle */
.mode-toggle {
  display: inline-flex;
  gap: 6px;
  margin-bottom: 10px;
}

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
</style>
