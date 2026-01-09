<!-- src/components/stats/FlightStats.vue -->
<script setup>
import { ref, computed } from 'vue'

import ScoreDistributionChart from '@/components/stats/ScoreDistributionChart.vue'
import StatsTable from '@/components/stats/StatsTable.vue'

const props = defineProps({
  players: { type: Array, required: true },
  scoreMode: { type: String, required: true } // 'gross' | 'net'
})

/* ========================
   Toggle
======================== */
const statsMode = ref('player') // 'player' | 'hole'

/* ========================
   Helpers
======================== */
function safeNum(v, fallback = 0) {
  const n = Number(v)
  return Number.isFinite(n) ? n : fallback
}

function classifyResult(hole, scoreMode) {
  const key = scoreMode === 'net' ? 'net_result' : 'gross_result'
  const r = hole?.[key]
  if (!r) return null

  // normalize to your chart buckets
  if (r === 'EAGLE') return 'Eagle'
  if (r === 'BIRDIE') return 'Birdie'
  if (r === 'PAR') return 'Par'
  if (r === 'BOGEY') return 'Bogey'
  if (r === 'DOUBLE') return 'Double'
  // anything else (TRIPLE, QUAD, etc)
  return 'Other'
}

/* ========================
   Score distribution (working)
======================== */
const scoreDistribution = computed(() => {
  const dist = { Eagle: 0, Birdie: 0, Par: 0, Bogey: 0, Double: 0, Other: 0 }

  for (const p of props.players || []) {
    const holes = p?.holes || {}
    for (const h of Object.values(holes)) {
      const bucket = classifyResult(h, props.scoreMode)
      if (bucket) dist[bucket]++
    }
  }

  return dist
})

/* ========================
   Player summaries (KEY FIX)
   Must match StatsTable fields:
   name, total, avg, eagles, birdies, pars, bogeys, doublePlus
======================== */
const playerSummaries = computed(() => {
  return props.players.map(p => {
    const holes = Object.values(p.holes || {})
    const mode = props.scoreMode // 'gross' | 'net'

    let toPar = 0
    let eagles = 0
    let birdies = 0
    let pars = 0
    let bogeys = 0
    let doublePlus = 0

    holes.forEach(h => {
      const diff = h[`${mode}_diff`]
      const result = h[`${mode}_result`]

      toPar += diff

      if (result === 'EAGLE') eagles++
      else if (result === 'BIRDIE') birdies++
      else if (result === 'PAR') pars++
      else if (result === 'BOGEY') bogeys++
      else doublePlus++
    })

    return {
      name: p.name,
      total: toPar,
      avg: Number((toPar / holes.length).toFixed(2)),
      eagles,
      birdies,
      pars,
      bogeys,
      doublePlus
    }
  })
})



/* ========================
   Hole summaries (stub but safe)
   Return the correct shape so toggle doesn't break.
======================== */
const holeSummaries = computed(() => {
  const holeMap = {}

  const diffKey = props.scoreMode === 'net' ? 'net_diff' : 'gross_diff'
  const resultKey = props.scoreMode === 'net' ? 'net_result' : 'gross_result'

  props.players.forEach(player => {
    Object.entries(player.holes).forEach(([holeNum, h]) => {
      if (!holeMap[holeNum]) {
        holeMap[holeNum] = {
          hole: Number(holeNum),
          totalDiff: 0,
          count: 0,
          eagles: 0,
          birdies: 0,
          pars: 0,
          bogeys: 0,
          bogeyPlus: 0
        }
      }

      const row = holeMap[holeNum]

      row.totalDiff += h[diffKey]
      row.count += 1

      switch (h[resultKey]) {
        case 'EAGLE':
          row.eagles++
          break
        case 'BIRDIE':
          row.birdies++
          break
        case 'PAR':
          row.pars++
          break
        case 'BOGEY':
          row.bogeys++
          break
        default:
          row.bogeyPlus++
      }
    })
  })

  return Object.values(holeMap).map(h => ({
    hole: h.hole,
    total: h.totalDiff,
    avg: Number((h.totalDiff / h.count).toFixed(2)), // avg to par (gross/net)
    eagles: h.eagles,
    birdies: h.birdies,
    pars: h.pars,
    bogeys: h.bogeys,
    doublePlus: h.bogeyPlus
  }))
})



</script>

<template>
  <section class="flight-stats">
    <ScoreDistributionChart :distribution="scoreDistribution" />

    <div class="stats-table-panel">
      <div class="mode-toggle stats-toggle">
        <button
            class="pill-btn pill-btn--sm"
            :class="{ 'is-active': statsMode === 'player' }"
            @click="statsMode = 'player'"
        >
            By Player
        </button>

        <button
            class="pill-btn pill-btn--sm"
            :class="{ 'is-active': statsMode === 'hole' }"
            @click="statsMode = 'hole'"
        >
            By Hole
        </button>
      </div>

      <StatsTable
        :rows="statsMode === 'player' ? playerSummaries : holeSummaries"
        :mode="statsMode"
      />
    </div>
  </section>
</template>

<style scoped>
/* ===============================
   Layout
================================ */
.flight-stats {
  display: grid;
  grid-template-columns: minmax(320px, 1fr) minmax(0, 2fr);
  gap: 20px;
  margin-top: 24px;
}

.flight-stats > * {
  min-width: 0;
}

.stats-table-panel {
  display: flex;
  flex-direction: column;
}


/* ===============================
   Toggle (uses global pill-btn)
================================ */
.stats-toggle {
  display: inline-flex;
  gap: 8px;            /* tighter grouping */
  margin-bottom: 14px; /* space before table */
}


/* ===============================
   Small pill override (local only)
================================ */
.pill-btn--sm {
  padding: 4px 10px;
  font-size: 12px;
  line-height: 1.2;
  border-radius: 999px;
}


/* ===============================
   Responsive
================================ */
@media (max-width: 900px) {
  .flight-stats {
    grid-template-columns: 1fr;
  }
}

</style>
