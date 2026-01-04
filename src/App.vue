<!-- App.vue -->
<script setup>
// import { ref, onMounted, computed } from 'vue'
import EventView from '@/views/EventView.vue'

import eventLogo from '@/assets/logos/madmen-mvcc.png'

</script>

<template>
  <div class="app-shell">
    <header class="site-header">
      <img
        :src="eventLogo"
        alt="MadMen – Moon Valley Country Club"
        class="site-logo"
      />
    </header>

    <main class="main-content">
      <EventView />
    </main>

    <footer class="site-footer">
      © {{ new Date().getFullYear() }} Fore-Skore Golf Solutions.
      All rights reserved. A DGMDomains project.
    </footer>
  </div>
</template>


<style scoped>
  .site-footer {
  max-width: 1200px;
  margin: 48px auto 24px auto; /* center horizontally */
  padding: 16px 24px;

  font-size: 12px;
  text-align: center;
  letter-spacing: 0.02em;

  color: #6b7280;              /* light mode */
  border-top: 1px solid #e5e7eb;
}

.site-header {
  max-width: 1200px;
  margin: 24px auto 12px auto;
  padding: 0 24px;
  text-align: center;
}

.site-logo {
  max-width: 220px;
  width: 100%;
  height: auto;
}

/* Dark mode harmony */
@media (prefers-color-scheme: dark) {
  .site-logo {
    filter: brightness(0.95);
  }
}

.main-content {
  max-width: 100%;
  margin: 0 auto;
  padding: 0;
}


</style>
