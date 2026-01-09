<!-- src/components/stats/StatsTable.vue -->
<script setup>
import { ref, computed, watch } from 'vue'

/* ========================
   Props
======================== */
const props = defineProps({
  rows: { type: Array, required: true },
  mode: {
    type: String,
    default: 'player',
    validator: v => ['player', 'hole'].includes(v)
  }
})

/* ========================
   Sorting
======================== */
const sortKey = ref('total')
const sortDir = ref('asc')

function toggle(key) {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortKey.value = key
    sortDir.value = 'asc'
  }
}

/* Reset default sort when mode changes */
watch(
  () => props.mode,
  () => {
    sortKey.value = 'total'
    sortDir.value = 'asc'
  },
  { immediate: true }
)

const sorted = computed(() => {
  return [...props.rows].sort((a, b) => {
    const k = sortKey.value

    const n1 = toNumber(a[k])
    const n2 = toNumber(b[k])

    if (Number.isNaN(n1) && Number.isNaN(n2)) return 0
    if (Number.isNaN(n1)) return 1
    if (Number.isNaN(n2)) return -1

    const res = n1 > n2 ? 1 : n1 < n2 ? -1 : 0
    return sortDir.value === 'asc' ? res : -res
  })
})


/* ========================
   Helpers
======================== */
function toNumber(v) {
  if (v === null || v === undefined) return NaN
  return Number(String(v).replace('−', '-'))
}

function isNegative(value) {
  return toNumber(value) < 0
}

/* ========================
   Mode-aware labels
======================== */
const firstColLabel = computed(() =>
  props.mode === 'hole' ? 'Hole' : 'Player'
)

const avgLabel = computed(() =>
  props.mode === 'hole' ? 'Avg vs Par' : 'Per Hole'
)

function firstColValue(row) {
  return props.mode === 'hole'
    ? ` ${row.hole}`
    : row.name
}
</script>

<template>
  <div class="table-wrap" :class="`mode-${mode}`">
    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th @click="toggle('hole')">{{ firstColLabel }}</th>
            <th @click="toggle('total')">To Par</th>
            <th @click="toggle('avg')">{{ avgLabel }}</th>
            <th @click="toggle('eagles')">Eagles</th>
            <th @click="toggle('birdies')">Birdies</th>
            <th @click="toggle('pars')">Pars</th>
            <th @click="toggle('bogeys')">Bogeys</th>
            <th @click="toggle('doublePlus')">Bogey+</th>
          </tr>
        </thead>

        <tbody v-if="sorted.length">
          <tr
            v-for="row in sorted"
            :key="row.id || row.name || row.hole"
          >
            <td>{{ firstColValue(row) }}</td>

            <td :class="{ negative: isNegative(row.total) }">
              {{ row.total }}
            </td>

            <td :class="{ negative: isNegative(row.avg) }">
              {{ row.avg }}
            </td>

            <td>{{ row.eagles }}</td>
            <td>{{ row.birdies }}</td>
            <td>{{ row.pars }}</td>
            <td>{{ row.bogeys }}</td>
            <td>{{ row.doublePlus }}</td>
          </tr>
        </tbody>
        <tbody v-else>
          <tr>
            <td colspan="8" style="text-align:center; padding:16px;">
              No data available
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
/* ========================
   Mobile tweaks
======================== */
@media (max-width: 480px) {
  thead th:first-child,
  tbody td:first-child {
    max-width: 130px;
    width: 130px;
  }

  table {
    font-size: 12px;
  }
}

/* ========================
   Outer card
======================== */
.table-wrap {
  background: #ffffff;
  border-radius: 5px;
  border: 1px solid #e5e7eb;
  width: 100%;
  box-sizing: border-box;
}

/* ========================
   Scroll container
======================== */
.table-scroll {
  width: 100%;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

/* ========================
   Table (critical)
======================== */
table {
  border-collapse: collapse;
  width: max-content;
  min-width: 900px;
  font-size: 14px;
}

/* ========================
   Headers
======================== */
th {
  background: #f3f4f6;
  font-weight: 700;
  cursor: pointer;
  padding: 8px 12px;
  text-align: center;
  border-bottom: 1px solid #e5e7eb;
}

/* ========================
   Cells
======================== */
td {
  padding: 9px 12px;
  border-top: 1px solid #e5e7eb;
  text-align: center;
}

tbody tr:hover {
  background: #f9fafb;
}

/* ========================
   First column
======================== */
thead th:first-child,
tbody td:first-child {
  text-align: left;
  white-space: nowrap;
  padding-right: 24px;
}

/* Header first column */
th:first-child {
  font-weight: 700;
}

/* Body first column */
td:first-child {
  font-weight: 700;
}
/* ========================
   Stat columns
======================== */
thead th:not(:first-child),
tbody td:not(:first-child) {
  width: 64px;
  min-width: 64px;
}

/* ========================
   First column sizing
======================== */

/* Default (By Player) */
.mode-player thead th:first-child,
.mode-player tbody td:first-child {
  min-width: 200px;
  max-width: 260px;
}

/* By Hole: tighter column */
.mode-hole thead th:first-child,
.mode-hole tbody td:first-child {
  min-width: 64px;
  max-width: 80px;
  text-align: center;
}


/* ========================
   Negative values
======================== */
.negative {
  color: #dc2626;
  font-weight: 600;
}
</style>
