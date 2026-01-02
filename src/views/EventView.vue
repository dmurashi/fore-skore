<!-- src/views/EventView.vue -->
<script setup>
import { ref, computed } from 'vue'
import FlightSection from '@/components/event/FlightSection.vue'

import eventJson from '@/data/events/madmen-event.json'
import courseManifest from '@/data/courses/moon_valley_course.json'

import { buildFlightPrizeSummary } from '@/utils/prizeReducer'

/* ---------- Course / Tee ---------- */

const teeSetId = '1'

const teeSet = computed(() =>
  courseManifest.tee_sets?.[teeSetId] ?? { holes: {} }
)

// STATE
const scoreMode = ref('gross') // 'gross' | 'net'
const prizeView = ref(false)

// DERIVED
const scoreModeLabel = computed(() => (scoreMode.value === 'net' ? 'Net' : 'Gross'))

// These assume your eventJson still has the same shape you had before:
const flights = computed(() => {
  const set = new Set()
  for (const p of eventJson.players || []) {
    if (p.flight) set.add(p.flight)
  }
  return Array.from(set)
})

const players = computed(() => eventJson.players || [])

const prizeSummaries = computed(() => buildFlightPrizeSummary(eventJson))

</script>

<template>

  <section class="leaderboard-page">
    <FlightSection
      v-for="flight in flights"
      :key="flight"
      :flight="flight"
      :players="players"
      :tee-set="teeSet"
      :prize-summary="prizeSummaries[flight]"
      :score-mode="scoreMode"
      :score-mode-label="scoreModeLabel"
      :prize-view="prizeView"
      :course-manifest="courseManifest"
      @set-gross="scoreMode = 'gross'"
      @set-net="scoreMode = 'net'"
      @toggle-prizes="prizeView = !prizeView"
    />
  </section>
</template>

<style scoped>
.event-view {
  display: flex;
  flex-direction: column;
  gap: 32px;
  min-width: 0;  
}
</style>
