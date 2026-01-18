export function getFamilyFromHost(host = window.location.hostname) {
  const sub = (host.split(".")[0] || "").toLowerCase();
  return sub;
}
