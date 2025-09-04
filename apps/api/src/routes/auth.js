import { Router } from "express";
const r = Router();
r.post("/login", async (req, res) => {
  // Dummy login
  res.json({ token: "dummy-token", user: { email: req.body.email } });
});
export default r;
