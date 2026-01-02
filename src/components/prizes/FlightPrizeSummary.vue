<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import FlightPrizeSummaryDesktop from './FlightPrizeSummaryDesktop.vue'
import FlightPrizeSummaryMobile from './FlightPrizeSummaryMobile.vue'


const props = defineProps({
  flightName: { type: String, required: true },
  playerCount: { type: Number, required: true },
  summary: { type: Object, required: true },
})

const isMobile = ref(false)

function updateIsMobile() {
  isMobile.value = window.matchMedia('(max-width: 768px)').matches
}

onMounted(() => {
  updateIsMobile()
  window.addEventListener('resize', updateIsMobile)
})
onBeforeUnmount(() => window.removeEventListener('resize', updateIsMobile))
</script>

<template>
  <FlightPrizeSummaryMobile
    v-if="isMobile"
    :flight-name="flightName"
    :player-count="playerCount"
    :summary="summary"
  />

  <FlightPrizeSummaryDesktop
    v-else
    :flight-name="flightName"
    :player-count="playerCount"
    :summary="summary"
  />
</template>
