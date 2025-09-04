import { Router } from "express";
import axios from "axios";
const r = Router();
const OPENAI_KEY = process.env.OPENAI_API_KEY || "";
r.post("/", async (req, res) => {
  try {
    const { prompt } = req.body;
    const { data } = await axios.post(
      "https://api.openai.com/v1/completions",
      {
        model: "text-davinci-003",
        prompt,
        max_tokens: 100
      },
      { headers: { Authorization: `Bearer ${OPENAI_KEY}` } }
    );
    res.json(data);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});
export default r;
