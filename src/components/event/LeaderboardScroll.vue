<!-- LeaderboardScroll.vue -->
<template>
  <div class="leaderboard-scroll" aria-label="Leaderboard scroll area">
    <slot />
  </div>
</template>

<style scoped>
/*
  This element must be the ONLY horizontal overflow boundary.
  It should not allow child intrinsic width (e.g. max-content tables)
  to affect the page / other sections (summary cards).
*/
.leaderboard-scroll {
  overflow-x: auto;
  overflow-y: visible;
  min-width: 0;
  width: 100%;
  -webkit-overflow-scrolling: touch;
  padding-right: 4px;
}

/* Table sizing */
:deep(.scorecard) {
  width: max-content;   /* size to content */
  min-width: 100%;      /* fill container if content is smaller */
  border-collapse: separate;
  border-spacing: 0;
  box-sizing: border-box;
}

/* Prevent wrapping inside cells */
:deep(.scorecard th),
:deep(.scorecard td) {
  white-space: nowrap;
}

</style>
