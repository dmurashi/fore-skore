export function formatCurrency(
  value,
  {
    symbol = '$',
    decimals = 2,
    hideZero = true,
    placeholder = '—'
  } = {}
) {
  const num = Number(value)

  if (!Number.isFinite(num)) return placeholder
  if (hideZero && num === 0) return placeholder

  return `${symbol}${num.toFixed(decimals)}`
}


export function totalPayout(player) {
  let total = 0;

  // round-level competitions
  if (Array.isArray(player.round_competitions)) {
    for (const c of player.round_competitions) {
      total += Number(c.payout || 0);
    }
  }

  // hole-level competitions
  if (player.holes) {
    for (const hole of Object.values(player.holes)) {
      if (Array.isArray(hole.competitions)) {
        for (const c of hole.competitions) {
          total += Number(c.payout || 0);
        }
      }
    }
  }

  return total;
}