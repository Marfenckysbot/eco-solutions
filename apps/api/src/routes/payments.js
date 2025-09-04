import { Router } from "express";
import axios from "axios";
import crypto from "crypto";
const r = Router();
const BASE = "https://api.paystack.co";
const SECRET = process.env.PAYSTACK_SECRET_KEY || "";
function paystack(headers = {}) {
  return axios.create({
    baseURL: BASE,
    headers: { Authorization: `Bearer ${SECRET}`, "Content-Type": "application/json", ...headers }
  });
}
r.post("/initialize", async (req, res) => {
  try {
    const { email, amount, metadata } = req.body || {};
    if (!email || !amount) return res.status(400).json({ error: "email and amount required" });
    const callback_url = process.env.PAYSTACK_CALLBACK_URL || `${process.env.BACKEND_URL || "http://localhost:5000"}/api/payments/verify`;
    const { data } = await paystack().post("/transaction/initialize", { email, amount, metadata, callback_url });
    res.json({ authorization_url: data.data.authorization_url, reference: data.data.reference });
  } catch (e) {
    res.status(500).json({ error: "init_failed", details: e.response?.data || e.message });
  }
});
r.get("/verify", async (req, res) => {
  try {
    const ref = req.query.reference;
    if (!ref) return res.status(400).json({ error: "missing reference" });
    const { data } = await paystack().get(`/transaction/verify/${ref}`);
    res.json(data.data);
  } catch (e) {
    res.status(500).json({ error: "verify_failed", details: e.response?.data || e.message });
  }
});
r.post("/webhook", async (req, res) => {
  const signature = req.headers["x-paystack-signature"];
  const payload = JSON.stringify(req.body || {});
  const hash = crypto.createHmac("sha512", SECRET).update(payload).digest("hex");
  if (hash !== signature) return res.status(401).send("invalid signature");
  console.log("Paystack webhook:", req.body?.event, req.body?.data?.reference);
  res.status(200).send("ok");
});
export default r;