<!-- src/views/EventView.vue -->
<script setup>
  console.log('URL search:', window.location.search)
import { ref, computed, onMounted } from 'vue'

import FlightSection from '@/components/event/FlightSection.vue'
import { buildFlightPrizeSummary } from '@/utils/prizeReducer'

/* ---------- Hardcoded for this weekend ---------- */
const getEventIdFromQuery = () => {
  const params = new URLSearchParams(window.location.search)
  return params.get('event_id') || '44'
}

const EVENT_ID = getEventIdFromQuery()
//const EVENT_ID = 44
const COURSE_ID = 44

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
const eventTitle = computed(() => {
  const meta = eventJson.value?.meta
  if (!meta?.event_date) return ''

  const { event_name, event_date } = meta

  // Force local date interpretation (no timezone shift)
  const [year, month, day] = event_date.split('-').map(Number)
  const localDate = new Date(year, month - 1, day)

  const formattedDate = new Intl.DateTimeFormat('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
  }).format(localDate)

  return `${event_name} — ${formattedDate}`
})

</script>

<template>
  <div class="event-view" :class="{ 'fade-in': !loading }" >
    <h1 class="event-title">
      {{ eventTitle }}
    </h1>

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
  </div>
</template>


<style scoped>
.event-view {
  display: flex;
  flex-direction: column;
  gap: 32px;
  min-width: 0;
}

.event-title {
  font-size: 24px;          /* down from giant hero size */
  font-weight: 700;
  line-height: 1.15;
  margin: 0 0 0px 0;

  color: #1f2937;           /* neutral slate */
  letter-spacing: -0.01em;

  /* keep it visually aligned with tables */
  max-width: 1250px;
}

/* ---------- Dark Mode ---------- */
@media (prefers-color-scheme: dark) {
  .event-title {
    color: #f3f4f6;          /* near-white, not pure white */
    border-bottom: 1px solid #374151;
  }
}
/* ---------- Page Load Animation ---------- */
.fade-in {
  opacity: 0;
  transform: translateY(12px);
  animation: fadeInUp 650ms cubic-bezier(0.22, 1, 0.36, 1) both;
}

@keyframes fadeInUp {
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Respect reduced motion preferences */
@media (prefers-reduced-motion: reduce) {
  .fade-in {
    animation: none;
    opacity: 1;
    transform: none;
  }
}
</style>
