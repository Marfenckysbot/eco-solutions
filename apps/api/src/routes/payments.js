import { Router } from "express";
import axios from "axios";
import crypto from "crypto";
const r = Router();
const BASE = "https://api.paystack.co";
const SECRET = process.env.PAYSTACK_SECRET_KEY || "";
function paystack(headers = {}) {
  return axios.create({
    baseURL: BASE,
    headers: { Authorization: `Bearer ${SECRET}`, ...headers }
  });
}
r.post("/initialize", async (req, res) => {
  try {
    const { data } = await paystack().post("/transaction/initialize", req.body);
    res.json(data);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});
r.get("/verify", async (req, res) => {
  try {
    const { reference } = req.query;
    const { data } = await paystack().get(`/transaction/verify/${reference}`);
    res.json(data);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});
r.post("/webhook", async (req, res) => {
  // Optionally verify signature here
  res.status(200).send("ok");
});
export default r;
