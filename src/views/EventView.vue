<!-- src/views/EventView.vue -->
<script setup>
console.log('URL search:', window.location.search)

import { ref, computed, onMounted, watch } from 'vue'
import FlightSection from '@/components/event/FlightSection.vue'
import { buildFlightPrizeSummary } from '@/utils/prizeReducer'

/* ---------- Hardcoded for this weekend ---------- */
const getEventIdFromQuery = () => {
  const params = new URLSearchParams(window.location.search)
  return params.get('event_id') || '44'
}

const EVENT_ID = getEventIdFromQuery()
const COURSE_ID = 44

/* ---------- State ---------- */
const eventJson = ref(null)
const courseManifest = ref(null)
const loading = ref(true)
const error = ref(false)

const scoreMode = ref('gross') // 'gross' | 'net'
const prizeView = ref(false)
const selectedFlight = ref(null)

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

/* ---------- Default Flight Selection ---------- */
watch(flights, (newFlights) => {
  if (!selectedFlight.value && newFlights.length) {
    selectedFlight.value = newFlights[0]
  }
})

/* ---------- Event Title ---------- */
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

  return `Results:\u00A0\u00A0${formattedDate}`
  // return `Results: ${event_name} — ${formattedDate}`
})
</script>

<template>
  <div class="event-view" :class="{ 'fade-in': !loading }">
    <h1 class="event-title">
      {{ eventTitle }}
    </h1>

    <section class="leaderboard-page">
      <div v-if="loading">Loading…</div>
      <div v-else-if="error">Failed to load event</div>

      <template v-else>
        <!-- Flight Selector -->
        <div class="flight-selector">
          <button
            v-for="flight in flights"
            :key="flight"
            class="flight-btn"
            :class="{ active: flight === selectedFlight }"
            @click="selectedFlight = flight"
          >
            Flight {{ flight }}
          </button>
        </div>

        <!-- Single Flight Render -->
        <FlightSection
          v-if="selectedFlight"
          :flight="selectedFlight"
          :players="players"
          :tee-set="teeSet"
          :prize-summary="prizeSummaries[selectedFlight]"
          :score-mode="scoreMode"
          :score-mode-label="scoreModeLabel"
          :prize-view="prizeView"
          :course-manifest="courseManifest"
          @set-gross="scoreMode = 'gross'"
          @set-net="scoreMode = 'net'"
          @toggle-prizes="prizeView = !prizeView"
        />
      </template>
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
  font-size: 24px;
  font-weight: 700;
  line-height: 1.15;
  margin: 0 auto;            /* ✅ center container */
  text-align: center;        /* ✅ center text */

  color: #1f2937;
  letter-spacing: -0.01em;
  max-width: 1250px;
}

/* ---------- Flight Selector ---------- */
.flight-selector {
  display: flex;
  gap: 10px;
  margin: 0 auto 14px auto;  /* ✅ center container */
  justify-content: center;   /* ✅ center buttons */
  flex-wrap: wrap;
  max-width: 1250px;         /* optional but recommended */
}

.flight-btn {
  padding: 6px 14px;
  border-radius: 999px;
  border: 1px solid #d1d5db;
  background: #f9fafb;
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
  transition:
    background-color 120ms ease,
    color 120ms ease,
    border-color 120ms ease;
}

.flight-btn:hover {
  background: #f3f4f6;
}

.flight-btn.active {
  background: #111827;
  color: #ffffff;
  border-color: #111827;
}

/* ---------- Dark Mode ---------- */
@media (prefers-color-scheme: dark) {
  .event-title {
    color: #f3f4f6;
    border-bottom: 1px solid #374151;
  }

  .flight-btn {
    background: #1f2937;
    color: #e5e7eb;
    border-color: #374151;
  }

  .flight-btn:hover {
    background: #374151;
  }

  .flight-btn.active {
    background: #f9fafb;
    color: #111827;
    border-color: #f9fafb;
  }
}
</style>
