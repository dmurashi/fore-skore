export function getFamilyFromHost(host = window.location.hostname) {
  const sub = (host.split('.')[0] || '').toLowerCase()
  // local dev / pages.dev fallbacks:
  if (sub === 'localhost' || sub.includes('pages')) return 'madmen' // pick your default
  return sub
}