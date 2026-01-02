<!-- src/components/event/PrizeLegend.vue -->
<template>
  <div class="prize-legend">
    <div class="legend-item">
      <span class="legend-sample both-skins"></span>
      <span>Gross + Net Skin</span>
    </div>

    <div class="legend-item">
      <span class="legend-sample gross-skin"></span>
      <span>Gross Skin</span>
    </div>

    <div class="legend-item">
      <span class="legend-sample net-skin"></span>
      <span>Net Skin</span>
    </div>

    <div class="legend-item">
      <span class="legend-sample final4-box"></span>
      <span>Final 4 Net (15–18)</span>
    </div>

    <div class="legend-item">
      <span class="legend-sample ctp">⛳</span>
      <span>Closest to the Pin</span>
    </div>

    <div class="legend-item">
      <span class="legend-sample ctp">🏅</span>
      <span>Medalist</span>
    </div>
  </div>
</template>

<style scoped>
/* Prize Legend */
.prize-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 12px 18px;
  margin: 10px 0 14px;
  font-size: 12px;
  color: #374151;
}

.legend-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.legend-sample {
  width: 18px;
  height: 18px;
  border-radius: 0px;
  border: 1px solid #e5e7eb;
}

/* SKINS STYLING (legend samples use same classes) */

.gross-skin {
  background-color: #c1f873; 
  background-image:
    radial-gradient(rgba(255, 255, 255, 0.078) 1px, transparent 1px),
    radial-gradient(rgba(0,0,0,0.12) 1px, transparent 1px);
  background-size: 3px 3px;
  background-position: 0 0, 1.5px 1.5px;
}

.net-skin {
  background-color: #52b9fd80; 
  background-image:
    radial-gradient(rgba(255, 255, 255, 0.078) 1px, transparent 1px),
    radial-gradient(rgba(0,0,0,0.12) 1px, transparent 1px);
  background-size: 3px 3px;
  background-position: 0 0, 1.5px 1.5px;
}

.both-skins {
  background-color: #b61604ed; 
  background-image:
    radial-gradient(rgba(255,255,255,0.12) 1px, transparent 1px),
    radial-gradient(rgba(0,0,0,0.12) 1px, transparent 1px);
  background-size: 3px 3px;
  background-position: 0 0, 1.5px 1.5px;
}


/* FINAL 4 outline sample */
.legend-sample.final4-box {
  border: 2px solid #2563eb;
  background: transparent;
}

/* CTP */
.legend-sample.ctp {
  font-size: 14px;
  width: auto;
  height: auto;
  border: none;
}

/* Medal */
.legend-sample.medal {
  font-size: 14px;
  width: auto;
  height: auto;
  border: none;
}
</style>

