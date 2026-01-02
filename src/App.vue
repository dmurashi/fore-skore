<!-- App.vue -->
<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import EventView from '@/views/EventView.vue'


const eventData = ref<any | null>(null)

onMounted(async () => {
  const mod = await import('@/data/events/madmen-event.json')
  eventData.value = mod.default
})

const playersByFlight = computed(() => {
  if (!eventData.value?.players) return {}

  return Object.values(eventData.value.players).reduce(
    (acc: Record<string, any[]>, player: any) => {
      const flight = player.flight || 'A'
      acc[flight] ||= []
      acc[flight].push(player)
      return acc
    },
    {}
  )
})
</script>

<template>
  <div id="app">
    <div class="app-shell">
      <div v-if="eventData">
        <EventView />
      </div>

      <div v-else>
        Loading...
      </div>
    </div>
  </div>
</template>
