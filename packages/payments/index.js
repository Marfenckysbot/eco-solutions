export function formatNairaKobo(naira) {
  return "₦" + Number(naira).toLocaleString("en-NG", { minimumFractionDigits: 2 });
}
