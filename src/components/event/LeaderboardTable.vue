<script setup>
import { computed } from 'vue'
import { formatCurrency, totalPayout } from '@/utils/money'

import {
  getHole,
  getScore,
  scoreClass,
  sumHoles,
  teeStyle,
  holeClasses,
  strokeCount,
  receivesStrokes,
  hasCTP,
  isLowGrossWinner,
} from '@/utils/leaderboardHelpers'

const props = defineProps({
  players: { type: Array, required: true },
  teeSet: { type: Object, required: true },
  scoreMode: { type: String, required: true },
  prizeView: { type: Boolean, required: true },
})

/* ---------- Holes ---------- */
const frontNine = computed(() => [1,2,3,4,5,6,7,8,9])
const backNine  = computed(() => [10,11,12,13,14,15,16,17,18])

/* ---------- PAR + INDEX (FIXED) ---------- */
const parFor = (h) =>
  props.teeSet?.holes?.[String(h)]?.par?.men ?? null

const idxMenFor = (h) =>
  props.teeSet?.holes?.[String(h)]?.index.men ?? null

const idxWomenFor = (h) =>
  props.teeSet?.holes?.[String(h)]?.index.women ?? null

const frontNinePar = computed(() =>
  frontNine.value.reduce((s,h) => s + (parFor(h) ?? 0), 0)
)
const backNinePar = computed(() =>
  backNine.value.reduce((s,h) => s + (parFor(h) ?? 0), 0)
)
const totalPar = computed(() => frontNinePar.value + backNinePar.value)

/* ---------- TOTALS (SINGLE SOURCE OF TRUTH) ---------- */
const frontTotal = (p) => sumHoles(p, frontNine.value, props.scoreMode)
const backTotal  = (p) => sumHoles(p, backNine.value,  props.scoreMode)

const roundTotal = (p) => {
  const f = frontTotal(p)
  const b = backTotal(p)
  return f == null && b == null ? null : (f ?? 0) + (b ?? 0)
}

/* ---------- SORTING (THIS WAS BROKEN) ---------- */
const viewPlayers = computed(() => {
  return [...props.players].sort((a, b) => {
    const ta = roundTotal(a)
    const tb = roundTotal(b)

    if (ta == null && tb == null) return a.name.localeCompare(b.name)
    if (ta == null) return 1
    if (tb == null) return -1
    if (ta !== tb) return ta - tb

    return a.name.localeCompare(b.name)
  })
})

/* ---------- RANK LABEL ---------- */
const rankLabel = (p) =>
  props.scoreMode === 'gross'
    ? p.gross_rank_label
    : p.net_rank_label

const totalUnderPar = (t) =>
  t != null && t < totalPar.value
</script>


<template>
  <table class="scorecard" :class="{ 'is-prize-view': prizeView }">
    <thead>
      <tr>
        <th class="rank-col">#</th>
        <th class="player-col">Player</th>
        <th class="tee-col">Tee</th>

        <th v-for="h in frontNine" :key="h" class="hole-col">{{ h }}</th>
        <th class="total-col">OUT</th>

        <th v-for="h in backNine" :key="h" class="hole-col">{{ h }}</th>
        <th style="width: 50px;">IN</th>

        <th class="total-col">TOTAL</th>
        <th class="payout-col"></th>
      </tr>

      <tr class="par-row">
        <th class="rank-col">-</th>
        <th class="player-col">PAR</th>
        <th></th>

        <th v-for="h in frontNine" :key="'pf' + h">
          {{ parFor(h) ?? '—' }}
        </th>
        <th>{{ frontNinePar }}</th>

        <th v-for="h in backNine" :key="'pb' + h">
          {{ parFor(h) ?? '—' }}
        </th>
        <th>{{ backNinePar }}</th>

        <th>{{ totalPar }}</th>
        <th class="payout-col">$</th>
      </tr>
    </thead>

    <tbody>
      <tr v-for="player in viewPlayers" :key="player.event_player_id">
        <td class="rank-col">
          {{ rankLabel(player) }}
        </td>

        <td class="player-col">
          <span class="player-name">{{ player.name }}</span>
          <span v-if="player.course_handicap !== null && player.course_handicap !== undefined">
            ({{ player.course_handicap }})
          </span>

          <!-- LOW NET badge (only if eventJson includes it on round_competitions) -->
          <span
            v-if="prizeView && player.round_competitions?.some(c => c.type === 'LOW_NET')"
            class="badge low-net"
          >
            LOW NET
          </span>

          <!-- LOW GROSS medal -->
          <span
            v-if="prizeView && isLowGrossWinner(player)"
            class="badge low-gross"
            title="Low Gross"
          >
            🏅
          </span>
        </td>

        <td class="tee-col">
          <span
            class="tee-badge"
            :style="teeStyle(player.tee_name)"
            :title="player.tee_name"
          />
        </td>

        <!-- Front 9 -->
        <td
          v-for="h in frontNine"
          :key="'f' + h"
          class="hole-col"
          :class="holeClasses(player, h, prizeView)"
        >
          <!-- Stroke indicator -->
          <span v-if="strokeCount(getHole(player, h)) !== 0" class="stroke-indicator">
            <span
              v-if="receivesStrokes(getHole(player, h))"
              class="stroke-dots"
              :title="`${strokeCount(getHole(player, h))} stroke(s) received`"
            >
              {{ '●'.repeat(Math.min(strokeCount(getHole(player, h)), 3)) }}
            </span>
            <span v-else class="stroke-plus" title="Giving strokes">+</span>
          </span>

          <!-- Score -->
          <span
            v-if="getScore(player, h, scoreMode) !== null"
            class="hole-score"
            :class="scoreClass(player, h, scoreMode)"
          >
            {{ getScore(player, h, scoreMode) }}
          </span>
          <span v-else class="placeholder">—</span>

          <!-- CTP -->
          <span
            v-if="prizeView && getScore(player, h, scoreMode) !== null && hasCTP(getHole(player, h))"
            class="ctp-badge"
            title="Closest to the Pin"
          >
            ⛳
          </span>
        </td>

        <td class="total-col" :class="{ 'total-under-par': frontTotal(player) < frontNinePar }">
          {{ frontTotal(player) ?? '—' }}
        </td>

        <!-- Back 9 -->
        <td
          v-for="h in backNine"
          :key="'b' + h"
          class="hole-col"
          :class="holeClasses(player, h, prizeView)"
        >
          <!-- Stroke indicator -->
          <span v-if="strokeCount(getHole(player, h)) !== 0" class="stroke-indicator">
            <span
              v-if="receivesStrokes(getHole(player, h))"
              class="stroke-dots"
              :title="`${strokeCount(getHole(player, h))} stroke(s) received`"
            >
              {{ '●'.repeat(Math.min(strokeCount(getHole(player, h)), 3)) }}
            </span>
            <span v-else class="stroke-plus" title="Giving strokes">+</span>
          </span>

          <!-- Score -->
          <span
            v-if="getScore(player, h, scoreMode) !== null"
            class="hole-score"
            :class="scoreClass(player, h, scoreMode)"
          >
            {{ getScore(player, h, scoreMode) }}
          </span>
          <span v-else class="placeholder">—</span>

          <!-- CTP -->
          <span
            v-if="prizeView && getScore(player, h, scoreMode) !== null && hasCTP(getHole(player, h))"
            class="ctp-badge"
            title="Closest to the Pin"
          >
            ⛳
          </span>
        </td>

        <td class="total-col" :class="{ 'total-under-par': backTotal(player) < backNinePar }">
          {{ backTotal(player) ?? '—' }}
        </td>

        <td class="total-col" :class="{ 'total-under-par': totalUnderPar(roundTotal(player)) }">
          {{ roundTotal(player) ?? '—' }}
        </td>

        <td class="payout-col">
          {{ formatCurrency(totalPayout(player)) }}
        </td>
      </tr>
    </tbody>

    <tfoot>
      <tr class="index-row">
        <th class="rank-col"></th>
        <th class="player-col">Index (M)</th>
        <th></th>
        <td v-for="h in frontNine" :key="'imf' + h">
          {{ idxMenFor(h) ?? '—' }}
        </td>
        <td></td>
        <td v-for="h in backNine" :key="'imb' + h">
          {{ idxMenFor(h) ?? '—' }}
        </td>
        <td></td>
        <td></td>
        <td></td>
      </tr>

      <tr class="index-row">
        <th class="rank-col"></th>
        <th class="player-col">Index (W)</th>
        <th></th>
        <td v-for="h in frontNine" :key="'iwf' + h">
          {{ idxWomenFor(h) ?? '—' }}
        </td>
        <td></td>
        <td v-for="h in backNine" :key="'iwb' + h">
          {{ idxWomenFor(h) ?? '—' }}
        </td>
        <td></td>
        <td></td>
        <td></td>
      </tr>
    </tfoot>
  </table>
</template>

<style scoped>
/* =========================================================
   Base
========================================================= */
.player-name {
  font-weight: 700;
}

.scorecard {
  width: max-content;
  min-width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}

.scorecard th,
.scorecard td {
  border: 1px solid #e5e7eb;
  padding: 6px 8px;
  text-align: center;
  white-space: nowrap;
  box-sizing: border-box;
}

/* =========================================================
   Header
========================================================= */
.scorecard th {
  background: #f9fafb;
  font-weight: 700;
  color: #111827;
}

/* =========================================================
   Sticky columns (NO custom background)
========================================================= */
.rank-col {
  width: 32px;
  min-width: 32px;
  max-width: 32px;
  font-weight: 600;
}

.scorecard th.rank-col,
.scorecard td.rank-col {
  position: sticky;
  left: 0;
  z-index: 4;
  box-shadow:
    inset 1px 0 0 #e5e7eb,   /* left edge */
    inset -1px 0 0 #e5e7eb;  /* right edge */
}

.scorecard th.player-col,
.scorecard td.player-col {
  position: sticky;
  left: 32px;
  z-index: 3;
  text-align: left;
  box-shadow: 1px 0 0 rgba(0, 0, 0, 0.06);
  
}

/* =========================================================
   Body rows
========================================================= */
.scorecard tbody tr td {
  background: #ffffff;
  color: #111827;
}

.scorecard tbody tr:hover td {
  background: #f3f4f6;
}

/* =========================================
   Player row hover highlight (LEFT BLUE BAR)
========================================= */

/* Ensure the player column is sticky */
.player-col {
  position: sticky;
  left: 0;
  background: white;
  z-index: 3;
}

/* Create the hover rail */
.player-col::before {
  content: "";
  position: absolute;
  left: 0;
  top: 0;
  width: 2px;
  height: 100%;
  background: transparent;
  transition: background-color 120ms ease;
}

/* Activate on row hover */
.scorecard tbody tr:hover .player-col::before {
  background-color: #3b82f6; /* Tailwind blue-500 */
}


/* =========================================================
   Dark mode — PAPER STAYS WHITE
========================================================= */
@media (prefers-color-scheme: dark) {
  /* Borders slightly stronger for contrast */
  .scorecard th,
  .scorecard td {
    border-color: #d1d5db;
  }

  /* Text remains dark-on-white */
  .scorecard th {
    background: #f9fafb;
    color: #111827;
  }

  .scorecard tbody tr td {
    background: #ffffff;
    color: #111827;
  }

  /* Hover remains subtle */
  .scorecard tbody tr:hover td {
    background: #f3f4f6;
  }

  /* Sticky divider shadow tuned for dark chrome */
  .scorecard th.player-col,
  .scorecard td.player-col {
    box-shadow: 0.5px 0 0 rgba(0, 0, 0, 0.12);
  }
}

.scorecard tbody tr td.total-under-par {
  color: #dc2626;
  font-weight: 800;
}

/* =========================================================
   Column sizing
========================================================= */
.hole-col {
  width: 32px;
  position: relative;
}

.total-col {
  width: 42px;
  font-weight: 600;
}

.total-col-in {
  width: 42px;
  font-weight: 800;
}

.placeholder {
  color: #9ca3af;
}

/* =========================================================
   PAR / Index rows
========================================================= */
.par-row th,
.par-row td {
  background: #f3f4f6;
  color: #6b7280;
  border-bottom: 1px solid #e5e7eb;
}

.index-row th,
.index-row td {
  background: #fafafa;
  color: #6b7280;
  font-size: 12px;
}

.index-row th:nth-child(2) {
  text-align: left;
  padding-left: 12px;
}

/* =========================================================
   Footer
========================================================= */
tfoot tr:first-child th,
tfoot tr:first-child td {
  border-top: 2px solid #e5e7eb;
}

/* =========================================================
   Tee column
========================================================= */
.tee-col {
  width: 28px;
  text-align: center;
}

.tee-badge {
  display: inline-block;
  width: 14px;
  height: 14px;
  border-radius: 2px;
}

/* =========================================================
   Hole score styling
========================================================= */
.hole-score {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  line-height: 1;
}

.score-birdie {
  border: 1.5px solid #22c55e;
  border-radius: 50%;
}

.score-eagle {
  position: relative;
  border: 1.5px solid #16a34a;
  border-radius: 50%;
}
.score-eagle::after {
  content: '';
  position: absolute;
  inset: 1.3px;
  border: 1.5px solid #16a34a;
  border-radius: 50%;
}

.score-bogey {
  border: 1px solid #9ca3af;
  border-radius: 3px;
}

.score-dbl-bogey-plus {
  position: relative;
  border: 1px solid #9ca3af;
  border-radius: 3px;
}
.score-dbl-bogey-plus::after {
  content: '';
  position: absolute;
  inset: 1.5px;
  border: 1px solid #9ca3af;
  border-radius: 2px;
}

/* =========================================================
   Stroke indicators
========================================================= */
.stroke-indicator {
  position: absolute;
  top: 2px;              /* visual offset from top border */
  left: 50%;
  transform: translateX(-50%);
  line-height: 1;
  pointer-events: none;
}

.stroke-dots {
  font-size: 4px;
  line-height: 1;
  display: block;
  color: #870909;
  opacity: 0.5;
}

.stroke-plus {
  font-size: 7px;
  line-height: 1;
  font-weight: 600;
  display: block;
  color: #023ec0;
  opacity: 0.5;
}

/* =========================================================
   CTP
========================================================= */
.ctp-badge {
  position: absolute;
  bottom: 1px;
  right: 1px;
  font-size: 18px;
  pointer-events: none;
}

/* =========================================================
   Prize badges
========================================================= */
.badge {
  display: inline-flex;
  gap: 4px;
  margin-left: 8px;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 700;
  border-radius: 999px;
}

.badge.low-net {
  background: #eb253fd9;
  color: #ffffff;
}

.badge.low-gross {
  font-size: 18px;
  padding: 0;
  background: transparent;
}

/* =========================================================
   Skins
========================================================= */
.scorecard td.gross-skin,
.scorecard td.net-skin,
.scorecard td.both-skins {
  background-size: 3px 3px !important;
  background-position: 0 0, 1.5px 1.5px !important;
}

.scorecard td.gross-skin {
  background-color: #c1f873 !important;
}

.scorecard td.net-skin {
  background-color: #52b9fd80 !important;
}

.scorecard td.both-skins {
  background-color: #b61604ed !important;
}

.scorecard td.both-skins .hole-score {
  color: #ffffff !important;
  font-weight: 700;
}

/* =========================================================
   FINAL 4 NET
========================================================= */
.final4 {
  box-shadow: inset 0 2px 0 #2563eb, inset 0 -2px 0 #2563eb;
}
.final4.first {
  box-shadow:
    inset 2px 0 0 #2563eb,
    inset 0 2px 0 #2563eb,
    inset 0 -2px 0 #2563eb;
}
.final4.last {
  box-shadow:
    inset -2px 0 0 #2563eb,
    inset 0 2px 0 #2563eb,
    inset 0 -2px 0 #2563eb;
}
</style>

