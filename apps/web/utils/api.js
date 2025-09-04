const apiBase = process.env.NEXT_PUBLIC_BACKEND_URL;

export const isPlaceholder = (url) => {
  if (!url) return true;
  return url.includes("placeholder");
};

export const fetchFromAPI = async (endpoint) => {
  if (isPlaceholder(apiBase)) {
    console.warn("⚠️ API URL is a placeholder — skipping real fetch");
    return { ok: false, message: "API not connected yet" };
  }
  const res = await fetch(`${apiBase}${endpoint}`);
  return res.json();
};
