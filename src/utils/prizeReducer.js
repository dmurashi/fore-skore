// src/utils/prizeReducer.js

export function buildFlightPrizeSummary(eventJson) {
  const flights = {}

  for (const player of eventJson.players || []) {
    const flight = player.flight
    if (!flight) continue

    if (!flights[flight]) {
      flights[flight] = {
        flight,
        totalPot: 0,
        totalWins: 0,
        per: 0,
        players: [],
      }
    }

    const winMap = {} // type -> { name, entries: [], total }
    let playerTotal = 0
    let winCount = 0

    const ensureBucket = (comp) => {
      if (!winMap[comp.type]) {
        winMap[comp.type] = {
          name: comp.name,
          entries: [],
          total: 0,
        }
      }
      return winMap[comp.type]
    }

    /* ---------- Round-level competitions ---------- */
    for (const comp of player.round_competitions || []) {
      const payout = Number(comp?.payout ?? 0)
      if (!Number.isFinite(payout) || payout <= 0) continue

      const bucket = ensureBucket(comp)

      bucket.entries.push({
        value: comp.value,
        detail: comp.details ?? null,
      })

      bucket.total += payout
      playerTotal += payout
      winCount++
    }

    /* ---------- Hole-level competitions ---------- */
    for (const [holeNum, hole] of Object.entries(player.holes || {})) {
      for (const comp of hole.competitions || []) {
        const payout = Number(comp?.payout ?? 0)
        if (!Number.isFinite(payout) || payout <= 0) continue

        const bucket = ensureBucket(comp)

        bucket.entries.push({
          hole: Number(holeNum),
          detail: comp.details ?? hole.par_result ?? null,
        })

        bucket.total += payout
        playerTotal += payout
        winCount++
      }
    }

    if (playerTotal > 0) {
      flights[flight].players.push({
        name: player.name.trim(),
        total: playerTotal,
        winCount,

        wins: Object.values(winMap)
          .map(w => {
            // HOLE-LEVEL (skins, ctp)
            if (w.entries[0]?.hole !== undefined) {
              const holeParts = w.entries.map(e =>
                e.detail
                  ? `${e.hole} (${e.detail})`
                  : `${e.hole}`
              )
              return `${w.name}: ${holeParts.join(', ')}`
            }

            // ROUND-LEVEL (final four, low total)
            const round = w.entries[0]
            const detailPart = round.detail ? ` (${round.detail})` : ''
            return `${w.name}: ${round.value}${detailPart}`
          })
          .join(', ')
      })

      flights[flight].totalPot += playerTotal
      flights[flight].totalWins += winCount
    }
  }

  /* ---------- Final per-win calculation + sorting ---------- */
  for (const flight of Object.values(flights)) {
    flight.per =
      flight.totalWins > 0
        ? Number((flight.totalPot / flight.totalWins).toFixed(2))
        : 0

    flight.players.sort((a, b) => b.total - a.total)
  }

  return flights
}

/**
 * ✅ Backwards-compatible alias:
 * Your EventView.vue currently imports reducePrizesByFlight(...)
 */
export function reducePrizesByFlight(eventJson) {
  return buildFlightPrizeSummary(eventJson)
}
