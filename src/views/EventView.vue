<!-- src/views/EventView.vue -->
<script setup>
import { ref, computed, onMounted } from 'vue'

import FlightSection from '@/components/event/FlightSection.vue'
import { buildFlightPrizeSummary } from '@/utils/prizeReducer'

/* ---------- Hardcoded for this weekend ---------- */
const EVENT_ID = 45
const COURSE_ID = 45

/* ---------- State ---------- */
const eventJson = ref(null)
const courseManifest = ref(null)
const loading = ref(true)
const error = ref(false)

const scoreMode = ref('gross') // 'gross' | 'net'
const prizeView = ref(false)

/* ---------- Fetch data ---------- */
onMounted(async () => {
  try {
    const eventRes = await fetch(`/data/events/${EVENT_ID}.json`)
    if (!eventRes.ok) throw new Error('Failed to load event')
    eventJson.value = await eventRes.json()

    const courseRes = await fetch(`/data/courses/${COURSE_ID}.json`)
    if (!courseRes.ok) throw new Error('Failed to load course')
    courseManifest.value = await courseRes.json()
  } catch (e) {
    console.error(e)
    error.value = true
  } finally {
    loading.value = false
  }
})

/* ---------- Course / Tee ---------- */
/*
  TEMP:
  Fixed tee set for leaderboard display.
  Later: driven by selected player.
*/
const teeSetId = '1'

const teeSet = computed(() =>
  courseManifest.value?.courses?.[0]?.tee_sets?.[teeSetId] ?? { holes: {} }
)
// const teeSet = computed(() =>
//   courseManifest.value?.tee_sets?.[teeSetId] ?? { holes: {} }
// )

/* ---------- Derived ---------- */
const scoreModeLabel = computed(() =>
  scoreMode.value === 'net' ? 'Net' : 'Gross'
)

const flights = computed(() => {
  if (!eventJson.value?.players) return []
  return [...new Set(eventJson.value.players.map(p => p.flight))]
})

const players = computed(() =>
  eventJson.value?.players ?? []
)

const prizeSummaries = computed(() =>
  eventJson.value ? buildFlightPrizeSummary(eventJson.value) : {}
)
</script>

<template>
  <section class="leaderboard-page">
    <div v-if="loading">Loading…</div>
    <div v-else-if="error">Failed to load event</div>

    <FlightSection
      v-else
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
