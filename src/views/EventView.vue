<!-- src/views/EventView.vue -->
<script setup>
  console.log(import.meta.env)
console.log('URL search:', window.location.search)

import { ref, computed, onMounted, watch } from 'vue'
import FlightSection from '@/components/event/FlightSection.vue'
import { buildFlightPrizeSummary } from '@/utils/prizeReducer'
import { DATA_BASE_URL } from '@/config/datasources'

/* ---------- Helpers ---------- */
const getEventIdFromQuery = () => {
  const params = new URLSearchParams(window.location.search)
  return params.get('event_id')
}

/* ---------- State ---------- */
const eventIndex = ref([])
const selectedEventId = ref(getEventIdFromQuery())

const eventJson = ref(null)
const courseManifest = ref(null)
const loading = ref(true)
const error = ref(false)

const scoreMode = ref('gross')
const prizeView = ref(false)
const selectedFlight = ref(null)

/* ---------- Loaders ---------- */
const loadEventIndex = async () => {
  const res = await fetch(`${DATA_BASE_URL}/events/index.json`)
  if (!res.ok) throw new Error('Failed to load event index')
  const json = await res.json()

  eventIndex.value = json.events ?? []

  // Default to latest event if none selected
  if (!selectedEventId.value && eventIndex.value.length) {
    selectedEventId.value = eventIndex.value[0].id
  }
}

const loadEvent = async (eventId) => {
  if (!eventId) return

  loading.value = true
  error.value = false
  selectedFlight.value = null

  try {
    const eventRes = await fetch(`${DATA_BASE_URL}/events/${eventId}.json`)
    if (!eventRes.ok) throw new Error('Failed to load event')
    eventJson.value = await eventRes.json()

    const courseId = eventJson.value?.meta?.course_id ?? eventId
    const courseRes = await fetch(`${DATA_BASE_URL}/courses/${courseId}.json`)
    if (!courseRes.ok) throw new Error('Failed to load course')
    courseManifest.value = await courseRes.json()

    // keep URL in sync
    const params = new URLSearchParams(window.location.search)
    params.set('event_id', eventId)
    window.history.replaceState({}, '', `?${params}`)
  } catch (e) {
    console.error(e)
    error.value = true
  } finally {
    loading.value = false
  }
}

/* ---------- Init ---------- */
onMounted(async () => {
  try {
    await loadEventIndex()
    await loadEvent(selectedEventId.value)
  } catch (e) {
    console.error(e)
    error.value = true
    loading.value = false
  }
})

/* ---------- Reload when event changes ---------- */
watch(selectedEventId, (id) => {
  loadEvent(id)
})

/* ---------- Course / Tee ---------- */
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

  const [year, month, day] = meta.event_date.split('-').map(Number)
  const localDate = new Date(year, month - 1, day)

  const formattedDate = new Intl.DateTimeFormat('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
  }).format(localDate)

  return `Results:\u00A0\u00A0${formattedDate}`
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
        <!-- Event Selector -->
        <div class="event-selector">
          <select v-model="selectedEventId">
            <option
              v-for="e in eventIndex"
              :key="e.id"
              :value="e.id"
            >
              {{ e.name }} — {{ e.date }}
            </option>
          </select>
        </div>

        <!-- Flight Selector -->
        <div class="flight-selector">
          <button
            v-for="flight in flights"
            :key="flight"
            class="pill-btn"
            :class="{ 'is-active': flight === selectedFlight }"
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
  margin: 0 auto;
  text-align: center;
  color: #1f2937;
  max-width: 1250px;
}

 @media (prefers-color-scheme: dark) {
  .event-view .event-title {
    color: #ffffff;
  }
}

/* ---------- Event Selector ---------- */
.event-selector {
  display: flex;
  justify-content: center;
  margin-bottom: 20px;
  
}

.event-selector select {
  padding: 6px 10px;
  font-size: 14px;
  border-radius: 6px;
}

/* ---------- Flight Selector ---------- */
.flight-selector {
  display: flex;
  gap: 10px;
  margin: 0 auto 14px auto;
  justify-content: center;
  flex-wrap: wrap;
  max-width: 1250px;
}

</style>
