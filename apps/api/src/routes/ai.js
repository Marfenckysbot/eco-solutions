import { Router } from "express";
import axios from "axios";
const r = Router();
const OPENAI_KEY = process.env.OPENAI_API_KEY || "";
r.post("/", async (req, res) => {
  try {
    const prompt = req.body?.prompt?.toString()?.slice(0, 2000) || "";
    if (!prompt) return res.status(400).json({ error: "empty prompt" });
    if (!OPENAI_KEY) return res.status(503).json({ error: "missing_openai_key" });
    const { data } = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a helpful assistant for pet care guidance." },
          { role: "user", content: prompt }
        ],
        temperature: 0.4,
        max_tokens: 300
      },
      { headers: { Authorization: `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" } }
    );
    const reply = data?.choices?.[0]?.message?.content || "No reply";
    res.json({ reply });
  } catch (e) {
    res.status(500).json({ error: "ai_failed", details: e.response?.data || e.message });
  }
});
export default r;