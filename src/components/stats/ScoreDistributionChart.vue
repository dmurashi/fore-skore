<!-- src/components/stats/ScoreDistributionChart.vue -->
<script setup>
import { computed, ref, watch, onMounted, onBeforeUnmount } from 'vue'
import Chart from 'chart.js/auto'
import ChartDataLabels from 'chartjs-plugin-datalabels'

Chart.register(ChartDataLabels)

/* ========================
   Props
======================== */
const props = defineProps({
  distribution: {
    type: Object,
    required: true
  }
})

/* ========================
   Chart refs
======================== */
const canvas = ref(null)
let chart = null

/* ========================
   Constants
======================== */
const ORDER = ['Eagle', 'Birdie', 'Par', 'Bogey', 'Double', 'Other']

const COLORS = {
  Eagle: '#16a34a',
  Birdie: '#22c55e',
  Par: '#9ca3af',
  Bogey: '#f97316',
  Double: '#ef4444',
  Other: '#7c2d12'
}

/* ========================
   Derived data
======================== */
const filtered = computed(() =>
  ORDER
    .map(label => ({
      label,
      value: Number(props.distribution[label] ?? 0)
    }))
    .filter(d => d.value > 0)
)

const values = computed(() => filtered.value.map(d => d.value))

const chartData = computed(() => ({
  labels: filtered.value.map(d => d.label),
  datasets: [
    {
      data: values.value,
      backgroundColor: filtered.value.map(d => COLORS[d.label]),
      borderRadius: 4,
      categoryPercentage: 0.8,
      barPercentage: 0.9
    }
  ]
}))

/* ========================
   Render
======================== */
function render() {
  if (!canvas.value) return

  chart?.destroy()

  const max = Math.max(...values.value, 1)

  chart = new Chart(canvas.value, {
    type: 'bar',
    data: chartData.value,
    options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,

        plugins: {
        legend: { display: false },
        tooltip: { enabled: true },
        datalabels: {
            color: '#ffffff',
            anchor: 'center',
            align: 'center',
            font: {
            weight: '700',
            size: 12
            },
            formatter: v => v
          }
        }, // ✅ plugins CLOSED HERE

        layout: {
        padding: {
            top: 4,
            bottom: 4,
            left: 0,
            right: 0
        }
        },

        scales: {
        y: {
            grid: { display: false },
            ticks: {
            font: { size: 12 }
            }
        },
        x: {
            beginAtZero: true,
            max,
            grace: '0%',
            ticks: {
            maxTicksLimit: 4,
            precision: 0,
            font: { size: 11 }
            },
            grid: { drawBorder: false }
        }
        }
    }
  })

}

/* ========================
   Lifecycle
======================== */
onMounted(render)
watch(chartData, render)
onBeforeUnmount(() => chart?.destroy())
</script>

<template>
  <div class="chart-wrapper">
    <canvas ref="canvas" />
  </div>
</template>

<style scoped>
/* ========================
   Chart container
======================== */

/*
  Key principles:
  - Height is explicit and capped
  - Width is controlled by parent grid
  - No scroll
  - No magic row math
*/

.chart-wrapper {
  background: #f9fafb;
  border-radius: 5px;
  padding: 12px;
  height: 260px; /* desktop */
}

@media (max-width: 768px) {
  .chart-wrapper {
    height: 230px; /* ⬅️ was 200 */
  }
}

.chart-wrapper canvas {
  height: 100% !important;
}

</style>
