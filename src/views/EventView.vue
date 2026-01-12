<!-- src/views/EventView.vue -->
<script setup>
/* =======================
 * Imports
 * ======================= */
import { ref, computed, watch, onMounted, nextTick } from 'vue'

import FlightSection from '@/components/event/FlightSection.vue'
import { buildFlightPrizeSummary } from '@/utils/prizeReducer'
import {
  familyIndexUrl,
  monthIndexUrl,
  eventUrl,
  courseUrl,
} from '@/config/datasources'

/* =======================
 * Constants
 * ======================= */
const FAMILY = 'madmen'
const DEFAULT_TEE_SET_ID = '1'

/* =======================
 * State
 * ======================= */
const eventJson = ref(null)
const courseManifest = ref(null)

const familyIndex = ref(null)

const monthOptions = ref([])        // [{ key, year, month, path }]
const selectedMonthKey = ref(null)

const monthEvents = ref([])         // events for selector
const selectedEventId = ref(null)

const currentYear = ref(null)
const currentMonth = ref(null)

const loading = ref(true)
const error = ref(false)

const scoreMode = ref('gross')
const prizeView = ref(false)
const selectedFlight = ref(null)

/* =======================
 * Helpers
 * ======================= */
async function fetchJson(url) {
  const res = await fetch(url, { cache: 'no-store' })
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`)
  return res.json()
}

const loadMonthIndex = async ({ year, month, path }) => {
  const url = path
    ? `${import.meta.env.VITE_DATA_BASE_URL}/${FAMILY}/${path}`
    : monthIndexUrl(FAMILY, year, month)

  const monthJson = await fetchJson(url)
  monthEvents.value = monthJson.events ?? []
}

const loadEventAndCourse = async ({ year, month, event_id }) => {
  const eventRes = await fetchJson(
    eventUrl({ f: FAMILY, y: year, m: month, id: event_id })
  )
  eventJson.value = eventRes

  const courseRes = await fetchJson(
    courseUrl({ f: FAMILY, y: year, m: month, id: event_id })
  )
  courseManifest.value = courseRes

  const params = new URLSearchParams(window.location.search)
  params.set('event_id', event_id)
  window.history.replaceState({}, '', `?${params}`)
}

/* =======================
 * Initial Load (Latest)
 * ======================= */
const loadLatestEvent = async () => {
  loading.value = true
  error.value = false
  selectedFlight.value = null

  try {
    const fam = await fetchJson(familyIndexUrl(FAMILY))
    if (!fam?.latest) throw new Error('family-index missing latest')

    familyIndex.value = fam

    // build month selector
    const monthsObj = fam.months ?? {}
    monthOptions.value = Object.entries(monthsObj)
      .map(([key, v]) => ({
        key,
        year: Number(v.year),
        month: String(v.month).padStart(2, '0'),
        path: v.path,
      }))
      .sort((a, b) => b.key.localeCompare(a.key))

    const { year, month, event_id } = fam.latest

    currentYear.value = Number(year)
    currentMonth.value = String(month).padStart(2, '0')
    selectedMonthKey.value = `${currentYear.value}-${currentMonth.value}`

    await loadMonthIndex({
      year: currentYear.value,
      month: currentMonth.value,
      path: monthsObj[selectedMonthKey.value]?.path,
    })

    selectedEventId.value = String(event_id)

    await loadEventAndCourse({
      year: currentYear.value,
      month: currentMonth.value,
      event_id: selectedEventId.value,
    })
  } catch (e) {
    console.error(e)
    error.value = true
  } finally {
    loading.value = false
  }
}

/* =======================
 * React to Month Change
 * ======================= */
watch(selectedMonthKey, async (key) => {
  if (!key || !familyIndex.value?.months?.[key]) return

  loading.value = true
  error.value = false
  selectedFlight.value = null

  try {
    const meta = familyIndex.value.months[key]
    currentYear.value = Number(meta.year)
    currentMonth.value = String(meta.month).padStart(2, '0')

    await loadMonthIndex({
      year: currentYear.value,
      month: currentMonth.value,
      path: meta.path,
    })

    // only auto-select if nothing is selected yet
    selectedEventId.value = null
    await nextTick()
    selectedEventId.value = monthEvents.value?.[0]?.event_id ?? null


  } catch (e) {
    console.error(e)
    error.value = true
  } finally {
    loading.value = false
  }
})

/* =======================
 * React to Event Change
 * ======================= */
watch(selectedEventId, async (id) => {
  if (!id || !currentYear.value || !currentMonth.value) return

  loading.value = true
  error.value = false
  selectedFlight.value = null

  try {
    await loadEventAndCourse({
      year: currentYear.value,
      month: currentMonth.value,
      event_id: String(id),
    })
  } catch (e) {
    console.error(e)
    error.value = true
  } finally {
    loading.value = false
  }
})


/* =======================
 * Init
 * ======================= */
onMounted(loadLatestEvent)

/* =======================
 * Course / Tee
 * ======================= */
const teeSet = computed(() =>
  courseManifest.value?.courses?.[0]?.tee_sets?.[DEFAULT_TEE_SET_ID] ?? { holes: {} }
)

/* =======================
 * Derived
 * ======================= */
const scoreModeLabel = computed(() =>
  scoreMode.value === 'net' ? 'Net' : 'Gross'
)

const players = computed(() =>
  eventJson.value?.players ?? []
)

const flights = computed(() => {
  if (!players.value.length) return []
  return [...new Set(players.value.map(p => p.flight))]
})

const prizeSummaries = computed(() =>
  eventJson.value ? buildFlightPrizeSummary(eventJson.value) : {}
)

/* =======================
 * Default Flight Selection
 * ======================= */
watch(flights, (newFlights) => {
  if (!selectedFlight.value && newFlights.length) {
    selectedFlight.value = newFlights[0]
  }
})

/* =======================
 * Event Title
 * ======================= */
const eventTitle = computed(() => {
  const meta = eventJson.value?.meta
  if (!meta?.event_date) return ''

  const [y, m, d] = meta.event_date.split('-').map(Number)
  const localDate = new Date(y, m - 1, d)

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
        <!-- Month + Event Selector -->
        <div class="event-selector">
          <select v-model="selectedMonthKey">
            <option
              v-for="m in monthOptions"
              :key="m.key"
              :value="m.key"
            >
              {{ m.key }}
            </option>
          </select>

          <select v-model="selectedEventId">
            <option
              v-for="e in monthEvents"
              :key="e.event_id"
              :value="String(e.event_id)"
            >
              {{ e.name }} – {{ e.date }}
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
  gap: 10px;
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
