// src/utils/leaderboardHelpers.js

export function getHole(player, holeNumber) {
  return player?.holes?.[String(holeNumber)] ?? null
}

export function getScore(player, holeNumber, scoreMode) {
  const hole = getHole(player, holeNumber)
  if (!hole) return null
  return scoreMode === 'gross' ? hole.gross : hole.net
}

export function scoreClass(player, holeNumber, scoreMode) {
  const hole = getHole(player, holeNumber)
  if (!hole) return null

  const diff = scoreMode === 'gross' ? hole.gross_diff : hole.net_diff
  if (diff >= 2) return 'score-dbl-bogey-plus'

  const result = scoreMode === 'gross' ? hole.gross_result : hole.net_result
  if (result === 'EAGLE') return 'score-eagle'
  if (result === 'BIRDIE') return 'score-birdie'
  if (result === 'BOGEY') return 'score-bogey'
  return null
}

/**
 * Safe sum helper.
 * - Accepts an array of hole numbers (preferred)
 * - If something else is passed, returns null instead of throwing
 */
export function sumHoles(player, holes, scoreMode) {
  if (!Array.isArray(holes)) return null

  let total = 0
  let hasScore = false

  for (const h of holes) {
    const score = getScore(player, h, scoreMode)
    if (score !== null && score !== undefined) {
      total += Number(score)
      hasScore = true
    }
  }
  return hasScore ? total : null
}

/* ---------- Tee badge ---------- */
export function teeStyle(tee) {
  if (!tee) return {}

  const colors = tee.split('/').map(t => t.trim().toLowerCase())
  const colorMap = {
    black: '#111827',
    blue: '#2563eb',
    white: '#ffffff',
    red: '#fc5a5a',
  }

  if (colors.length === 1) {
    return {
      backgroundColor: colorMap[colors[0]] || '#e5e7eb',
      border: colors[0] === 'white' ? '1px solid #9ca3af' : 'none',
    }
  }

  const c1 = colorMap[colors[0]] || '#e5e7eb'
  const c2 = colorMap[colors[1]] || '#e5e7eb'
  return {
    background: `linear-gradient(135deg, ${c1} 50%, ${c2} 50%)`,
    border: '1px solid #d1d5db',
  }
}

/* ---------- Prize helpers ---------- */
export function hasFinal4(player) {
  return player?.round_competitions?.some(c => c.type === 'FINAL_4_NET')
}
export function hasGrossSkin(hole) {
  return hole?.competitions?.some(c => c.type === 'GROSS_SKINS')
}
export function hasNetSkin(hole) {
  return hole?.competitions?.some(c => c.type === 'NET_SKINS')
}
export function hasBothSkins(hole) {
  return hasGrossSkin(hole) && hasNetSkin(hole)
}
export function hasCTP(hole) {
  return hole?.competitions?.some(c => c.type === 'CTP')
}
export function isLowGrossWinner(player) {
  return player?.gross_rank === 1
}
export function isLowNetWinner(player) {
  return Array.isArray(player?.round_competitions)
    && player.round_competitions.some(c => c.type === 'LOW_NET')
}

export function holeClasses(player, holeNumber, prizeView) {
  const classes = []

  if (prizeView && hasFinal4(player) && holeNumber >= 15 && holeNumber <= 18) {
    classes.push('final4')
    if (holeNumber === 15) classes.push('first')
    if (holeNumber === 18) classes.push('last')
  }

  // 🔑 FIX: hole keys are strings in player.holes
  const hole = getHole(player, holeNumber)
  if (!prizeView || !hole) return classes

  if (hasBothSkins(hole)) classes.push('both-skins')
  else if (hasGrossSkin(hole)) classes.push('gross-skin')
  else if (hasNetSkin(hole)) classes.push('net-skin')

  return classes
}

// dots for strokes received, + for strokes given
export function strokeCount(hole) {
  if (!hole || hole.gross === null || hole.net === null) return 0
  return hole.gross - hole.net
}
export function receivesStrokes(hole) {
  return strokeCount(hole) > 0
}
